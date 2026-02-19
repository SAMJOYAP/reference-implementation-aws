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
- `manifests/configmap-web.yaml`

### 4.2 Ingress 스켈레톤

경로: `templates/backstage/springboot-apache/skeleton-ingress/`

포함 파일:

- `manifests/ingress.yaml`

`enableIngress=true`일 때만 적용되도록 구성.

---

## 5. 배포 런타임 구성

앱 컨테이너는 Apache(httpd) 기반으로 생성:

- 이미지: `httpd:2.4-alpine`
- 서비스: `ClusterIP`
- 포트: 템플릿 `servicePort` 입력값 사용

또한 `configmap-web.yaml`의 `index.html`을 마운트하여,
Apache 기본 welcome 페이지 대신 커스텀 랜딩 페이지가 보이도록 구성.

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

- `Powered by Apache HTTP Server`

수정 파일:

- `templates/backstage/springboot-apache/skeleton-base/manifests/configmap-web.yaml`

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

