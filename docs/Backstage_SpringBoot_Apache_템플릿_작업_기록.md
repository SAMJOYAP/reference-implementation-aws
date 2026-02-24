# Spring Boot + Gradle + Apache 템플릿 작업 기록

## 1. 작업 목적

Backstage Scaffolder에서 다음 요구사항을 만족하는 신규 템플릿 구현:

- Java(Spring Boot) 프로젝트 자동 생성
- Gradle 빌드 구성 자동 생성
- Apache(httpd) 기반 Kubernetes 배포 매니페스트 생성
- GitHub 저장소 생성 + 초기 push
- GitHub Actions CI 포함
- Argo CD 앱 자동 등록
- Node 템플릿과 유사한 네트워크 옵션(Ingress/Host/Port) 지원

---

## 2. 생성한 템플릿

- 템플릿 파일: `templates/backstage/springboot-apache/template.yaml`
- 카탈로그 등록: `templates/backstage/catalog-info.yaml`
  - `./springboot-apache/template.yaml` 추가

---

## 3. 템플릿 입력 옵션

### 3.1 필수 입력

- `projectName`
- `repoUrl`
- `hostPrefix`

### 3.2 빌드/런타임 옵션

요청하신 1,2,3,4,5,6,8 반영:

1. `javaVersion`
2. `springBootVersion`
3. `gradleVersion`
4. `packaging` (`jar`/`war`)
5. `useActuator`
6. `useSpringWeb`
8. `useLombok`

### 3.3 네트워크 옵션

- `servicePort`
- `enableIngress`
- `hostPrefix`
- `baseDomain`

Ingress host 형식:

- `${hostPrefix}.${baseDomain}`

---

## 4. 스켈레톤 구성

### 4.1 Base 스켈레톤

경로: `templates/backstage/springboot-apache/skeleton-base/`

포함 파일:

- `build.gradle` (옵션 기반 의존성 조건 처리)
- `settings.gradle`
- `src/main/java/com/example/app/Application.java`
- `src/main/resources/application.yaml`
- `src/test/java/com/example/app/ApplicationTests.java`
- `.github/workflows/ci.yaml`
- `catalog-info.yaml`
- `README.md`
- `.gitignore`
- `manifests/namespace.yaml`
- `manifests/deployment.yaml`
- `manifests/service.yaml`
- `src/main/resources/static/index.html`

### 4.2 Ingress 스켈레톤

경로: `templates/backstage/springboot-apache/skeleton-ingress/`

포함 파일:

- `manifests/ingress.yaml`

`enableIngress=true`일 때만 적용되도록 구성.

---

## 5. 배포 런타임 구성

앱은 Spring Boot 정적 리소스를 통해 랜딩 페이지를 직접 서빙하도록 구성:

- `src/main/resources/static/index.html` -> `/`
- 서비스: `ClusterIP`
- 포트: 템플릿 `servicePort` 입력값 사용

---

## 6. 랜딩 페이지 작업

요청사항 반영:

- Node 템플릿 랜딩 스타일과 동일한 UI 적용
- Java 템플릿 옵션 값들을 화면에 표시

표시 항목:

- Java Version
- Spring Boot
- Gradle Version
- Packaging
- Spring Web
- Actuator
- Lombok
- Service Port
- Ingress Host
- Runtime (`apache`)

문구:

- `Powered by Spring Boot`

수정 파일:

- `templates/backstage/springboot-apache/skeleton-base/src/main/resources/static/index.html`

---

## 7. CI 구성

파일:

- `templates/backstage/springboot-apache/skeleton-base/.github/workflows/ci.yaml`

동작:

- `pull_request`, `push(main)` 트리거
- JDK 세팅 (`javaVersion` 반영)
- Gradle 세팅 (`gradleVersion` 반영)
- `gradle clean build --no-daemon` 실행

---

## 8. 템플릿 실행 플로우

1. GitHub repo 생성 (`github:repo:create`)
2. Base 스켈레톤 렌더링 (`fetch:template`)
3. Ingress 옵션 시 ingress 오버레이 렌더링
4. 초기 push (`github:repo:push`)
5. Argo CD App 자동 생성 (`cnoe:create-argocd-app`)
6. Backstage Catalog 등록 (`catalog:register`)

---

## 9. 운영 시 확인 포인트

1. 템플릿이 Backstage Create 화면에 노출되는지
2. 템플릿 실행 시 repo 생성/초기 push 성공 여부
3. Argo CD Application 자동 생성 여부
4. Ingress host 접속 가능 여부
5. 랜딩 페이지가 Apache 기본 화면이 아닌 커스텀 화면인지
6. CI가 정상 트리거/성공하는지

