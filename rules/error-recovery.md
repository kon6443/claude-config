# Error Handling and Recovery Patterns

> 자동 라우팅: "버그/장애/에러/안 됨/이상해/디버그/원인", 테스트 실패, 회귀 시 즉시 로드.
> 버그 리포트 작성 시 `~/.claude/templates/bugfix.md` 동시 로드.

---

## 1. "Stop-the-Line" Rule

예상 못 한 일이 일어나면 (테스트 실패, 빌드 에러, 행위 회귀):
- **즉시 기능 추가 중지**.
- 증거 보존 (에러 출력, 재현 단계).
- 진단·재계획으로 돌아간다.

## 2. Triage Checklist (순서대로)

1. **Reproduce** — 테스트, 스크립트, 또는 최소 단계로 안정 재현.
2. **Localize** — 어느 레이어인가 (UI / API / DB / 네트워크 / 빌드 도구).
3. **Reduce** — 최소 실패 케이스로 축소 (입력·단계 줄이기).
4. **Fix** — 증상이 아닌 root cause 수정.
5. **Guard** — 회귀 커버리지 추가 (테스트 또는 invariant 체크).
6. **Verify** — 원래 보고에 대해 end-to-end 확인.

## 3. Safe Fallbacks (시간 압박 시)

- 부분 동작보다 "safe default + warning" 선호.
- graceful degradation:
  - 침묵 실패가 아닌 **actionable error** 반환.
- "이참에 리팩터" 금지 — 수정 중에는 수정만.

## 4. Rollback Strategy (위험 큰 변경)

- 변경을 되돌릴 수 있게:
  - feature flag, config gating, 격리 커밋.
- 운영 영향이 불확실하면 **disabled-by-default** 플래그 뒤로 출시.

## 5. Instrumentation as a Tool (Not a Crutch)

- 로깅·메트릭은 다음 중 하나일 때만 추가:
  - 디버깅 시간을 의미 있게 줄이거나, 재발 방지에 기여.
- 임시 디버그 출력은 해결 후 제거 (장기적으로 유용한 것은 예외).

## 6. 사용자에게 책임 떠넘기지 않기

- 막히지 않는 한 디버깅을 사용자에게 떠넘기지 않는다.
- 막혔다면: 1개 질문 + 권장 디폴트 + 답에 따른 분기 명시.
- "이렇게 해보세요" 식 추측 제안 금지 — 가능성·확실성을 명시.

## 7. Postmortem 의무

- 동일 버그를 두 번째 만나면:
  - 원인·탐지 신호·예방 규칙을 lessons에 기록.
  - 자동 라우팅 표 갱신 검토.
