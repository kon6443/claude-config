---
name: bugfix
description: 버그 분석·수정 리포트를 작성한다. 재현 절차, 기대 대비 실제, 근본 원인, 수정 내용, 회귀 커버리지, 검증 결과, 롤백 노트를 채운다. 버그를 고친 뒤 결과를 정리해 남길 때 사용한다.
when_to_use: 사용자가 "버그 리포트", "버그 분석서", "포스트모템"을 요청할 때. 또는 버그를 수정한 뒤 근본 원인과 회귀 커버리지를 문서로 남겨야 할 때.
argument-hint: "[버그 요약]"
---

# 버그 리포트

대상: `$ARGUMENTS`

디버깅 절차 자체는 자동 로드되는 `~/.claude/rules/error-recovery.md`를 따른다.
이 스킬은 **결과를 남기는 골격**이다. 추측을 쓰지 않고, 확인하지 못한 항목은 "미확인"으로 명시한다.

---

---

## 1. Repro Steps

최소 안정 재현 절차. 환경·데이터·실행 명령 명시.

- 환경 (OS / 런타임 / 의존성 버전):
- 입력 / 데이터:
- 실행 명령 또는 클릭 단계:
- 재현율 (always / sometimes / 첫 1회만 등):

## 2. Expected vs Actual

| | Expected | Actual |
|---|---|---|
| 동작 | | |
| 출력 | | |
| 상태 | | |

## 3. Root Cause

증상이 아닌 근본 원인.

- 원인 위치 (파일/함수/라인):
- 왜 그렇게 동작했는가:
- 왜 지금까지 발견 안 됐는가 (테스트 갭 분석):

## 4. Fix

- 변경 요약:
- 변경 파일 목록:
- 핵심 diff 또는 의사코드:
- 의도적으로 손대지 않은 인접 영역과 그 이유:

## 5. Regression Coverage

- 추가한 테스트 (unit / integration / E2E):
- 이 테스트가 동일 회귀를 잡을 수 있는가? (긍정·부정 케이스):
- 픽스 전 테스트 실행 → 실패 확인 → 픽스 후 통과 확인:

## 6. Verification Performed

- 실행한 검증 명령과 결과:
- 수동 재현 절차 다시 돌렸는가:
- 인접 기능 회귀 테스트:

## 7. Risk / Rollback Notes

- 운영 환경 영향:
- 롤백 절차 (revert 가능 여부, feature flag 등):
- 모니터링·알람 추가 필요성:

## 8. Lessons

- 동일 패턴의 다른 위치에 같은 버그가 있는가:
- `rules/` 또는 lessons 파일에 추가할 규칙:

---

> Definition of Done: `~/.claude/CLAUDE.md`의 DoD 섹션 (SSOT) 참조.

---

> Definition of Done: `~/.claude/CLAUDE.md`의 DoD 섹션 (SSOT) 참조.
