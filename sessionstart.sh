#!/bin/sh
# Claude Code SessionStart hook (matcher: startup|resume — settings.json)
#
# 동작:
#  1) audit.log 일 1회 회전 (gzip 압축, 30일 후 삭제)
#  2) 1MB 초과 시 즉시 trim (회전 사이 폭주 방어)
#  3) 직전 활동 요약 (cwd 매칭, 노이즈 필터, 시크릿 마스킹)
#  4) 24h 위험 명령 강조 (reset --hard / force push / --no-verify / rm -rf 등)
#  0) ~/.claude 심링크 자동 복구 (repo에 새 파일이 생겨도 셋업 재실행 없이 연결)
#  5) 프로젝트 CLAUDE.md 미존재 시 안내
#  6) jq 미설치 경고 (check-secrets / db-guard / audit-log 가드가 무음 비활성화되므로)
#
# 출력 방식: JSON {"systemMessage": ...} — 사용자 화면에만 표시.
#   ⚠️ SessionStart의 "평문 stdout"은 모델 컨텍스트에 주입된다 (공식 hooks 문서).
#   사용자용 메시지는 반드시 systemMessage 필드로 보내야 토큰 비용 0이 된다.
# stdin: { "session_id":"...", "transcript_path":"...", "cwd":"...", "source":"..." }
# timeout: 5초 내 종료 (settings.json 설정)

set -eu
umask 077

input=$(cat 2>/dev/null || true)
log="$HOME/.claude/audit.log"
last_rotate="$HOME/.claude/.audit-last-rotated"
backup_dir="$HOME/.claude/backups"
mkdir -p "$backup_dir" 2>/dev/null || true

has_jq=1
command -v jq >/dev/null 2>&1 || has_jq=0

# cwd 추출 (없으면 현재 셸 cwd)
cwd=""
if [ "$has_jq" -eq 1 ] && [ -n "$input" ]; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
[ -z "$cwd" ] && cwd="$PWD"

output=""

# ─────────────────────────────────────────────────────────
# (0) ~/.claude 심링크 자동 복구
#     repo 경로는 기존 링크에서 역추적한다 (설치 위치를 가정하지 않기 위해).
#     "없는 링크만" 만든다 — 실파일이나 다른 곳을 가리키는 링크는 건드리지 않는다(setup.sh 몫).
# ─────────────────────────────────────────────────────────
repo=""
[ -L "$HOME/.claude/CLAUDE.md" ] && repo=$(dirname "$(readlink "$HOME/.claude/CLAUDE.md")" 2>/dev/null || true)
[ -d "${repo:-/nonexistent}" ] || repo="$HOME/dotfiles/claude-config"

if [ -d "$repo" ]; then
  linked=""
  # 훅 스크립트는 글롭으로 잡는다 — repo 에 새 훅을 추가해도 이 목록을 고칠 필요가 없다
  for src in "$repo"/*.sh "$repo/CLAUDE.md" "$repo/settings.json" \
             "$repo/agents" "$repo/rules"; do
    [ -e "$src" ] || continue
    dst="$HOME/.claude/$(basename "$src")"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ] && ln -s "$src" "$dst" 2>/dev/null; then
      linked="$linked $(basename "$src")"
    fi
  done
  for src in "$repo"/skills/*/; do
    [ -d "$src" ] || continue
    mkdir -p "$HOME/.claude/skills" 2>/dev/null || true
    dst="$HOME/.claude/skills/$(basename "$src")"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ] && ln -s "${src%/}" "$dst" 2>/dev/null; then
      linked="$linked skills/$(basename "$src")"
    fi
  done
  [ -n "$linked" ] && output="🔧 심링크 자동 복구:$linked
"
fi

# ─────────────────────────────────────────────────────────
# (1) audit.log 일 1회 회전
# ─────────────────────────────────────────────────────────
today=$(date +%Y-%m-%d)
last=""
[ -f "$last_rotate" ] && last=$(cat "$last_rotate" 2>/dev/null || true)

