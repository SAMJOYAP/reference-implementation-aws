# AWS Reference Implementation - 상세 트러블슈팅 가이드

> 실제 배포 과정에서 발생한 문제들과 해결 방법을 정리한 문서입니다.

## 📋 목차

1. [ExternalSecret 리전 불일치 (CRITICAL)](#1-externalsecret-리전-불일치-critical)
2. [Keycloak 이미지 Pull 실패](#2-keycloak-이미지-pull-실패)
3. [kubectl 다운로드 URL 오류](#3-kubectl-다운로드-url-오류)
4. [DNS Name Server 설정](#4-dns-name-server-설정)
5. [eksctl Pod Identity Associations 오류](#5-eksctl-pod-identity-associations-오류)
6. [Backstage CLI GitHub App 생성 실패](#6-backstage-cli-github-app-생성-실패)
7. [Applications OutOfSync 문제](#7-applications-outofync-문제)
8. [Certificate 발급 지연](#8-certificate-발급-지연)

---

## 1. ExternalSecret 리전 불일치 (CRITICAL)

### 문제 증상

모든 ExternalSecret 리소스가 `SecretSyncedError` 상태로 실패:

```bash
kubectl get externalsecrets -A

NAME                     STORE                 REFRESH   STATUS              READY
argocd-github            aws-secretsmanager    1h        SecretSyncedError   False
backstage-github-app     aws-secretsmanager    1h        SecretSyncedError   False
keycloak-config          aws-secretsmanager    1h        SecretSyncedError   False
```

### 에러 로그

```
could not get secret data from provider: User: arn:aws:sts::ACCOUNT:assumed-role/external-secrets-sa-role/...
is not authorized to perform: secretsmanager:GetSecretValue on resource: cnoe-ref-impl/config
because no identity-based policy allows the secretsmanager:GetSecretValue action
```

### 원인 분석

**ClusterSecretStore가 잘못된 리전을 사용**하고 있었습니다:

```yaml
# packages/external-secrets/manifests/cluster-secret-store.yaml
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2  # ❌ 잘못된 리전!
```

- AWS Secrets는 `ap-northeast-2` (서울)에 생성됨
- ClusterSecretStore는 `us-west-2`를 바라봄
- 리전이 다르면 Secret을 찾을 수 없음

### 해결 방법

**Step 1: ClusterSecretStore 리전 변경**

```bash
# 방법 1: sed 명령어로 일괄 변경
sed -i '' "s/us-west-2/ap-northeast-2/g" \
  packages/external-secrets/manifests/cluster-secret-store.yaml

# 방법 2: 직접 편집
vi packages/external-secrets/manifests/cluster-secret-store.yaml
```

변경 내용:
```yaml
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-2  # ✅ 올바른 리전으로 변경
```

**Step 2: 변경사항 커밋 & Push**

```bash
git add packages/external-secrets/manifests/cluster-secret-store.yaml
git commit -m "Fix ClusterSecretStore region to ap-northeast-2"
git push origin main
```

**Step 3: External Secrets Operator 재시작**

```bash
# Operator Pod 삭제 (자동으로 재생성됨)
kubectl delete pod -n external-secrets \
  -l app.kubernetes.io/name=external-secrets

# 새로운 Pod가 Running 상태 확인
kubectl get pods -n external-secrets -w
```

**Step 4: ExternalSecret 상태 확인**

```bash
# 약 1-2분 후 모든 ExternalSecret이 Synced 상태가 됨
kubectl get externalsecrets -A

NAME                     STORE                 REFRESH   STATUS    READY
argocd-github            aws-secretsmanager    1h        Synced    True
backstage-github-app     aws-secretsmanager    1h        Synced    True
keycloak-config          aws-secretsmanager    1h        Synced    True
```

### 중요 사항

- ⚠️ **이 문제는 전체 플랫폼 배포의 핵심 블로커입니다**
- 모든 애플리케이션이 ExternalSecret에 의존하므로 이것이 해결되지 않으면 아무것도 작동하지 않습니다
- **반드시 클러스터 생성 전에 리전을 확인하세요**

### 예방 방법

새 프로젝트 시작 시 즉시 확인:

```bash
# config.yaml의 리전 확인
yq '.region' config.yaml

# ClusterSecretStore의 리전 확인
yq '.spec.provider.aws.region' \
  packages/external-secrets/manifests/cluster-secret-store.yaml

# 두 값이 일치하는지 확인!
```

---

## 2. Keycloak 이미지 Pull 실패

### 문제 증상

Keycloak Pod가 `ImagePullBackOff` 상태:

```bash
kubectl get pods -n keycloak

NAME                        READY   STATUS             RESTARTS   AGE
keycloak-0                  0/1     ImagePullBackOff   0          5m
keycloak-postgresql-0       0/1     ImagePullBackOff   0          5m
```

### 에러 로그

```bash
kubectl describe pod keycloak-0 -n keycloak

Events:
  Warning  Failed     Failed to pull image "docker.io/bitnami/keycloak:26.2.5-debian-12-r1":
           rpc error: code = NotFound desc = failed to pull and unpack image
           "docker.io/bitnami/keycloak:26.2.5-debian-12-r1":
           failed to resolve reference "docker.io/bitnami/keycloak:26.2.5-debian-12-r1":
           docker.io/bitnami/keycloak:26.2.5-debian-12-r1: not found
```

PostgreSQL도 동일한 문제:
```
Failed to pull image "docker.io/bitnami/postgresql:17.4.0-debian-12-r17": not found
```

### 원인 분석

**Bitnami가 일부 이미지 지원을 종료**했습니다:
- Bitnami는 최신 이미지만 유지
- 구버전 이미지는 `bitnamilegacy` 레지스트리로 이전됨
- 차트에서 참조하는 특정 버전이 더 이상 존재하지 않음

### 해결 방법

**bitnamilegacy 레지스트리 사용**으로 변경:

```bash
# packages/keycloak/values.yaml 편집
vi packages/keycloak/values.yaml
```

변경 내용:

```yaml
global:
  defaultStorageClass: gp3
  security:
    allowInsecureImages: true  # ✅ Legacy 이미지 허용

image:
  registry: docker.io
  repository: bitnamilegacy/keycloak  # ✅ bitnamilegacy로 변경
  tag: latest                          # ✅ latest 태그 사용

postgresql:
  enabled: true
  image:
    registry: docker.io
    repository: bitnamilegacy/postgresql  # ✅ bitnamilegacy로 변경
    tag: latest                            # ✅ latest 태그 사용
  auth:
    username: bn_keycloak
    database: bitnami_keycloak
  primary:
    persistence:
      enabled: true
      storageClass: "gp3"
      size: 8Gi
```

**변경사항 적용:**

```bash
# Git commit & push
git add packages/keycloak/values.yaml
git commit -m "Fix Keycloak to use bitnamilegacy registry"
git push origin main

# Argo CD에서 수동 Sync (또는 자동 sync 대기)
kubectl patch application keycloak -n argocd \
  --type json \
  -p='[{"op": "replace", "path": "/operation", "value": {"sync": {"syncOptions": ["CreateNamespace=true"], "prune": true}}}]'

# Keycloak Pod 상태 확인
kubectl get pods -n keycloak -w
```

### 영구적 해결책

**Option 1: Keycloak Operator 사용** (권장)
```bash
# Keycloak Operator는 공식 이미지 사용
# 향후 업그레이드 시 고려
```

**Option 2: 고정 버전 지정**
```yaml
# bitnamilegacy에서 안정적인 버전 선택
image:
  repository: bitnamilegacy/keycloak
  tag: "24.0.5"  # 특정 버전 고정
```

### 중요 사항

- ⚠️ `latest` 태그는 프로덕션 환경에서 권장되지 않음
- `allowInsecureImages: true` 필요 (bitnamilegacy 서명 문제)
- 정기적인 이미지 업데이트 확인 필요

---

## 3. kubectl 다운로드 URL 오류

### 문제 증상

Keycloak 설정 Job이 실패:

```bash
kubectl logs -n keycloak keycloak-config-xxxxx

+ curl -sS -LO https://dl.k8s.io/release/v1.28.3//bin/linux/amd64/kubectl
curl: (22) The requested URL returned error: 404
```

### 원인 분석

Job 스크립트에 **URL에 이중 슬래시(`//`)** 존재:
```bash
# 잘못된 URL
https://dl.k8s.io/release/v1.28.3//bin/linux/amd64/kubectl
                                 ^^ 이중 슬래시!
```

### 해결 방법

**packages/keycloak/manifests/user-sso-config-job.yaml 수정:**

```bash
vi packages/keycloak/manifests/user-sso-config-job.yaml
```

**기존 코드 (324-326번 라인):**
```bash
# Download kubectl
KUBECTL_VERSION=v1.28.3
curl -sS -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}//bin/linux/amd64/kubectl"
```

**수정 후 코드:**
```bash
# Download kubectl
KUBECTL_VERSION=$(curl -sS -L https://dl.k8s.io/release/stable.txt)
curl -sS -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
```

**변경사항 적용:**

```bash
git add packages/keycloak/manifests/user-sso-config-job.yaml
git commit -m "Fix kubectl download URL in keycloak-config job"
git push origin main

# Job 재실행 (기존 Job 삭제)
kubectl delete job keycloak-config -n keycloak

# Keycloak Application 재동기화
kubectl patch application keycloak -n argocd \
  --type json \
  -p='[{"op": "replace", "path": "/operation", "value": {"sync": {"syncOptions": ["CreateNamespace=true"], "prune": true}}}]'

# Job 완료 확인
kubectl get job -n keycloak
kubectl logs -n keycloak job/keycloak-config -f
```

### 개선 사항

이 수정으로 얻은 이점:
1. ✅ 이중 슬래시 제거
2. ✅ 최신 stable 버전 자동 사용
3. ✅ 하드코딩된 버전에서 벗어남

---

## 4. DNS Name Server 설정

### 문제 증상

도메인이 해석되지 않음:

```bash
dig sesac.already11.cloud +short
# (응답 없음)

dig sesac.already11.cloud

;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 12345
```

웹 브라우저에서 접속 불가:
```
https://sesac.already11.cloud
→ "This site can't be reached"
```

### 원인 분석

**Route53에는 DNS 레코드가 생성되었지만, 도메인의 Name Server가 Route53을 가리키지 않음:**

```bash
# Route53 Hosted Zone의 NS 레코드
aws route53 get-hosted-zone --id Z00297703HVW1L99K37IL

NameServers:
  - ns-219.awsdns-27.com
  - ns-1819.awsdns-35.co.uk
  - ns-980.awsdns-58.net
  - ns-1173.awsdns-18.org

# 하지만 도메인의 실제 NS는 다른 곳을 가리킴
dig already11.cloud NS +short
# (가비아 또는 다른 등록 업체의 NS)
```

### 해결 방법

**가비아에서 Name Server 변경:**

#### Step 1: Route53 Name Server 확인

```bash
aws route53 get-hosted-zone \
  --id Z00297703HVW1L99K37IL \
  --query 'DelegationSet.NameServers' \
  --output table

# 출력:
# ns-219.awsdns-27.com
# ns-1819.awsdns-35.co.uk
# ns-980.awsdns-58.net
# ns-1173.awsdns-18.org
```

#### Step 2: 가비아에서 변경

1. https://www.gabia.com 로그인
2. **My가비아** → **서비스 관리** → **도메인**
3. 해당 도메인 선택 (already11.cloud)
4. **관리도구** → **네임서버 설정**
5. **네임서버 설정 방법 선택:**
   - ☐ 가비아 네임서버 사용 (기본)
   - ☑ **다른 네임서버 사용** 선택
6. **네임서버 정보 입력:**
   ```
   Primary 네임서버:   ns-219.awsdns-27.com
   Secondary 네임서버: ns-1819.awsdns-35.co.uk
   세 번째 네임서버:   ns-980.awsdns-58.net
   네 번째 네임서버:   ns-1173.awsdns-18.org
   ```
7. **적용** 클릭

#### Step 3: DNS 전파 확인

```bash
# Name Server 변경 확인 (1-5분 소요)
dig already11.cloud NS +short

# 출력:
# ns-219.awsdns-27.com.
# ns-1819.awsdns-35.co.uk.
# ns-980.awsdns-58.net.
# ns-1173.awsdns-18.org.

# 서브도메인 해석 확인 (DNS 전파 후)
dig sesac.already11.cloud +short

# 출력: (ALB 주소)
# cnoe-f472efd5a609d4d4.elb.ap-northeast-2.amazonaws.com.
# XX.XX.XX.XX
```

### DNS 전파 시간

- **일반적:** 5-10분
- **최대:** 24-48시간 (매우 드뭄)
- **확인 도구:** https://dnschecker.org

### 타 도메인 등록 업체

#### AWS Route53에서 구매한 도메인
- Name Server가 자동으로 설정됨
- 별도 작업 불필요

#### Cloudflare
1. Cloudflare 대시보드 → DNS 메뉴
2. Name Server를 Route53 NS로 변경
3. Cloudflare Proxy 비활성화 (DNS Only)

#### GoDaddy, Namecheap 등
1. 도메인 관리 페이지
2. Nameservers 섹션 → Custom 선택
3. Route53의 4개 NS 입력

---

## 5. eksctl Pod Identity Associations 오류

### 문제 증상

`eksctl` 클러스터 생성 실패:

```bash
eksctl create cluster -f /tmp/eksctl-sesac-config.yaml

Error: wellKnownPolicies is not supported for addon.podIdentityAssociations,
use addon.useDefaultPodIdentityAssociations instead
```

### 원인 분석

`create-cluster.sh` 스크립트가 생성한 설정 파일에 **잘못된 필드 사용**:

```yaml
# 잘못된 설정
addons:
  - name: eks-pod-identity-agent
    podIdentityAssociations:
      - serviceAccountName: crossplane-sa
        wellKnownPolicies:  # ❌ 지원되지 않는 필드!
          externalDNS: true
```

### 해결 방법

**eksctl 설정 파일 수정:**

```bash
vi /tmp/eksctl-sesac-config.yaml
```

**변경 내용:**

```yaml
addons:
  - name: eks-pod-identity-agent
    useDefaultPodIdentityAssociations: true  # ✅ 올바른 필드
```

또는 각 ServiceAccount별로 명시적 설정:

```yaml
iam:
  podIdentityAssociations:
    - serviceAccountName: crossplane-sa
      namespace: crossplane-system
      roleName: crossplane-sa-role
      permissionPolicyARNs:
        - arn:aws:iam::aws:policy/PowerUserAccess

    - serviceAccountName: external-secrets-sa
      namespace: external-secrets
      roleName: external-secrets-sa-role
      permissionPolicyARNs:
        - arn:aws:iam::aws:policy/SecretsManagerReadWrite

    - serviceAccountName: external-dns
      namespace: external-dns
      roleName: external-dns-sa-role
      permissionPolicyARNs:
        - arn:aws:iam::aws:policy/Route53FullAccess
```

**클러스터 재생성:**

```bash
eksctl create cluster -f /tmp/eksctl-sesac-config.yaml
```

### 참고

- `useDefaultPodIdentityAssociations: true`는 EKS가 자동으로 Pod Identity 설정
- 수동 설정이 필요하면 `iam.podIdentityAssociations` 사용
- eksctl 버전에 따라 필드명이 다를 수 있음

---

## 6. Backstage CLI GitHub App 생성 실패

### 문제 증상

Backstage CLI로 GitHub App 생성 시도 시 실패:

```bash
npx @backstage/cli create-github-app SAMJOYAP

npm error code ERESOLVE
npm error ERESOLVE unable to resolve dependency tree
npm error While resolving: undefined@undefined
npm error Found: @backstage/cli@0.28.5
npm error node_modules/@backstage/cli
...
```

### 원인 분석

- npm 의존성 충돌
- Backstage CLI 버전 호환성 문제
- Node.js 버전 불일치 가능성

### 해결 방법

**수동으로 GitHub App 생성:**

#### Step 1: GitHub Organization에서 App 생성

**Backstage용:**
1. https://github.com/organizations/YOUR-ORG/settings/apps/new 접속
2. 정보 입력:
   ```
   GitHub App name: YOUR-ORG-backstage
   Homepage URL: https://your-domain.com
   Callback URL: https://your-domain.com/api/auth/github/handler/frame
   Webhook: ☐ Active (체크 해제)
   ```

3. **Permissions** 설정:
   - Repository permissions:
     - Administration: Read and write
     - Contents: Read and write
     - Metadata: Read-only
   - Organization permissions:
     - Members: Read-only
     - Administration: Read-only

4. `Create GitHub App` → **Generate a private key**
5. **Install App** → Organization 선택

**Argo CD용:** (같은 방법으로)
```
GitHub App name: YOUR-ORG-argocd
Homepage URL: https://your-domain.com/argocd
Webhook: ☐ Active
```

Permissions (읽기 전용):
- Repository: Contents (Read-only), Metadata (Read-only)
- Organization: Members (Read-only)

#### Step 2: 정보 수집

다음 정보 기록:
- App ID
- Client ID
- Client Secret (Generate new client secret 클릭)
- Private Key (.pem 파일 다운로드)
- Installation ID (URL: `github.com/organizations/YOUR-ORG/settings/installations/ID`)

#### Step 3: 설정 파일 작성

```bash
cp private/backstage-github.yaml.template private/backstage-github.yaml
cp private/argocd-github.yaml.template private/argocd-github.yaml
```

**private/backstage-github.yaml:**
```yaml
appId: YOUR_APP_ID
webhookUrl: https://your-domain.com
clientId: YOUR_CLIENT_ID
clientSecret: YOUR_CLIENT_SECRET
webhookSecret: ""
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  [.pem 파일 내용 전체 붙여넣기]
  -----END RSA PRIVATE KEY-----
```

**private/argocd-github.yaml:**
```yaml
url: https://github.com/YOUR-ORG
appId: "YOUR_APP_ID"
installationId: "YOUR_INSTALLATION_ID"
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  [.pem 파일 내용 전체 붙여넣기]
  -----END RSA PRIVATE KEY-----
```

### 중요 사항

- ⚠️ **Argo CD와 Backstage가 같은 GitHub App을 공유할 수 있습니다**
- Private Key는 절대 Git에 커밋하지 마세요
- `private/` 디렉토리는 `.gitignore`에 포함되어 있어야 합니다

---

## 7. Applications OutOfSync 문제

### 문제 증상

Argo CD에서 일부 Application이 `OutOfSync` 상태:

```bash
kubectl get applications -n argocd

NAME             SYNC STATUS   HEALTH STATUS
backstage        OutOfSync     Progressing
keycloak         OutOfSync     Degraded
```

### 일반적인 원인

1. **Git 변경사항 반영 지연**
2. **Resource Hooks 실패**
3. **의존성 순서 문제**
4. **ExternalSecret 미준비**

### 해결 방법

#### Method 1: Hard Refresh (권장)

```bash
# Application annotation으로 강제 새로고침
kubectl annotate application APPNAME -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# 예시:
kubectl annotate application backstage -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

#### Method 2: 수동 Sync

```bash
# CLI로 sync
argocd app sync APPNAME

# 또는 kubectl patch
kubectl patch application APPNAME -n argocd \
  --type json \
  -p='[{"op": "replace", "path": "/operation", "value": {"sync": {"syncOptions": ["CreateNamespace=true"], "prune": true}}}]'
```

#### Method 3: 재생성

```bash
# Application 삭제 (리소스는 유지)
kubectl delete application APPNAME -n argocd

# Argo CD가 자동으로 재생성 (ApplicationSet 사용 시)
# 또는 수동으로 재생성
kubectl apply -f packages/APPNAME/application.yaml
```

### Keycloak 특수 케이스

Keycloak Job은 한 번만 실행되므로 수동 삭제 필요:

```bash
# 기존 Job 삭제
kubectl delete job keycloak-config -n keycloak

# Secret 확인
kubectl get secret keycloak-clients -n keycloak

# 없으면 Application 재동기화
kubectl patch application keycloak -n argocd \
  --type json \
  -p='[{"op": "replace", "path": "/operation", "value": {"sync": {"syncOptions": ["CreateNamespace=true"], "prune": true}}}]'
```

### 전체 동기화

모든 Application을 한번에:

```bash
# 모든 Application Hard Refresh
kubectl get applications -n argocd -o name | \
  xargs -I {} kubectl annotate {} -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# 또는 개별 sync
for app in $(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'); do
  argocd app sync $app
done
```

---

## 8. Certificate 발급 지연

### 문제 증상

인증서가 `Ready: False` 상태로 유지:

```bash
kubectl get certificate -A

NAMESPACE   NAME                 READY   SECRET               AGE
argocd      argocd-server-tls    False   argocd-server-tls    10m
backstage   backstage-tls        False   backstage-tls        10m
```

### 원인 분석

#### Case 1: DNS 미전파

가장 흔한 원인:

```bash
kubectl describe certificate argocd-server-tls -n argocd

Events:
  Warning  Failed  Waiting for DNS propagation: DNS record not found
```

**해결:** DNS Name Server 변경 완료 대기 (섹션 4 참조)

#### Case 2: Let's Encrypt Rate Limit

```bash
Events:
  Warning  Failed  too many certificates already issued for domain
```

**해결:**
- 1시간 대기 후 재시도
- 또는 staging 환경 사용:
  ```yaml
  # packages/cert-manager/values.yaml
  clusterIssuer:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
  ```

#### Case 3: HTTP-01 Challenge 실패

```bash
Events:
  Warning  Failed  Waiting for HTTP-01 challenge propagation
```

**확인:**
```bash
# Ingress 확인
kubectl get ingress -A

# Challenge Pod 확인
kubectl get pods -n cert-manager

# Challenge 상세 정보
kubectl describe challenge -A
```

**해결:**
```bash
# cert-manager Pod 재시작
kubectl rollout restart deployment cert-manager -n cert-manager

# Certificate 재발급 시도
kubectl delete certificate CERTNAME -n NAMESPACE
# cert-manager가 자동으로 재생성
```

### 수동 확인 방법

```bash
# Certificate 상세 정보
kubectl describe certificate CERTNAME -n NAMESPACE

# cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f

# Order 상태
kubectl get orders -A

# Challenge 상태
kubectl get challenges -A
```

### 정상 발급 시

```bash
kubectl get certificate -A

NAMESPACE   NAME                 READY   SECRET               AGE
argocd      argocd-server-tls    True    argocd-server-tls    15m
backstage   backstage-tls        True    backstage-tls        15m

# Secret 확인
kubectl get secret argocd-server-tls -n argocd -o yaml | \
  yq '.data."tls.crt"' | base64 -d | openssl x509 -noout -text
```

---

## 🔍 일반적인 디버깅 명령어

### Application 상태 확인

```bash
# 모든 Application 상태
kubectl get applications -n argocd

# 특정 Application 상세
kubectl describe application APPNAME -n argocd

# Application 로그
kubectl logs -n argocd deployment/argocd-application-controller -f
```

### Pod 문제 진단

```bash
# Pod 상태
kubectl get pods -A

# 특정 Pod 상세
kubectl describe pod PODNAME -n NAMESPACE

# Pod 로그
kubectl logs PODNAME -n NAMESPACE -f

# 이전 실패한 Pod 로그
kubectl logs PODNAME -n NAMESPACE --previous

# Events 확인
kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'
```

### Secret 확인

```bash
# ExternalSecret 상태
kubectl get externalsecrets -A

# Secret 생성 확인
kubectl get secrets -n NAMESPACE

# Secret 내용 확인 (base64 디코딩)
kubectl get secret SECRETNAME -n NAMESPACE -o yaml

# 특정 키 값 확인
kubectl get secret SECRETNAME -n NAMESPACE \
  -o jsonpath='{.data.KEY}' | base64 -d
```

### Argo CD CLI

```bash
# Application 목록
argocd app list

# Application 상태
argocd app get APPNAME

# Sync
argocd app sync APPNAME

# Logs
argocd app logs APPNAME
```

### 리소스 정리

```bash
# 실패한 Pods 삭제
kubectl delete pods --field-selector=status.phase=Failed -A

# 완료된 Jobs 삭제
kubectl delete jobs --field-selector=status.successful=1 -A

# 재시작
kubectl rollout restart deployment DEPLOYMENT -n NAMESPACE
```

---

## 📚 추가 리소스

- [공식 문서](https://github.com/cnoe-io/reference-implementation-aws)
- [설치 가이드](./INSTALLATION.md)
- [Argo CD 문서](https://argo-cd.readthedocs.io/)
- [External Secrets 문서](https://external-secrets.io/)
- [cert-manager 문서](https://cert-manager.io/)

---

## 💡 예방 체크리스트

새 환경 배포 전 확인사항:

- [ ] **리전 일치 확인**
  - config.yaml의 region
  - ClusterSecretStore의 region
  - AWS Secrets Manager 생성 리전

- [ ] **DNS 준비**
  - Route53 Hosted Zone 생성
  - Name Server 변경 완료
  - DNS 전파 확인

- [ ] **GitHub Apps 준비**
  - Backstage App 생성 완료
  - Private Key 다운로드
  - Installation ID 확인

- [ ] **이미지 레지스트리**
  - Bitnami 이미지 가용성 확인
  - 필요시 bitnamilegacy 사용

- [ ] **AWS 권한**
  - IAM User/Role 생성
  - 필수 Policy 연결 확인
  - AWS CLI 인증 테스트

---

**문제 해결이 안 되시나요?**

- GitHub Issues: https://github.com/cnoe-io/reference-implementation-aws/issues
- CNOE Slack: https://cloud-native.slack.com
- 이 가이드 업데이트 제안: Pull Request 환영합니다!

---

**Happy Troubleshooting! 🔧**
