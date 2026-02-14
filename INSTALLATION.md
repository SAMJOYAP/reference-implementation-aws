# AWS Reference Implementation - 설치 가이드

> 이 가이드는 처음 배포하는 사용자를 위한 핵심 설치 가이드입니다.

## 📋 목차

1. [사전 준비사항](#1-사전-준비사항)
2. [Repository Fork & Clone](#2-repository-fork--clone)
3. [GitHub Apps 생성](#3-github-apps-생성)
4. [설정 파일 작성](#4-설정-파일-작성)
5. [AWS Secrets 생성](#5-aws-secrets-생성)
6. [EKS Cluster 생성](#6-eks-cluster-생성)
7. [플랫폼 설치](#7-플랫폼-설치)
8. [DNS 설정](#8-dns-설정)
9. [접속 확인](#9-접속-확인)
10. [다음 단계](#10-다음-단계)

---

## 1. 사전 준비사항

### 필수 도구 설치

```bash
# AWS CLI
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# kubectl
# https://kubernetes.io/docs/tasks/tools/

# yq
# https://mikefarah.gitbook.io/yq/

# helm
# https://helm.sh/docs/intro/install/

# eksctl (Cluster 생성용)
# https://eksctl.io/installation/
```

### AWS 계정 요구사항

- ✅ AWS 계정 및 IAM 자격 증명
- ✅ EKS 클러스터 생성 권한
- ✅ Route53 Hosted Zone (도메인 필요)

### AWS CLI 설정

```bash
aws configure --profile your-project-name
# AWS Access Key ID 입력
# AWS Secret Access Key 입력
# Default region: ap-northeast-2 (또는 원하는 리전)
# Default output format: json
```

---

## 2. Repository Fork & Clone

### 2-1. GitHub Organization 생성

GitHub Organization이 없다면 생성:
- https://github.com/account/organizations/new
- Organization 이름 입력 (예: `my-company`)

> [!NOTE]
> 개인 계정이 아닌 Organization을 사용하는 것을 권장합니다.

### 2-2. Repository Fork

1. https://github.com/cnoe-io/reference-implementation-aws 접속
2. 우측 상단 `Fork` 버튼 클릭
3. Owner를 생성한 Organization으로 선택
4. `Create fork` 클릭

### 2-3. Clone

```bash
git clone https://github.com/YOUR-ORG/reference-implementation-aws.git
cd reference-implementation-aws
```

---

## 3. GitHub Apps 생성

Backstage와 Argo CD는 GitHub Apps를 통해 GitHub과 인증합니다.

### 3-1. Backstage GitHub App 생성

1. https://github.com/organizations/YOUR-ORG/settings/apps/new 접속
2. 다음 정보 입력:

```
GitHub App name: YOUR-ORG-backstage
Homepage URL: https://your-domain.com  (나중에 변경 가능)
Callback URL: https://your-domain.com/api/auth/github/handler/frame
Webhook: ☐ Active (체크 해제)  ← 중요: 반드시 비활성화!
```

> **왜 Webhook을 비활성화하나요?**
> - Webhook을 활성화하면 GitHub가 이벤트를 Backstage로 실시간 전송
> - 외부 접근 가능한 URL과 추가 보안 설정 필요
> - 비활성화해도 Backstage는 polling으로 정상 작동
> - 간단한 설정을 위해 비활성화 권장

3. **Permissions** 설정:
   - Repository permissions:
     - Administration: Read and write
     - Contents: Read and write
     - Metadata: Read-only
   - Organization permissions:
     - Members: Read-only
     - Administration: Read-only

4. `Create GitHub App` 클릭
5. **Generate a private key** 클릭하여 키 다운로드
6. **Install App** 클릭하여 Organization에 설치

### 3-2. Argo CD GitHub App 생성

동일한 과정으로 Argo CD용 App 생성:

```
GitHub App name: YOUR-ORG-argocd
Homepage URL: https://your-domain.com/argocd
Webhook: ☐ Active (체크 해제)  ← 중요: 반드시 비활성화!
```

**Permissions** (읽기 전용):
- Repository permissions:
  - Contents: Read-only
  - Metadata: Read-only
- Organization permissions:
  - Members: Read-only

### 3-3. GitHub App 정보 저장

다음 정보를 기록해두세요:
- App ID
- Client ID
- Client Secret
- Private Key (다운로드한 .pem 파일 내용)
- Installation ID (App 설치 페이지 URL에서 확인)

### 3-4. 설정 파일 생성

```bash
# Template 파일 복사
cp private/backstage-github.yaml.template private/backstage-github.yaml
cp private/argocd-github.yaml.template private/argocd-github.yaml
```

**private/backstage-github.yaml** 편집:
```yaml
appId: YOUR_APP_ID
webhookUrl: https://your-domain.com
clientId: YOUR_CLIENT_ID
clientSecret: YOUR_CLIENT_SECRET
webhookSecret: "dummy-webhook-secret-not-used"  # ⚠️ 빈 문자열("")이 아닌 이 값 사용!
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  [Private Key 내용 붙여넣기]
  -----END RSA PRIVATE KEY-----
```

> **⚠️ 중요: webhookSecret 값**
>
> - **반드시** `"dummy-webhook-secret-not-used"` 문자열을 사용하세요
> - GitHub App에서 Webhook을 비활성화했더라도 이 값은 필수입니다
> - 빈 문자열(`""`)을 사용하면 Backstage pod이 시작 실패합니다
> - Backstage 설정 검증 로직에서 이 필드를 필수로 체크하기 때문입니다

**왜 Webhook을 비활성화하나요?**

- Webhook을 활성화하면 GitHub가 이벤트를 Backstage로 실시간 전송합니다
- 하지만 Backstage가 외부에서 접근 가능해야 하고 추가 보안 설정이 필요합니다
- 비활성화해도 Backstage는 polling 방식으로 GitHub을 주기적으로 확인하여 정상 작동합니다
- 간단한 설정을 위해 Webhook 비활성화를 권장합니다

**private/argocd-github.yaml** 편집:
```yaml
url: https://github.com/YOUR-ORG
appId: "YOUR_APP_ID"
installationId: "YOUR_INSTALLATION_ID"
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  [Private Key 내용 붙여넣기]
  -----END RSA PRIVATE KEY-----
```

> [!TIP]
> Installation ID는 `https://github.com/organizations/YOUR-ORG/settings/installations/ID` URL에서 확인할 수 있습니다.

---

## 4. 설정 파일 작성

### 4-1. config.yaml 편집

Repository 루트의 `config.yaml` 파일을 편집:

```yaml
repo:
  url: "https://github.com/YOUR-ORG/reference-implementation-aws"
  revision: "main"
  basepath: "packages"

cluster_name: "your-cluster-name"  # Kubernetes 리소스 이름 규칙 준수
auto_mode: "false"                  # EKS Auto Mode 사용 여부
region: "ap-northeast-2"            # AWS 리전

domain: your-subdomain.your-domain.com  # 실제 도메인 입력
route53_hosted_zone_id: Z0XXXXXXXXX     # Route53 Hosted Zone ID

path_routing: "true"  # true: /argocd, false: argocd.domain.com

tags:
  githubRepo: "github.com/YOUR-ORG/reference-implementation-aws"
  env: "dev"
  project: "your-project"
```

### 4-2. ClusterSecretStore 리전 설정

```bash
# packages/external-secrets/manifests/cluster-secret-store.yaml 편집
sed -i '' "s/us-west-2/ap-northeast-2/g" \
  packages/external-secrets/manifests/cluster-secret-store.yaml
```

또는 직접 편집:
```yaml
# packages/external-secrets/manifests/cluster-secret-store.yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-2  # 사용할 리전으로 변경
```

---

## 5. AWS Secrets 생성

설정 파일을 AWS Secrets Manager에 저장:

```bash
export AWS_PROFILE=your-project-name

./scripts/create-config-secrets.sh
# 입력: yes
```

생성되는 Secrets:
- `cnoe-ref-impl/config`: config.yaml 내용
- `cnoe-ref-impl/github-app`: GitHub Apps 자격 증명

---

## 6. EKS Cluster 생성

### 6-1. Cluster 생성 스크립트 실행

```bash
export REPO_ROOT=$(git rev-parse --show-toplevel)
$REPO_ROOT/scripts/create-cluster.sh
```

### 6-2. 도구 선택

```
Choose a tool to create the cluster:
1) eksctl
2) terraform
선택: 1  # eksctl 권장
```

### 6-3. 생성 확인

```bash
# 클러스터 생성 완료까지 약 15-20분 소요

# 진행 상황 확인 (별도 터미널)
watch -n 10 'aws cloudformation describe-stacks \
  --region ap-northeast-2 \
  --stack-name eksctl-YOUR-CLUSTER-NAME-cluster \
  --query "Stacks[0].StackStatus" \
  --output text'
```

생성되는 리소스:
- EKS Cluster (Managed Node Group 4 nodes)
- VPC, Subnets, Security Groups
- Pod Identity Associations (Crossplane, External Secrets, External DNS 등)

---

## 7. 플랫폼 설치

### 7-1. kubectl context 확인

```bash
kubectl get nodes
# 4개의 노드가 Ready 상태여야 함
```

### 7-2. 설치 시작

```bash
./scripts/install.sh
# 입력: yes
```

### 7-3. 설치 모니터링

**별도 터미널 1** - Applications 상태:
```bash
watch -n 5 'kubectl get applications -n argocd'
```

**별도 터미널 2** - Pods 상태:
```bash
watch -n 5 'kubectl get pods -A'
```

**별도 터미널 3** - Argo CD UI (Port Forward):
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:80
# http://localhost:8080/argocd 접속
```

**Argo CD 로그인 정보:**
```bash
# Username: admin
# Password:
kubectl get secrets -n argocd argocd-initial-admin-secret \
  -oyaml | yq '.data.password' | base64 -d && echo
```

### 7-4. 설치 완료 확인

모든 Applications이 `Synced / Healthy` 상태가 되어야 합니다:
```bash
kubectl get applications -n argocd
```

---

## 8. DNS 설정

플랫폼이 외부에서 접속 가능하려면 DNS 설정이 필요합니다.

### 8-1. Route53 Name Server 확인

```bash
aws route53 get-hosted-zone \
  --id YOUR_HOSTED_ZONE_ID \
  --query 'DelegationSet.NameServers' \
  --output table
```

출력 예시:
```
ns-219.awsdns-27.com
ns-1819.awsdns-35.co.uk
ns-980.awsdns-58.net
ns-1173.awsdns-18.org
```

### 8-2. 도메인 등록 업체에서 Name Server 변경

#### 가비아 사용 시:

1. https://www.gabia.com 로그인
2. **My가비아** → **도메인** 메뉴
3. 해당 도메인 선택 → **관리**
4. **네임서버 설정** 탭
5. **다른 네임서버 사용** 선택
6. Route53의 4개 Name Server 입력
7. **저장**

#### AWS Route53에서 직접 구매한 도메인:
- Name Server가 자동으로 설정되어 있으므로 별도 작업 불필요

### 8-3. DNS 전파 확인

```bash
# Name Server 확인
dig your-domain.com NS +short

# 도메인 해석 확인
dig your-subdomain.your-domain.com +short
```

DNS 전파 시간:
- 일반적으로 5-10분
- 최대 24-48시간 (드물게)

---

## 9. 접속 확인

### 9-1. URL 확인

```bash
./scripts/get-urls.sh
```

**Path Routing 사용 시** (`path_routing: "true"`):
```
Backstage:      https://your-domain.com
Argo CD:        https://your-domain.com/argocd
Argo Workflows: https://your-domain.com/argo-workflows
```

**Domain Routing 사용 시** (`path_routing: "false"`):
```
Backstage:      https://backstage.your-domain.com
Argo CD:        https://argocd.your-domain.com
Argo Workflows: https://argo-workflows.your-domain.com
```

### 9-2. 접속 및 로그인

**Argo CD 초기 비밀번호:**
```bash
kubectl get secrets -n argocd argocd-initial-admin-secret \
  -oyaml | yq '.data.password' | base64 -d && echo
```

**Keycloak SSO 사용자 (Backstage, Argo Workflows):**
```bash
# Username: user1
# Password:
kubectl get secret -n keycloak keycloak-config \
  -o jsonpath='{.data.USER1_PASSWORD}' | base64 -d && echo
```

### 9-3. 인증서 확인

Let's Encrypt 인증서가 자동으로 발급됩니다 (약 2-5분 소요):

```bash
kubectl get certificate -A
# READY: True 확인
```

---

## 10. 다음 단계

### ✅ 설치 완료!

이제 다음을 할 수 있습니다:

1. **Backstage에서 애플리케이션 생성**
   - Software Templates 사용
   - GitHub Repository 자동 생성
   - Argo CD Application 자동 배포

2. **Crossplane으로 AWS 리소스 프로비저닝**
   - RDS, S3, DynamoDB 등
   - Kubernetes CRD로 관리

3. **Argo Workflows로 CI/CD 파이프라인 구축**

### 📚 추가 문서

- [트러블슈팅 가이드](./TROUBLESHOOTING_DETAILED.md) - 문제 해결 방법
- [한국어 전체 가이드](./docs/SETUP_GUIDE_KR.md) - 상세 설명
- [빠른 시작 가이드](./docs/QUICK_START_KR.md) - 경험자용

### 🔧 관리

**Git Commit & Push:**
```bash
git add .
git commit -m "Initial platform configuration"
git push origin main
```

**플랫폼 업데이트:**
```bash
# config.yaml 수정 후
./scripts/create-config-secrets.sh

# Argo CD가 자동으로 동기화
# 또는 수동 sync:
kubectl annotate application -n argocd APP_NAME \
  argocd.argoproj.io/refresh=hard --overwrite
```

**삭제:**
```bash
# 플랫폼 제거
./scripts/uninstall.sh

# CRDs 제거
./scripts/cleanup-crds.sh

# EKS Cluster 제거
eksctl delete cluster --name YOUR-CLUSTER-NAME --region ap-northeast-2
```

---

## 💡 유용한 명령어

```bash
# 모든 Applications 상태
kubectl get applications -n argocd

# 특정 namespace의 pods
kubectl get pods -n NAMESPACE

# Logs 확인
kubectl logs -n NAMESPACE POD_NAME -f

# Port Forward
kubectl port-forward -n NAMESPACE svc/SERVICE_NAME LOCAL_PORT:REMOTE_PORT

# Argo CD Application 재동기화
kubectl patch application APP_NAME -n argocd \
  --type json -p='[{"op": "replace", "path": "/operation", \
  "value": {"sync": {"syncOptions": ["CreateNamespace=true"], "prune": true}}}]'
```

---

## 🆘 문제 발생 시

문제가 발생하면 [트러블슈팅 가이드](./TROUBLESHOOTING_DETAILED.md)를 참고하세요.

자주 발생하는 이슈:
- Keycloak 이미지 문제
- DNS 설정 오류
- Applications OutOfSync
- ExternalSecret 오류

---

**Happy Hacking! 🚀**
