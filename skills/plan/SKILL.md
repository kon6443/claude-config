---
name: plan
description: 비단순 작업의 계획서를 작성한다. 계획·설계·마이그레이션·아키텍처 결정·3단계 이상 작업·다중 파일 변경을 시작하기 전에 사용한다. 목표와 수용 기준, 최소 접근, 얇은 수직 슬라이스, 검증 방법, 롤백 전략을 채운 골격을 만든다.
when_to_use: 사용자가 "계획", "플랜", "설계", "마이그레이션", "작업 계획서"를 요청할 때. 또는 3단계 이상이거나 여러 파일을 건드리는 작업을 시작하기 전.
argument-hint: "[작업 이름]"
---

# 작업 계획서

대상: `$ARGUMENTS`

아래 골격을 채워 사용자에게 제시하거나 task 파일로 옮긴다.
**빈 항목을 남기지 않는다** — 해당 없으면 "해당 없음"과 그 이유를 한 줄로 쓴다.

플랜 모드(`shift+tab`)와는 다르다. 플랜 모드는 편집을 막는 세션 상태이고, 이 스킬은 산출물 골격이다. 둘을 함께 써도 된다.

---

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

---

> Definition of Done: `~/.claude/CLAUDE.md`의 DoD 섹션 (SSOT) 참조.
