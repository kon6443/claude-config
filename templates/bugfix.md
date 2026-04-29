# Bugfix Report Template

> 버그 분석·수정 리포트 골격. 자동 라우팅: "버그 리포트 작성/제출" 시 로드.
> 디버그 워크플로우 자체는 `~/.claude/rules/error-recovery.md` 참조.

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
- 자동 라우팅·lessons 파일에 추가할 규칙:

---

> Definition of Done: `~/.claude/CLAUDE.md`의 DoD 섹션 (SSOT) 참조.
