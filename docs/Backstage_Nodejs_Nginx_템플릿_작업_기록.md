# Node.js + Nginx Backstage 템플릿 작업 기록

## 1. 작업 목적

CNOE IDP on AWS 환경의 Backstage Scaffolder에서 다음 요구사항을 만족하는 신규 템플릿을 구현:

- Node.js 웹 프로젝트 자동 생성
- Nginx 기반 서비스/배포 매니페스트 자동 생성
- Express 사용 여부 선택 옵션
- Node.js 버전 선택 옵션 (기본값 24.13.1)
- GitHub 저장소 자동 생성 및 초기 push
- CI( GitHub Actions ) 자동 구성
- Argo CD 앱 자동 등록
- Ingress 옵션 + Host/Port 사용자 입력
- 랜딩 페이지 커스터마이징(언어/버전/옵션 표시)

---

## 2. 최종 템플릿 구조

### 2.1 템플릿 엔트리

- `templates/backstage/nodejs-nginx/template.yaml`

주요 단계:

1. `github:repo:create` (저장소 생성)
2. `fetch:template` base 스켈레톤 생성
3. 조건부 오버레이 적용
   - Ingress 오버레이
   - Express 오버레이(JS)
   - TypeScript base 오버레이
   - Express 오버레이(TS)
4. `github:repo:push`
5. `cnoe:create-argocd-app`
6. `catalog:register`

### 2.2 카탈로그 등록

- `templates/backstage/catalog-info.yaml`에 아래 타겟 추가:
  - `./nodejs-nginx/template.yaml`

---

## 3. 입력 파라미터 설계

### 3.1 프로젝트 기본

- `name` (필수)
- `repoUrl` (필수)

### 3.2 런타임 옵션

- `appLanguage` (`javascript` | `typescript`)
- `nodeVersion` (기본 `24.13.1`, 추가 선택 버전 포함)
- `useExpress` (boolean)

### 3.3 네트워크 옵션

- `servicePort` (기본 80)
- `enableIngress` (기본 true)
- `hostPrefix` (필수, 기본값 없음)
- `baseDomain` (기본 `sesac.already11.cloud`, 수정 가능)

Ingress Host는 최종적으로 다음 형태:

- `${hostPrefix}.${baseDomain}`

예: `node-test.sesac.already11.cloud`

---

## 4. 스켈레톤/오버레이 구성

### 4.1 Base

- `templates/backstage/nodejs-nginx/skeleton-base/**`

포함 내용:

- Node 프로젝트 기본 파일 (`package.json`, `.nvmrc`, `.node-version`, scripts, tests)
- Dockerfile + nginx config
- Kubernetes manifests
  - namespace
  - deployment
  - service
- GitHub Actions CI 워크플로우 (`.github/workflows/ci.yaml`)
- Backstage catalog entity (`catalog-info.yaml`)

### 4.2 Express 오버레이 (JavaScript)

- `templates/backstage/nodejs-nginx/skeleton-express/**`

포함 내용:

- `express` dependency 추가
- `server/index.mjs` 생성
- 관련 테스트 추가

### 4.3 TypeScript Base 오버레이

- `templates/backstage/nodejs-nginx/skeleton-typescript-base/**`

포함 내용:

- `typescript`, `tsx`, `@types/node`
- `tsconfig.json`
- `typecheck/build` 스크립트
- TS 기본 소스 추가

### 4.4 TypeScript + Express 오버레이

- `templates/backstage/nodejs-nginx/skeleton-typescript-express/**`

포함 내용:

- `express` + `@types/express`
- `server/index.ts`
- `start:api` (`tsx server/index.ts`)

---

## 5. 랜딩 페이지 개선

기존 문제:

- `/` 접근 시 nginx 기본 welcome 페이지 표시

해결:

- 앱 코드 리소스(`public/index.html`)에 커스텀 디자인 적용
- 별도 ConfigMap 주입 없이 컨테이너 이미지에 포함된 정적 파일을 직접 서빙

표시 항목:

- Language
- Node.js Version
- Express Enabled
- Service Port
- Ingress Host
- Runtime (`nginx`)
- `Powered by NGINX` 문구

---

## 6. 작업 중 발생 이슈 및 처리

### 6.1 GitHub App 권한 오류 (Initialize Repository 실패)

증상:

- `refusing to allow a GitHub App to create or update workflow '.github/workflows/ci.yaml' without workflows permission`

원인:

- Backstage가 사용하는 GitHub App에 `Workflows` 권한 부족

대응:

