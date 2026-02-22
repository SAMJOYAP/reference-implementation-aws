# GitOps 통합 운영 가이드

## 1. 목적

이 문서는 현재 적용된 GitOps 운영 구조를 정리합니다.

- Node 템플릿 앱 (`node-express`)
- Java 템플릿 앱 (`java-spring`)
- Backstage 앱 (`backstage-kr`)

모든 앱의 배포 매니페스트를 별도 GitOps 저장소(`SAMJOYAP/gitops`)에서 관리하도록 통일합니다.

---

## 2. 현재 구조 요약

### 2.1 애플리케이션 코드 저장소

- `SAMJOYAP/node-express`
- `SAMJOYAP/java-spring`
- `SAMJOYAP/backstage-app`

역할:
- 애플리케이션 소스코드 관리
- CI/CD에서 이미지 빌드 후 ECR 푸시

### 2.2 GitOps 저장소

- `SAMJOYAP/gitops`

배포 경로:
- `apps/node-express/...`
- `apps/java-spring/...`
- `apps/backstage-kr/...`

역할:
- Kubernetes 배포 매니페스트 단일 소스
- Node/Java CD는 `deployment.yaml`의 `image:` 갱신
- Backstage CD는 `values-kr.yaml`의 `backstage.image.*` 갱신
- PR + auto-merge로 변경 반영

---

## 3. 템플릿 반영 사항 (Node/Java)

변경 파일:
- `templates/backstage/nodejs-nginx/template.yaml`
- `templates/backstage/springboot-apache/template.yaml`
- `templates/backstage/nodejs-nginx/skeleton-base/.github/workflows/cd.yaml`
- `templates/backstage/springboot-apache/skeleton-base/.github/workflows/cd.yaml`

핵심 변경:
1. 템플릿 파라미터에 `gitopsRepoUrl` 추가
2. Argo CD App source를 앱 코드 repo가 아니라 GitOps repo(`apps/<app-name>`)로 변경
3. CD가 GitOps repo의 `apps/<app-name>`를 자동 생성/갱신
4. CD가 GitOps repo에 PR 생성 + auto-merge 수행
5. CD 실행 순서 고정: `CI(main) 성공 -> CD(workflow_run)`
6. 템플릿 CD heredoc 들여쓰기 문제 수정(신규 생성 repo YAML 파싱 오류 방지)

---

## 4. Backstage 앱 반영 사항

변경 파일:
- `backstage-app/.github/workflows/build-and-deploy-ecr.yaml`

핵심 변경:
1. 기존 `reference-implementation-aws/packages/backstage/values-kr.yaml` 직접 수정 방식 제거
2. `SAMJOYAP/gitops/apps/backstage-kr` 갱신 방식으로 전환
3. GitOps repo에 PR 생성 + auto-merge 수행
4. `packages/appset-chart`에서 `backstage-kr`만 GitOps repo/경로를 사용하도록 차트별 source override 지원
   - `repoURLGit`, `repoURLGitRevision`, `repoURLGitBasePath`
   - `valuesPathName`, `additionalResourcesPathName`

---

## 5. GitOps 디렉터리 표준

Node/Java 표준:

```text
apps/<app-name>/
  kustomization.yaml
  manifests/
    namespace.yaml
    service.yaml
    deployment.yaml
    ingress.yaml
```

Backstage-kr 표준:

```text
apps/backstage-kr/
  values.yaml
  values-kr.yaml
  kustomization.yaml
  manifests/
    external-secrets.yaml
    k8s-config-secret.yaml
```

CD 업데이트 대상:
- `apps/<app-name>/manifests/deployment.yaml`의 `image:` 필드
- `apps/backstage-kr/values-kr.yaml`의 `backstage.image.registry/repository/tag`

---

## 6. 필수 GitHub Secrets

### 6.1 공통

- `AWS_ROLE_ARN` (또는 기존 AWS 인증 방식)
- `AWS_REGION`
- `GITOPS_REPO_TOKEN`

### 6.2 `GITOPS_REPO_TOKEN` 사용처

- Node/Java 생성 앱 CD
- `backstage-app` CD

용도:
- `SAMJOYAP/gitops` clone
- GitOps repo PR 생성
- auto-merge 실행

---

## 7. GITOPS_REPO_TOKEN 발급 방법

실무 권장 순서:
1. 우선 Fine-grained PAT로 빠르게 시작
2. 이후 GitHub App 토큰 방식으로 전환(권한 분리/보안 강화)

### 7.1 방법 A: Fine-grained PAT (빠른 적용)

1. GitHub 우측 상단 프로필 -> `Settings`
2. `Developer settings` -> `Personal access tokens` -> `Fine-grained tokens`
3. `Generate new token`
4. Repository access:
   - `Only select repositories`
   - `gitops` repo만 선택
5. Permissions:
   - `Contents`: Read and write
   - `Pull requests`: Read and write
   - `Metadata`: Read
6. 만료일 설정 후 토큰 생성
7. 생성된 값을 Secret으로 등록:
   - Organization secret 또는 각 repo secret 이름: `GITOPS_REPO_TOKEN`

### 7.2 방법 B: GitHub App Token (장기 권장)

1. GitOps 전용 GitHub App 생성(예: `samjoyap-gitops`)
2. App 권한:
   - `Contents: Read and write`
   - `Pull requests: Read and write`
   - `Metadata: Read`
3. App을 `gitops` repo에 설치
4. 워크플로우에서 App 토큰 발급 후 `GITOPS_REPO_TOKEN` 대신 사용

참고:
- 현재 워크플로우는 `GITOPS_REPO_TOKEN` secret 값을 직접 사용하도록 구현되어 있습니다.

---

## 8. Org/Repository 정책 체크리스트

1. `Settings -> Actions -> General`
   - `Workflow permissions: Read and write permissions`
   - `Allow GitHub Actions to create and approve pull requests` 활성화
2. GitOps repo에서 auto-merge 가능 상태 확인
3. Ruleset/Branch protection이 CD PR auto-merge를 차단하지 않는지 확인
4. Argo CD source가 GitOps repo 경로를 바라보는지 확인
5. Ruleset이 없다면 bypass 설정은 불필요(기능 차단 원인은 보통 auto-merge/권한 설정)

---

## 9. 운영 시 확인 순서

1. 앱 코드 repo에서 main 머지
2. CI 성공 확인
3. CD에서 ECR 이미지 생성 확인
4. GitOps repo에 `chore(cd): update ... image tag` PR 생성 확인
5. PR auto-merge 완료 확인
6. Argo CD sync 후 신규 이미지 배포 확인
7. 도메인 접속 시 커스텀 랜딩 페이지 노출 확인

---

## 10. 참고 커밋 (운영 전환 기준)

- `reference-implementation-aws`
  - `36e264d`: CD를 CI 성공 이후에만 실행하도록 변경
  - `0fae281`: Node/Java 템플릿 CD YAML heredoc 파싱 오류 수정
  - `2085110`: `backstage-kr` ApplicationSet source를 GitOps repo 기반으로 전환
- `gitops`
  - `80a66f2`: `backstage-kr`를 values 기반 + external manifests 구조로 정리
- `backstage-app`
  - `3e34b7c`: `backstage-kr` 이미지 업데이트를 GitOps values 파일 갱신 방식으로 전환
