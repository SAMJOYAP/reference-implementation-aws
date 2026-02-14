# 빠른 시작 가이드 (Quick Start)

## 🚀 5분 안에 시작하기

이미 사전 요구사항이 준비되어 있다면, 이 가이드를 따라 빠르게 플랫폼을 구축할 수 있습니다.

---

## 사전 준비 체크리스트

- [ ] AWS Account & Access Keys
- [ ] GitHub Organization
- [ ] Route53 Hosted Zone & Domain
- [ ] 로컬 도구 설치 (aws-cli, kubectl, eksctl, helm, yq, gh)

---

## Step 1: 환경 변수 설정 (1분)

```bash
# AWS Profile
export AWS_PROFILE=your-project-name
export AWS_REGION=ap-northeast-2

# GitHub
export GH_ORG=your-org-name
export GH_TOKEN=your_github_token

# Domain
export DOMAIN=your-subdomain.your-domain.com
export HOSTED_ZONE_ID=Z00XXXXXXXX

# Cluster
export CLUSTER_NAME=your-cluster-name
```

---

## Step 2: Repository Fork & Clone (1분)

```bash
# GitHub CLI 로그인
echo $GH_TOKEN | gh auth login --with-token

# Fork
gh repo fork cnoe-io/reference-implementation-aws --org $GH_ORG --clone=true

# 이동
cd reference-implementation-aws
```

---

## Step 3: GitHub Apps 생성 (5-10분)

**Backstage App:**
```bash
# 브라우저에서 수동 생성
open "https://github.com/organizations/$GH_ORG/settings/apps/new"
```

1. Name: `$GH_ORG-backstage`
2. Homepage URL: `https://$DOMAIN`
3. Callback URL: `https://$DOMAIN/api/auth/github/handler/frame`
4. Webhook: Uncheck
5. Permissions: Administration (Read/Write), Contents (Read/Write), Members (Read), Organization Admin (Read)
6. Create → Generate Private Key → Install App

**Argo CD App:** (동일 과정 반복, 읽기 전용 권한)

**설정 파일 생성:**
```bash
cp private/backstage-github.yaml.template private/backstage-github.yaml
cp private/argocd-github.yaml.template private/argocd-github.yaml

# 편집 (App ID, Client ID, Client Secret, Private Key, Installation ID 입력)
vi private/backstage-github.yaml
vi private/argocd-github.yaml
```

---

## Step 4: 설정 파일 작성 (2분)

**config.yaml:**
```bash
cat > config.yaml << EOF
repo:
  url: "https://github.com/$GH_ORG/reference-implementation-aws"
  revision: "main"
  basepath: "packages"

cluster_name: "$CLUSTER_NAME"
auto_mode: "false"
region: "$AWS_REGION"

domain: $DOMAIN
route53_hosted_zone_id: $HOSTED_ZONE_ID

path_routing: "true"

tags:
  githubRepo: "github.com/$GH_ORG/reference-implementation-aws"
  env: "dev"
  project: "$(echo $CLUSTER_NAME | cut -d'-' -f1)"
EOF
```

**ClusterSecretStore 리전 수정:**
```bash
sed -i '' "s/us-west-2/$AWS_REGION/g" \
  packages/external-secrets/manifests/cluster-secret-store.yaml
```

---

## Step 5: AWS Secrets 생성 (1분)

```bash
./scripts/create-config-secrets.sh
# 입력: yes
```

---

## Step 6: EKS Cluster 생성 (15-20분)

```bash
./scripts/create-cluster.sh
# 선택: 1 (eksctl)
```

**다른 터미널에서 진행 상황 확인:**
```bash
watch -n 10 'aws cloudformation describe-stacks \
  --region $AWS_REGION \
  --stack-name eksctl-$CLUSTER_NAME-cluster \
  --query "Stacks[0].StackStatus" \
  --output text'
```

---

## Step 7: 플랫폼 설치 (5-10분)

```bash
./scripts/install.sh
# 입력: yes
```

**모니터링 (별도 터미널):**
```bash
# Terminal 1
watch -n 5 'kubectl get applications -n argocd'

# Terminal 2
watch -n 5 'kubectl get pods -A'

# Terminal 3
kubectl port-forward -n argocd svc/argocd-server 8080:80
# http://localhost:8080/argocd
```

---

## Step 8: Git Push (1분)

```bash
git add .
git commit -m "Initial platform configuration

- Configure for $CLUSTER_NAME
- Set domain to $DOMAIN
- Update ClusterSecretStore region to $AWS_REGION

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push origin main
```

---

## Step 9: DNS 전파 대기 (5분)

```bash
# DNS 전파 확인
watch -n 10 "dig $DOMAIN"

# ALB 생성 확인
kubectl get ingress -A

# External DNS 로그 확인
kubectl logs -n external-dns deployment/external-dns --tail=50
```

---

## Step 10: 접속 확인 ✅

```bash
# Admin 비밀번호 확인
echo "Argo CD:"
kubectl get secrets -n argocd argocd-initial-admin-secret \
  -oyaml | yq '.data.password' | base64 -d && echo

echo "Keycloak User1:"
kubectl get secret -n keycloak keycloak-config \
  -o jsonpath='{.data.USER1_PASSWORD}' | base64 -d && echo
```

**브라우저 접속:**
- Backstage: `https://$DOMAIN/`
- Argo CD: `https://$DOMAIN/argocd`
- Argo Workflows: `https://$DOMAIN/argo-workflows`

---

## 문제 발생 시

### ClusterSecretStore 리전 오류

```bash
# 현재 리전 확인
kubectl get clustersecretstore aws-secretsmanager \
  -o jsonpath='{.spec.provider.aws.region}'

# 올바른 리전으로 패치
kubectl patch clustersecretstore aws-secretsmanager \
  --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/spec/provider/aws/region\", \"value\":\"$AWS_REGION\"}]"

# External Secrets 재시작
kubectl rollout restart deployment external-secrets -n external-secrets
```

### Applications 생성 안됨

```bash
# Cluster secret 확인
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# 없으면 ExternalSecret 재생성
kubectl delete externalsecret hub-cluster-secret -n argocd
kubectl apply -f packages/argo-cd/manifests/hub-cluster-secret.yaml
```

### 상세 트러블슈팅

전체 트러블슈팅 가이드: [SETUP_GUIDE_KR.md - 트러블슈팅 섹션](./SETUP_GUIDE_KR.md#트러블슈팅)

---

## 총 소요 시간

- **준비**: 10분
- **EKS Cluster**: 15-20분
- **플랫폼 설치**: 5-10분
- **DNS 전파**: 5분

**전체**: 약 40-50분

---

## 다음 단계

1. [운영 가이드](./SETUP_GUIDE_KR.md#운영-가이드) 읽기
2. Backstage에서 첫 프로젝트 생성
3. Argo CD에서 GitOps 워크플로우 학습
4. Crossplane으로 AWS 리소스 프로비저닝

---

**Happy Hacking! 🚀**