---

## 10. 관련 파일 목록

- `templates/backstage/springboot-apache/template.yaml`
- `templates/backstage/springboot-apache/skeleton-base/**`
- `templates/backstage/springboot-apache/skeleton-ingress/**`
- `templates/backstage/catalog-info.yaml`

---

## 11. 추가 반영 사항 (최신)

### 11.1 템플릿 명칭 및 설명 정비

- 템플릿 타이틀을 `Java Web App (Apache + Spring Boot + Gradle)` 형태로 정리
- 생성 README, catalog-info 설명 문구도 동일 톤으로 통일

### 11.2 Repository 공개 범위 선택 옵션 추가

- `template.yaml`에 `repoVisibility` 파라미터 추가
  - 선택값: `public`, `private`
  - 기본값: `public`
- `github:repo:create` 입력에 `repoVisibility` 연결
- `github:repo:create` 입력에 `allowAutoMerge: true` 추가(생성 repo 자동 설정)
- `template.yaml`에 `gitopsRepoUrl` 파라미터 추가

### 11.3 CD 구성 추가 및 CI/CD 분리

- `.github/workflows/cd.yaml` 추가
- `ci.yaml`: 빌드/테스트 전용
- `cd.yaml`: 이미지 빌드/푸시 + 매니페스트 업데이트 전용
- CD 트리거를 `workflow_run` 기반으로 변경하여 **CI 성공 후 CD 실행**으로 고정

### 11.4 Dockerfile 추가

- Java 이미지 빌드용 Dockerfile 추가:
  - `templates/backstage/springboot-apache/skeleton-base/Dockerfile`

### 11.5 CD 안정화 보강

- Backstage 렌더링 시 GitHub 표현식 깨짐 방지를 위해 `{% raw %}...{% endraw %}` 적용
- Git tag가 없을 경우 버전 `1.0.0` 기본값 사용
- 보호 브랜치 환경 대응을 위해 direct push 대신 PR 생성 방식으로 변경

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
- Organization secret은 실행 대상 repo를 포함하도록 visibility를 설정

### 12.3 브랜치 보호 규칙

- `main` direct push가 막힌 환경에서는 CD가 생성한 PR을 리뷰/병합해서 반영

### 12.4 IAM Role(ECR) 권한

- 최소 권한에 아래 action 포함 필요:
  - `ecr:BatchGetImage`
  - `ecr:DescribeImages`

### 12.5 Auto-merge 설정

- 템플릿의 `github:repo:create`에서 `allowAutoMerge: true`를 자동 설정
- CD에서 생성한 이미지 업데이트 PR에 auto-merge를 자동 활성화

### 12.6 GitOps 연동 필수 시크릿

- `GITOPS_REPO_TOKEN` 필요
- 용도: GitOps repo(`apps/<app-name>`) 경로에 PR 생성 및 auto-merge

---

## 13. 개발 시작 전 주의사항 (/ 리디렉션)

- 초기 템플릿은 앱 코드 기준으로 `/`에서 랜딩 화면을 직접 서빙
- 필요 시 개발자가 `src/main/resources/static/index.html`을 앱 홈으로 교체 가능

## 14. 개발자 가이드 (Spring Boot) - `/` 페이지 커스터마이징

- 수정 파일: `src/main/resources/static/index.html`
- 이 파일이 `/` 응답 화면이므로 원하는 UI/기능으로 그대로 교체하면 됨
- Kubernetes 매니페스트 수정은 필요 없음
- 반영 흐름:
1. `src/main/resources/static/index.html` 수정
2. `main`으로 push
3. CI 성공 -> CD 실행 -> 이미지 업데이트 PR 생성
4. auto-merge로 PR 자동 병합 후 배포 반영

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
  - `appName`, `appNamespace`: `${{ parameters.projectName }}`
  - `repoUrl`: `${{ parameters.gitopsRepoUrl }}`
  - `path`: `apps/${{ parameters.projectName }}`

### 15.4 생성되는 CD 워크플로우 Preflight 추가

- 파일: `templates/backstage/springboot-apache/skeleton-base/.github/workflows/cd.yaml`
- `preflight` job 추가 후 `publish-ecr`에 `needs: preflight` 적용
- 검증 항목:
  - 필수 시크릿 존재: `AWS_REGION`, `AWS_ROLE_ARN`, `GITOPS_REPO_TOKEN`
  - GitOps repo 접근 가능 여부(`git ls-remote`)
  - `apps/<app-name>` 경로 상태(bootstrap/update 모드) 확인

