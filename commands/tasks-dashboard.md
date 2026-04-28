프로젝트의 태스크 파일을 분석하여 현재 진행 상황을 대시보드 테이블로 요약합니다.
사전에 현재 코드/파일 상태와 비교하여 누락된 업데이트가 있으면 사용자 승인 후 반영합니다.
프로젝트 타입을 자동 감지하여 관련 커스텀 컬럼을 추가합니다.

## 사용법

- `/tasks-dashboard` : 기본 (요약 + 진행중 + 블로커)
- `/tasks-dashboard all` : 모든 테이블 표시
- `/tasks-dashboard recent` : 최근 완료 강조
- `/tasks-dashboard sync` : 동기화만 수행 (대시보드 미표시)
- `/tasks-dashboard <파일경로>` : 특정 태스크 파일만 분석
- `/tasks-dashboard --include-git` : 모호할 때 git log/blame까지 보조 활용

## 절차

### 1단계: 태스크 파일 탐색

다음 경로 순서로 검색합니다:
- 인자로 파일경로가 주어지면 그 파일만 사용
- `tasks/*.md`
- `docs/tasks-*.md`, `docs/tasks/*.md`
- `TODO.md`, `TODOS.md`
- 프로젝트 `CLAUDE.md`에 태스크 경로 힌트가 있으면 우선 사용

### 2단계: 프로젝트 타입 감지

다음 시그널로 타입 추정:
- `package.json` + `@nestjs/core` → NestJS 백엔드
- `package.json` + `react`/`next` → React/Next 프론트엔드
- `pubspec.yaml` → Flutter
- `pyproject.toml` + `fastapi`/`django` → Python 백엔드
- `go.mod` → Go
- `Cargo.toml` → Rust
- `Dockerfile` + `docker-stack*.yml` → 인프라 작업
- `terraform/` → IaC

`CLAUDE.md`에 "Task Dashboard Custom Columns" 섹션이 있으면 그 정의를 최우선으로 사용.

### 3단계: 태스크 파싱

각 태스크 파일에서 추출:
- 태스크 제목 (h1, h2)
- Phase 구분 (h3 "Phase N:" 패턴)
- 체크박스 항목 (`- [ ]`, `- [x]`)
- 상태 텍스트 (진행중/완료/블로커 등 키워드)
- 우선순위 표기 (P0/P1/P2, High/Medium/Low)
- "결정 사항", "Working Notes", "Results" 섹션
- 날짜 패턴 (YYYY-MM-DD)

진행률 계산: `완료 체크박스 / 전체 체크박스`

### 4단계: 동기화 후보 탐지 (코드 직접 비교)

**핵심 원칙: 태스크 항목과 "현재 프로젝트의 실제 코드/파일 상태"를 직접 비교**합니다.
git log/커밋은 보조 단서일 뿐, 본질이 아닙니다.

#### 4-1. 코드 단서 추출
미체크된 각 태스크 항목 본문에서 다음을 추출:
- 파일 경로 (예: `src/common/throttler/throttler.module.ts`)
- 함수/클래스/모듈명 (예: `ThrottlerModule`, `CustomerJtiThrottlerGuard`)
- 패키지명 (예: `@nestjs/throttler`, `ioredis`)
- 환경변수 / 설정키 (예: `REDIS_HOST`, `REDIS_PASSWORD`)
- 디렉토리 (예: `infra/`, `tasks/`)

#### 4-2. 실제 상태 확인
추출한 단서를 현재 작업 디렉토리에서 직접 검증:
- 파일 존재: `Read` 또는 `Glob`
- 코드 존재: `Grep`
- 패키지 설치: `package.json`/`go.mod`/`pyproject.toml` 등 직접 확인
- 환경변수 정의: `.env*`, 배포 워크플로우 파일
- 디렉토리 구조: `Bash ls`

#### 4-3. 매칭 → 동기화 후보화
미체크 항목인데 코드/파일이 **이미 존재**하면 후보:
```
[후보] tasks/throttling.md > Phase 2 > "ThrottlerModule 등록"
근거: 
  - src/common/throttler/throttler.module.ts 존재
  - app.module.ts에 AppThrottlerModule import 라인 발견
  - package.json에 @nestjs/throttler 6.5.0 설치됨
이 항목을 [x]로 체크할까요? (Y/N/Skip)
```

