# Backstage Catalog 동작 원리

> **외부 템플릿을 추가하고 적용하는 방법**

---

## 📚 목차

1. [Backstage Catalog란?](#backstage-catalog란)
2. [동작 원리](#동작-원리)
3. [Catalog 등록 방법](#catalog-등록-방법)
4. [외부 템플릿 추가하기](#외부-템플릿-추가하기)
5. [적용 과정](#적용-과정)
6. [실전 예제](#실전-예제)

---

## Backstage Catalog란?

Backstage Catalog는 **Software의 메타데이터 저장소**입니다.

```
┌─────────────────────────────────────────────────┐
│            Backstage Catalog                    │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │      Catalog Database (PostgreSQL)       │  │
│  │                                          │  │
│  │  - Components (서비스, 앱)                │  │
│  │  - Templates (프로젝트 생성 템플릿)        │  │
│  │  - Resources (AWS 리소스)                │  │
│  │  - APIs (OpenAPI 스펙)                   │  │
│  │  - Locations (다른 catalog 포인터)        │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │     Catalog Processor (백그라운드)        │  │
│  │  - catalog-info.yaml 파일 수집            │  │
│  │  - Entity 파싱 및 검증                    │  │
│  │  - Database에 저장                        │  │
│  │  - 주기적 새로고침                         │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## 동작 원리

### 1. Entity와 Location

**Entity**: Backstage에 등록된 모든 것 (Component, Template, Resource 등)

**Location**: Entity들이 저장된 위치를 가리키는 포인터

```yaml
# Location (포인터)
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: my-templates
spec:
  type: url
  targets:
    - https://github.com/org/repo/blob/main/template.yaml
    - https://github.com/org/repo/blob/main/catalog-info.yaml

---
# Entity (실제 데이터)
apiVersion: backstage.io/v1alpha1
kind: Template
metadata:
  name: my-template
spec:
  # 템플릿 정의...
```

### 2. Catalog Processing 흐름

```
1. Location 등록
   ↓
2. Catalog Processor가 URL에서 파일 다운로드
   ↓
3. YAML 파싱 및 검증
   ↓
4. Entity로 변환
   ↓
5. Database에 저장
   ↓
6. Frontend에서 표시
```

### 3. Refresh 메커니즘

```
┌─────────────────────────────────────────────┐
│  자동 Refresh (기본: 100초마다)              │
├─────────────────────────────────────────────┤
│  1. Catalog Processor가 등록된 Location 확인 │
│  2. 각 Location의 파일 다시 다운로드          │
│  3. 변경사항 감지                            │
│  4. Database 업데이트                        │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  수동 Refresh                                │
├─────────────────────────────────────────────┤
│  - Backstage UI: "Refresh" 버튼             │
│  - API: POST /api/catalog/refresh            │
└─────────────────────────────────────────────┘
```

---

## Catalog 등록 방법

### 방법 1: app-config.yaml (정적 설정) ⭐ 권장

**장점:**
- Backstage 시작 시 자동 로드
- GitOps로 관리 가능
- 버전 관리 용이

**단점:**
- 변경 시 재배포 필요

#### 설정 방법:

**packages/backstage/values.yaml 수정:**

```yaml
backstage:
  appConfig:
    catalog:
      locations:
        # 로컬 템플릿 (우리 Repository)
        - type: url
          target: https://github.com/SAMJOYAP/reference-implementation-aws/blob/main/templates/backstage/catalog-info.yaml

        # 외부 템플릿 (다른 Organization)
        - type: url
          target: https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml

        # 여러 템플릿을 포함하는 Location
        - type: url
          target: https://github.com/spotify/cookiecutter-golang/blob/main/template.yaml
```

**적용:**

```bash
# 1. 파일 수정
vi packages/backstage/values.yaml

# 2. Git commit & push
git add packages/backstage/values.yaml
git commit -m "Add external catalog locations"
git push origin main

# 3. ArgoCD 동기화 (자동 또는 수동)
kubectl patch application backstage -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'

# 4. Backstage pod 재시작
kubectl rollout restart deployment backstage -n backstage
```

---

### 방법 2: Backstage UI (동적 등록) ⚡ 빠름

**장점:**
- 즉시 적용
- 재배포 불필요
- 테스트 용이

**단점:**
- Backstage pod 재시작 시 사라짐 (DB에만 저장)
- GitOps 아님

#### 등록 방법:

**Step 1: Backstage 접속**

```bash
open https://sesac.already11.cloud/
```

**Step 2: Register Existing Component**

1. 왼쪽 사이드바 → **"Catalog"**
2. 우측 상단 → **"Create..."** → **"Register Existing Component"**
3. **URL 입력:**
   ```
   https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml
   ```
4. **"Analyze"** 클릭
5. **"Import"** 클릭

**Step 3: 확인**

- **Create...** 메뉴에 새 템플릿이 나타남

---

### 방법 3: AWS Secrets Manager + Environment Variable

**우리 환경에서 사용 가능한 방법:**

#### Step 1: AWS Secrets Manager 업데이트

```bash
# 현재 설정 가져오기
aws secretsmanager get-secret-value \
  --secret-id cnoe-ref-impl/config \
  --region ap-northeast-2 \
  --query SecretString \
  --output text > /tmp/config.json

# 편집
vi /tmp/config.json
```

**추가할 내용:**

```json
{
  "BACKSTAGE_CATALOG_LOCATIONS": "- type: url\n  target: https://github.com/SAMJOYAP/reference-implementation-aws/blob/main/templates/backstage/catalog-info.yaml\n- type: url\n  target: https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml"
}
```

**업데이트:**

```bash
aws secretsmanager update-secret \
  --secret-id cnoe-ref-impl/config \
  --region ap-northeast-2 \
  --secret-string file:///tmp/config.json
```

#### Step 2: Backstage values.yaml 수정

```yaml
backstage:
  extraEnvVarsSecrets:
    - backstage-env-vars
  appConfig:
    catalog:
      locations:
        $env: BACKSTAGE_CATALOG_LOCATIONS
```

#### Step 3: 적용

```bash
# External Secret이 자동으로 업데이트됨 (약 1분)
kubectl get externalsecret -n backstage -w

# Backstage pod 재시작
kubectl rollout restart deployment backstage -n backstage
```

---

### 방법 4: Location Entity로 등록

**가장 유연한 방법!**

#### catalog-info.yaml 작성:

```yaml
# templates/backstage/external-templates.yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: external-templates
  description: External community templates
  annotations:
    backstage.io/managed-by-location: url:https://github.com/SAMJOYAP/reference-implementation-aws/blob/main/templates/backstage/catalog-info.yaml
spec:
  type: url
  targets:
    # Backstage 공식 템플릿
    - https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml
    - https://github.com/backstage/software-templates/blob/main/scaffolder-templates/springboot-grpc-template/template.yaml

    # Spotify 템플릿
    - https://github.com/spotify/cookiecutter-golang/blob/main/template.yaml

    # 다른 조직 템플릿
    - https://github.com/your-other-org/templates/blob/main/catalog-info.yaml
```

#### catalog-info.yaml에 추가:

```yaml
# templates/backstage/catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: basic-example-templates
spec:
  targets:
    - ./basic/template.yaml
    - ./argo-workflows/template.yaml
    - ./app-with-bucket/template.yaml
    - ./terraform-ec2/template.yaml
    - ./external-templates.yaml  # ← 추가!
```

#### 적용:

```bash
git add templates/backstage/external-templates.yaml
git add templates/backstage/catalog-info.yaml
git commit -m "Add external templates location"
git push origin main

# Backstage UI에서 Refresh 또는 자동 새로고침 대기
```

---

## 외부 템플릿 추가하기

### 예제 1: Backstage 공식 React Template 추가

#### 방법 A: UI에서 직접 등록

1. **Backstage → Create... → Register Existing Component**
2. **URL 입력:**
   ```
   https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml
   ```
3. **Import**

#### 방법 B: catalog-info.yaml에 추가

```yaml
# templates/backstage/catalog-info.yaml
spec:
  targets:
    - ./basic/template.yaml
    - https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml
```

### 예제 2: 다른 Organization의 Private Template 추가

**GitHub Apps 권한 필요!**

```yaml
# templates/backstage/catalog-info.yaml
spec:
  targets:
    # Private Repository (GitHub Apps 인증 사용)
    - https://github.com/your-other-org/private-templates/blob/main/template.yaml
```

**주의사항:**
- GitHub Apps가 해당 Organization에도 설치되어 있어야 함
- 또는 Personal Access Token 사용

### 예제 3: Monorepo에서 여러 템플릿 가져오기

```yaml
# other-org의 templates/catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: company-templates
spec:
  type: url
  targets:
    - ./frontend/react-template/template.yaml
    - ./backend/golang-template/template.yaml
    - ./infrastructure/terraform-eks/template.yaml
    - ./ml/jupyter-template/template.yaml
```

**등록:**

```
https://github.com/company/templates/blob/main/catalog-info.yaml
```

---

## 적용 과정

### 전체 흐름

```
┌──────────────────────────────────────────────────────┐
│ 1. Git Repository 수정                                │
│    - catalog-info.yaml 편집                          │
│    - 새 Location 추가                                 │
└──────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────┐
│ 2. Git Push                                          │
│    git push origin main                              │
└──────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────┐
│ 3. ArgoCD Sync (자동 또는 수동)                       │
│    - 변경 감지: ~3분                                  │
│    - 또는 수동: argocd app sync backstage            │
└──────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────┐
│ 4. Backstage Catalog Refresh                         │
│    방법 A: 자동 새로고침 대기 (~100초)                 │
│    방법 B: UI에서 "Refresh" 버튼                      │
│    방법 C: Pod 재시작                                 │
└──────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────┐
│ 5. Catalog Processor 실행                            │
│    - Location URL에서 파일 다운로드                   │
│    - YAML 파싱                                        │
│    - Entity 생성                                      │
│    - Database 저장                                    │
└──────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────┐
│ 6. Frontend 업데이트                                  │
│    - Create 메뉴에 템플릿 표시                        │
│    - Catalog에서 검색 가능                            │
└──────────────────────────────────────────────────────┘
```

### 시간 소요

| 단계 | 시간 | 비고 |
|------|------|------|
| Git Push | 즉시 | |
| ArgoCD Sync (자동) | ~3분 | 수동: 즉시 |
| Backstage Refresh (자동) | ~100초 | 수동: 즉시 |
| Catalog Processing | ~10초 | Location 크기에 따라 |
| **총 소요 시간** | **~5분** | **수동 시: ~30초** |

---

## 실전 예제

### 예제 1: Backstage 공식 템플릿 추가

#### Step 1: Location 파일 생성

```bash
cat > templates/backstage/community-templates.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: backstage-community-templates
  description: Official Backstage community templates
spec:
  type: url
  targets:
    # React Template
    - https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml

    # Spring Boot Template
    - https://github.com/backstage/software-templates/blob/main/scaffolder-templates/springboot-grpc-template/template.yaml

    # Create React App Template
    - https://github.com/backstage/software-templates/blob/main/scaffolder-templates/create-react-app/template.yaml
EOF
```

#### Step 2: catalog-info.yaml에 등록

```bash
# templates/backstage/catalog-info.yaml 편집
cat >> templates/backstage/catalog-info.yaml << 'EOF'
---
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: backstage-community-templates
  description: Official Backstage community templates
spec:
  type: url
  targets:
    - ./community-templates.yaml
EOF
```

#### Step 3: Git Push

```bash
git add templates/backstage/community-templates.yaml
git add templates/backstage/catalog-info.yaml
git commit -m "Add Backstage community templates"
git push origin main
```

#### Step 4: 적용 확인

```bash
# ArgoCD 동기화 확인
kubectl get application backstage -n argocd -w

# Backstage 로그 확인
kubectl logs -n backstage deployment/backstage --tail=50 | grep -i "community-templates\|catalog\|location"

# UI 확인
open https://sesac.already11.cloud/create
```

---

### 예제 2: 조직 내 다른 팀 템플릿 추가

**시나리오:** Data Team이 ML 템플릿을 만들었고, 이것을 Platform Team의 Backstage에 추가

#### Data Team (템플릿 제공)

```bash
# data-team/ml-templates/ 구조
data-team/ml-templates/
├── catalog-info.yaml
├── jupyter-notebook/
│   ├── template.yaml
│   └── skeleton/
├── mlflow-experiment/
│   ├── template.yaml
│   └── skeleton/
└── sagemaker-endpoint/
    ├── template.yaml
    └── skeleton/
```

**data-team/ml-templates/catalog-info.yaml:**

```yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: ml-templates
  description: Machine Learning templates
spec:
  type: url
  targets:
    - ./jupyter-notebook/template.yaml
    - ./mlflow-experiment/template.yaml
    - ./sagemaker-endpoint/template.yaml
```

#### Platform Team (템플릿 추가)

```yaml
# reference-implementation-aws/templates/backstage/catalog-info.yaml
spec:
  targets:
    - ./basic/template.yaml
    - ./terraform-ec2/template.yaml
    # Data Team 템플릿 추가
    - https://github.com/SAMJOYAP/data-team/blob/main/ml-templates/catalog-info.yaml
```

---

### 예제 3: Terraform Module Marketplace

**시나리오:** 여러 팀이 Terraform 모듈을 공유하는 Marketplace 구축

#### Step 1: Marketplace Repository 생성

```bash
# terraform-marketplace/catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: terraform-marketplace
  description: Shared Terraform modules
spec:
  type: url
  targets:
    # Compute
    - ./compute/ec2/template.yaml
    - ./compute/ecs/template.yaml
    - ./compute/lambda/template.yaml

    # Database
    - ./database/rds/template.yaml
    - ./database/dynamodb/template.yaml
    - ./database/elasticache/template.yaml

    # Network
    - ./network/vpc/template.yaml
    - ./network/alb/template.yaml
    - ./network/cloudfront/template.yaml

    # Security
    - ./security/iam-role/template.yaml
    - ./security/security-group/template.yaml
```

#### Step 2: 각 팀의 Backstage에 등록

```yaml
# Platform Team
- https://github.com/company/terraform-marketplace/blob/main/catalog-info.yaml

# Application Team
- https://github.com/company/terraform-marketplace/blob/main/catalog-info.yaml

# Data Team
- https://github.com/company/terraform-marketplace/blob/main/catalog-info.yaml
```

**결과:** 모든 팀이 동일한 Terraform 템플릿 사용 가능!

---

## 🔍 디버깅

### Catalog Refresh가 안 될 때

#### 1. Backstage 로그 확인

```bash
# Catalog processing 에러 확인
kubectl logs -n backstage deployment/backstage | grep -i "error\|failed\|catalog"

# 특정 Location 처리 확인
kubectl logs -n backstage deployment/backstage | grep -i "terraform-ec2"
```

#### 2. Database 확인

```bash
# Backstage Pod에 접속
kubectl exec -it -n backstage deployment/backstage -- /bin/bash

# PostgreSQL 연결
psql -h $POSTGRES_HOST -U $POSTGRES_USER -d backstage

# Location 목록 확인
SELECT * FROM final_entities WHERE kind='Location';

# Template 목록 확인
SELECT * FROM final_entities WHERE kind='Template';
```

#### 3. 수동 Refresh API 호출

```bash
# Backstage API로 직접 refresh 요청
kubectl port-forward -n backstage svc/backstage 7007:7007

# API 호출
curl -X POST http://localhost:7007/api/catalog/locations \
  -H "Content-Type: application/json" \
  -d '{
    "type": "url",
    "target": "https://github.com/SAMJOYAP/reference-implementation-aws/blob/main/templates/backstage/catalog-info.yaml"
  }'
```

---

## 📚 참고 자료

### Backstage 공식 문서

- [Software Catalog](https://backstage.io/docs/features/software-catalog/)
- [Adding Components to the Catalog](https://backstage.io/docs/features/software-catalog/life-of-an-entity)
- [Catalog Configuration](https://backstage.io/docs/features/software-catalog/configuration)

### Community Templates

- [Backstage Software Templates](https://github.com/backstage/software-templates)
- [Spotify Templates](https://github.com/spotify/cookiecutter-golang)
- [RoadieHQ Templates](https://github.com/RoadieHQ/software-templates)

### Best Practices

1. **GitOps 방식 사용**
   - catalog-info.yaml을 Git으로 관리
   - PR로 리뷰 후 추가

2. **Location 계층 구조**
   - 루트 Location → 팀별 Location → 개별 Template
   - 관리 용이

3. **주기적 검증**
   - CI/CD에서 catalog-info.yaml 검증
   - Schema validation

4. **문서화**
   - 각 템플릿에 README.md 추가
   - 사용 예제 포함

---

**이제 외부 템플릿을 자유롭게 추가할 수 있습니다! 🎉**
