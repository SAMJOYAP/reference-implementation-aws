# Fork 후 사용자 설정 체크리스트

> 이 Repository를 Fork한 후 자신의 환경에 맞게 설정해야 하는 항목들입니다.

## ✅ 필수 설정 항목

### 1. config.yaml (필수)

```yaml
repo:
  url: "https://github.com/YOUR-ORG/reference-implementation-aws"  # ← 당신의 Fork URL
  revision: "main"
  basepath: "packages"

cluster_name: "your-cluster-name"  # ← 당신의 클러스터 이름
auto_mode: "false"
region: "ap-northeast-2"  # ← 당신의 AWS 리전 (선택)

domain: your-domain.com  # ← 당신의 도메인
route53_hosted_zone_id: Z0XXXXXXXXX  # ← 당신의 Route53 Zone ID

path_routing: "true"

tags:
  githubRepo: "github.com/YOUR-ORG/reference-implementation-aws"  # ← 당신의 Fork
  env: "dev"
  project: "your-project"  # ← 당신의 프로젝트 이름
```

**변경 필요:**
- ✅ `repo.url`: 당신의 Fork URL
- ✅ `cluster_name`: 당신의 클러스터 이름
- ✅ `region`: 당신의 AWS 리전 (다른 리전 사용 시)
- ✅ `domain`: 당신의 도메인
- ✅ `route53_hosted_zone_id`: 당신의 Hosted Zone ID
- ✅ `tags.githubRepo`: 당신의 Fork
- ✅ `tags.project`: 당신의 프로젝트 이름

---

### 2. ClusterSecretStore 리전 (다른 리전 사용 시)

**파일**: `packages/external-secrets/manifests/cluster-secret-store.yaml`

**현재 값:**
```yaml
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-2  # ← 현재 설정된 리전
```

**다른 리전 사용 시 수정 방법:**
```bash
# 예: us-west-2 사용 시
sed -i.bak "s/ap-northeast-2/us-west-2/g" \
  packages/external-secrets/manifests/cluster-secret-store.yaml
```

**변경 필요:**
- ✅ `region`: 당신의 AWS 리전과 일치시키기

---

### 3. GitHub Apps 자격 증명 (필수)

**파일**: `private/backstage-github.yaml`, `private/argocd-github.yaml`

**Backstage GitHub App:**
```yaml
appId: YOUR_APP_ID  # ← 당신의 App ID
webhookUrl: https://your-domain.com  # ← 당신의 도메인
clientId: YOUR_CLIENT_ID  # ← 당신의 Client ID
clientSecret: YOUR_CLIENT_SECRET  # ← 당신의 Client Secret
webhookSecret: "dummy-webhook-secret-not-used"  # ← 이 값 그대로 사용!
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  YOUR_PRIVATE_KEY  # ← 당신의 Private Key
  -----END RSA PRIVATE KEY-----
```

**Argo CD GitHub App:**
```yaml
url: https://github.com/YOUR-ORG  # ← 당신의 Organization URL
appId: "YOUR_APP_ID"  # ← 당신의 App ID
installationId: "YOUR_INSTALLATION_ID"  # ← 당신의 Installation ID
privateKey: |
  -----BEGIN RSA PRIVATE KEY-----
  YOUR_PRIVATE_KEY  # ← 당신의 Private Key
  -----END RSA PRIVATE KEY-----
```

**변경 필요:**
- ✅ 모든 GitHub Apps 정보를 당신의 값으로 교체

---

### 4. AWS Credentials (필수)

```bash
aws configure --profile your-project-name
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: your-region
# Default output format: json
```

**설정 필요:**
- ✅ AWS Profile 생성
- ✅ Access Key 및 Secret Key 설정
- ✅ 리전 설정

---

### 5. Backstage 템플릿 Organization (필수)

**파일들**: `templates/backstage/*/template.yaml`

**현재 값:**
```yaml
allowedOwners:
  - SAMJOYAP  # ← 당신의 GitHub Organization 이름으로 변경
```

**변경 방법:**
```bash
# 모든 템플릿에서 Organization 이름 변경
find templates/backstage -name "template.yaml" -exec \
  sed -i.bak "s/SAMJOYAP/YOUR-ORG/g" {} \;
```

