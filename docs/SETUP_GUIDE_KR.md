# AWS Reference Implementation 설치 가이드 (한글)

## 📋 목차

1. [개요](#개요)
2. [사전 요구사항](#사전-요구사항)
3. [아키텍처](#아키텍처)
4. [단계별 설치 가이드](#단계별-설치-가이드)
5. [트러블슈팅](#트러블슈팅)
6. [운영 가이드](#운영-가이드)
7. [접속 방법](#접속-방법)

---

## 개요

이 가이드는 AWS EKS에 Internal Developer Platform (IDP)을 구축하는 전체 과정을 단계별로 설명합니다.

### 설치되는 컴포넌트

| 컴포넌트 | 설명 | 용도 |
|---------|------|------|
| **Argo CD** | GitOps CD 도구 | 애플리케이션 배포 관리 |
| **Backstage** | Developer Portal | 개발자 셀프서비스 포털 |
| **Keycloak** | Identity Provider | 통합 인증/인가 |
| **Crossplane** | Infrastructure as Code | 클라우드 리소스 관리 |
| **External Secrets** | Secret 관리 | AWS Secrets Manager 연동 |
| **Cert Manager** | 인증서 관리 | Let's Encrypt 자동 발급 |
| **External DNS** | DNS 관리 | Route53 자동 레코드 관리 |
| **Ingress NGINX** | Ingress Controller | L7 트래픽 라우팅 |
| **Argo Workflows** | Workflow Engine | CI/CD 파이프라인 |

---

## 사전 요구사항

### 1. 로컬 환경 도구 설치

```bash
# AWS CLI
brew install awscli  # macOS
# 또는 https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# kubectl
brew install kubectl  # macOS
# 또는 https://kubernetes.io/docs/tasks/tools/

# eksctl
brew install eksctl  # macOS
# 또는 https://eksctl.io/installation/

# yq
brew install yq  # macOS

# helm
brew install helm  # macOS

# GitHub CLI
brew install gh  # macOS
```

### 2. AWS 계정 준비

- AWS 계정 및 관리자 권한
- AWS Access Key & Secret Access Key
- EKS, VPC, IAM 권한

### 3. GitHub 계정

- GitHub Organization (무료 버전 가능)
- 개인 Access Token (repo, admin:org 권한)

### 4. 도메인

- Route53 Hosted Zone
- 도메인 소유 및 관리 권한

---

## 아키텍처

### 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │   Route 53   │
                  │  Hosted Zone │
                  └──────┬───────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Application Load    │
              │     Balancer         │
              └──────────┬───────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   ┌─────────┐    ┌──────────┐    ┌──────────┐
   │Backstage│    │ Argo CD  │    │ Keycloak │
   └─────────┘    └──────────┘    └──────────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │    EKS Cluster       │
              │  ┌────────────────┐  │
              │  │  Worker Nodes  │  │
              │  │   (m5.large)   │  │
              │  │    x 4 nodes   │  │
              │  └────────────────┘  │
              └──────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
 ┌─────────────┐  ┌─────────────┐  ┌──────────┐
 │   Secrets   │  │  Parameter  │  │   ECR    │
 │   Manager   │  │    Store    │  └──────────┘
 └─────────────┘  └─────────────┘
```

### GitOps 워크플로우

```
┌──────────────┐
│   GitHub     │
│  Repository  │
└──────┬───────┘
       │ 1. Push changes
       ▼
┌──────────────────┐
│   Argo CD        │
│  (Sync Engine)   │
└──────┬───────────┘
       │ 2. Detect changes
       │ 3. Apply manifests
       ▼
┌──────────────────┐
│  EKS Cluster     │
│  (Applications)  │
└──────────────────┘
```

---

## 단계별 설치 가이드

### Step 1: AWS Credentials 설정

#### 1.1 AWS Access Key 생성

AWS Console → IAM → Users → Security credentials → Create access key

#### 1.2 AWS CLI Profile 생성

```bash
# Credentials 파일 생성
mkdir -p ~/.aws
touch ~/.aws/credentials
chmod 600 ~/.aws/credentials

# Profile 추가
cat >> ~/.aws/credentials << EOF
[your-project-name]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
EOF

# Config 파일에 리전 설정
cat >> ~/.aws/config << EOF
[profile your-project-name]
region = ap-northeast-2
output = json
EOF
```

#### 1.3 Profile 테스트

```bash
export AWS_PROFILE=your-project-name
aws sts get-caller-identity
```

**예상 출력:**
```json
{
    "UserId": "AIDAXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

---

### Step 2: GitHub 설정

#### 2.1 GitHub Organization 생성

1. https://github.com/account/organizations/new 접속
2. Organization name 입력
3. Contact email 입력
4. "My personal account" 선택
5. Create organization (무료)

#### 2.2 GitHub CLI 인증

```bash
# GitHub Token으로 로그인
echo "YOUR_GITHUB_TOKEN" | gh auth login --with-token

# 인증 확인
gh auth status
```

#### 2.3 Repository Fork

```bash
gh repo fork cnoe-io/reference-implementation-aws \
  --org YOUR_ORG_NAME \
  --clone=false
```

#### 2.4 로컬 Repository 설정

```bash
cd /path/to/reference-implementation-aws

# Remote 변경
git remote set-url origin https://github.com/YOUR_ORG/reference-implementation-aws.git
git remote add upstream https://github.com/cnoe-io/reference-implementation-aws.git
git remote -v
```

---

### Step 3: GitHub Apps 생성

#### 3.1 Backstage GitHub App

**수동 생성 방법:**

1. **App 생성 페이지 이동**
   ```
   https://github.com/organizations/YOUR_ORG/settings/apps/new
   ```

2. **기본 정보 입력**
   - **GitHub App name**: `YOUR_ORG-backstage`
   - **Homepage URL**: `https://backstage.your-domain.com`
   - **Callback URL**: `https://backstage.your-domain.com/api/auth/github/handler/frame`
   - **Webhook → Active**: ❌ Uncheck (반드시 체크 해제!)

   > **💡 왜 Webhook을 비활성화하나요?**
   >
   > - Webhook을 활성화하면 GitHub가 이벤트를 Backstage로 실시간 전송합니다
   > - 하지만 외부에서 접근 가능한 URL과 추가 보안 설정이 필요합니다
   > - 비활성화해도 Backstage는 polling 방식으로 GitHub을 주기적으로 확인하여 정상 작동합니다
   > - 간단한 설정을 위해 Webhook 비활성화를 권장합니다

3. **Permissions 설정**

   **Repository permissions:**
   - Administration: `Read and write`
   - Contents: `Read and write`
   - Metadata: `Read-only` (자동)

   **Organization permissions:**
   - Members: `Read-only`
   - Administration: `Read-only`

4. **Where can this GitHub App be installed?**
   - `Only on this account` 선택

5. **Create GitHub App** 클릭

6. **Private Key 생성**
   - App 설정 페이지에서 **"Generate a private key"** 클릭
   - `.pem` 파일 다운로드 → 안전한 위치에 저장

7. **Client Secret 생성**
   - **"Generate a new client secret"** 클릭
   - Secret 복사 (다시 볼 수 없음!)

8. **App 설치**
   - 왼쪽 메뉴에서 **"Install App"** 클릭
   - Organization 선택
   - **"All repositories"** 선택
   - **Install** 클릭

9. **정보 수집**
   - App ID: 설정 페이지 상단
   - Client ID: 설정 페이지
   - Client Secret: 생성한 값
   - Installation ID:
     ```
     https://github.com/organizations/YOUR_ORG/settings/installations/[ID]
     ```
     URL의 마지막 숫자

#### 3.2 Argo CD GitHub App

위와 동일한 과정을 반복하되, 다음 차이점만 적용:

**App name**: `YOUR_ORG-argocd`
**Homepage URL**: `https://argocd.your-domain.com`
**Callback URL**: 불필요 (비워두기)

**Permissions (읽기 전용):**
- Repository permissions:
  - Checks: `Read-only`
  - Contents: `Read-only`
  - Members: `Read-only`
  - Metadata: `Read-only`

#### 3.3 설정 파일 생성

```bash
cd reference-implementation-aws

# 템플릿 복사
cp private/backstage-github.yaml.template private/backstage-github.yaml
cp private/argocd-github.yaml.template private/argocd-github.yaml
```

**private/backstage-github.yaml 편집:**
```yaml
appId: 2858537  # Your App ID
webhookUrl: https://backstage.your-domain.com
clientId: Iv23liXXXXXXXXXXXX  # Your Client ID
clientSecret: 7d96e56c52d608bd669a628c1f1873b871122960  # Your Client Secret
webhookSecret: "dummy-webhook-secret-not-used"  # ⚠️ 반드시 이 값 사용! (빈 문자열 사용 시 pod 실패)
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  [다운로드한 .pem 파일의 내용을 여기에 붙여넣기]
  -----END RSA PRIVATE KEY-----
```

> **⚠️ 중요: webhookSecret 값**
>
> - **반드시** `"dummy-webhook-secret-not-used"` 문자열을 사용하세요
> - GitHub App에서 Webhook을 비활성화했더라도 이 값은 필수입니다
> - 빈 문자열(`""`)을 사용하면 Backstage pod이 CrashLoopBackOff로 실패합니다
> - Backstage 설정 검증 로직에서 이 필드를 필수로 체크하기 때문입니다

**private/argocd-github.yaml 편집:**
```yaml
url: https://github.com/YOUR_ORG
appId: "2858537"  # Your App ID
installationId: "109915595"  # Your Installation ID
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  [다운로드한 .pem 파일의 내용을 여기에 붙여넣기]
  -----END RSA PRIVATE KEY-----
```

---

### Step 4: config.yaml 설정

```bash
cd reference-implementation-aws
vi config.yaml
```

**설정 예시:**
```yaml
repo:
  url: "https://github.com/YOUR_ORG/reference-implementation-aws"
  revision: "main"
  basepath: "packages"

cluster_name: "your-cluster-name"  # 예: sesac-ref-impl
auto_mode: "false"  # Managed Node Group 사용
region: "ap-northeast-2"  # Seoul region

domain: your-subdomain.your-domain.com  # 예: sesac.already11.cloud
route53_hosted_zone_id: Z00297703HVWXXXXX  # Your Hosted Zone ID

path_routing: "true"  # Path 기반 라우팅 사용

tags:
  githubRepo: "github.com/YOUR_ORG/reference-implementation-aws"
  env: "dev"
  project: "your-project"
```

**Route53 Hosted Zone ID 확인:**
```bash
aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='your-domain.com.'].Id" \
  --output text | cut -d'/' -f3
```

---

### Step 5: 리전 설정 수정 (중요!)

**ClusterSecretStore 리전 수정:**
```bash
vi packages/external-secrets/manifests/cluster-secret-store.yaml
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-2  # 👈 YOUR REGION으로 변경!
```

**변경사항 저장:**
```bash
git add packages/external-secrets/manifests/cluster-secret-store.yaml
git commit -m "Update ClusterSecretStore region to ap-northeast-2"
```

---

### Step 6: AWS Secrets Manager에 설정 저장

```bash
export AWS_PROFILE=your-project-name
export AWS_REGION=ap-northeast-2

./scripts/create-config-secrets.sh
```

입력: `yes`

**생성되는 Secrets:**
- `cnoe-ref-impl/config`: config.yaml 내용
- `cnoe-ref-impl/github-app`: GitHub Apps 설정

**확인:**
```bash
aws secretsmanager list-secrets \
  --region ap-northeast-2 \
  --query 'SecretList[?starts_with(Name, `cnoe-ref-impl`)].[Name,ARN]' \
  --output table
```

---

### Step 7: EKS Cluster 생성

#### 7.1 Crossplane IAM Policy 생성

자동으로 생성됩니다 (스크립트 내부에서 처리).

#### 7.2 Cluster 생성

```bash
export AWS_PROFILE=your-project-name
export AWS_REGION=ap-northeast-2

./scripts/create-cluster.sh
```

**선택:**
- Tool: `1` (eksctl)

**예상 소요 시간:** 15-20분

**생성되는 리소스:**
- EKS Cluster (Kubernetes 1.33)
- VPC (10.0.0.0/16)
- 3개 가용 영역의 Public/Private Subnets
- Managed Node Group (4 nodes, m5.large)
- Pod Identity Associations (Crossplane, External Secrets, External DNS, AWS LB Controller)

**진행 상황 확인:**
```bash
# CloudFormation 스택 상태
aws cloudformation describe-stacks \
  --region ap-northeast-2 \
  --stack-name eksctl-your-cluster-name-cluster \
  --query 'Stacks[0].StackStatus' \
  --output text

# 또는 AWS Console
https://ap-northeast-2.console.aws.amazon.com/cloudformation
```

**완료 확인:**
```bash
# Kubeconfig 자동 업데이트 (스크립트가 자동 실행)
kubectl get nodes

# 예상 출력:
NAME                                           STATUS   ROLES    AGE   VERSION
ip-10-0-32-13.ap-northeast-2.compute.internal  Ready    <none>   5m    v1.33.7-eks-70ce843
ip-10-0-55-162.ap-northeast-2.compute.internal Ready    <none>   5m    v1.33.7-eks-70ce843
ip-10-0-8-170.ap-northeast-2.compute.internal  Ready    <none>   5m    v1.33.7-eks-70ce843
ip-10-0-89-87.ap-northeast-2.compute.internal  Ready    <none>   5m    v1.33.7-eks-70ce843
```

---

### Step 8: 플랫폼 컴포넌트 설치

```bash
export AWS_PROFILE=your-project-name
export AWS_REGION=ap-northeast-2

./scripts/install.sh
```

입력: `yes`

**설치 순서:**
1. Argo CD
2. External Secrets Operator
3. ClusterSecretStore
4. Hub Cluster Secret (Argo CD cluster 정보)
5. Addons ApplicationSet

**예상 소요 시간:** 5-10분

#### 설치 진행 상황 모니터링

**터미널 1 - Applications 상태:**
```bash
watch -n 5 'kubectl get applications -n argocd'
```

**터미널 2 - Pods 상태:**
```bash
watch -n 5 'kubectl get pods -A'
```

**터미널 3 - Argo CD UI (Port Forward):**
```bash
# Admin 비밀번호 확인
kubectl get secrets -n argocd argocd-initial-admin-secret \
  -oyaml | yq '.data.password' | base64 -d && echo

# Port forward
kubectl port-forward -n argocd svc/argocd-server 8080:80

# 브라우저에서 http://localhost:8080 또는 http://localhost:8080/argocd 접속
# Username: admin
# Password: 위에서 확인한 비밀번호
```

#### 예상 Application 상태

| Application | Sync Status | Health Status | 설명 |
|------------|-------------|---------------|------|
| addons-appset-pr | ✅ Synced | ✅ Healthy | ApplicationSet |
| external-secrets | ✅ Synced | ✅ Healthy | Secret 관리 |
| ingress-nginx | ✅ Synced | ✅ Healthy | Ingress Controller |
| cert-manager | ✅ Synced | ✅ Healthy | 인증서 관리 |
| external-dns | ✅ Synced | ✅ Healthy | DNS 관리 |
| aws-load-balancer-controller | ✅ Synced | ✅ Healthy | ALB 관리 |
| crossplane | ✅ Synced | ✅ Healthy | IaC |
| keycloak | 🔄 Synced | 🔄 Progressing | SSO |
| backstage | 🔄 Synced | 🔄 Progressing | Developer Portal |
| argocd | 🔄 Synced | 🔄 Progressing | GitOps |
| argo-workflows | 🔄 Synced | 🔄 Progressing | Workflow Engine |

---

### Step 9: GitHub Apps 웹 설정 업데이트

**Backstage GitHub App 업데이트:**
1. https://github.com/organizations/YOUR_ORG/settings/apps 접속
2. YOUR_ORG-backstage 선택
3. **Homepage URL**: `https://your-subdomain.your-domain.com` 업데이트
4. **Callback URL**: `https://your-subdomain.your-domain.com/api/auth/github/handler/frame` 업데이트
5. **Save changes** 클릭

**Argo CD GitHub App 업데이트:**
1. YOUR_ORG-argocd 선택
2. **Homepage URL**: `https://your-subdomain.your-domain.com/argocd` 업데이트
3. **Save changes** 클릭

---

### Step 10: 변경사항 Push

```bash
git add config.yaml packages/external-secrets/manifests/cluster-secret-store.yaml
git commit -m "Configure for production deployment

- Update domain and Route53 Hosted Zone ID
- Fix ClusterSecretStore region

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push origin main
```

Argo CD가 자동으로 변경사항을 감지하고 동기화합니다.

---

## 트러블슈팅

### 문제 1: ExternalSecret이 SecretSyncedError 상태

**증상:**
```bash
kubectl get externalsecret -n argocd
NAME                 STATUS              READY
hub-cluster-secret   SecretSyncedError   False
```

**원인 1: 잘못된 리전**

```bash
# ClusterSecretStore 리전 확인
kubectl get clustersecretstore aws-secretsmanager -o jsonpath='{.spec.provider.aws.region}'
# 출력: us-west-2 (잘못된 리전!)
```

**해결:**
```bash
# 1. Manifest 파일 수정
vi packages/external-secrets/manifests/cluster-secret-store.yaml
# region을 올바른 리전으로 변경 (예: ap-northeast-2)

# 2. 적용
kubectl apply -f packages/external-secrets/manifests/cluster-secret-store.yaml

# 3. External Secrets Operator 재시작
kubectl rollout restart deployment external-secrets -n external-secrets

# 4. Git에 커밋
git add packages/external-secrets/manifests/cluster-secret-store.yaml
git commit -m "Fix ClusterSecretStore region"
git push origin main
```

**원인 2: IAM 권한 부족**

```bash
# ExternalSecret 에러 확인
kubectl describe externalsecret hub-cluster-secret -n argocd

# AccessDeniedException이 보이면 IAM policy 확인
aws iam get-role-policy \
  --role-name eksctl-CLUSTER-NAME-podidentityrole-externa-Role1-XXXXX \
  --policy-name eksctl-CLUSTER-NAME-podidentityrole-external-secrets-external-secrets-Policy1 \
  --region YOUR_REGION
```

**해결:** EKS Cluster 재생성 시 올바른 권한으로 생성되어야 합니다.

---

### 문제 2: Applications가 생성되지 않음

**증상:**
```bash
kubectl get applications -n argocd
No resources found in argocd namespace.
```

**원인: Cluster Secret 누락**

```bash
# Cluster secret 확인
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster
# No resources found (문제!)
```

**해결:**
```bash
# 1. ExternalSecret 확인
kubectl get externalsecret hub-cluster-secret -n argocd

# 없으면 재생성
kubectl apply -f packages/argo-cd/manifests/hub-cluster-secret.yaml

# 2. 대기 (ExternalSecret이 secret 생성)
sleep 30

# 3. 확인
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster
```

---

### 문제 3: DNS가 작동하지 않음

**증상:**
도메인 접속이 안됨 (예: https://backstage.your-domain.com)

**진단:**
```bash
# 1. External DNS pod 상태 확인
kubectl get pods -n external-dns

# 2. External DNS 로그 확인
kubectl logs -n external-dns deployment/external-dns

# 3. Route53 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Type=='A']"
```

**해결:**
```bash
# Ingress 확인
kubectl get ingress -A

# ALB 생성 확인
aws elbv2 describe-load-balancers --region YOUR_REGION

# External DNS 재시작
kubectl rollout restart deployment external-dns -n external-dns
```

---

### 문제 4: Cert Manager 인증서 발급 실패

**증상:**
```bash
kubectl get certificate -A
NAME              READY   SECRET            AGE
default-cert      False   default-cert-tls  10m
```

**진단:**
```bash
# Certificate 상세 정보
kubectl describe certificate default-cert -n NAMESPACE

# CertificateRequest 확인
kubectl get certificaterequest -A

# Challenge 확인 (Let's Encrypt)
kubectl get challenges -A
```

**일반적인 원인:**
- DNS 전파 지연 (최대 5분)
- Route53 권한 부족
- 도메인 설정 오류

**해결:**
```bash
# 1. DNS 전파 대기
dig your-subdomain.your-domain.com

# 2. Certificate 재생성
kubectl delete certificate default-cert -n NAMESPACE
# Argo CD가 자동으로 재생성

# 3. ClusterIssuer 확인
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

---

### 문제 5: Backstage가 Degraded 상태

**증상:**
```bash
kubectl get application backstage-sesac-ref-impl -n argocd
NAME                        SYNC STATUS   HEALTH STATUS
backstage-sesac-ref-impl    Synced        Degraded
```

**진단:**
```bash
# Backstage pods 확인
kubectl get pods -n backstage

# Pod 로그 확인
kubectl logs -n backstage deployment/backstage --tail=100

# Events 확인
kubectl get events -n backstage --sort-by='.lastTimestamp'
```

**일반적인 원인:**
- GitHub App 설정 오류
- Database 연결 실패
- Keycloak 미준비

**해결:**
```bash
# 1. GitHub App secret 확인
kubectl get secret github-app-credentials -n backstage

# 2. Database pod 확인
kubectl get pods -n backstage -l app=postgresql

# 3. Keycloak 준비 대기
kubectl get pods -n keycloak

# 4. Backstage 재시작
kubectl rollout restart deployment backstage -n backstage
```

---

### 문제 6: Keycloak 접속 불가

**증상:**
Keycloak 페이지 접속 시 502/503 에러

**진단:**
```bash
# Keycloak pods 상태
kubectl get pods -n keycloak

# Keycloak 로그
kubectl logs -n keycloak statefulset/keycloak

# Database 상태
kubectl get pods -n keycloak -l app.kubernetes.io/name=postgresql
```

**해결:**
```bash
# 1. Database 초기화 대기 (첫 설치 시 시간 소요)
# PostgreSQL이 완전히 ready 상태가 될 때까지 대기

# 2. Keycloak pod 재시작
kubectl rollout restart statefulset keycloak -n keycloak

# 3. Admin 비밀번호 확인
kubectl get secret keycloak-config -n keycloak \
  -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d && echo
```

---

## 운영 가이드

### 일상적인 모니터링

#### Applications 상태 확인

```bash
# 모든 applications 상태
kubectl get applications -n argocd

# 특정 application 상세 정보
kubectl describe application backstage-sesac-ref-impl -n argocd

# 실시간 모니터링
watch -n 5 'kubectl get applications -n argocd'
```

#### 리소스 사용량 확인

```bash
# Node 리소스
kubectl top nodes

# Pod 리소스
kubectl top pods -A

# Namespace별 리소스
kubectl top pods -n backstage
kubectl top pods -n keycloak
kubectl top pods -n argocd
```

#### 로그 확인

```bash
# Argo CD
kubectl logs -n argocd deployment/argocd-server --tail=100

# Backstage
kubectl logs -n backstage deployment/backstage --tail=100

# Keycloak
kubectl logs -n keycloak statefulset/keycloak --tail=100
```

---

### Backup & Restore

#### Argo CD Applications Backup

```bash
# 모든 applications 백업
kubectl get applications -n argocd -o yaml > applications-backup.yaml

# 특정 application 백업
kubectl get application backstage-sesac-ref-impl -n argocd -o yaml \
  > backstage-already11-backup.yaml
```

#### Secrets Backup

```bash
# AWS Secrets Manager에 이미 백업됨
aws secretsmanager get-secret-value \
  --secret-id cnoe-ref-impl/config \
  --region ap-northeast-2 \
  --query SecretString \
  --output text > config-backup.json
```

#### Keycloak Realm Backup

```bash
# Keycloak Admin Console에서 Export
# URL: https://your-domain.com/keycloak/admin
# Realm Settings → Export → Export (include users, groups, etc.)
```

---

### Scaling

#### Node Group Scaling

```bash
# eksctl로 스케일링
eksctl scale nodegroup \
  --cluster=your-cluster-name \
  --name=managed-ng-1 \
  --nodes=6 \
  --region=ap-northeast-2

# 또는 AWS Console
# EKS → Clusters → your-cluster-name → Compute → Node groups → Edit
```

#### Application Scaling

```bash
# Backstage replicas 증가
kubectl scale deployment backstage -n backstage --replicas=3

# 또는 HPA (Horizontal Pod Autoscaler) 설정
kubectl autoscale deployment backstage -n backstage \
  --min=2 --max=5 --cpu-percent=80
```

---

### 업그레이드

#### Platform Components 업그레이드

```bash
# 1. Upstream 변경사항 가져오기
git fetch upstream
git merge upstream/main

# 2. 충돌 해결 (필요시)
git status
git mergetool

# 3. 테스트 환경에서 검증
# ...

# 4. Production 배포
git push origin main

# Argo CD가 자동으로 감지하고 동기화
```

#### Kubernetes Version 업그레이드

```bash
# EKS 클러스터 버전 업그레이드
eksctl upgrade cluster \
  --name=your-cluster-name \
  --region=ap-northeast-2 \
  --version=1.34 \
  --approve

# Node group 업그레이드
eksctl upgrade nodegroup \
  --name=managed-ng-1 \
  --cluster=your-cluster-name \
  --region=ap-northeast-2
```

---

### 보안

#### Secrets Rotation

```bash
# 1. GitHub Apps Private Key 갱신
# GitHub에서 새 Private Key 생성

# 2. 로컬 파일 업데이트
vi private/backstage-github.yaml
vi private/argocd-github.yaml

# 3. AWS Secrets Manager 업데이트
./scripts/create-config-secrets.sh

# 4. ExternalSecrets 재동기화
kubectl annotate externalsecret github-app-org -n argocd \
  force-sync="$(date +%s)" --overwrite
```

#### Network Policies 적용

```bash
# Namespace간 통신 제한
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: backstage
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

---

## 접속 방법

### Backstage (Developer Portal)

**URL (Path Routing):**
```
https://your-subdomain.your-domain.com/
```

**URL (Domain Routing):**
```
https://backstage.your-subdomain.your-domain.com/
```

**로그인:**
- **SSO (Keycloak)**:
  - Username: `user1`
  - Password:
    ```bash
    kubectl get secret -n keycloak keycloak-config \
      -o jsonpath='{.data.USER1_PASSWORD}' | base64 -d && echo
    ```

**기능:**
- Software Catalog: 애플리케이션 목록
- Templates: 프로젝트 생성 템플릿
- TechDocs: 기술 문서
- Kubernetes: 클러스터 리소스 조회

---

### Argo CD (GitOps)

**URL (Path Routing):**
```
https://your-subdomain.your-domain.com/argocd
```

**URL (Domain Routing):**
```
https://argocd.your-subdomain.your-domain.com/
```

**로그인 (Admin):**
- **Username**: `admin`
- **Password**:
  ```bash
  kubectl get secrets -n argocd argocd-initial-admin-secret \
    -oyaml | yq '.data.password' | base64 -d && echo
  ```

**로그인 (SSO):**
- **"Login via Keycloak"** 클릭
- Keycloak credentials 사용

**기능:**
- Applications: 배포된 애플리케이션 관리
- Repositories: Git 저장소 연결
- Settings: 설정 관리
- Sync: 수동 동기화

---

### Argo Workflows (CI/CD)

**URL (Path Routing):**
```
https://your-subdomain.your-domain.com/argo-workflows
```

**URL (Domain Routing):**
```
https://argo-workflows.your-subdomain.your-domain.com/
```

**로그인:**
SSO (Keycloak) 자동 연동

**기능:**
- Workflows: 워크플로우 실행 및 모니터링
- Workflow Templates: 재사용 가능한 템플릿
- Cron Workflows: 스케줄된 워크플로우

---

### Keycloak (SSO Admin)

**URL (Path Routing):**
```
https://your-subdomain.your-domain.com/keycloak/admin
```

**URL (Domain Routing):**
```
https://keycloak.your-subdomain.your-domain.com/admin
```

**Admin 로그인:**
- **Username**: `admin`
- **Password**:
  ```bash
  kubectl get secret keycloak-config -n keycloak \
    -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d && echo
  ```

**기능:**
- Realms: 인증 영역 관리
- Users: 사용자 관리
- Groups: 그룹 관리
- Clients: OAuth/OIDC 클라이언트 설정

---

### Port Forwarding (로컬 개발)

DNS 설정 전 또는 로컬 테스트용:

```bash
# Argo CD
kubectl port-forward -n argocd svc/argocd-server 8080:80
# 접속: http://localhost:8080 또는 http://localhost:8080/argocd

# Backstage
kubectl port-forward -n backstage svc/backstage 7007:7007
# 접속: http://localhost:7007

# Keycloak
kubectl port-forward -n keycloak svc/keycloak 8081:80
# 접속: http://localhost:8081
```

---

## Cleanup (삭제)

### 전체 삭제 순서

```bash
# 1. Addons 삭제
./scripts/uninstall.sh

# 2. CRDs 삭제
./scripts/cleanup-crds.sh

# 3. EKS Cluster 삭제
eksctl delete cluster \
  --name=your-cluster-name \
  --region=ap-northeast-2 \
  --wait

# 4. AWS Secrets 삭제
aws secretsmanager delete-secret \
  --secret-id cnoe-ref-impl/config \
  --region=ap-northeast-2 \
  --force-delete-without-recovery

aws secretsmanager delete-secret \
  --secret-id cnoe-ref-impl/github-app \
  --region=ap-northeast-2 \
  --force-delete-without-recovery

# 5. IAM Policies 삭제
aws iam delete-policy \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT:policy/crossplane-permissions-boundary
```

---

## 참고 자료

### 공식 문서

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Backstage Documentation](https://backstage.io/docs/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

### 커뮤니티

- [CNCF Slack](https://slack.cncf.io/)
- [Backstage Discord](https://discord.gg/backstage)
- [Argo Project Slack](https://argoproj.github.io/community/join-slack/)

---

## 라이선스

이 프로젝트는 Apache 2.0 라이선스를 따릅니다.

---

## 기여

버그 리포트, 기능 제안, Pull Request를 환영합니다!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

**작성일**: 2026-02-14
**작성자**: SESAC Project Team
**버전**: 1.0.0