### 15.5 문서 정합성 정리

- README에서 `kubectl apply -f manifests/` 절차를 제거하고 GitOps 기반 운영으로 설명 통일

---

## 15. 최신 반영 사항 (2026-02-23)

### 15.1 템플릿 한글화 적용

- `template.yaml` 입력 항목/설명/실행 step 문구를 한글화했다.
- 고유명사는 영어로 유지했다.
  - `Java`, `Spring Boot`, `Gradle`, `Apache`, `GitHub`, `Argo CD`, `EKS`

### 15.2 `catalog-info` 한글화 영향

- 카탈로그 엔티티 설명/표시 문구가 한글로 노출된다.
- 템플릿 동작(step/action)에는 영향이 없다.
- 운영 Backstage가 최신 catalog source를 참조하지 않으면 UI에 보이지 않을 수 있다.

### 15.3 EKS Cluster 선택 기능

- 파라미터 `eksCluster` 추가
- `ui:field: EksClusterPicker` 연결
- 리전 기본값 `ap-northeast-2` 적용

### 15.4 현재 상태

- Java 템플릿 소스 반영 완료
- 운영 노출 확인은 Backstage 배포 버전/카탈로그 소스 동기화 이후 진행 중

### 15.5 클라우드/배포 옵션 통합 및 필수값 강화 (2026-02-23)

- 기존 분리 섹션:
  - `클라우드 배포 옵션`
  - `배포 옵션`
- 변경 후:
  - `클라우드/배포 옵션` 단일 섹션으로 통합
- `EKS Cluster`를 필수 입력으로 변경
  - `required: [eksCluster]`

### 15.6 대상 Namespace 기본값 UX 개선 (2026-02-23)

- `targetNamespace` 입력 필드에 `DefaultNamespace` 커스텀 필드 적용
- 초기값은 `projectName`(프로젝트 이름)으로 자동 채움
- 사용자가 입력을 수정하면 수정값을 우선 사용
- 안내 문구도 다음 의미로 통일:
  - "기본값은 프로젝트 이름이며, 필요하면 수정 가능"

### 15.7 Repository/HostPrefix 기본값 자동화 (2026-02-23)

- `repoUrl` 입력을 `RepoUrlFromProjectPicker`로 변경
  - 레포지토리 이름 미입력 시 `projectName`을 repo 이름으로 자동 사용
- `hostPrefix` 입력을 선택값으로 변경
  - 미입력 시 `projectName`으로 자동 사용
  - 안내 문구에 자동 등록 동작 명시

### 15.8 Argo CD Project 설명 문구 명확화 (2026-02-23)

- 설명 문구를 아래 의미로 정리:
  - "생성할 Application이 소속될 Argo CD Project를 선택합니다."
- 혼동 포인트 정리:
  - 이 값은 Application 이름이 아니라 `spec.project`를 결정함

### 15.9 ArgoCD preflight 선행 + 허브/비허브 배포 경로 정리 (2026-02-23)

- 템플릿 step에서 `create-repo` 이전에 `ArgoCD 사전 검증` 단계 추가
  - 검증 실패 시 repo/ECR 생성 전에 중단
- 허브 클러스터(`sesac-ref-impl`) 선택 시
  - destination server를 `https://kubernetes.default.svc`로 강제 매핑
- 허브 외 클러스터 선택 시
  - Argo CD 등록 여부 확인
  - 미등록이면 자동 등록 시도
  - 이미 등록되어 있으면 skip
  - 등록 후 재조회 검증까지 통과해야 앱 생성 진행

---

## 16. 최신 반영 사항 (2026-02-24)

### 16.1 Java 템플릿 빌드도구 선택 추가 (Maven 기본)

- 파일: `templates/backstage/springboot-apache/template.yaml`
- 변경:
  - `buildTool` 라디오 선택 추가 (`maven` / `gradle`)
  - 기본값을 `maven`으로 설정
  - 템플릿 제목에서 `Gradle` 문구 제거

### 16.2 Gradle 경로 유지 + Maven 경로 오버레이 분기

- `gradle` 선택:
  - 기존 `skeleton-base`의 CI/CD 동작을 그대로 사용
