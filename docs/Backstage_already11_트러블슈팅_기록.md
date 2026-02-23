# Backstage-kr 트러블슈팅 기록

## 어디에 문서화해야 하는가

이번 이슈의 중심은 Backstage 앱 코드가 아니라 다음 운영/배포 레이어였다.

- Argo CD ApplicationSet
- addons values merge
- Ingress path-routing
- cluster secret annotation/revision

따라서 **주 문서는 `reference-implementation-aws/docs`에 작성**하는 것이 맞다.
`backstage-already11`은 이미지/앱 코드 관점 메모만 유지한다.

## 요약

문제는 크게 3가지였다.

1. `/kr/` 접속 시 기존 backstage로 라우팅되거나 404
2. `backstage-already11` 앱에서 `ComparisonError` 발생
3. `Application` 삭제 후 재생성/동기화가 꼬임

핵심 원인:

- `ingress.pathType`를 backstage chart values에 넣어 schema 검증 실패
- Argo CD 상위 앱(`addons-appset-pr-*`)이 동일 repo를 서로 다른 revision(`main` vs SHA)으로 참조하는 stale operation 상태

현재 운영 결론:
- `/kr` 경로 방식은 사용하지 않고, `https://bs.<domain>` 서브도메인 방식으로 고정

## 1) 증상: `/kr/` 접속 시 기존 backstage 또는 404

### 확인 명령

```bash
kubectl get ingress -A -o yaml | egrep -n "name: backstage-already11|host: sesac.already11.cloud|path: /kr|rewrite-target|use-regex"
```

### 기대값

- `path: /kr(/|$)(.*)`
- `nginx.ingress.kubernetes.io/use-regex: "true"`
- `nginx.ingress.kubernetes.io/rewrite-target: /$2`

### 조치

`packages/addons/values.yaml`의 `backstage-already11.valuesObject.ingress`를 아래와 같이 유지:

- `path: /kr(/|$)(.*)` (path-routing일 때)
- `use-regex: true`
- `rewrite-target: /$2`

주의:
- backstage chart 스키마에서 `ingress.pathType`는 허용되지 않으므로 넣지 않는다.

## 2) 증상: ComparisonError (`Additional property pathType is not allowed`)

### 에러 예시

- `Error: values don't meet the specifications ... ingress: Additional property pathType is not allowed`

### 원인

- `pathType`가 chart schema에 없는 값으로 전달됨

### 조치

레포 전체에서 `backstage-already11` 관련 `pathType` 제거 후 재동기화.

검증:

```bash
kubectl -n argocd get app backstage-already11-sesac-ref-impl -o yaml | grep -n pathType
```

정상: 출력 없음

## 3) 증상: ComparisonError (`cannot reference a different revision of the same repository`)

### 에러 예시

- `$values references "main" ... while the application references "080c3e..."`

### 원인

- `addons-appset-pr-sesac-ref-impl`의 오래된 sync operation이 SHA 리비전을 재시도하면서,
  현재 spec(`main`)과 충돌

### 확인 명령

```bash
kubectl -n argocd describe app addons-appset-pr-sesac-ref-impl | egrep -i "ComparisonError|cannot reference a different revision|Message" -n
kubectl -n argocd get app addons-appset-pr-sesac-ref-impl -o yaml | grep -n targetRevision
kubectl -n argocd get secret hub-cluster -o jsonpath='{.metadata.annotations.addons_repo_revision}{"\n"}'
```

### 최종 복구 절차

```bash
# 1) cluster secret revision 확인 (main 권장)
kubectl -n argocd get secret hub-cluster -o jsonpath='{.metadata.annotations.addons_repo_revision}{"\n"}'

# 2) 상위 앱 hard refresh
kubectl -n argocd annotate application addons-appset-pr-sesac-ref-impl argocd.argoproj.io/refresh=hard --overwrite

# 3) stale operation 제거를 위해 상위 앱 재생성
kubectl -n argocd delete application addons-appset-pr-sesac-ref-impl

# 4) 재생성 확인
kubectl -n argocd get application addons-appset-pr-sesac-ref-impl -o wide
kubectl -n argocd get applicationset backstage-already11
kubectl -n argocd get application backstage-already11-sesac-ref-impl -o wide
```

정상 상태 예:
- `addons-appset-pr-sesac-ref-impl`: `Synced / Healthy`
- `applicationset backstage-already11`: 존재
- `application backstage-already11-sesac-ref-impl`: 생성됨

## 4) Application 삭제가 멈춘 것처럼 보일 때

### 원인

- Argo CD finalizer로 인해 삭제가 대기 상태

### 조치

