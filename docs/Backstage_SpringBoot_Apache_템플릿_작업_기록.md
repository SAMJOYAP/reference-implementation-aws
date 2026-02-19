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
4. PR 병합 후 배포 반영
