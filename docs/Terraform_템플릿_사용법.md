# Terraform 템플릿 사용법

> **Backstage를 AWS 리소스 Vending Machine으로 사용하기**

---

## 🚀 빠른 시작

### 1단계: AWS Credentials 설정

Terraform이 AWS API를 호출할 수 있도록 GitHub Organization Secrets에 자격 증명을 추가합니다.

#### 방법 1: GitHub CLI 사용 (권장)

```bash
# GitHub CLI 로그인 확인
gh auth status

# Organization Secrets 추가
gh secret set AWS_ACCESS_KEY_ID --org SAMJOYAP --body "YOUR_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --org SAMJOYAP --body "YOUR_SECRET_ACCESS_KEY"
gh secret set AWS_REGION --org SAMJOYAP --body "ap-northeast-2"
```

#### 방법 2: GitHub UI 사용

1. `https://github.com/organizations/SAMJOYAP/settings/secrets/actions` 접속
2. **New organization secret** 클릭
3. 다음 3개 Secret 추가:
   ```
   Name: AWS_ACCESS_KEY_ID
   Value: YOUR_ACCESS_KEY_ID

   Name: AWS_SECRET_ACCESS_KEY
   Value: YOUR_SECRET_ACCESS_KEY

   Name: AWS_REGION
   Value: ap-northeast-2
   ```
4. **Repository access** 선택:
   - `All repositories` 또는
   - `Selected repositories` (Terraform 템플릿으로 생성된 repo만)

### 2단계: 템플릿 사용

#### Backstage UI에서 실행

1. **Backstage 접속**
   ```bash
   open https://sesac.already11.cloud/
   ```

2. **Create 버튼 클릭**
   - 왼쪽 사이드바 → **Create...**

3. **"Create EC2 Instance with Terraform" 선택**

4. **파라미터 입력**
   ```
   Name: my-web-server
   Repository Location:
     Owner: SAMJOYAP  ← Organization 이름
     Repo: my-web-server

   Instance Type: t3.micro  ← Free Tier
   AWS Region: ap-northeast-2
   ```

5. **Review & Create**

### 3단계: 배포 확인

#### GitHub Actions 확인

```bash
# Repository 열기
gh repo view SAMJOYAP/my-web-server --web

# Actions 탭에서 "Terraform" 워크플로우 확인
```

**기대 결과:**
```
✅ Terraform Format Check
✅ Terraform Init
✅ Terraform Validate
✅ Terraform Plan
✅ Terraform Apply
```

#### AWS Console 확인

```bash
# EC2 인스턴스 목록
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=my-web-server" \
  --region ap-northeast-2 \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,State.Name]' \
  --output table

# 출력 예시:
# ---------------------------------
# |  i-0abc123def456789  |
# |  54.180.123.45      |
# |  running            |
# ---------------------------------
```

#### 웹 서버 접속

```bash
# Public IP 가져오기
PUBLIC_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=my-web-server" \
  --region ap-northeast-2 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# 브라우저에서 열기
open "http://${PUBLIC_IP}"
```

**기대 화면:**
```html
Hello from my-web-server!
Instance Type: t3.micro
Region: ap-northeast-2
```

---

## 🔧 고급 사용법

### 인스턴스 타입 변경

#### 1. Repository Clone

```bash
gh repo clone SAMJOYAP/my-web-server
cd my-web-server
```

#### 2. 변수 수정

```bash
# terraform/variables.tf 편집
vi terraform/variables.tf
```

```hcl
variable "instance_type" {
  default = "t3.small"  # ← t3.micro에서 변경
}
```

#### 3. Commit & Push

```bash
git add terraform/variables.tf
git commit -m "Upgrade to t3.small"
git push origin main
```

**GitHub Actions가 자동으로 실행되어 인스턴스 타입을 변경합니다.**

### 수동 Terraform 실행

#### 로컬 환경 설정

```bash
# AWS Credentials 설정
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="ap-northeast-2"

# Terraform 실행
cd terraform
terraform init
terraform plan
terraform apply
```

### 리소스 삭제

#### 방법 1: GitHub Actions (권장)

1. GitHub Repository → **Actions** 탭
2. **Terraform** 워크플로우 선택
3. **Run workflow** 버튼 클릭
4. **action**: `destroy` 선택
5. **Run workflow** 클릭

#### 방법 2: 로컬에서 실행

```bash
cd terraform
terraform destroy
```

---

## 📚 추가 템플릿 만들기

### S3 Bucket 템플릿 예제

**디렉토리 구조:**
```
templates/backstage/terraform-s3/
├── template.yaml
└── skeleton/
    ├── catalog-info.yaml
    ├── README.md
    ├── .gitignore
    ├── terraform/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── .github/
        └── workflows/
            └── terraform.yaml
```

**main.tf 예제:**

