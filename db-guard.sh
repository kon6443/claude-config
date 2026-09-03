#!/bin/sh
# db-guard.sh — Claude Code PreToolUse(Bash) hook
# 목적: 스크립트 런타임(node/python/bun/deno/tsx/npx 등)을 통한 DB 접속·변경을 게이트한다.
#
# 판정 (오탐 최소화를 위해 "두 신호 동시"일 때만 하드 차단):
#   - 쓰기 SQL 시그니처 + DB 접속 시그니처 둘 다 감지 → deny (exit 2)
#   - 쓰기 SQL만 감지 (접속 코드 없음 — 주석/문자열 오탐 가능)   → ask
#   - DB 접속 시그니처만 감지 (SELECT 등 읽기 포함)             → ask
#   - 실행 대상 코드를 확인 못 함 (REPL/파이프/확장자 없는 파일)  → ask
#   - DB와 무관                                                  → 통과 (exit 0)
#
# 입력: PreToolUse hook payload (JSON, stdin) — { cwd, tool_input.command }
# 출력: deny = stderr + exit 2 / ask = stdout JSON(permissionDecision=ask) + exit 0 / pass = exit 0
#
# 설계 원칙:
#   * 내부 오류·jq 부재 시 fail-open — 세션 전체를 막지 않기 위함(sessionstart.sh가 jq 부재 경고).
#   * 런타임 실행 명령이 아니면 즉시 통과 → 일반 명령 오탐 원천 차단.
#   * 긴급 우회: settings.json env 또는 셸에 CLAUDE_DB_GUARD=off (audit.log에 남는다).

[ "${CLAUDE_DB_GUARD:-on}" = "off" ] && exit 0
input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$cmd" ] && exit 0
[ -z "$cwd" ] && cwd="$PWD"

# ── (0) 스크립트 런타임 실행 명령만 대상 ──────────────────────────
# 세그먼트 시작(줄머리/&&/;/|/&)에서 런타임이 실행어로 등장하는가
RUNTIMES='node|nodejs|python[0-9.]*|bun|deno|tsx|ts-node|npx|uv run|poetry run|pipenv run|(pnpm|yarn) (exec|dlx)|npm exec'
if ! printf '%s' "$cmd" \
  | grep -qE "(^|&&|;|\||&)[[:space:]]*($RUNTIMES)([[:space:]]|\$|;|&)"; then
  exit 0
fi

# ── (1) 스캔 대상(corpus) 구성 ────────────────────────────────────
# 명령 문자열 자체(인라인 -e/-c, heredoc 본문 포함) + 참조 스크립트 파일 내용
corpus="$cmd"

cd_target=$(printf '%s' "$cmd" \
  | sed -nE 's@.*(^|&&|;)[[:space:]]*cd[[:space:]]+"?([^"[:space:];&|]+)"?.*@\2@p' \
  | head -1)
case "$cd_target" in
  /*|'') ;;
  *) cd_target="$cwd/$cd_target" ;;
esac

files=$(printf '%s' "$cmd" | tr -d '"' | tr -d "'" | tr '[:space:]' '\n' \
  | grep -E '\.(js|cjs|mjs|ts|mts|cts|py)$' || true)

file_read=0
for f in $files; do
  found=""
  case "$f" in
    /*) [ -f "$f" ] && found="$f" ;;
    *)
      for base in "$cd_target" "$cwd" "."; do
        [ -z "$base" ] && continue
        if [ -f "$base/$f" ]; then found="$base/$f"; break; fi
      done
      ;;
  esac
  if [ -n "$found" ] && [ -r "$found" ]; then
    body=$(head -c 200000 "$found" 2>/dev/null || true)
    corpus="$corpus
$body"
    file_read=1
  fi
done

inline_present=0
if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(-e|--eval|-c|-p|--print)([[:space:]]|=)|<<'; then
  inline_present=1
fi

flat=$(printf '%s' "$corpus" | tr '\n\r\t' '   ')

# ── (2) 시그니처 정의 ─────────────────────────────────────────────
WRITE_SQL='INSERT[[:space:]]+INTO|UPDATE[[:space:]]+[^;]{1,80}[[:space:]]SET[[:space:]]|DELETE[[:space:]]+FROM|REPLACE[[:space:]]+INTO|TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?[A-Za-z0-9_`]|DROP[[:space:]]+(TABLE|DATABASE|INDEX|VIEW)|ALTER[[:space:]]+TABLE|CREATE[[:space:]]+(TABLE|DATABASE|INDEX|VIEW)|GRANT[[:space:]]+[A-Z]+[[:space:]]+ON|MERGE[[:space:]]+INTO'

DB_CONN='require\([^)]*(mysql|typeorm|sequelize|prisma|ioredis|mongodb|mongoose|knex|better-sqlite3|oracledb|mssql|tedious|[^A-Za-z]pg[^A-Za-z]|[^A-Za-z]redis[^A-Za-z])|import[[:space:]]+[^;]*(mysql|typeorm|sequelize|prisma|mongoose|knex|ioredis|drizzle|mongodb)|(import|from)[[:space:]]+(pymysql|psycopg2?|asyncpg|sqlalchemy|MySQLdb|pymssql|pymongo|redis|aiomysql|motor)|createConnection|createPool|createDataSource|new[[:space:]]+DataSource|PrismaClient|DATABASE_URL|DB_HOST|DB_PASSWORD|DB_USERNAME|DB_DATABASE|DB_PORT|process\.env\.DB_|getenv\([^)]*DB_'

# ── (3) 판정 ──────────────────────────────────────────────────────
emit_ask() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' \
    2>/dev/null
  exit 0
}

sql_hit=$(printf '%s' "$flat" | grep -ioE "$WRITE_SQL" 2>/dev/null | head -1 || true)
conn_hit=0
printf '%s' "$flat" | grep -iqE "$DB_CONN" 2>/dev/null && conn_hit=1

# (3-a) 쓰기 SQL + DB 접속 → deny
if [ -n "$sql_hit" ] && [ "$conn_hit" -eq 1 ]; then
  echo "[db-guard] DB 변경(쓰기) 시그니처 + DB 접속 코드 감지 — 차단했습니다." >&2
  echo "[db-guard] 근거: $sql_hit" >&2
  echo "[db-guard] INSERT/UPDATE/DELETE/DDL 등 변경 쿼리는 AI 직접 실행 금지입니다. 사용자가 직접 실행하세요." >&2
  exit 2
fi

# (3-b) 쓰기 SQL만 → ask (주석/문자열 오탐 가능성 있어 하드 차단하지 않음)
if [ -n "$sql_hit" ]; then
  emit_ask "쓰기 SQL 문자열 감지('$sql_hit'). DB 접속 코드는 보이지 않지만 확인 후 실행하세요."
fi

# (3-c) DB 접속(읽기 포함) → ask
if [ "$conn_hit" -eq 1 ]; then
  emit_ask "스크립트가 DB에 접속합니다(SELECT 등 읽기 포함). 쿼리는 확인 후 실행하세요."
fi

# (3-d) 실행 대상 코드를 확인 못 함 → ask
if [ "$file_read" -eq 0 ] && [ "$inline_present" -eq 0 ]; then
  emit_ask "실행 대상 스크립트 내용을 확인할 수 없어(파이프/REPL/확장자 없음 등) DB 접속 여부를 검증하지 못했습니다."
fi

exit 0
