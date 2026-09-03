#!/bin/sh
# Claude Code status line — 미니멀 이모지 스타일
#
# 표시: 📂 dir · ⎇ branch · 🧠 model · 📈 ctx 사용% · ⚡ 5h 사용% · ⏱ 리셋까지 · 📊 +a/-r
# 설계:
#  - jq 1회 호출로 모든 필드 추출 후 @sh 로 안전 인용 → eval (공백·따옴표 포함 값도 안전)
#    heredoc/임시파일을 쓰지 않는다: 샌드박스나 읽기전용 TMPDIR 에서 파싱이 통째로 실패했다.
#  - 숫자는 jq 에서 floor → sh 산술에 소수점이 들어가 스크립트가 즉시 종료되는 사고 방지
#    (bash POSIX 모드에서 $(( 12.5 )) 는 fatal → 상태라인이 빈 문자열로 사라졌던 원인)
#  - 어떤 필드가 비어도, jq 가 없어도 반드시 최소 1개 세그먼트를 출력한다
input=$(cat 2>/dev/null || true)

cwd=""; model=""; ctx_used=""; rate_used=""; resets_at=""; added=""; removed=""
if command -v jq >/dev/null 2>&1 && [ -n "$input" ]; then
  eval "$(printf '%s' "$input" | jq -r '
    def num: if type == "number" then (floor | tostring) else "" end;
    @sh "cwd=\(.workspace.current_dir // .cwd // "")
         model=\(.model.display_name // "")
         ctx_used=\((.context_window.used_percentage
                     // (if .context_window.remaining_percentage != null
                         then 100 - .context_window.remaining_percentage else null end)) | num)
         rate_used=\(.rate_limits.five_hour.used_percentage | num)
         resets_at=\(.rate_limits.five_hour.resets_at | num)
         added=\(.cost.total_lines_added | num)
         removed=\(.cost.total_lines_removed | num)"' 2>/dev/null || true)"
fi
[ -z "$cwd" ] && cwd="$PWD"
dir=$(basename "$cwd")

# Git branch
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# 5h 리셋 카운트다운 (resets_at: unix epoch seconds, 정수만 처리)
session_left=""
case "$resets_at" in
  ''|*[!0-9]*) ;;
  *)
    diff=$((resets_at - $(date +%s)))
    if [ "$diff" -gt 0 ]; then
      hr=$((diff / 3600)); min=$(((diff % 3600) / 60))
      if [ "$hr" -gt 0 ]; then session_left="${hr}h${min}m"; else session_left="${min}m"; fi
    fi
    ;;
esac

parts="📂 ${dir}"
[ -n "$git_branch" ] && parts="${parts} · ⎇ ${git_branch}"
[ -n "$model" ]      && parts="${parts} · 🧠 ${model}"

# 컨텍스트 사용률 (0 → 100 증가)
if [ -n "$ctx_used" ]; then parts="${parts} · 📈 ctx ${ctx_used}%"; else parts="${parts} · 📈 ctx --%"; fi

# 5h 세션 사용률 (Pro/Max — 필드 없으면 생략)
[ -n "$rate_used" ]    && parts="${parts} · ⚡ 5h ${rate_used}%"
[ -n "$session_left" ] && parts="${parts} · ⏱ ${session_left}"

if [ -n "$added" ] || [ -n "$removed" ]; then
  parts="${parts} · 📊 +${added:-0}/-${removed:-0}"
fi

printf '%s' "$parts"