if [ -f "$log" ] && [ "$today" != "$last" ]; then
  if [ -s "$log" ]; then
    stamp="${last:-$(date -r "$log" +%Y-%m-%d 2>/dev/null || stat -f %Sm -t %Y-%m-%d "$log" 2>/dev/null || echo init)}"
    target="$backup_dir/audit.log.$stamp.gz"
    # 같은 날짜 백업이 이미 있으면 append (gzip 멤버 연결 — zcat으로 정상 해제)
    if [ -f "$target" ]; then
      gzip -c "$log" >> "$target" 2>/dev/null || true
    else
      gzip -c "$log" > "$target" 2>/dev/null || true
    fi
    chmod 600 "$target" 2>/dev/null || true
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
    if tail -10000 "$log" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$log" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
    else
      rm -f "$tmp" 2>/dev/null || true
    fi
  fi
  chmod 600 "$log" 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────
# (3)(4) 요약 + 위험 명령
# ─────────────────────────────────────────────────────────
# 시크릿 마스킹 (audit-log.sh와 동일 표현식 — 기록 시점 마스킹의 2차 방어)
# 마스킹은 3단으로 적용한다. 순서가 중요하다 —
#  (1) 인증 스킴+자격증명: `Bearer eyJhbG...` 처럼 구분자 없이 공백으로 이어지는 형태.
#      (2)를 먼저 돌리면 `Authorization:` 만 지워지고 뒤의 토큰이 그대로 남는다.
#  (2) key=value / key: value: 키 이름 앞뒤에 접두·접미가 붙어도 잡는다 (AWS_SECRET_ACCESS_KEY, X-Api-Key).
#  (3) 고정 프리픽스 고엔트로피 토큰: 키 이름 없이 값만 등장하는 경우.
mask='s/(-u|--user)[[:space:]]+([^[:space:]:]+):[^[:space:]]+/\1 \2:[REDACTED]/g; s/([Bb]earer|[Bb]asic|[Tt]oken)[[:space:]]+[A-Za-z0-9._~+/=-]{8,}/\1 [REDACTED]/g; s/([A-Za-z_-]*(secret|token|password|passwd|api[_-]?key|apikey|credential|authorization)[A-Za-z_-]*)[[:space:]]*[:=][[:space:]]*[^[:space:]"'"'"']+/\1=[REDACTED]/gI; s/(sk-[A-Za-z0-9_-]{8,}|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|ghs_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,}|AKIA[0-9A-Z]{8,}|xox[baprs]-[0-9A-Za-z-]{8,}|AIza[0-9A-Za-z_-]{20,}|glpat-[0-9A-Za-z_-]{10,})/[REDACTED]/g'

if [ -f "$log" ]; then
  recent=$(tail -500 "$log" 2>/dev/null \
    | grep -F "[$cwd]" 2>/dev/null \
    | grep -vE '\] git (status|diff|log|branch|show|fetch)( |$)|\] (ls|cat|head|tail|echo|pwd|date|wc|jq) ' \
    | sed -E "$mask" \
    | tail -5 || true)

  since=$(date -v-24H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)
  risky=""
  if [ -n "$since" ]; then
    risky=$(awk -v s="[$since]" '$0 >= s' "$log" 2>/dev/null \
      | grep -E 'reset --hard|push[^|]*--force|push[^|]*-f( |$)|push[^|]*\+[a-zA-Z]|--no-verify|--no-gpg-sign|rm -rf|chmod 777|drop[[:space:]]+(table|database)|truncate[[:space:]]+table|--dangerously-skip-permissions' \
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
if [ -d "$cwd" ] && [ ! -f "$cwd/CLAUDE.md" ] && [ ! -f "$cwd/.claude/CLAUDE.md" ]; then
  if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    output="${output}
ℹ️  이 프로젝트에 CLAUDE.md 없음 — 필요 시 /init 으로 생성하세요.
"
  fi
fi

# ─────────────────────────────────────────────────────────
# (6) jq 미설치 경고 — 가드 훅 3종이 조용히 무력화되는 상태
# ─────────────────────────────────────────────────────────
if [ "$has_jq" -eq 0 ]; then
  # jq 없이는 JSON 조립이 불가 → 평문(모델 컨텍스트에 들어가지만 1줄이며, 알아야 할 정보)
  printf '⚠️  jq 미설치: check-secrets / db-guard / audit-log 훅이 비활성 상태입니다. brew install jq\n'
  exit 0
fi

# ─────────────────────────────────────────────────────────
# 출력: systemMessage (사용자 전용, 컨텍스트 미주입)
# ─────────────────────────────────────────────────────────
if [ -n "$output" ]; then
  jq -nc --arg m "$output" '{systemMessage: $m}'
fi

exit 0
