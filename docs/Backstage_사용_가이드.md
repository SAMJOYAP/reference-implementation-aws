# Backstage 사용 가이드

> **Backstage를 Internal Developer Platform (IDP)으로 활용하기**
>
> 이 가이드는 Backstage를 AWS 리소스 프로비저닝을 위한 **Vending Machine (자판기)**처럼 사용하는 방법을 설명합니다.

---

## 📚 목차

1. [Backstage Component 개념](#backstage-component-개념)
2. [Component 구조와 타입](#component-구조와-타입)
3. [기존 템플릿 사용하기](#기존-템플릿-사용하기)
4. [외부 Component 추가하기](#외부-component-추가하기)
5. [새로운 템플릿 만들기](#새로운-템플릿-만들기)
6. [Terraform + GitHub Actions 활용](#terraform--github-actions-활용)
7. [Vending Machine 패턴](#vending-machine-패턴)

---

## Backstage Component 개념

### 🎯 Backstage란?

Backstage는 **Software Catalog**를 중심으로 한 **Developer Portal**입니다.

```
┌─────────────────────────────────────────────────────┐
│                   Backstage                         │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │         Software Catalog (중심)               │  │
│  │  - Components (서비스, 앱, 라이브러리)          │  │
│  │  - Resources (데이터베이스, S3, RDS 등)        │  │
│  │  - Systems (여러 Component의 그룹)             │  │
│  │  - APIs (OpenAPI, GraphQL 스펙)               │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  │
│  │ Scaffolder   │  │ TechDocs     │  │ Plugins  │  │
│  │ (템플릿 실행) │  │ (문서화)      │  │ (통합)   │  │
│  └──────────────┘  └──────────────┘  └──────────┘  │
└─────────────────────────────────────────────────────┘
```

### 🧩 Entity 타입

Backstage는 여러 **Entity 타입**을 지원합니다:

| Entity 타입 | 설명 | 예시 |
|-------------|------|------|
| **Component** | 소프트웨어 컴포넌트 (서비스, 웹사이트, 라이브러리) | 마이크로서비스, Frontend 앱 |
| **Resource** | 인프라 리소스 (AWS, GCP, DB 등) | S3 Bucket, RDS, DynamoDB |
| **System** | 여러 Component/Resource의 논리적 그룹 | E-commerce System |
| **API** | API 정의 (OpenAPI, AsyncAPI, GraphQL) | REST API, gRPC Service |
| **Template** | 새로운 프로젝트를 생성하는 템플릿 | Create React App, Go Microservice |
| **Location** | 다른 catalog-info.yaml을 가리키는 포인터 | Monorepo의 각 서비스 |
| **Domain** | 비즈니스 영역 | Payments, Identity, Shipping |
| **Group** | 사용자 그룹 (팀, 조직) | Platform Team, Data Team |
| **User** | 개별 사용자 | john@company.com |

---

## Component 구조와 타입

### 📄 catalog-info.yaml 구조

모든 Backstage Entity는 **catalog-info.yaml** 파일로 정의됩니다:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component                    # Entity 타입
metadata:
  name: my-service                 # 고유 이름
  description: My awesome service  # 설명
  annotations:                     # 메타데이터
    github.com/project-slug: org/repo
    backstage.io/kubernetes-label-selector: 'app=my-service'
    argocd/app-name: my-service
  labels:                          # 태그
    env: production
    tier: backend
  links:                           # 외부 링크
    - url: https://dashboard.example.com
      title: Dashboard
      icon: dashboard
spec:
  type: service                    # Component 타입
  lifecycle: production            # 라이프사이클
  owner: team-platform             # 소유자
  system: e-commerce               # 속한 System
  dependsOn:                       # 의존성
    - resource:default/my-database
  providesApis:                    # 제공하는 API
    - my-api
```

### 🏷️ Component Type (spec.type)

| Type | 설명 | 사용 예시 |
|------|------|-----------|
| **service** | 백엔드 서비스 | REST API, gRPC 서비스 |
| **website** | 웹사이트/프론트엔드 | React 앱, Vue 앱 |
| **library** | 공유 라이브러리 | npm 패키지, Go module |
| **documentation** | 문서 | 가이드, API 문서 |
| **tool** | 개발 도구 | CI/CD 스크립트, 유틸리티 |

### 🔄 Lifecycle (spec.lifecycle)

| Lifecycle | 설명 |
|-----------|------|
| **experimental** | 실험 단계 (개발 중) |
| **production** | 운영 환경 배포 |
| **deprecated** | 사용 중단 예정 |

### 📌 Annotations (통합)

Annotations는 Backstage Plugin과 통합하는 핵심입니다:

```yaml
annotations:
  # GitHub Integration
  github.com/project-slug: SAMJOYAP/my-repo

  # Kubernetes Integration
  backstage.io/kubernetes-id: my-service
  backstage.io/kubernetes-label-selector: 'app=my-service'
  backstage.io/kubernetes-namespace: production

  # ArgoCD Integration
  argocd/app-name: my-service

  # Argo Workflows Integration
  argo-workflows.cnoe.io/label-selector: 'app=my-service'

  # TechDocs (문서)
  backstage.io/techdocs-ref: dir:.

  # Crossplane (AWS 리소스)
  crossplane.io/claim-name: my-s3-bucket
```

---

## 기존 템플릿 사용하기

### 📦 현재 사용 가능한 템플릿

| 템플릿 | 설명 | 생성 리소스 |
|--------|------|-------------|
| **Create a Basic Deployment** | 기본 Kubernetes Deployment | Deployment, Service, Ingress |
| **Add a Go App with AWS resources** | Crossplane으로 S3 Bucket 생성 | Go App + S3 Bucket |
| **Basic Argo Workflow with Spark Job** | Spark Job 실행 | Argo Workflow + Spark |

### 🚀 템플릿 실행 방법

#### 1. Backstage UI 접속

```bash
open https://sesac.already11.cloud/
```

#### 2. Create 버튼 클릭

왼쪽 사이드바 → **Create...** 버튼

#### 3. 템플릿 선택

원하는 템플릿 카드 클릭

#### 4. 파라미터 입력

**⚠️ 중요: Organization 사용 필수!**

```
Name: my-app
Repository Location:
  Owner: SAMJOYAP  ← Organization 이름 (개인 계정 사용 시 에러!)
  Repo: my-app
```

#### 5. Review & Create

모든 입력 확인 후 **Create** 클릭

#### 6. 진행 상황 확인

```
✅ Step 1: Create Repository
✅ Step 2: Generating component
✅ Step 3: Initialize Repository
✅ Step 4: Waiting for the repo to be ready
✅ Step 5: Create ArgoCD App
✅ Step 6: Register

Success! 🎉
```

#### 7. 결과 확인

```bash
# GitHub에 Repository 생성됨
gh repo view SAMJOYAP/my-app

# ArgoCD에 Application 생성됨
kubectl get application my-app -n argocd

# Backstage Catalog에 등록됨
https://sesac.already11.cloud/catalog/default/component/my-app
```

---

## 외부 Component 추가하기

### 방법 1: GitHub Repository에서 가져오기

기존 GitHub Repository를 Backstage에 등록:

#### 1. Repository에 catalog-info.yaml 추가

```yaml
# catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: existing-service
  description: My existing service
  annotations:
    github.com/project-slug: SAMJOYAP/existing-service
spec:
  type: service
  lifecycle: production
  owner: team-platform
```

#### 2. Backstage UI에서 Import

```
1. Backstage → Create... → Register Existing Component
2. URL 입력: https://github.com/SAMJOYAP/existing-service/blob/main/catalog-info.yaml
3. Analyze → Import
```

#### 3. 자동 등록 (권장)

AWS Secrets Manager에 catalog locations 추가:

```bash
# config.yaml 또는 Secrets Manager에 추가
BACKSTAGE_CATALOG_LOCATIONS: |
  - type: url
    target: https://github.com/SAMJOYAP/existing-service/blob/main/catalog-info.yaml
```

### 방법 2: Monorepo에서 여러 Component 등록

```yaml
# 루트 catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: my-monorepo
  description: All services in monorepo
spec:
  type: url
  targets:
    - ./services/frontend/catalog-info.yaml
    - ./services/backend/catalog-info.yaml
    - ./services/auth/catalog-info.yaml
```

### 방법 3: 외부 조직의 Component 등록

다른 팀/조직의 공개 템플릿 사용:

```yaml
# 외부 템플릿 참조
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: external-templates
spec:
  type: url
  targets:
    - https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml
```

---

## 새로운 템플릿 만들기

### 📁 템플릿 디렉토리 구조

```
templates/backstage/my-template/
├── template.yaml          # 템플릿 정의 (메타데이터 + 파라미터 + 스텝)
└── skeleton/              # 생성될 파일들
    ├── catalog-info.yaml  # Backstage 등록 파일
    ├── README.md          # 프로젝트 문서
    ├── .github/
    │   └── workflows/
    │       └── deploy.yaml  # GitHub Actions
    ├── terraform/         # Terraform 코드
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── manifests/         # Kubernetes 매니페스트
        ├── deployment.yaml
        └── service.yaml
```

### 📝 template.yaml 작성

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: terraform-ec2
  title: Create EC2 Instance with Terraform
  description: Creates an EC2 instance using Terraform and GitHub Actions
  tags:
    - terraform
    - aws
    - ec2
spec:
  owner: platform-team
  type: infrastructure

  # 사용자 입력 파라미터
  parameters:
    - title: Configuration
      required:
        - name
        - repoUrl
      properties:
        name:
          type: string
          description: Name of the EC2 instance
          ui:autofocus: true
        repoUrl:
          title: Repository Location
          type: string
          description: 'Use your GitHub Organization name (e.g., SAMJOYAP)'
          ui:field: RepoUrlPicker
          ui:options:
            allowedHosts:
              - github.com
            allowedOwners:
              - SAMJOYAP
        instanceType:
          type: string
          title: Instance Type
          description: EC2 instance type
          default: t3.micro
          enum:
            - t3.micro
            - t3.small
            - t3.medium
            - t3.large
        region:
          type: string
          title: AWS Region
          description: AWS region for deployment
          default: ap-northeast-2
          enum:
            - us-east-1
            - us-west-2
            - ap-northeast-2
            - eu-west-1

  # 실행 스텝
  steps:
    # 1. GitHub Repository 생성
    - id: create-repo
      name: Create Repository
      action: github:repo:create
      input:
        repoUrl: ${{ parameters.repoUrl }}
        description: EC2 instance managed by Terraform

    # 2. 템플릿 파일 생성
    - id: template
      name: Generating component
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          instanceType: ${{ parameters.instanceType }}
          region: ${{ parameters.region }}
          repoUrl: ${{ parameters.repoUrl }}
          remoteUrl: ${{ steps['create-repo'].output.remoteUrl }}

    # 3. GitHub에 Push
    - id: init-repo
      name: Initialize Repository
      action: github:repo:push
      input:
        repoUrl: ${{ parameters.repoUrl }}
        defaultBranch: main

    # 4. GitHub Secrets 생성 (AWS Credentials)
    - id: create-secrets
      name: Create GitHub Secrets
      action: github:repo:secrets
      input:
        repoUrl: ${{ parameters.repoUrl }}
        secrets:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ parameters.region }}

    # 5. Backstage Catalog 등록
    - id: register
      name: Register
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['init-repo'].output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'

  # 출력 (완료 후 링크)
  output:
    links:
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps['register'].output.entityRef }}
      - title: Open in GitHub
        icon: github
        url: ${{ steps['create-repo'].output.remoteUrl }}
```

### 🗂️ skeleton/catalog-info.yaml

```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: ${{ values.name }}-ec2
  description: EC2 instance managed by Terraform
  annotations:
    github.com/project-slug: ${{ values.repoUrl | parseRepoUrl | pick('owner') }}/${{ values.repoUrl | parseRepoUrl | pick('repo') }}
spec:
  type: ec2-instance
  owner: platform-team
  lifecycle: production
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.name }}
  description: Terraform configuration for EC2 instance
  annotations:
    github.com/project-slug: ${{ values.repoUrl | parseRepoUrl | pick('owner') }}/${{ values.repoUrl | parseRepoUrl | pick('repo') }}
    backstage.io/techdocs-ref: dir:.
  links:
    - url: ${{ values.remoteUrl }}
      title: Repository
      icon: github
spec:
  type: infrastructure
  lifecycle: production
  owner: platform-team
  dependsOn:
    - resource:default/${{ values.name }}-ec2
```

---

## Terraform + GitHub Actions 활용

### 🏗️ Vending Machine 패턴

**목표:** 개발자가 버튼 클릭만으로 AWS 리소스를 프로비저닝

```
Developer → Backstage Template → GitHub Repo + Actions → Terraform → AWS
```

### 📦 Terraform 템플릿 예제

#### skeleton/terraform/main.tf

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "sesac-terraform-state"
    key    = "${{ values.name }}/terraform.tfstate"
    region = "${{ values.region }}"
  }
}

provider "aws" {
  region = var.aws_region
}

# EC2 Instance
resource "aws_instance" "main" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  tags = {
    Name        = var.instance_name
    ManagedBy   = "Terraform"
    CreatedFrom = "Backstage"
    Project     = "${{ values.name }}"
  }
}

# Latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Outputs
output "instance_id" {
  value = aws_instance.main.id
}

output "public_ip" {
  value = aws_instance.main.public_ip
}
```

#### skeleton/terraform/variables.tf

```hcl
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "${{ values.name }}"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "${{ values.instanceType }}"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${{ values.region }}"
}
```

### ⚙️ GitHub Actions 워크플로우

#### skeleton/.github/workflows/terraform.yaml

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

env:
  AWS_REGION: ${{ values.region }}
  TF_VERSION: 1.6.0

jobs:
  terraform:
    name: Terraform
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: ./terraform
        run: terraform init

      - name: Terraform Plan
        working-directory: ./terraform
        run: terraform plan -no-color
        continue-on-error: true

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        working-directory: ./terraform
        run: terraform apply -auto-approve

      - name: Terraform Output
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        working-directory: ./terraform
        run: |
          echo "### Terraform Outputs" >> $GITHUB_STEP_SUMMARY
          terraform output -json | jq -r 'to_entries[] | "- **\(.key)**: \(.value.value)"' >> $GITHUB_STEP_SUMMARY
```

---

## Vending Machine 패턴

### 🎰 Self-Service Infrastructure

**목표:** 개발자가 직접 인프라를 프로비저닝할 수 있는 셀프 서비스 플랫폼

### 📋 표준 카탈로그 구성

| 카테고리 | 템플릿 | 설명 |
|---------|--------|------|
| **Compute** | terraform-ec2 | EC2 인스턴스 생성 |
| | terraform-ecs | ECS 클러스터 + 서비스 |
| | terraform-lambda | Lambda 함수 |
| **Container** | terraform-eks | EKS 클러스터 생성 |
| | k8s-deployment | Kubernetes Deployment |
| **Database** | terraform-rds | RDS (PostgreSQL, MySQL) |
| | terraform-dynamodb | DynamoDB 테이블 |
| **Storage** | terraform-s3 | S3 Bucket |
| | terraform-efs | EFS 파일시스템 |
| **Network** | terraform-vpc | VPC + Subnets |
| | terraform-alb | Application Load Balancer |

### 🔐 보안 모범 사례

#### 1. AWS Credentials 관리

**방법 1: GitHub Organization Secrets (권장)**

```bash
# Organization 레벨에서 설정
gh secret set AWS_ACCESS_KEY_ID --org SAMJOYAP
gh secret set AWS_SECRET_ACCESS_KEY --org SAMJOYAP
gh secret set AWS_REGION --org SAMJOYAP
```

**방법 2: OIDC (GitHub Actions → AWS)**

```hcl
# terraform/iam.tf
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:SAMJOYAP/*:*"
          }
        }
      }
    ]
  })
}
```

#### 2. Terraform State 관리

**S3 Backend + DynamoDB Lock**

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "sesac-terraform-state"
    key            = "${var.project_name}/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

#### 3. Policy as Code (OPA, Sentinel)

```rego
# policy/compute.rego
package terraform.compute

# EC2 인스턴스는 t3.micro, t3.small, t3.medium만 허용
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_instance"
  not contains(["t3.micro", "t3.small", "t3.medium"], resource.change.after.instance_type)
  msg := sprintf("Instance type %s is not allowed", [resource.change.after.instance_type])
}
```

---

## 📚 추가 리소스

### 공식 문서

- [Backstage 공식 문서](https://backstage.io/docs/overview/what-is-backstage)
- [Software Templates](https://backstage.io/docs/features/software-templates/)
- [Software Catalog](https://backstage.io/docs/features/software-catalog/)

### 예제 템플릿

- [Backstage Software Templates](https://github.com/backstage/software-templates)
- [Spotify Templates](https://github.com/spotify/backstage/tree/master/plugins/scaffolder-backend/sample-templates)

### Terraform Modules

- [AWS Terraform Modules](https://github.com/terraform-aws-modules)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

## 🚀 다음 단계

1. **기존 템플릿으로 실습**
   ```bash
   # Backstage에서 "Create a Basic Deployment" 실행
   open https://sesac.already11.cloud/
   ```

2. **Terraform 템플릿 생성**
   ```bash
   # terraform-ec2 템플릿 추가 (다음 섹션 참조)
   mkdir -p templates/backstage/terraform-ec2/{skeleton/terraform,.github/workflows}
   ```

3. **자동화 파이프라인 구축**
   - GitHub Actions로 Terraform 자동 배포
   - ArgoCD로 Kubernetes 배포 자동화
   - Crossplane으로 AWS 리소스 GitOps

4. **거버넌스 추가**
   - OPA Policy 추가
   - Cost Estimation (Infracost)
   - Security Scanning (tfsec, Checkov)

---

**Happy Building! 🏗️**
