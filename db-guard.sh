#!/bin/sh
# db-guard.sh — Claude Code PreToolUse(Bash) hook
# 목적: 스크립트 런타임(node/python/bun/deno/tsx/npx 등)을 통한 DB 접속·변경을 게이트한다.
#
# 판정 (오탐 최소화를 위해 "두 신호 동시"일 때만 하드 차단):
#   - 쓰기 SQL 시그니처 + DB 접속 시그니처 둘 다 감지 → deny (exit 2)
#   - 쓰기 SQL만 감지 (접속 코드 없음 — 주석/문자열 오탐 가능)   → ask
#   - 신뢰된 읽기 전용 러너 단독 호출 (아래 (2-b) 조건 전부 충족) → 통과 (exit 0)
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
# `VAR=값 node …`, `env node …`, `command node …` 처럼 접두·래퍼가 붙어도 런타임으로 본다
# — 없으면 접두 하나로 가드 전체를 건너뛴다. 서브셸 `(node …)` 도 세그먼트 시작으로 본다.
RUNTIMES='node|nodejs|python[0-9.]*|bun|deno|tsx|ts-node|npx|uv run|poetry run|pipenv run|(pnpm|yarn) (exec|dlx)|npm exec'
ENV_ASSIGN="[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|'[^']*'|[^[:space:]\"'])*"
WRAPPER='(env|command|exec|nohup|nice|time|sudo)([[:space:]]+-[^[:space:]]+)*'
PREFIX="(($ENV_ASSIGN|$WRAPPER)[[:space:]]+)*"
if ! printf '%s' "$cmd" \
  | grep -qE "(^|&&|;|\||&|\(|\`)[[:space:]]*$PREFIX($RUNTIMES)([[:space:]]|\$|;|&|\))"; then
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

files=$(printf '%s' "$cmd" | tr -d '"' | tr -d "'" | tr '[:space:]();&|`' '\n' \
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

# ── (2-b) 신뢰된 읽기 전용 러너 → 통과 ────────────────────────────
# 프로젝트가 스스로 쓰기를 막는 조회 스크립트(READ ONLY 트랜잭션·키워드 허용목록 등)를 제공하면
# 아래 조건을 모두 만족할 때 게이트 없이 통과시킨다. 이후 허가 여부는 일반 권한 규칙이 정한다.
#   1) 명령이 `<런타임> <상대경로> [인자…]` 로 시작하는 단독 호출 — 접두·래퍼·런타임 플래그 없음,
#      경로는 [A-Za-z0-9_./-] 만(따옴표·공백·글롭 불가, `..` 불가), 따옴표 밖 셸 메타문자·명령 치환·백슬래시 없음
#   2) 러너가 cwd 가 속한 git 저장소 안(루트 직속 제외)에 있는 실파일이고, 바이트가 HEAD 의 blob 과 동일
#      — 에이전트가 새로 만들거나 고친 러너는 커밋(=사람 확인) 전까지 신뢰하지 않는다
#   3) 본문에 마커 문자열 `claude-db-guard: readonly-runner`
#   4) 러너 폴더에 미추적·무시 파일이 없고, 러너~저장소 루트 사이 폴더에 node_modules 가 없음 (의존성 가림 차단)
#   5) 명령 문자열에 쓰기 SQL 없음 (러너가 거부하겠지만 이중으로 막는다)
# git 은 필터·fsmonitor 를 실행하지 않는 명령만 쓴다 — 저장소 설정(core.fsmonitor, clean 필터)이 곧 코드 실행이기 때문.
# 한계: 러너가 import 하는 다른 추적 파일의 미커밋 수정, 저장소 루트 node_modules 변조, 에이전트가 직접 만든
#       저장소로 cwd 를 옮기는 경우는 막지 않는다 — 실제 경계는 러너의 READ ONLY 트랜잭션과 DB 계정 권한이다.
READONLY_MARKER='claude-db-guard: readonly-runner'

# 따옴표 밖 메타문자·명령 치환이 있으면 1. 정규식 치환으로는 따옴표 중첩을 셸과 다르게 해석해
# 구분자를 숨길 수 있으므로(`"x'" ; evil ; "'y"`) 셸과 같은 규칙으로 한 글자씩 훑는다.
shell_unsafe() {
  r=$(printf '%s' "$1" | awk '
    BEGIN { RS = "\001" }
    {
      n = length($0); q = ""; bad = 0
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (q == "\047") { if (c == "\047") q = ""; continue }
        if (q == "\"") {
          if (c == "\\") { i++; continue }
          if (c == "$" || c == "`") { bad = 1; break }
          if (c == "\"") q = ""
          continue
        }
        if (c == "\047" || c == "\"") { q = c; continue }
        if (index(";&|<>()$`\\{}*?[~#!\n\r", c) > 0) { bad = 1; break }
      }
      if (q != "") bad = 1
      print bad
    }' 2>/dev/null)
  [ "$r" != "0" ]
}

gitq() { git -c core.fsmonitor=false -c core.untrackedCache=false "$@" 2>/dev/null; }

trusted_readonly_runner() {
  shell_unsafe "$cmd" && return 1
  rs=$(printf '%s' "$cmd" | sed -nE 's@^[[:space:]]*(node|nodejs|bun|tsx|python[0-9.]*)[[:space:]]+([A-Za-z0-9_][A-Za-z0-9_./-]*\.(js|cjs|mjs|ts|mts|cts|py))([[:space:]].*)?$@\2@p')
  [ -n "$rs" ] || return 1
  case "/$rs/" in */../*|*/./*) return 1 ;; esac
  command -v git >/dev/null 2>&1 || return 1
  top=$(gitq -C "$cwd" rev-parse --show-toplevel) && [ -n "$top" ] || return 1
  top=$(cd "$top" && pwd -P) || return 1
  rf="$cwd/$rs"
  [ -f "$rf" ] && [ ! -L "$rf" ] || return 1
  rdir=$(cd "$(dirname "$rf")" && pwd -P) || return 1
  case "$rdir/" in "$top"/?*) ;; *) return 1 ;; esac
  rel="${rdir#"$top"/}/$(basename "$rf")"
  want=$(gitq -C "$top" rev-parse --verify --quiet "HEAD:$rel") && [ -n "$want" ] || return 1
  got=$(gitq -C "$top" hash-object --no-filters -- "$rf") || return 1
  [ "$want" = "$got" ] || return 1
  grep -qF "$READONLY_MARKER" "$rf" 2>/dev/null || return 1
  [ -z "$(GIT_LITERAL_PATHSPECS=1 gitq -C "$top" ls-files --others --directory -- "${rel%/*}/")" ] || return 1
  d="$rdir"
  while [ "$d" != "$top" ]; do
    [ -e "$d/node_modules" ] && return 1
    d=$(dirname "$d")
  done
  ! printf '%s' "$cmd" | tr '\n\r\t' '   ' | grep -iqE "$WRITE_SQL"
}

trusted_readonly_runner && exit 0

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
