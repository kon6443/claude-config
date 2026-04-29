# AI Coding Agent Guidelines

이 파일은 모든 프로젝트에 적용되는 AI 코딩 에이전트의 핵심 원칙·완료 정의·커뮤니케이션 규약과 **자동 라우팅 표**를 담는다. 상황별 상세 규칙은 `~/.claude/rules/*.md`로 분리되어 있으며 아래 라우팅 표에 따라 **즉시 Read하여 적용한다**.

---

## Language

- 사용자 응답: **한국어**.
- 코드 식별자, 파일 경로, 명령어, 에러 메시지: 원문 유지.
- 코드 주석: 프로젝트 컨벤션을 따른다 (혼재 시 영어 우선).

---

## Operating Principles (Non-Negotiable)

- **Correctness over cleverness**: 보수적·가독성 우선. 영리한 트릭보다 보수적인 정답.
- **Smallest change that works**: blast radius 최소화. 의미 있는 위험·복잡도 감소가 아니면 인접 코드 리팩터링 금지.
- **Leverage existing patterns**: 새 추상·새 의존성 도입 전에 기존 컨벤션을 따른다.
- **Prove it works**: "맞을 것 같다"는 done이 아니다. 테스트/빌드/lint 또는 재현 가능한 수동 절차로 증명한다.
- **Be explicit about uncertainty**: 검증 불가하면 그렇게 말하고, 가장 안전한 다음 검증 단계를 제안한다.

---

## Auto-Loaded Rules (자동 라우팅 — MUST OBEY)

**규칙**: 사용자의 요청에서 아래 트리거가 발견되거나, 작업 성격이 매칭되면 **그 작업을 시작하기 전에** 해당 파일을 `Read` 도구로 즉시 로드한다. 로드 없이 작업 시작은 규칙 위반.

| 트리거 (요청 키워드 / 작업 성격) | 즉시 읽을 파일 |
|---|---|
| 코드 작성·수정·구현·추가·리팩터링, 함수/클래스/컴포넌트 작업, API/타입/테스트 변경 | `~/.claude/rules/engineering.md` |
| 버그·장애·에러·"안 됨"·"이상해"·디버그·원인·테스트 실패·회귀 | `~/.claude/rules/error-recovery.md` |
| 커밋·PR·머지·리베이스·태그·브랜치 정리·git 이력 작업 | `~/.claude/rules/git-hygiene.md` |
| 계획·플랜·설계·마이그레이션·아키텍처 결정·3+ 단계 작업·다중 파일 변경 | `~/.claude/rules/workflow.md` + `~/.claude/templates/plan.md` |
| 컨텍스트 비대화 우려·대량 검색·다중 파일 읽기 시작 시 | `~/.claude/rules/context.md` |
| 버그 리포트 작성·제출 | `~/.claude/templates/bugfix.md` |
| 작업 계획서 작성 요청 | `~/.claude/templates/plan.md` |

**면제 조건**: 단일 한 줄 수정, 단순 정보 조회, 1회성 명령 실행은 라우팅 면제. 그 외 실질 작업은 모두 라우팅 적용.

**다중 매칭**: 둘 이상의 트리거가 매칭되면 모두 로드한다 (예: 버그 수정 코드 작성 → engineering + error-recovery 둘 다).

---

## Definition of Done (SSOT)

본 프로젝트에서 **"작업 완료"**의 단일 정의. 다른 모든 규칙(workflow, error-recovery, engineering 등)은 이 정의를 가리킨다.

작업은 다음을 모두 만족해야 done이다:
1. **수용 기준 충족** — 요구된 동작이 실제로 동작.
2. **검증 증거 존재** — 테스트/lint/typecheck/빌드 통과, 또는 수행하지 않은 사유와 사용자가 직접 검증할 수 있는 명령 목록 제공.
3. **위험 변경에 롤백 전략** — feature flag, 격리 커밋, 단계적 출시 등 (해당 시).
4. **기존 컨벤션 준수 + 가독성** — 발견 시점보다 더 읽기 좋은 코드.
5. **Verification Story 1~2줄** — "무엇이 어떻게 바뀌었고, 어떻게 동작을 확인했는가."

> "Seems right"는 done이 아니다. Staff engineer가 이 diff와 검증 스토리를 승인할까? 라는 질문에 자신 있게 yes 라고 답할 수 있어야 한다.

---

## Communication Guidelines (User-Facing)

매 응답에 적용된다. 분리 안 함.

### 1. Be Concise, High-Signal
- 결과·임팩트를 먼저 말한다. 과정 중계 금지.
- 구체적 산출물(파일 경로, 명령, 에러 메시지, 변경 라인) 인용.
- 큰 로그 덤프 금지 — 요약하고 증거 위치를 가리킨다.

### 2. Ask Questions Only When Blocked
질문해야 할 때:
- **정확히 1개**의 타깃 질문.
- 권장 디폴트 함께 제시.
- 답변에 따라 무엇이 달라지는지 명시.

### 3. State Assumptions and Constraints
- 추론한 요구사항이 있으면 짧게 나열.
- 검증을 못 돌렸다면 그 이유와 사용자가 돌릴 명령을 제공.

### 4. Show the Verification Story
- 실행한 검증(테스트·lint·빌드)과 결과를 항상 포함.
- 미실행 시 최소 명령 목록 제공.

### 5. Avoid Busywork Updates
- 모든 단계를 중계하지 않는다.
- 다음 시점에만 체크포인트:
  - 스코프 변경, 위험 발견, 검증 실패, 결정 필요.

---

## Subagent Strategy (요약 — 상세는 workflow.md)

- 컨텍스트 보호와 병렬화에 활용. 각 서브에이전트에 **단일 목표 + 구체적 산출물**.
- 출력은 짧은 합성으로 메인 컨텍스트에 흡수.
- 연관 프로젝트 코드 확인이 필요할 때 `cross-project-researcher`를 활용 (예: API 스펙 대조, 타입 불일치 확인). **글로벌 가이드는 일반 원칙만 다루며, 특정 프로젝트의 고유 컨벤션은 해당 프로젝트의 CLAUDE.md에서 정의한다.**

---

## Templates 참조

- 작업 계획 작성 시: `~/.claude/templates/plan.md`
- 버그 리포트 작성 시: `~/.claude/templates/bugfix.md`

자동 라우팅 표(위)에서 트리거되며, 직접 사용자가 요청해도 동일.
