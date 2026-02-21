# Backstage / Backstage-kr 운영 전환 런북

작성일: 2026-02-22  
대상 환경: `ap-northeast-2`, 클러스터 `sesac-ref-impl`

## 1) 목적

이 문서는 아래 4가지를 한 번에 정리한다.

1. 최근 `backstage-kr` 장애 트러블슈팅(특히 `ErrImagePull`) 원인/해결
2. 현재 `backstage` + `backstage-kr` 병행 운영 구조
3. `backstage-kr`의 관리 방식(GitOps/Argo CD)
4. `backstage-kr` 안정화 후 기존 `backstage`를 대체/정리하는 롤아웃

---

## 2) 최근 장애 트러블슈팅 요약

### 케이스 A: Node.js 20 스캐폴더 에러 (`--no-node-snapshot`)

#### 증상

- `backstage-kr`에서 템플릿 생성 시 아래 에러 발생

```text
When using Node.js version 20 or newer, the scaffolder backend plugin requires that it be started with the --no-node-snapshot option.
Please make sure that you have NODE_OPTIONS=--no-node-snapshot in your environment.
```

#### 원인

- `backstage-kr` 배포 env에 `NODE_OPTIONS=--no-node-snapshot` 누락

#### 해결

- GitOps 값 파일(`packages/addons/values.yaml`)의 `backstage-kr.valuesObject.backstage.extraEnvVars`에 아래 추가:

```yaml
- name: NODE_OPTIONS
  value: "--no-node-snapshot"
```

즉시 반영(임시/수동) 커맨드:

```bash
kubectl -n backstage-kr set env deployment/backstage-kr NODE_OPTIONS=--no-node-snapshot
kubectl -n backstage-kr rollout status deployment/backstage-kr --timeout=180s
```

---

### 케이스 B: `ImagePullBackOff` (`no match for platform`)

### 증상

- `backstage-kr` 파드가 `ImagePullBackOff`
- 이벤트:
  - `no match for platform in manifest: not found`

예시 확인 명령어:

```bash
kubectl -n backstage-kr describe pod <pod-name> | egrep -i "Failed|ErrImagePull|ImagePullBackOff|manifest|platform"
```

### 원인

- 태그 `1.0.0`가 ECR에 존재했지만, 클러스터 노드 아키텍처(`linux/amd64`)에 맞는 매니페스트가 없었음
- 로컬(Mac arm64)에서 푸시된 이미지 태그를 그대로 사용하면서 발생

### 해결

`backstage-app` 레포에서 `linux/amd64`로 재빌드/재푸시:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t 710232982381.dkr.ecr.ap-northeast-2.amazonaws.com/backstage-app:1.0.0 \
  --push \
  .
```

검증:

```bash
docker buildx imagetools inspect 710232982381.dkr.ecr.ap-northeast-2.amazonaws.com/backstage-app:1.0.0
aws ecr describe-images \
  --repository-name backstage-app \
  --region ap-northeast-2 \
  --profile cnoe-ref-impl \
  --image-ids imageTag=1.0.0
```

### 관련 코드 반영

- 이미지 참조값: `reference-implementation-aws/packages/backstage/values-kr.yaml`
  - `registry: 710232982381.dkr.ecr.ap-northeast-2.amazonaws.com`
  - `repository: backstage-app`
  - `tag: 1.0.0`
- 빌드 안정화(스크립트/빌드도구): `backstage-app/Dockerfile`
  - `stage-2`에서 `scripts` 복사
  - Python/build-essential 보강

---

## 3) 현재 병행 운영 구조 (backstage + backstage-kr)

### 서비스 엔드포인트

- 기존: `https://sesac.already11.cloud` (경로 라우팅 시 루트)
- 신규: `https://backstage-kr.sesac.already11.cloud`

### 네임스페이스 분리

- 기존: `backstage`
- 신규: `backstage-kr`

### 앱 정의/소스

- `packages/addons/values.yaml`
  - `backstage` 블록
  - `backstage-kr` 블록 (`namespace: backstage-kr`, `releaseName: backstage-kr`)
- `packages/backstage/values-kr.yaml`
  - `backstage-kr`용 이미지/타이틀/TLS 값
- `packages/backstage-kr/manifests/*`
  - `ExternalSecret`, `k8s-config-secret` 등 부가 리소스

### 인증/연동

