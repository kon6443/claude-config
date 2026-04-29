#!/bin/sh
# Claude Code SessionStart hook
#
# 동작:
#  1) audit.log 일 1회 회전 (gzip 압축, 30일 후 삭제)
#  2) 1MB 초과 시 즉시 trim (회전 사이 폭주 방어)
#  3) 직전 활동 요약 (cwd 매칭, 노이즈 필터, 시크릿 마스킹, 24h 윈도)
#  4) 24h 위험 명령 강조 (reset --hard / force push / --no-verify / rm -rf 등)
#  5) 프로젝트 CLAUDE.md 미존재 시 1회 안내
#
# 출력 방식: stdout — 사용자 화면에만 표시 (additionalContext 아님 → 토큰 0)
# stdin: { "session_id":"...", "transcript_path":"...", "cwd":"...", "source":"..." }
# timeout: 5초 내 종료 (settings.json 설정)

set -eu

input=$(cat 2>/dev/null || true)
log="$HOME/.claude/audit.log"
last_rotate="$HOME/.claude/.audit-last-rotated"
backup_dir="$HOME/.claude/backups"
mkdir -p "$backup_dir" 2>/dev/null || true

# cwd 추출 (없으면 현재 셸 cwd)
cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$input" ]; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
[ -z "$cwd" ] && cwd="$PWD"

# ─────────────────────────────────────────────────────────
# (1) audit.log 일 1회 회전
# ─────────────────────────────────────────────────────────
today=$(date +%Y-%m-%d)
last=""
[ -f "$last_rotate" ] && last=$(cat "$last_rotate" 2>/dev/null || true)

if [ -f "$log" ] && [ "$today" != "$last" ]; then
  if [ -s "$log" ]; then
    stamp="${last:-$(date -r "$log" +%Y-%m-%d 2>/dev/null || echo init)}"
    target="$backup_dir/audit.log.$stamp.gz"
    # 같은 날짜 백업이 이미 있으면 append (방어)
    if [ -f "$target" ]; then
      gzip -c "$log" >> "$target" 2>/dev/null || true
    else
      gzip -c "$log" > "$target" 2>/dev/null || true
    fi
    : > "$log" 2>/dev/null || true
  fi
  echo "$today" > "$last_rotate" 2>/dev/null || true

  # 30일 초과 압축 백업 삭제
  find "$backup_dir" -maxdepth 1 -name 'audit.log.*.gz' -mtime +30 -delete 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────
# (2) 1MB 초과 시 즉시 trim
# ─────────────────────────────────────────────────────────
if [ -f "$log" ]; then
  size=$(wc -c < "$log" 2>/dev/null | tr -d ' ' || echo 0)
  if [ "${size:-0}" -gt 1048576 ]; then
    tmp=$(mktemp 2>/dev/null) || tmp="$log.tmp"
    tail -10000 "$log" > "$tmp" 2>/dev/null && mv "$tmp" "$log" 2>/dev/null || true
  fi
fi

# ─────────────────────────────────────────────────────────
# (3)(4) 요약 + 위험 명령 (모두 stdout)
# ─────────────────────────────────────────────────────────
output=""

# 시크릿 마스킹 sed 표현식 (stdout 노출 방지)
mask='s/(token|password|secret|api[_-]?key|authorization|bearer)[^[:space:]]*/[REDACTED]/gI; s/(sk-[A-Za-z0-9_-]{8,}|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|ghs_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,}|AKIA[0-9A-Z]{8,}|xox[baprs]-[0-9A-Za-z-]{8,})/[REDACTED]/g'

if [ -f "$log" ]; then
  # 최근 활동: 현재 cwd 매칭 + 노이즈 필터 + 시크릿 마스킹 + 5건
  recent=$(tail -500 "$log" 2>/dev/null \
    | grep -F "[$cwd]" 2>/dev/null \
    | grep -vE '\] git (status|diff|log|branch|show|fetch)( |$)|\] (ls|cat|head|tail|echo|pwd|date|wc|jq) ' \
    | sed -E "$mask" \
    | tail -5 || true)

  # 24h 위험 시그널
  since=$(date -v-24H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)
  risky=""
  if [ -n "$since" ]; then
    risky=$(awk -v s="[$since]" '$0 >= s' "$log" 2>/dev/null \
      | grep -E 'reset --hard|push[^|]*--force|push[^|]*-f( |$)|push[^|]*\+[a-zA-Z]|--no-verify|--no-gpg-sign|rm -rf|chmod 777|drop[[:space:]]+(table|database)|truncate[[:space:]]+table' \
      | sed -E "$mask" \
      | tail -3 || true)
  fi

  if [ -n "$recent" ]; then
    output="${output}── 최근 활동 (이 디렉토리 · 노이즈 제외 · 마지막 5개) ──
${recent}
"
  fi
  if [ -n "$risky" ]; then
    output="${output}
⚠️  최근 24h 위험 명령 (마스킹 적용):
${risky}
"
  fi
fi

# ─────────────────────────────────────────────────────────
# (5) 프로젝트 CLAUDE.md 부재 안내 (git 레포에 한정)
# ─────────────────────────────────────────────────────────
if [ -d "$cwd" ] && [ ! -f "$cwd/CLAUDE.md" ]; then
  if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    output="${output}
ℹ️  이 프로젝트에 CLAUDE.md 없음 — 필요 시 \`/init\` 슬래시 커맨드로 생성하세요.
"
  fi
fi

[ -n "$output" ] && printf '%s\n' "$output"

exit 0