```hcl
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    ManagedBy   = "Terraform"
    CreatedFrom = "Backstage"
  }
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### RDS 템플릿 예제

**main.tf 예제:**

```hcl
resource "aws_db_instance" "main" {
  identifier           = var.db_name
  engine               = "postgres"
  engine_version       = "15.3"
  instance_class       = var.instance_class
  allocated_storage    = 20
  storage_encrypted    = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  skip_final_snapshot = true

  tags = {
    Name        = var.db_name
    ManagedBy   = "Terraform"
    CreatedFrom = "Backstage"
  }
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.db_name}-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}
```

---

## 🔐 보안 모범 사례

### 1. IAM 권한 최소화

Terraform 실행에 필요한 최소 권한만 부여:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:CreateTags",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-northeast-2"
        }
      }
    }
  ]
}
```

### 2. Terraform State 보안

**S3 Backend 사용 (권장):**

```hcl
terraform {
  backend "s3" {
    bucket         = "sesac-terraform-state"
    key            = "my-web-server/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

**S3 Bucket 생성:**

```bash
# State 저장용 S3 Bucket
aws s3api create-bucket \
  --bucket sesac-terraform-state \
  --region ap-northeast-2 \
  --create-bucket-configuration LocationConstraint=ap-northeast-2

# Versioning 활성화
aws s3api put-bucket-versioning \
  --bucket sesac-terraform-state \
  --versioning-configuration Status=Enabled

# Encryption 활성화
aws s3api put-bucket-encryption \
  --bucket sesac-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# DynamoDB Lock Table
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-2
```

### 3. Secrets 관리

**Sensitive 값은 AWS Secrets Manager 사용:**

```hcl
# Secrets Manager에서 읽기
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "my-db-password"
}

# RDS에 적용
resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
  # ...
}
```

### 4. Policy as Code

**Terraform Plan 검증 (GitHub Actions):**

```yaml
- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    working_directory: terraform

- name: Run Checkov
  uses: bridgecrewio/checkov-action@v12
  with:
    directory: terraform
    framework: terraform
```

---

## 🎯 Vending Machine 패턴

### 표준 카탈로그 구성

| 카테고리 | 템플릿 | 예상 시간 | 비용 (월) |
|---------|--------|----------|----------|
| **Compute** | terraform-ec2 | 5분 | $8-50 |
| | terraform-ecs | 10분 | $30-200 |
| **Container** | terraform-eks | 15분 | $70+ |
| **Database** | terraform-rds | 10분 | $15-200 |
| | terraform-dynamodb | 3분 | Free-$10 |
| **Storage** | terraform-s3 | 2분 | $0.02/GB |
| **Network** | terraform-vpc | 5분 | Free |

### 사용자 워크플로우

```
1. Developer → Backstage UI
   ↓
2. 템플릿 선택 (e.g., "Create EC2 Instance")
   ↓
3. 파라미터 입력 (Name, Instance Type, Region)
   ↓
4. Create 버튼 클릭
   ↓
5. Backstage → GitHub Repository 생성
   ↓
6. GitHub Actions → Terraform Apply
   ↓
7. AWS 리소스 생성 ✅
   ↓
8. Backstage Catalog에 등록
   ↓
9. Developer → Backstage에서 리소스 관리
```

### 거버넌스

**조직 정책 적용:**

```hcl
# 예: t3.micro, t3.small, t3.medium만 허용
variable "instance_type" {
  type = string
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Only t3.micro, t3.small, t3.medium are allowed."
  }
}

# 예: 특정 리전만 허용
variable "aws_region" {
  type = string
  validation {
    condition     = contains(["ap-northeast-2", "us-west-2"], var.aws_region)
    error_message = "Only ap-northeast-2 and us-west-2 are allowed."
  }
}
```

---

## 📊 모니터링

### Backstage에서 확인

```yaml
# catalog-info.yaml에 추가
metadata:
  annotations:
    # CloudWatch Dashboard
    aws/cloudwatch-dashboard: my-web-server-dashboard

    # Cost Explorer
    aws/cost-explorer: true
```

### GitHub Actions에서 비용 추정

```yaml
- name: Terraform Cost Estimation
  uses: infracost/actions/setup@v2
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate Infracost JSON
  run: infracost breakdown --path terraform --format json --out-file /tmp/infracost.json

- name: Post Cost Estimate
  uses: infracost/actions/comment@v1
  with:
    path: /tmp/infracost.json
```

---

## 🚀 다음 단계

1. **AWS Credentials 추가** (필수)
   ```bash
   gh secret set AWS_ACCESS_KEY_ID --org SAMJOYAP
   gh secret set AWS_SECRET_ACCESS_KEY --org SAMJOYAP
   ```

2. **첫 번째 EC2 인스턴스 생성**
   - Backstage → Create → "Create EC2 Instance with Terraform"

3. **더 많은 템플릿 추가**
   - S3 Bucket
   - RDS Database
   - EKS Cluster

4. **거버넌스 강화**
   - OPA Policy
   - Cost Limits
   - Security Scanning

---

**Happy Building! 🏗️**