```bash
kubectl -n argocd get application backstage-already11-sesac-ref-impl -o yaml | egrep -n "deletionTimestamp|finalizers"
kubectl -n argocd patch application backstage-already11-sesac-ref-impl --type merge -p '{"metadata":{"finalizers":[]}}'
```

## 5) 노드 0 -> 재확장 후 Keycloak 로그인 타임아웃

증상:

- `RPError: outgoing request timed out after 10000ms`

원인:

- 노드 재기동 직후 Keycloak/Ingress 준비 지연

즉시 복구:

```bash
kubectl get pods -A | egrep -i "keycloak|backstage|ingress-nginx"
kubectl -n keycloak rollout restart statefulset/keycloak
kubectl -n backstage rollout restart deployment/backstage
kubectl -n backstage-already11 rollout restart deployment/backstage-already11
```

## 최종 기대 동작

- `https://sesac.already11.cloud/` -> 기존 `backstage`
- `https://bs.sesac.already11.cloud/` -> `backstage-already11`

검증:

```bash
kubectl -n backstage-already11 get ingress backstage-already11 -o yaml | egrep -n "path:|rewrite-target|use-regex|host:"
```

## 최종 원인 정리 (이번 장애의 실제 순서)

1. `/kr/` 경로 라우팅 미완성
- `backstage-already11` ingress가 초기에 `/kr/` regex/rewrite 없이 적용되어
  `/kr/` 요청이 기존 backstage로 가거나 404가 발생.

2. chart schema 불일치
- `backstage` chart values에 `ingress.pathType`를 넣어
  `Additional property pathType is not allowed` ComparisonError 발생.

3. Argo CD 리비전 충돌
- 동일 repo를 `main`과 고정 SHA(`080c3e...`)로 혼용 참조하는 stale operation 때문에
  `cannot reference a different revision of the same repository` 에러 반복.
- 결과적으로 `backstage-already11` ApplicationSet/Application 재생성이 지연/실패.

4. DB 인증/연결 연쇄 이슈
- 재생성 과정에서 `POSTGRES_PASSWORD`와 기존 DB 상태가 어긋나
  `password authentication failed`.
- 이후에는 PostgreSQL 워크로드/엔드포인트 불안정으로 `ECONNREFUSED`가 반복.

## 실제 복구 절차 (실행한 명령 중심)

### A. Argo CD 상위 앱 정상화

```bash
kubectl -n argocd annotate application addons-appset-pr-sesac-ref-impl argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd delete application addons-appset-pr-sesac-ref-impl
kubectl -n argocd get application addons-appset-pr-sesac-ref-impl -o wide
kubectl -n argocd get applicationset backstage-already11
kubectl -n argocd get application backstage-already11-sesac-ref-impl -o wide
```

### B. `/kr/` 라우팅 고정

(`packages/addons/values.yaml` 기준)
- `path: /kr(/|$)(.*)`
- `use-regex: true`
- `rewrite-target: /$2`
- `pathType` 미사용

검증:

```bash
kubectl -n backstage-already11 get ingress backstage-already11 -o yaml | egrep -n "path:|rewrite-target|use-regex|host:"
```

### C. DB 복구 및 안정화

```bash
# 기존 깨진 Postgres 상태 제거
kubectl -n backstage-already11 delete statefulset backstage-already11-postgresql
kubectl -n backstage-already11 delete pvc data-backstage-already11-postgresql-0

# 앱 재동기화/재기동
kubectl -n argocd patch application backstage-already11-sesac-ref-impl --type merge -p '{"operation":{"sync":{"prune":true,"syncStrategy":{"apply":{}}}}}'
kubectl -n backstage-already11 rollout restart deployment backstage-already11
kubectl -n backstage-already11 rollout status deployment backstage-already11 --timeout=180s
```

최종 검증:

```bash
kubectl -n backstage-already11 get pods
kubectl -n backstage-already11 get endpoints backstage-already11-postgresql -o yaml
kubectl -n backstage-already11 logs deployment/backstage-already11 --tail=140
```

정상 기준:
- `backstage-already11` 1/1 Running
- `backstage-already11-postgresql-0` 1/1 Running
- readiness probe `200`
- DB 관련 `password authentication failed` / `ECONNREFUSED` 로그 미발생

## 최종 결과

- `https://sesac.already11.cloud/` -> 기존 `backstage`
- `https://sesac.already11.cloud/kr/` -> `backstage-already11`

두 인스턴스는 네임스페이스/DB가 분리되어 동작하고, 외부 연동(Keycloak/GitHub/ArgoCD)은 공통 구성을 참조한다.
