# Plan Template

> 비단순 작업의 계획서 골격. 자동 라우팅: "계획/플랜/설계/마이그레이션/3+ 단계 작업" 시 로드.

작업 시작 전 이 골격을 채워서 사용자에게 제시하거나 task 파일에 옮긴다.

---

## Goal & Acceptance Criteria

- 무엇을 달성하는가:
- 끝났다는 것을 어떻게 아는가 (수용 기준):
- 비목표 (이번 작업에서 안 하는 것):

## Existing Patterns / Source of Truth

- 참고할 기존 구현:
- 따를 컨벤션:
- 충돌 가능성 있는 영역:

## Design (Minimal Approach + Key Decisions)

- 접근 요지:
- 주요 결정과 대안 (why this, why not that):
- 트레이드오프:

## Implementation Steps (Thin Vertical Slices)

- [ ] Step 1 — (가장 작은 검증 가능 단위):
- [ ] Step 2 —
- [ ] Step 3 —
- [ ] ...

각 step은 implement → test → verify 사이클 1회를 포함한다.

## Tests / Verification

- [ ] 추가/수정할 테스트:
- [ ] 실행할 명령 (lint/tests/build/manual):
- [ ] 수동 재현 절차 (해당 시):

## Risk & Rollback

- 위험 요소:
- 롤백 전략 (feature flag, 격리 커밋, config switch 등):
- 운영 영향 (해당 시):

## Verification Story (작업 완료 후 채움)

- 무엇이 어떻게 바뀌었는가:
- 어떻게 동작을 확인했는가:

## Lessons (해당 시)

- 발견한 함정·새 규칙 → `memory/` 또는 lessons 파일에 옮길 항목:

---

> Definition of Done: `~/.claude/CLAUDE.md`의 DoD 섹션 (SSOT) 참조.
