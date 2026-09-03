#!/bin/sh
# 훅 스크립트 회귀 테스트 — 픽스처 JSON을 stdin으로 넣고 exit code / stdout / 부작용을 검사한다.
# 사용: sh tests/hooks/run.sh [스크립트 디렉토리]   (기본: 저장소 루트)
# 의존: jq, mktemp. CI와 scripts/check.sh에서 호출된다.
set -u
ROOT=${1:-$(cd "$(dirname "$0")/../.." && pwd)}
# 쓰기 가능한 임시 디렉토리를 찾는다. 샌드박스 환경에서는 TMPDIR 도 cwd 도 막힐 수 있어
# 후보를 순서대로 시도하고, 전부 실패하면 사유를 밝히고 종료한다 (조용히 죽지 않게).
TMP=$(mktemp -d 2>/dev/null) || TMP=""
if [ -z "$TMP" ]; then
  for cand in "${TMPDIR:-}" /tmp/claude /private/tmp/claude /tmp /var/tmp .; do
    [ -n "$cand" ] || continue
    [ -d "$cand" ] || continue
    c="$cand/.hooktest.$$"
    if mkdir -p "$c" 2>/dev/null; then TMP="$c"; break; fi
  done
fi
if [ -z "$TMP" ]; then
  echo "  FAIL 테스트 실행 불가" >&2
  echo "       쓰기 가능한 임시 디렉토리를 찾지 못했습니다 (TMPDIR·/tmp·cwd 모두 거부)." >&2
  echo "       샌드박스 안에서 실행 중이라면 셸에서 직접 실행하세요: sh tests/hooks/run.sh" >&2
  exit 1
