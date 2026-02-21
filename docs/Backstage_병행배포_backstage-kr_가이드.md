# Backstage 병행 배포 가이드 (`backstage-kr`)

## 목적

기존 `backstage` 인스턴스는 유지한 상태에서, 커스텀 이미지를 사용하는 신규 Backstage를
`backstage-kr` 네임스페이스로 병행 배포한다.

## 배경

운영 중인 기본 Backstage(`namespace: backstage`)를 즉시 교체하면 리스크가 크다.
따라서 신규 인스턴스를 별도 네임스페이스로 분리해 검증 후 전환 가능하도록 구성했다.

## 적용된 구성 변경

### 배포 방식 개요 (backstage-kr)

`backstage-kr`는 수동 `kubectl apply` 방식이 아니라, 기존 IDP와 동일한 **Argo CD + ApplicationSet(Addons)** 경로로 배포된다.

적용 흐름:

1. `packages/addons/values.yaml`에 `backstage-kr` addon 정의
2. bootstrap가 생성한 addons ApplicationSet이 해당 정의를 읽어 Application 생성
3. Application이 Backstage Helm Chart를 배포
4. 동시에 `packages/backstage-kr/manifests`, `packages/backstage-kr/path-routing`의 추가 매니페스트를 동기화
5. 결과적으로 `backstage-kr` 네임스페이스에 앱/시크릿/설정 리소스가 생성

즉, 운영자가 직접 리소스를 개별 적용하지 않아도 Git 변경 -> Argo CD Sync로 일관되게 반영된다.

### 1) Addons에 신규 앱 추가

- 파일: `packages/addons/values.yaml`
- 신규 키: `backstage-kr`
- 주요 값:
  - `chartName: backstage`
  - `namespace: backstage-kr`
  - `releaseName: backstage-kr`
  - `valueFiles: ["values-kr.yaml"]`
  - Ingress host: `backstage-kr.<domain>` (non path-routing)
  - 추가 리소스 경로: `packages/backstage-kr/manifests`

### 2) path-routing 오버레이 추가

- 파일: `packages/addons/path-routing-values.yaml`
- `backstage-kr` 추가
- 경로:
  - `packages/backstage-kr/manifests`
  - `packages/backstage-kr/path-routing`

### 3) Argo CD AppProject 대상 네임스페이스 허용

- 파일: `packages/argo-cd/manifests/appproject-cnoe.yaml`
- 추가:
  - `namespace: backstage-kr`

### 4) 신규 Backstage 전용 values 분리

- 파일: `packages/backstage/values-kr.yaml`
- 목적:
  - 기존 `packages/backstage/values.yaml`와 충돌 없이 신규 인스턴스 오버레이
- 포함:
  - TLS secret 이름 분리: `backstage-kr-server-tls`
  - 앱 타이틀/조직명 커스터마이징
  - 이미지 태그 지정(필요 시 커스텀 태그로 교체)

### 5) 신규 네임스페이스 전용 매니페스트 분리

- 디렉터리: `packages/backstage-kr/`
- 파일:
  - `manifests/external-secrets.yaml`
  - `manifests/k8s-config-secret.yaml`
  - `path-routing/default-cert-external-secret.yaml`
- 핵심:
  - 모든 네임스페이스를 `backstage-kr`로 고정
  - 기존 `backstage` 리소스와 Secret 충돌 방지

## 왜 이렇게 분리했는가 (원인-해결)

### 원인

기존 `backstage` 패키지의 매니페스트는 네임스페이스가 하드코딩(`backstage`)되어 있어,
동일 리소스를 재사용하면 신규 앱이 기존 리소스를 덮어쓰거나 충돌할 수 있다.

### 해결

신규 앱 전용 패키지 경로(`packages/backstage-kr`)를 만들고,
Argo CD ApplicationSet에서 해당 경로를 별도로 읽게 구성했다.

