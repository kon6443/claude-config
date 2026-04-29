# Workflow Orchestration

> 자동 라우팅: "계획 / 플랜 / 설계 / 리팩터링 / 마이그레이션 / 다중 파일 변경 / 3+ 단계 작업" 트리거 시 즉시 로드.
> 보완: `~/.claude/templates/plan.md` 동시 로드.

---

## 1. Plan Mode Default

- 비단순 작업(3단계 이상, 다중 파일, 아키텍처 결정, 운영 영향 변경)은 plan mode로 진입.
- 검증 단계를 계획에 **포함**시킨다 (사후 추가 금지).
- 계획을 무효화하는 새 정보 발견 시 → **stop** → 계획 갱신 → 재개.
- 요구사항이 모호하면 input/output, 엣지 케이스, 성공 기준이 들어간 짧은 spec부터 작성.

## 2. Subagent Strategy (Parallelize Intelligently)

- 메인 컨텍스트를 깨끗하게 유지하고 병렬화하기 위해 서브에이전트 활용:
  - 레포 탐색, 패턴 발견, 테스트 실패 분류, 의존성 조사, 위험 검토.
- 각 서브에이전트에 **단일 목표 + 구체적 산출물**:
  - "X 구현 위치 파악 후 파일/주요 함수 목록 반환" > "둘러봐."
- 결과를 짧고 실행 가능한 합성으로 정리한 뒤 코드 작성에 들어간다.
- 연관 프로젝트(프론트↔백 등) 조사가 필요할 때 `cross-project-researcher` 사용 — API 스펙, 타입 불일치, 컨벤션 파악.

## 3. Incremental Delivery (Reduce Risk)

- 빅뱅 변경 대신 **얇은 수직 슬라이스** 선호.
- 작은 단위로 검증 가능한 증분 배포: implement → test → verify → expand.
- 가능하면 변경을 보호:
  - feature flag, config switch, safe default 등.

## 4. Self-Improvement Loop

- 사용자 교정 또는 실수 발견 후:
  - lessons 파일에 항목 추가 — failure mode, detection signal, prevention rule.
- 세션 시작 시 + 대규모 리팩터링 전에 lessons 검토.

## 5. Verification Before "Done"

상세 정의는 `~/.claude/CLAUDE.md`의 **Definition of Done** 섹션 참조 (SSOT).
요지: 증거 없는 완료 선언 금지.

## 6. Demand Elegance (Balanced)

- 비단순 변경에서 잠시 멈추고 자문: "더 적은 움직이는 부품으로 더 단순한 구조가 있나?"
- 해킹스러운 수정이라면 스코프가 크게 늘지 않는 한 우아하게 다시 쓴다.
- 단순한 수정에는 과설계 금지 — 모멘텀과 명료성을 우선.

## 7. Autonomous Bug Fixing (With Guardrails)

- 버그 보고 처리: 재현 → 원인 격리 → 수정 → 회귀 커버리지 추가 → 검증.
- 정말 막히지 않는 한 디버깅 책임을 사용자에게 떠넘기지 않는다.
- 막혔다면 `Communication Guidelines #2` 적용: 1개 질문 + 디폴트 + 답에 따라 달라지는 점.

---

## Task Management (File-Based, Auditable)

비단순 작업에 적용. 단일 한 줄 수정에는 면제.

1. **Plan First** — 비단순 작업에 체크리스트. "Verify" 항목 명시 (lint/tests/build/manual).
2. **Define Success** — 수용 기준 명시 (Definition of Done과 정합).
3. **Track Progress** — 진행 중 1개 유지, 완료 즉시 마킹.
4. **Checkpoint Notes** — 발견·결정·제약을 그때그때 기록.
5. **Document Results** — 짧은 "Results" 섹션: 무엇이 어디서 어떻게 검증됐는가.
6. **Capture Lessons** — 교정·포스트모템 후 lessons 갱신.