fi
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n       %s\n' "$1" "$2"; }
# check NAME WANT_EXIT WANT_STDOUT_SUBSTR(빈문자열=stdout 비어야 함) GOT_EXIT GOT_STDOUT
check() {
  name=$1; want_exit=$2; want_out=$3; got_exit=$4; got_out=$5
  if [ "$got_exit" != "$want_exit" ]; then bad "$name" "exit $got_exit (want $want_exit)"; return; fi
  if [ -z "$want_out" ]; then
    if [ -z "$got_out" ]; then ok "$name"; else bad "$name" "stdout should be empty: $got_out"; fi
  else
    case "$got_out" in *"$want_out"*) ok "$name" ;; *) bad "$name" "stdout lacks '$want_out': $got_out" ;; esac
  fi
}
payload() { printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2"; }
run_guard() { out=$(payload "$1" "$2" | sh "$ROOT/db-guard.sh" 2>/dev/null); rc=$?; }

echo "── db-guard.sh ──"
W="$TMP/w"; mkdir -p "$W"
printf '// update the cache set on each build\nconsole.log(1);\n' > "$W/build.js"
printf '# grant access to the user when ready\nprint(1)\n' > "$W/tool.py"
printf 'const m = require("mysql2");\nconn.query("INSERT INTO t VALUES (1)");\n' > "$W/seed.js"
# shellcheck disable=SC2016
printf 'import { PrismaClient } from "@prisma/client";\nawait p.$executeRaw`DELETE FROM users`;\n' > "$W/seed.ts"
printf 'import psycopg2\ncur.execute("UPDATE users SET a=1")\n' > "$W/seed.py"
printf 'import psycopg2\ncur.execute("SELECT 1")\n' > "$W/read.py"
cp "$W/seed.js" "$W/seed"

run_guard "$W" "node build.js";        check "산문 'update … set' → ask (하드차단 아님)" 0 '"ask"' "$rc" "$out"
run_guard "$W" "python3 tool.py";      check "산문 'grant access' → 통과" 0 "" "$rc" "$out"
run_guard "$W" "node seed.js";         check "INSERT + require(mysql) → deny" 2 "" "$rc" "$out"
run_guard "$W" "npx tsx seed.ts";      check "npx tsx + DELETE + prisma → deny" 2 "" "$rc" "$out"
run_guard "$W" "bun run seed.ts";      check "bun run → deny" 2 "" "$rc" "$out"
run_guard "$W" "python3.12 seed.py";   check "python3.12 + UPDATE + psycopg2 → deny" 2 "" "$rc" "$out"
run_guard "$W" "cd $W && python read.py"; check "SELECT + psycopg2 → ask" 0 '"ask"' "$rc" "$out"
run_guard "$W" "node -e \\\"console.log(1)\\\""; check "인라인 무해 코드 → 통과" 0 "" "$rc" "$out"
run_guard "$W" "ls -la && git status";  check "런타임 아님 → 통과" 0 "" "$rc" "$out"
run_guard "$W" "node seed";            check "확장자 없는 파일(미확인) → ask" 0 '"ask"' "$rc" "$out"
out=$(payload "$W" "node seed.js" | CLAUDE_DB_GUARD=off sh "$ROOT/db-guard.sh" 2>/dev/null); rc=$?
check "CLAUDE_DB_GUARD=off → 통과" 0 "" "$rc" "$out"

echo "── statusline-command.sh ──"
sl() { out=$(printf '%s' "$1" | sh "$ROOT/statusline-command.sh" 2>/dev/null); rc=$?; }
sl '{"workspace":{"current_dir":"/tmp"},"model":{"display_name":"Fable"},"context_window":{"remaining_percentage":42},"rate_limits":{"five_hour":{"used_percentage":12.5,"resets_at":9999999999}}}'
check "소수점 rate → 출력 유지 + 사용률 표기" 0 "⚡ 5h 12%" "$rc" "$out"
check "ctx 사용률 = 100 - remaining" 0 "📈 ctx 58%" "$rc" "$out"
sl '{"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":33.7}}'
check "used_percentage 직접 제공 → floor" 0 "📈 ctx 33%" "$rc" "$out"
sl '{}';            check "빈 payload → 최소 세그먼트" 0 "📂" "$rc" "$out"
sl 'not json';      check "비JSON payload → 최소 세그먼트" 0 "📂" "$rc" "$out"
# 임시파일을 못 만드는 환경(샌드박스/읽기전용 TMPDIR)에서도 전체 파싱되어야 한다.
# here-document 기반 파싱은 여기서 조용히 실패해 model/ctx 세그먼트가 통째로 사라졌다.
# cwd 까지 쓰기 불가로 두어야 셸의 heredoc 폴백 경로가 모두 막힌다.
out=$(cd / && printf '{"workspace":{"current_dir":"/tmp"},"model":{"display_name":"Fable"},"context_window":{"used_percentage":18.4}}' \
  | TMPDIR=/nonexistent/nope sh "$ROOT/statusline-command.sh" 2>/dev/null); rc=$?
check "TMPDIR·cwd 쓰기 불가 → 파싱 유지" 0 "🧠 Fable" "$rc" "$out"
# 위 동작 테스트는 셸의 heredoc 폴백 위치에 따라 통과할 수 있으므로 구조적으로도 막는다
if grep -q '<<' "$ROOT/statusline-command.sh"; then
  bad "statusline 에 here-document 없음" "임시파일이 필요해 제약 환경에서 실패한다"
else ok "statusline 에 here-document 없음"; fi
# jq @sh 인용 없이 eval 하면 모델명/경로의 셸 메타문자가 실행된다
rm -f "$TMP/PWNED"
# shellcheck disable=SC2016  # 페이로드 안의 $( ) 는 확장되면 안 되는 테스트 입력이다
out=$(printf '{"cwd":"/tmp/a b","model":{"display_name":"X $(touch %s/PWNED) `id`"},"context_window":{"used_percentage":5}}' "$TMP" \
  | sh "$ROOT/statusline-command.sh" 2>/dev/null); rc=$?
if [ -e "$TMP/PWNED" ]; then bad "셸 인젝션 차단" "명령이 실행됨"; else ok "셸 인젝션 차단"; fi

echo "── audit-log.sh ──"
H="$TMP/home"; mkdir -p "$H/.claude"
printf '{"cwd":"/x","tool_input":{"command":"printf \\"a\\\\nb\\" && export token=abc123 && echo done"}}' | HOME="$H" sh "$ROOT/audit-log.sh"
lines=$(wc -l < "$H/.claude/audit.log" | tr -d ' ')
if [ "$lines" = "1" ]; then ok "개행 포함 명령 → 1줄 기록"; else bad "개행 포함 명령 → 1줄 기록" "lines=$lines"; fi
if grep -q 'token=\[REDACTED\]' "$H/.claude/audit.log"; then ok "기록 시점 시크릿 마스킹"; else bad "기록 시점 시크릿 마스킹" "$(cat "$H/.claude/audit.log")"; fi
if grep -q 'abc123' "$H/.claude/audit.log"; then bad "원문 시크릿 미노출" "found"; else ok "원문 시크릿 미노출"; fi
# GNU stat -f 는 파일시스템 정보를 stdout 에 뱉으므로 BSD 문법을 먼저 시도하면 Linux 에서 값이 오염된다.
# macOS 의 stat 은 -c 를 "illegal option" 으로 거부하므로 GNU 문법을 먼저 두는 순서가 양쪽에서 안전하다.
mode=$(stat -c '%a' "$H/.claude/audit.log" 2>/dev/null || stat -f '%Lp' "$H/.claude/audit.log" 2>/dev/null)
if [ "$mode" = "600" ]; then ok "audit.log 모드 600"; else bad "audit.log 모드 600" "mode=$mode"; fi

# 헤더·인라인 자격증명은 키 이름만 지워지고 값이 남는 회귀가 있었다 (audit-log / sessionstart 공용 mask)
mask_case() {
  printf '{"cwd":"/x","tool_input":{"command":"%s"}}' "$1" | HOME="$H" sh "$ROOT/audit-log.sh"
}
mask_case 'curl -H \"Authorization: Bearer ABCDEF123456\" https://x'
mask_case "curl -H 'X-Api-Key: LIVEKEY99999' https://x"
mask_case 'curl --header \"authorization: token GHXYZ7777\" https://x'
mask_case 'AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMIKEXAMPLEKEY aws s3 ls'
mask_case 'curl -u user:hunter2 -H \"Authorization:Bearer INLINE99999\" https://x'
if [ ! -s "$H/.claude/audit.log" ]; then
  bad "헤더·인라인 자격증명 마스킹" "audit.log 가 비어 있음 — 판정 불가"
else
  leaked=""
  for secret in ABCDEF123456 LIVEKEY99999 GHXYZ7777 wJalrXUtnFEMIKEXAMPLEKEY hunter2 INLINE99999; do
    grep -q "$secret" "$H/.claude/audit.log" && leaked="$leaked $secret"
  done
  if [ -n "$leaked" ]; then bad "헤더·인라인 자격증명 마스킹" "평문 잔존:$leaked"; else ok "헤더·인라인 자격증명 마스킹"; fi
fi
# 마스킹이 일반 명령을 훼손하면 감사 로그가 못 쓰게 된다
H3="$TMP/home3"; mkdir -p "$H3/.claude"
printf '{"cwd":"/x","tool_input":{"command":"git commit -m \\"add token bucket limiter\\" && sort -u names.txt"}}' | HOME="$H3" sh "$ROOT/audit-log.sh"
if grep -q 'token bucket limiter' "$H3/.claude/audit.log" && grep -q 'sort -u names.txt' "$H3/.claude/audit.log"; then
  ok "일반 명령 오탐 없음"
else bad "일반 명령 오탐 없음" "$(cat "$H3/.claude/audit.log")"; fi
# audit-log 와 sessionstart 의 mask 표현식은 반드시 동일해야 한다 (한쪽만 고치면 다른 쪽이 샌다)
if [ "$(grep -c "^mask=" "$ROOT/audit-log.sh")" = "1" ] && \
   [ "$(grep "^mask=" "$ROOT/audit-log.sh")" = "$(grep "^mask=" "$ROOT/sessionstart.sh")" ]; then
  ok "mask 표현식 두 파일 동일"
else bad "mask 표현식 두 파일 동일" "audit-log.sh 와 sessionstart.sh 의 mask= 라인이 다름"; fi

echo "── check-secrets.sh ──"
cs() { printf '{"prompt":"%s"}' "$1" | sh "$ROOT/check-secrets.sh" 2>/dev/null; rc=$?; }
expect() { if [ "$rc" = "$2" ]; then ok "$1"; else bad "$1" "rc=$rc (want $2)"; fi; }
# 픽스처는 접두사를 런타임에 조립한다.
# 리터럴로 두면 GitHub push protection 이 실제 키로 오인해 푸시를 거부한다
# (Stripe 형식으로 한 번 실제로 막혔다). 검사 대상 정규식은 그대로 통과한다.
p_google="AIza"; p_stripe="sk_$(printf live)_"; p_gitlab="glpat""-"; p_gh="ghp_"
slack_host="hooks.slack.$(printf com)/services"
cs "key=${p_google}SyA1234567890abcdefghijklmnopqrstuv"; expect "Google API key 차단" 2
cs "${p_stripe}51H1234567890abcdefghijklmn";             expect "Stripe live key 차단" 2
cs "${p_gitlab}abcdefghijklmnopqrstuv";                  expect "GitLab PAT 차단" 2
cs "https://${slack_host}/T000/B000/XXXXXXXXXXXXXXXXXXXXXXXX"; expect "Slack webhook 차단" 2
cs "${p_gh}$(printf 'a%.0s' $(seq 1 36))";               expect "GitHub PAT 차단" 2
cs "-----BEGIN RSA PRIVATE KEY-----";              expect "개인키 차단" 2
cs "settings.json의 permissions.allow를 정리해줘"; expect "일반 프롬프트 통과" 0
cs "";                                              expect "빈 프롬프트 통과" 0

echo "── sessionstart.sh ──"
H2="$TMP/home2"; mkdir -p "$H2/.claude/backups"
printf '[2000-01-01 00:00:00] [/proj] git reset --hard HEAD~1\n[2000-01-01 00:00:01] [/proj] npm test\n' > "$H2/.claude/audit.log"
echo "2000-01-01" > "$H2/.claude/.audit-last-rotated"
out=$(printf '{"cwd":"/proj","source":"startup"}' | HOME="$H2" sh "$ROOT/sessionstart.sh" 2>/dev/null); rc=$?
if [ "$rc" = 0 ]; then ok "exit 0"; else bad "exit 0" "rc=$rc"; fi
if ls "$H2/.claude/backups"/audit.log.2000-01-01.gz >/dev/null 2>&1; then ok "일 1회 회전 → gz 생성"; else bad "일 1회 회전 → gz 생성" "$(ls "$H2/.claude/backups")"; fi
if [ ! -s "$H2/.claude/audit.log" ]; then ok "회전 후 로그 비움"; else bad "회전 후 로그 비움" "not empty"; fi
# 평문 stdout은 모델 컨텍스트에 주입되므로 금지 — 출력은 없거나 systemMessage JSON이어야 한다
if [ -z "$out" ]; then ok "출력 없음 (평문 미출력)"; else
  if printf '%s' "$out" | jq -e '.systemMessage' >/dev/null 2>&1; then ok "출력은 systemMessage JSON"; else bad "출력은 systemMessage JSON" "$out"; fi; fi
date +%Y-%m-%d > "$H2/.claude/.audit-last-rotated"
now=$(date '+%Y-%m-%d %H:%M:%S')
printf '[%s] [/proj] npm run build\n[%s] [/proj] git push --force origin main\n' "$now" "$now" > "$H2/.claude/audit.log"
out=$(printf '{"cwd":"/proj","source":"startup"}' | HOME="$H2" sh "$ROOT/sessionstart.sh" 2>/dev/null)
if printf '%s' "$out" | jq -e '.systemMessage | contains("npm run build") and contains("위험 명령")' >/dev/null 2>&1; then
  ok "요약+위험명령이 systemMessage로 전달"; else bad "요약+위험명령이 systemMessage로 전달" "$out"; fi

# 심링크 자동 복구: 없는 링크만 만들고, 이미 있는 항목(실파일·타 경로 링크)은 건드리지 않는다
H4="$TMP/home4"; R4="$TMP/repo4"
mkdir -p "$H4/.claude" "$R4/skills/demo" "$R4/agents"
: > "$R4/CLAUDE.md"; : > "$R4/settings.json"; : > "$R4/newhook.sh"; : > "$R4/skills/demo/SKILL.md"
ln -s "$R4/CLAUDE.md" "$H4/.claude/CLAUDE.md"        # repo 경로 역추적용 기준 링크
printf 'keep me\n' > "$H4/.claude/settings.json"      # 실파일 — 덮어쓰면 안 된다
out=$(printf '{"cwd":"/proj","source":"startup"}' | HOME="$H4" sh "$ROOT/sessionstart.sh" 2>/dev/null)
if [ -L "$H4/.claude/newhook.sh" ]; then ok "심링크 자동 복구 — 누락된 훅 연결"; else bad "심링크 자동 복구 — 누락된 훅 연결" "newhook.sh 미생성"; fi
if [ -L "$H4/.claude/skills/demo" ]; then ok "심링크 자동 복구 — skills 개별 연결"; else bad "심링크 자동 복구 — skills 개별 연결" "skills/demo 미생성"; fi
if [ -f "$H4/.claude/settings.json" ] && [ ! -L "$H4/.claude/settings.json" ] && grep -q 'keep me' "$H4/.claude/settings.json"; then
  ok "심링크 자동 복구 — 기존 실파일 보존"; else bad "심링크 자동 복구 — 기존 실파일 보존" "실파일이 교체됨"; fi
if [ -z "$out" ] || printf '%s' "$out" | jq -e '.systemMessage' >/dev/null 2>&1; then
  ok "복구 알림도 systemMessage 로만 전달"; else bad "복구 알림도 systemMessage 로만 전달" "$out"; fi

# setup.sh: skills/ 가 없는 저장소에서 '*' 이름의 깨진 링크를 만들면 안 된다
H5="$TMP/home5"; R5="$TMP/repo5"
mkdir -p "$H5/.claude" "$R5/scripts" "$R5/agents" "$R5/rules" "$R5/tests/hooks"
cp "$ROOT/scripts/setup.sh" "$R5/scripts/setup.sh"
: > "$R5/CLAUDE.md"; : > "$R5/settings.json"; : > "$R5/hook.sh"; : > "$R5/tests/hooks/run.sh"
HOME="$H5" sh "$R5/scripts/setup.sh" >/dev/null 2>&1 || true
if [ -e "$H5/.claude/skills/*" ] || [ -L "$H5/.claude/skills/*" ]; then
  bad "setup.sh — skills 없는 저장소" "'*' 이름의 링크가 생성됨"
else ok "setup.sh — skills 없는 저장소에서 '*' 링크 미생성"; fi
if [ -L "$H5/.claude/hook.sh" ]; then ok "setup.sh — 루트 훅 글롭 연결"; else bad "setup.sh — 루트 훅 글롭 연결" "hook.sh 미연결"; fi

echo "── 문법/정적 검사 ──"
for f in "$ROOT"/*.sh "$ROOT"/scripts/*.sh "$ROOT"/tests/hooks/run.sh; do
  [ -f "$f" ] || continue   # 글롭 미매칭 시 리터럴 유입 방지
  if sh -n "$f" 2>/dev/null; then ok "sh -n $(basename "$f")"; else bad "sh -n $(basename "$f")" "syntax error"; fi
done
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -s sh --severity=warning "$ROOT"/*.sh "$ROOT"/scripts/*.sh "$ROOT"/tests/hooks/run.sh >/dev/null 2>&1; then ok "shellcheck"; else
    bad "shellcheck" "$(shellcheck -s sh --severity=warning "$ROOT"/*.sh "$ROOT"/scripts/*.sh "$ROOT"/tests/hooks/run.sh 2>&1 | head -5)"; fi
else echo "  skip shellcheck (미설치)"; fi

echo; echo "결과: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