- GitHub App 권한 측면 이슈로 확인
- 템플릿 자체 문제 아님
- 운영적으로 `Workflows: Read and write` 권한 필요

### 6.2 도메인 기본값 오타

증상:

- 기본 domain이 `sesac.already121.cloud`로 생성됨

대응:

- 기본값 `sesac.already11.cloud`로 수정
- 이후 사용자 요청으로 `baseDomain`을 다시 수정 가능 상태로 유지

### 6.3 Host Prefix 기본값 정책 변경

요청 변경:

- `hostPrefix` 기본값 제거
- 필수 입력값으로 강제

결과:

- 현재 템플릿은 `hostPrefix` 필수 + 빈값 허용 안 함

---

## 7. 현재 동작 요약

템플릿 실행 시:

1. GitHub 저장소 생성
2. 선택 옵션에 맞는 소스/매니페스트 생성
3. 초기 커밋/푸시
4. Argo CD 앱 자동 생성
5. Backstage Catalog 자동 등록

옵션 조합:

- JS + Nginx
- JS + Nginx + Express
- TS + Nginx
- TS + Nginx + Express
- Ingress on/off
- Host/Domain/Service Port 커스텀

---

## 8. 검증 체크리스트

템플릿 반영 후 점검:

1. Backstage Create 화면에 `Node.js Web App (Nginx + Optional Express)` 노출
2. 템플릿 실행 후 GitHub repo 생성
3. (권한 허용 시) GitHub Actions CI 실행
4. Argo CD App 자동 생성 여부 확인
5. 생성 앱 접속 시 커스텀 랜딩 페이지 표시 확인
6. 입력값(`language`, `nodeVersion`, `express`, `host`, `port`)이 페이지에 반영되는지 확인

---

## 9. 관련 파일 목록

핵심 파일:

- `templates/backstage/nodejs-nginx/template.yaml`
- `templates/backstage/catalog-info.yaml`
- `templates/backstage/nodejs-nginx/skeleton-base/**`
- `templates/backstage/nodejs-nginx/skeleton-ingress/**`
- `templates/backstage/nodejs-nginx/skeleton-express/**`
- `templates/backstage/nodejs-nginx/skeleton-typescript-base/**`
- `templates/backstage/nodejs-nginx/skeleton-typescript-express/**`

---

## 10. 추가 트러블슈팅: GitHub App 권한 부족으로 Initialize Repository 실패

### 증상

Backstage 템플릿 실행 중 `Initialize Repository` 단계에서 실패:

```text
refusing to allow a GitHub App to create or update workflow
'.github/workflows/ci.yaml' without `workflows` permission
```

### 원인

- 템플릿이 `.github/workflows/ci.yaml`를 생성함
- `github:repo:push` 액션은 Backstage GitHub App 권한으로 push 수행
- 해당 GitHub App에 `Repository permissions > Workflows: Read and write` 권한이 없어서
  workflow 파일 생성/수정 push가 거부됨

### 해결

1. GitHub App 설정에서 권한 추가
   - `Repository permissions > Workflows = Read and write`
2. GitHub Organization/Repository에 앱 재설치(또는 권한 재승인)
3. Backstage 템플릿 재실행

---

## 11. 추가 반영 사항 (최신)

### 11.1 Repository 공개 범위 선택 옵션 추가

- `template.yaml`에 `repoVisibility` 파라미터 추가
  - 선택값: `public`, `private`
  - 기본값: `public`
- `github:repo:create` 입력에 `repoVisibility` 연결
- `github:repo:create` 입력에 `allowAutoMerge: true` 추가(생성 repo 자동 설정)
- `template.yaml`에 `gitopsRepoUrl` 파라미터 추가

### 11.2 CI/CD 분리 및 실행 순서 고정

- `ci.yaml`: 빌드/테스트 전용
- `cd.yaml`: 배포 전용
- CD 트리거를 `push`에서 `workflow_run`으로 변경해 **CI 성공 후 CD 실행**으로 고정

### 11.3 CD GitHub 표현식 깨짐 이슈 대응

- Backstage 템플릿 렌더링 시 `${{ ... }}`가 빈값/NaN으로 깨지는 문제 대응
- `cd.yaml`의 GitHub 표현식에 `{% raw %}...{% endraw %}` 적용

### 11.4 버전 태그 정책

- Git tag가 있으면 해당 tag 기반 버전 사용
- Git tag가 없으면 기본 버전 `1.0.0` 사용

### 11.5 보호 브랜치 대응