#### 4-4. (보조) git 활용은 옵션
단서가 너무 모호한 항목(예: "리팩토링", "정리")은:
- 기본 동작: "확인 필요" 로 표기, 자동 매칭 시도 안 함
- `--include-git` 인자가 있을 때만 보조로 `git log -S "<keyword>"` 또는 `git blame` 활용

#### 4-5. 사용자 승인
각 후보를 개별적으로 사용자에게 제시 (Y/N/Skip).
일괄 승인 금지. 모호하면 사용자가 Skip하기 쉽게.
승인된 항목만 태스크 파일을 수정.

### 5단계: 컬럼 구성

#### 고정 컬럼 (범용)
- 태스크
- 단계 (Phase)
- 진행률 (예: 3/8 = 37%)
- 상태 (진행중/완료/블로커/대기)
- 우선순위 (P0/P1/P2 또는 High/Medium/Low)
- Blocker
- 다음 액션
- 마지막 업데이트일

#### 커스텀 컬럼 (감지된 타입별 추가)

| 타입 | 추가 컬럼 |
|---|---|
| NestJS 백엔드 | API 엔드포인트, DB 영향, 환경(qa/prod), Swagger 갱신 |
| React 프론트 | 페이지/라우트, 디자인 토큰, 접근성 |
| Flutter | 플랫폼, 빌드 버전 |
| Python 백엔드 | API, 마이그레이션, 환경 |
| Go | 서비스, gRPC 영향 |
| Rust | 크레이트, breaking change |
| 인프라 | 영향 서비스, 환경(qa/prod) |
| IaC | 리소스, 환경 |

`CLAUDE.md`에 "Task Dashboard Custom Columns" 섹션이 정의되어 있으면 위 자동 감지 결과를 무시하고 그대로 사용.

### 6단계: 대시보드 렌더링

#### 기본 모드 (`/tasks-dashboard`)
1. 📊 전체 요약
2. 🚀 진행 중
3. ⛔ 블로커

#### 전체 모드 (`/tasks-dashboard all`)
1. 📊 전체 요약
2. 🚀 진행 중
3. ⛔ 블로커
4. ✅ 최근 완료 (지난 7일)
5. 📅 단계별
6. 🎯 우선순위별
7. 🔥 위험/주의 (정체 7일 이상, 마감 임박 등)

#### 최근 모드 (`/tasks-dashboard recent`)
1. 📊 전체 요약
2. ✅ 최근 완료 (지난 7일, 강조)
3. 🚀 진행 중

### 테이블 형식

마크다운 표 사용. 행 수 많으면 가장 중요한 N개만 표시하고 "외 M건" 표기.

#### 전체 요약 테이블 예시
```
| 지표 | 값 |
|---|---|
| 전체 태스크 | 24개 |
| 완료 | 8 (33%) |
| 진행 중 | 5 |
| 블로커 | 2 |
| 대기 | 9 |
| 종합 진행률 | 37% |
```

#### 진행 중 테이블 예시
```
| 태스크 | 단계 | 진행률 | 우선순위 | 다음 액션 | API | 환경 |
|---|---|---|---|---|---|---|
| 스로틀링 도입 | Phase 2 | 4/6 (66%) | P0 | Guard 글로벌 등록 | 전 API | qa |
```

## 규칙

- **자동 수정 금지**: 동기화 후보는 반드시 항목별 사용자 승인
- **추측 금지**: 코드와 태스크 매칭이 모호하면 "확인 필요"로 표기
- **민감정보 비노출**: 태스크에 토큰/키 있어도 대시보드에 노출 X
- **읽기 우선**: 태스크 파일 직접 수정은 사용자 승인 후만
- **컬럼 폭 관리**: 컬럼 수가 많아 가독성 떨어지면 핵심 컬럼만 표시 + "그 외 컬럼은 옵션 인자로 표시 가능" 안내
- **빈 결과 처리**: 태스크 파일이 없으면 "현재 디렉토리에 태스크 파일을 찾을 수 없습니다. tasks/ 또는 docs/ 경로 확인 또는 CLAUDE.md에 위치 명시 권장."
- **git 의존 최소화**: 태스크 ↔ 코드 비교가 본질. git은 옵션 인자(`--include-git`)에서만 보조 활용

## 출력 끝맺음

대시보드 후 다음을 한 줄로 안내:
- 동기화로 변경한 항목 수 (있을 경우)
- 추가 옵션 안내 (`/tasks-dashboard all` 등)
- 가장 우선 처리 권장 태스크 1개 추천
