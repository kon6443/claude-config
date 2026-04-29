# Engineering Best Practices

> 자동 라우팅: "코드 작성/수정/구현/추가/리팩터링", 함수/클래스/컴포넌트 작업, API/타입/테스트 변경 시 즉시 로드.

---

## 1. API / Interface Discipline

- 안정 인터페이스 주위로 경계 설계: 함수, 모듈, 컴포넌트, 라우트 핸들러.
- 코드 경로 중복보다 **선택적 파라미터 추가** 선호.
- 에러 시맨틱 일관성 (throw vs return error vs empty result) — 한 모듈 안에서 섞지 않는다.

## 2. Testing Strategy

- 버그를 잡았을 가장 작은 테스트만 추가.
- 우선순위:
  - **unit** — 순수 로직.
  - **integration** — DB/네트워크 경계.
  - **E2E** — 핵심 사용자 플로우만.
- 우발적 구현 디테일에 묶인 테스트(brittle test) 금지.

## 3. Type Safety and Invariants

- 프로젝트가 명시 허용하지 않는 한 `any` / `@ts-ignore` / 동등 suppression 금지.
- 불변 조건은 합당한 위치에 인코딩:
  - 입력 경계의 검증 1회. 산발적 if 체크 금지.

## 4. Dependency Discipline

- 새 의존성 추가 전:
  - 기존 스택으로 깨끗히 풀리지 않는가? 이득이 명확한가?
- 표준 라이브러리·기존 유틸리티를 우선.
- 의존성 추가는 PR 본문에 동기 명시.

## 5. Security and Privacy

- 시크릿(키·토큰·개인키)을 코드/로그/응답에 절대 도입 금지.
- 사용자 입력은 신뢰 불가:
  - 검증·정제·제약 (boundary에서).
- 최소 권한 (특히 DB 접근, 서버사이드 액션).

## 6. Performance (Pragmatic)

- 조기 최적화 금지.
- 명백한 문제는 고친다:
  - N+1, 무한 루프 위험, 반복 계산, 큰 페이로드 unbounded 누적.
- 모르겠으면 측정. 추측 금지.

## 7. Accessibility and UX (UI 변경 시)

- 키보드 네비게이션, 포커스 관리, 가독성 있는 명도, 의미 있는 empty/error 상태.
- 화려한 효과보다 명확한 카피와 예측 가능한 인터랙션.

## 8. Verification

상세는 `~/.claude/CLAUDE.md`의 **Definition of Done** 섹션 참조 (SSOT).
코드 작업 종료 시 반드시 DoD 5항목을 충족해야 한다.