결과적으로 기존 인스턴스와 신규 인스턴스가 서로 독립적으로 동작한다.

## 배포/검증 절차

### 1) 변경 반영

```bash
git add packages/addons/values.yaml \
        packages/addons/path-routing-values.yaml \
        packages/argo-cd/manifests/appproject-cnoe.yaml \
        packages/backstage/values-kr.yaml \
        packages/backstage-kr
git commit -m "feat(backstage): add parallel deployment in backstage-kr namespace"
git push
```

### 2) Argo CD 동기화 확인

```bash
kubectl get applications -n argocd | grep backstage
```

확인 포인트:
- 기존 `backstage-<cluster>` 앱은 유지
- 신규 `backstage-kr-<cluster>` 앱 생성

### 3) 리소스 확인

```bash
kubectl get all -n backstage
kubectl get all -n backstage-kr
kubectl get externalsecret -n backstage-kr
```

### 4) 접속 확인

- non path-routing: `https://backstage-kr.<domain>`
- path-routing: `https://<domain>/kr/`

### 5) 경로 라우팅 동작 정리

path-routing(`path_routing=true`) 기준:

- `https://<domain>/` -> 기존 `backstage` 인스턴스
- `https://<domain>/kr/` -> 신규 `backstage-kr` 인스턴스

Ingress는 경로가 더 구체적인 규칙(`/kr/`)을 우선 매칭하므로, `/kr/` 요청은 `backstage-kr`로 라우팅된다.
또한 path-routing 시 ingress rewrite(`/kr/...` -> `/...`)를 적용해 Backstage 앱 내부 404를 방지한다.

적용된 ingress 예외처리(핵심):

- `path: /kr(/|$)(.*)`
- `nginx.ingress.kubernetes.io/use-regex: "true"`
- `nginx.ingress.kubernetes.io/rewrite-target: "/$2"`

주의:
- 현재 backstage chart 스키마에서는 `ingress.pathType` 필드를 허용하지 않으므로 사용하지 않는다.

설정 위치:

- 주 설정: `packages/addons/values.yaml` (`backstage-kr.valuesObject.ingress`)
- path-routing 오버레이(`packages/addons/path-routing-values.yaml`)에서는 `backstage-kr`의 추가 리소스 경로만 유지

## /kr/ 404 트러블슈팅

증상:
- `https://<domain>/kr/` 접속 시 404

원인:
- `/kr/` 경로가 앱으로 전달될 때 rewrite가 없거나 정규식 path 매칭이 누락된 경우

확인 명령:

```bash
kubectl get ingress -n backstage-kr -o yaml | egrep -n "path:|pathType:|rewrite-target|use-regex"
kubectl get applications -n argocd | grep backstage-kr
kubectl get pods -n backstage-kr
```

정상 기대값:
- ingress path가 `/kr(/|$)(.*)`
- `rewrite-target: /$2` 존재

## 운영 주의사항

1. Keycloak redirect URI에 path-routing URL(`https://<domain>/kr/*`)이 허용되어야 한다.
2. 커스텀 이미지 태그는 `packages/backstage/values-kr.yaml`에서 관리한다.
3. 기존 `backstage` 제거는 신규 인스턴스 안정화 후 별도 변경으로 진행한다.

## 데이터 연동/분리

- `backstage`와 `backstage-kr`는 각각 별도 네임스페이스와 별도 PostgreSQL(별도 PVC/DB)을 사용한다.
- 따라서 애플리케이션 내부 데이터(사용자 설정, 처리 이력, DB 저장 데이터)는 기본적으로 분리된다.
- 단, 외부 연동 대상은 일부 동일하다.
  - 동일 Keycloak realm/client 정책을 사용하면 로그인 체계는 유사하게 동작할 수 있다.
  - 동일 GitHub/Argo CD/클러스터를 바라보면 카탈로그 엔티티나 플러그인 화면의 대상은 겹쳐 보일 수 있다.
