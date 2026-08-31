#!/bin/sh
# git clean 필터 — 커밋 스냅샷에서 Orca 에이전트 훅만 제거한다.
#
# 배경: Orca는 이 머신(macOS)에서만 쓰지만, 설치 시 ~/.claude/settings.json
# (이 저장소 파일의 심볼릭 링크)에 훅을 직접 주입한다. 그대로 커밋하면 Orca를
# 쓰지 않는 다른 기기까지 훅 11개를 떠안고 모든 도구 호출마다 빈 셸이 뜬다.
# 작업 파일에는 훅을 남기고 저장소에만 안 들어가게 한다. 재주입돼도 자동 방어된다.
#
# 설정(clone마다 1회):
#   git config filter.strip-orca.clean "sh scripts/strip-orca.sh"
#
# jq가 없으면 그대로 통과시킨다 — 필터가 커밋 자체를 막지 않게.
command -v jq >/dev/null 2>&1 || { cat; exit 0; }

jq --indent 2 '
  if .hooks then
    .hooks |= (
      with_entries(
        .value |= (
          map(.hooks |= map(select((.command // "") | contains("orca/agent-hooks") | not)))
          | map(select((.hooks | length) > 0))
        )
      )
      | with_entries(select((.value | length) > 0))
    )
  else . end
'