- 직접 `main` push 방식 제거
- `peter-evans/create-pull-request`로 `manifests/deployment.yaml` 변경 PR 자동 생성 방식으로 전환

---

## 12. GitHub Settings 필수 확인 항목

### 12.1 Organization Actions 권한

- `Settings -> Actions -> General`
- `Workflow permissions`: `Read and write permissions`
- `Allow GitHub Actions to create and approve pull requests`: 활성화
- (Org 1회 설정 권장) 신규 템플릿 repo에 공통 적용 가능

### 12.2 Secrets/Variables

- `Settings -> Secrets and variables -> Actions`
- 필수 secret:
  - `AWS_ROLE_ARN`
  - `AWS_REGION`
- Organization secret 사용 시 `Visibility`를 실행 repo 범위(전체 또는 선택 repo)로 정확히 설정

### 12.3 브랜치 보호 규칙

- `main`이 PR 병합만 허용되는 경우, 현재 CD 설계(PR 자동 생성)가 정상 동작 방식

### 12.4 Auto-merge 설정

- 템플릿의 `github:repo:create`에서 `allowAutoMerge: true`를 자동 설정
- CD에서 생성한 이미지 업데이트 PR에 auto-merge를 자동 활성화

### 12.5 GitOps 연동 필수 시크릿

- `GITOPS_REPO_TOKEN` 필요
- 용도: GitOps repo(`apps/<app-name>`) 경로에 PR 생성 및 auto-merge

---

## 13. 개발 시작 전 주의사항 (/ 리디렉션)

- 초기 템플릿은 앱 코드 기준으로 `/`에서 랜딩 화면을 직접 서빙
- 필요 시 개발자가 `public/index.html`을 앱 홈으로 자유롭게 교체 가능

## 14. 개발자 가이드 (Node.js) - `/` 페이지 커스터마이징

- 수정 파일: `public/index.html`
- 이 파일이 `/` 응답 화면이므로 원하는 UI/기능으로 그대로 교체하면 됨
- Kubernetes 매니페스트 수정은 필요 없음
- 반영 흐름:
1. `public/index.html` 수정
2. `main`으로 push
3. CI 성공 -> CD 실행 -> 이미지 업데이트 PR 생성
4. auto-merge로 PR 자동 병합 후 배포 반영

### 확인 방법

1. 템플릿 실행 로그에서 `Initialize Repository` 성공 여부 확인
2. 생성된 저장소에 `.github/workflows/ci.yaml` 존재 확인
3. GitHub Actions 탭에서 CI 워크플로우 실행 확인

---

## 15. 최신 업데이트 (2026-02-22)

### 15.1 GitOps 단일 소스 원칙으로 정리

- 앱 코드 repo에서 Kubernetes 매니페스트를 제거함
  - 제거 대상:
    - `skeleton-base/manifests/*`
    - `skeleton-ingress/manifests/ingress.yaml`
- 결과:
  - 앱 코드 repo는 애플리케이션 소스/CI-CD만 포함
  - 배포 매니페스트는 GitOps repo `apps/<app-name>` 경로만 사용

### 15.2 템플릿 실행 순서 보강

- `catalog:register`를 `create-argocd-app`보다 먼저 실행하도록 조정
- 목적:
  - Catalog Location 중복(409) 발생 시 Argo CD 앱 생성 전 중단
  - 불필요한 리소스 생성 방지

### 15.3 Argo CD 생성 입력값 정상화

- `create-argocd-app` 입력을 하드코딩/파생값 대신 템플릿 파라미터 기준으로 통일
  - `appName`, `appNamespace`: `${{ parameters.name }}`
  - `repoUrl`: `${{ parameters.gitopsRepoUrl }}`
  - `path`: `apps/${{ parameters.name }}`

### 15.4 생성되는 CD 워크플로우 Preflight 추가

- 파일: `templates/backstage/nodejs-nginx/skeleton-base/.github/workflows/cd.yaml`
- `preflight` job 추가 후 `publish-ecr`에 `needs: preflight` 적용
- 검증 항목:
  - 필수 시크릿 존재: `AWS_REGION`, `AWS_ROLE_ARN`, `GITOPS_REPO_TOKEN`
  - GitOps repo 접근 가능 여부(`git ls-remote`)
  - `apps/<app-name>` 경로 상태(bootstrap/update 모드) 확인

### 15.5 로컬 검증 스크립트 정리

- `scripts/lint.mjs`에서 `manifests/deployment.yaml` 필수 체크 제거
- README의 `kubectl apply -f manifests/` 절차를 제거하고 GitOps 기반 운영으로 설명 통일