- `maven` 선택:
  - `template-maven-overlay` step으로 `skeleton-maven` 오버레이 적용
  - 오버레이 대상:
    - `.github/workflows/ci.yaml` (`CI`)
    - `.github/workflows/security.yaml` (`Security / DevSecOps Pipeline`)
    - `.github/workflows/cd.yaml` (`CD`)
    - `pom.xml`
    - `Dockerfile`
    - `README.md`

### 16.3 Maven 워크플로우 순서 보장 (CI -> Security -> CD)

- CI (`ci.yaml`)
  - 기본 빌드/테스트만 수행 (`mvn clean verify`)
- Security (`security.yaml`)
  - 트리거: CI 성공 시 `workflow_run`
  - SonarQube SAST/SCA + Trivy + SBOM + Cosign + ECR Push 수행
- CD (`cd.yaml`)
  - 트리거: Security 워크플로우 성공 시 `workflow_run`
  - 따라서 CD가 CI/보안 파이프라인보다 먼저 실행되지 않도록 강제됨
- 보완:
  - `workflow_run.head_sha` 기준 checkout으로 동일 커밋 기준 체인 유지
  - Maven 산출물(`target/*.jar`/`*.war`)을 `target/app-runtime.jar`로 정규화해 이미지 빌드 안정화
  - 호환성을 위해 `build/libs/app-runtime.jar`도 함께 생성하여 Dockerfile 경로 차이로 인한 실패 방지

### 16.5 파라미터 노출 정리 (2026-02-24 추가 반영)

- 파일: `templates/backstage/springboot-apache/template.yaml`
- 변경:
  - `Gradle Version` 필드를 `buildTool=gradle`일 때만 노출
  - `ui:order`로 `buildTool` 바로 아래에 표시되도록 정렬
  - `maven` 선택 시 노출되던 보안 파이프라인 안내 텍스트 필드 제거
- 목적:
  - 입력 폼 단순화
  - 실제 선택한 빌드도구와 무관한 입력/안내 노출 제거

### 16.6 ECR Push 단일화 및 CD 역할 분리 (2026-02-24 추가 반영)

- 파일:
  - `templates/backstage/springboot-apache/skeleton-maven/.github/workflows/security.yaml`
  - `templates/backstage/springboot-apache/skeleton-maven/.github/workflows/cd.yaml`
- 변경:
  - ECR Push는 Security 워크플로우에서만 수행
  - CD는 ECR 재빌드/재푸시를 하지 않고 GitOps 배포 갱신만 수행
  - CD 시작 시 `imageTag(head_sha)`가 실제 ECR에 존재하는지 사전 검증
- 목적:
  - 중복 빌드/중복 push 제거
  - 보안 검증 통과 이미지 기준으로만 배포 반영

### 16.7 Maven 생성 시 Gradle 산출물 혼입 방지 (2026-02-24 추가 반영)

- 파일:
  - `templates/backstage/springboot-apache/skeleton-gradle/build.gradle`
  - `templates/backstage/springboot-apache/skeleton-gradle/settings.gradle`
  - `templates/backstage/springboot-apache/template.yaml`
- 변경:
  - Gradle 빌드 파일(`build.gradle`, `settings.gradle`)을 base에서 분리해 `skeleton-gradle`로 이동
  - `buildTool=gradle`일 때만 Gradle 오버레이를 적용
  - `buildTool=maven`이면 Gradle 파일이 생성 repo에 포함되지 않도록 고정

### 16.8 Maven 패키징 정책/메타데이터 정합화 (2026-02-24 추가 반영)

- 파일: `templates/backstage/springboot-apache/template.yaml`
- 변경:
  - `buildTool=maven`일 때 `packaging`은 `jar`만 허용
  - 저장소 생성 description/topics를 buildTool 기준으로 분기
    - Maven 선택 시 `+ Maven`, `maven` topic
    - Gradle 선택 시 `+ Gradle`, `gradle` topic

### 16.9 Catalog 등록 InputError 수정 (2026-02-24 추가 반영)

- 증상:
  - `links.0.url` 검증 실패
  - 값에 `${{ steps[...] || steps[...] }}` 표현식 문자열이 남아 URL 파싱 실패
- 원인:
  - Backstage 템플릿 값 치환에서 해당 OR 표현식이 안전하게 해석되지 않음
- 조치 파일:
  - `templates/backstage/springboot-apache/template.yaml`
  - `templates/backstage/springboot-apache/skeleton-base/catalog-info.yaml`
- 변경:
  - `remoteUrl` 합성 표현식 제거
  - 링크 URL은 `https://github.com/${owner}/${repo}` 형태로 직접 구성
