#!/bin/sh
# Bash 명령어 감사 로그 — Claude Code PreToolUse(Bash) hook 전용
# 입력: hook payload (JSON, stdin)
# 출력: ~/.claude/audit.log 에 1줄 추가 (모드 600)
#
# 형식: [YYYY-MM-DD HH:MM:SS] [cwd] command
#  - 명령 안의 개행은 ⏎ 로 치환해 1줄 포맷을 유지한다 (sessionstart.sh의 시간 필터 전제)
#  - 시크릿 패턴은 기록 시점에 마스킹한다 (sessionstart.sh의 mask와 동일 표현식 유지)
#  - echo 대신 printf: /bin/sh(bash POSIX 모드·dash)의 echo는 \n 등을 해석해 JSON을 훼손한다
umask 077
input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0   # fail-open (sessionstart.sh가 jq 부재를 경고)

ts=$(date '+%Y-%m-%d %H:%M:%S')
cwd=$(printf '%s' "$input" | jq -r '.cwd // "?"' 2>/dev/null)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# 마스킹은 3단으로 적용한다. 순서가 중요하다 —
#  (1) 인증 스킴+자격증명: `Bearer eyJhbG...` 처럼 구분자 없이 공백으로 이어지는 형태.
#      (2)를 먼저 돌리면 `Authorization:` 만 지워지고 뒤의 토큰이 그대로 남는다.
#  (2) key=value / key: value: 키 이름 앞뒤에 접두·접미가 붙어도 잡는다 (AWS_SECRET_ACCESS_KEY, X-Api-Key).
#  (3) 고정 프리픽스 고엔트로피 토큰: 키 이름 없이 값만 등장하는 경우.
mask='s/(-u|--user)[[:space:]]+([^[:space:]:]+):[^[:space:]]+/\1 \2:[REDACTED]/g; s/([Bb]earer|[Bb]asic|[Tt]oken)[[:space:]]+[A-Za-z0-9._~+/=-]{8,}/\1 [REDACTED]/g; s/([A-Za-z_-]*(secret|token|password|passwd|api[_-]?key|apikey|credential|authorization)[A-Za-z_-]*)[[:space:]]*[:=][[:space:]]*[^[:space:]"'"'"']+/\1=[REDACTED]/gI; s/(sk-[A-Za-z0-9_-]{8,}|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|ghs_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,}|AKIA[0-9A-Z]{8,}|xox[baprs]-[0-9A-Za-z-]{8,}|AIza[0-9A-Za-z_-]{20,}|glpat-[0-9A-Za-z_-]{10,})/[REDACTED]/g'

line=$(printf '%s' "$cmd" | tr '\n\r' '  ' | sed -E "$mask")
log="$HOME/.claude/audit.log"
printf '[%s] [%s] %s\n' "$ts" "$cwd" "$line" >> "$log" 2>/dev/null || true
chmod 600 "$log" 2>/dev/null || true

# hook은 항상 정상 종료 (실패해도 본 작업 막지 않음)
exit 0