**왜 필요한가?**
- ✅ GitHub Apps는 **Organization에만 설치됨**
- ❌ 개인 계정 사용 시 "No token available" 에러 발생
- ✅ Organization 사용 시 GitHub Apps로 자동 인증

**변경 필요:**
- ✅ `allowedOwners`: 당신의 GitHub Organization 이름

---

## 🚫 변경하지 않아도 되는 것들

### packages/ 디렉토리
- ✅ `packages/*/values.yaml` - 기본값 그대로 사용 가능
- ✅ `packages/*/manifests/*.yaml` - 수정 불필요 (ClusterSecretStore 제외)
- ✅ Helm charts 설정 - 기본값 사용 가능

### scripts/ 디렉토리
- ✅ 모든 스크립트 - 수정 불필요
- ✅ `create-config-secrets.sh` - 그대로 사용
- ✅ `create-cluster.sh` - 그대로 사용
- ✅ `install.sh` - 그대로 사용

---

## 📋 설치 순서 (Fork 후)

### 1단계: Repository Fork
```bash
gh repo fork cnoe-io/reference-implementation-aws --org YOUR-ORG --clone=true
cd reference-implementation-aws
```

### 2단계: GitHub Apps 생성
- Backstage GitHub App 생성
- Argo CD GitHub App 생성
- 자격 증명 저장

### 3단계: 설정 파일 업데이트
```bash
# 1. config.yaml 편집
vi config.yaml
# - repo.url
# - cluster_name
# - domain
# - route53_hosted_zone_id
# - tags

# 2. ClusterSecretStore 리전 (다른 리전 사용 시)
sed -i.bak "s/ap-northeast-2/YOUR_REGION/g" \
  packages/external-secrets/manifests/cluster-secret-store.yaml

# 3. GitHub Apps 자격 증명
cp private/backstage-github.yaml.template private/backstage-github.yaml
cp private/argocd-github.yaml.template private/argocd-github.yaml
vi private/backstage-github.yaml  # 당신의 값 입력
vi private/argocd-github.yaml     # 당신의 값 입력
```

### 4단계: AWS Secrets Manager에 저장
```bash
export AWS_PROFILE=your-profile-name
./scripts/create-config-secrets.sh
```

### 5단계: EKS 클러스터 생성
```bash
./scripts/create-cluster.sh
```

### 6단계: 플랫폼 설치
```bash
./scripts/install.sh
```

### 7단계: Git Commit & Push
```bash
git add config.yaml
git add packages/external-secrets/manifests/cluster-secret-store.yaml
git add templates/backstage/*/template.yaml
git commit -m "Configure for my environment

- Update repo URL to my fork
- Set cluster name to my-cluster
- Configure domain and Route53
- Update ClusterSecretStore region
- Update Backstage templates with my organization

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push origin main
```

---

## ✅ 요약

### 변경 필수 항목 (6개)
1. ✅ `config.yaml` - 모든 환경 변수
2. ✅ `packages/external-secrets/manifests/cluster-secret-store.yaml` - 리전 (다른 리전 사용 시)
3. ✅ `private/backstage-github.yaml` - GitHub App 자격 증명
4. ✅ `private/argocd-github.yaml` - GitHub App 자격 증명
5. ✅ AWS Credentials - AWS 계정 설정
6. ✅ `templates/backstage/*/template.yaml` - GitHub Organization 이름

### 변경 불필요 항목
- ✅ packages/ 디렉토리 (ClusterSecretStore 제외)
- ✅ scripts/ 디렉토리
- ✅ 나머지 모든 설정

---

## 🎯 결론

**네, 맞습니다!**

Fork한 후 **6개 항목만 업데이트**하면:
- ✅ config.yaml (환경 설정)
- ✅ ClusterSecretStore (리전)
- ✅ GitHub Apps 자격 증명 (2개)
- ✅ AWS Credentials
- ✅ Backstage 템플릿 Organization

**나머지는 모두 그대로 사용 가능합니다!** 🎉

다른 사용자가 Fork해도 자신의 AWS Account와 GitHub Apps만 연동하면 바로 사용할 수 있습니다.