- Keycloak 클라이언트 `backstage`의 redirect/webOrigins에
  - 기존 backstage 도메인
  - `backstage-kr.<domain>`
  를 모두 허용하도록 구성
  - 근거: `packages/keycloak/manifests/user-sso-config-job.yaml`

즉, 두 UI는 동시에 떠 있지만 인증 소스(Keycloak realm/client 정책)는 같은 체계를 공유한다.

---

## 4) backstage-kr 관리 방식 (수동 배포 아님)

`backstage-kr`는 수동 `kubectl apply`가 아니라 Argo CD(ApplicationSet)로 관리한다.

1. `bootstrap`에서 `addons-appset` 또는 `addons-appset-pr`가 생성됨  
   - `packages/bootstrap/values.yaml`
2. 해당 AppSet이 클러스터 메타데이터를 읽어 addon별 `Application` 생성
3. `backstage-kr-<cluster>` Application이 생성/동기화
4. Helm(`backstage` chart + `values-kr.yaml`) + 추가 매니페스트(`packages/backstage-kr/manifests`) 적용

운영자가 실제로 보는 오브젝트:

- `ApplicationSet`: `addons-appset*`
- `Application`: `backstage-kr-sesac-ref-impl`

---

## 5) 운영 체크리스트 (안정화 기준)

아래를 연속 2~3일 이상 만족하면 대체 준비 완료로 본다.

1. `kubectl -n backstage-kr get pods`가 지속적으로 `Running`
2. 로그인/로그아웃, Catalog 조회, Scaffolder 생성이 정상
3. GitHub 연동(템플릿 생성/PR/Repo 생성)이 정상
4. Argo CD에서 `backstage-kr-*`가 `Synced/Healthy` 유지
5. `backstage-kr` 에러 로그 급증 없음

추천 점검 명령어:

```bash
kubectl -n backstage-kr get pods
kubectl -n backstage-kr logs deploy/backstage-kr --tail=200
kubectl -n argocd get applications | egrep "backstage|addons-appset"
```

---

## 6) 기존 backstage 대체 롤아웃 (권장 절차)

### 6.1 Phase 0 - 사전 고정

- `backstage-kr` 이미지 태그를 고정(`1.0.0`처럼)
- 운영 공지: 신규 접속 URL 우선 사용

### 6.2 Phase 1 - 트래픽 전환

- 사용자 기본 안내 URL을 `https://backstage-kr.sesac.already11.cloud`로 전환
- 기존 `https://sesac.already11.cloud`는 일시 유지(롤백용)

### 6.3 Phase 2 - 기존 backstage 비활성화(권장: GitOps)

`reference-implementation-aws/packages/addons/values.yaml`에서 기존 `backstage`를 끈다.

```yaml
backstage:
  enabled: false
```

그 후:

```bash
git add packages/addons/values.yaml
git commit -m "chore(backstage): disable legacy backstage after backstage-kr stabilization"
git push
```

Argo 동기화 후 확인:

```bash
kubectl -n argocd get applications | grep backstage
kubectl get ns | egrep "backstage$|backstage-kr$"
```

필요 시 잔여 리소스 점검:

```bash
kubectl get all -n backstage
kubectl get ingress -A | grep backstage
```

### 6.4 Phase 3 - 정리

- 레거시 `backstage` 네임스페이스의 잔여 리소스가 없음을 확인
- 문서/운영 Runbook의 기본 URL을 `backstage-kr`로 교체

---

## 7) 롤백 전략

전환 후 이슈 발생 시:

1. `packages/addons/values.yaml`에서 `backstage.enabled: true` 복구
2. push + Argo sync
3. 안내 URL을 기존 `https://sesac.already11.cloud`로 되돌림

핵심: `backstage-kr` 제거 전에 기존 `backstage`를 즉시 복원 가능한 상태로 유지한다.

---

## 8) 재발 방지 규칙

1. 이미지 태그 재사용 금지 (`1.0.0` 덮어쓰기 지양, `1.0.1` 사용)
2. EKS 대상 이미지는 항상 `linux/amd64` 확인 후 배포
3. 배포 전 아래 2개를 릴리즈 체크리스트에 고정:

```bash
docker buildx imagetools inspect <image:tag>
kubectl -n backstage-kr describe pod <new-pod> | egrep -i "ImagePull|platform|manifest|denied"
```
