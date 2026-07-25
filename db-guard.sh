#!/bin/sh
# db-guard.sh — Claude Code PreToolUse(Bash) hook
# 목적: node/python 스크립트를 통한 DB 접속/변경을 게이트한다.
#   - 쓰기(변경) SQL 시그니처 감지 → deny  (exit 2, 하드 차단)
#   - DB 접속 시그니처(SELECT 등 읽기 포함) → ask (권한 프롬프트)
#   - 실행 대상 코드를 확인 못 하는 node/python(REPL/파이프 등) → ask
#   - DB와 무관한 실행 → 무프롬프트 통과 (exit 0)
#
# 입력: PreToolUse hook payload (JSON, stdin) — { cwd, tool_input.command }
# 출력:
#   - deny: stderr 메시지 + exit 2
#   - ask : stdout JSON(permissionDecision=ask) + exit 0
#   - pass: 출력 없음 + exit 0
#
# 설계 원칙:
#   * 내부 오류 시 fail-open(통과) — 세션 전체를 막지 않기 위함(기존 훅과 동일 철학).
#     단, 쓰기 SQL이 '양성 감지'된 경우에만 하드 차단(exit 2)한다.
#   * node/python 실행이 아니면 즉시 통과 → 일반 명령 오탐 원천 차단.

input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$cmd" ] && exit 0
[ -z "$cwd" ] && cwd="$PWD"

# ── (0) node/python 실행 명령만 대상 ──────────────────────────────
# 세그먼트 시작(줄머리/&&/;/|/&)에서 node|nodejs|python|python3 이 실행어로 등장하는가
if ! printf '%s' "$cmd" \
  | grep -qE '(^|&&|;|\||&)[[:space:]]*(node|nodejs|python|python3)([[:space:]]|$|;|&)'; then
  exit 0
fi

# ── (1) 스캔 대상(corpus) 구성 ────────────────────────────────────
# 명령 문자열 자체(인라인 -e/-c, heredoc 본문 포함) + 참조 .js/.ts/.py 파일 내용
corpus="$cmd"

# 명령 내 'cd <dir>' 대상(상대경로 해석 보조)
cd_target=$(printf '%s' "$cmd" \
  | sed -nE 's@.*(^|&&|;)[[:space:]]*cd[[:space:]]+"?([^"[:space:];&|]+)"?.*@\2@p' \
  | head -1)
case "$cd_target" in
  /*|'') ;;                          # 절대경로 또는 없음
  *) cd_target="$cwd/$cd_target" ;;  # 상대 → cwd 기준
esac

# 후보 파일 토큰 추출 (따옴표 제거 → 공백 분해 → 확장자 필터)
files=$(printf '%s' "$cmd" | tr -d '"' | tr -d "'" | tr '[:space:]' '\n' \
  | grep -E '\.(js|cjs|mjs|ts|py)$' || true)

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

# 인라인 코드/heredoc 존재 여부(코드가 명령 문자열에 이미 포함됨 → 스캔됨)
inline_present=0
if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(-e|--eval|-c|-p|--print)([[:space:]]|=)|<<'; then
  inline_present=1
fi

# 개행/탭을 공백으로 평탄화(멀티라인 SQL 포착)
flat=$(printf '%s' "$corpus" | tr '\n\r\t' '   ')

# ── (2) 시그니처 정의 ─────────────────────────────────────────────
# 쓰기(변경) SQL — 감지 시 하드 차단
WRITE_SQL='INSERT[[:space:]]+INTO|UPDATE[[:space:]]+[^;]{1,80}[[:space:]]SET[[:space:]]|DELETE[[:space:]]+FROM|REPLACE[[:space:]]+INTO|TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?[A-Za-z0-9_`]|DROP[[:space:]]+(TABLE|DATABASE|INDEX|VIEW)|ALTER[[:space:]]+TABLE|CREATE[[:space:]]+(TABLE|DATABASE|INDEX|VIEW)|GRANT[[:space:]]|MERGE[[:space:]]+INTO'

# DB 접속 — 따옴표를 매칭하지 않도록 require(...)/import 범위 기반으로 구성(오탐/이스케이프 최소화)
DB_CONN='require\([^)]*(mysql|typeorm|sequelize|prisma|ioredis|mongodb|mongoose|knex|better-sqlite3|oracledb|mssql|tedious|[^A-Za-z]pg[^A-Za-z]|[^A-Za-z]redis[^A-Za-z])|import[[:space:]]+[^;]*(mysql|typeorm|sequelize|prisma|mongoose|knex|ioredis)|(import|from)[[:space:]]+(pymysql|psycopg2|sqlalchemy|MySQLdb|pymssql|pymongo|redis)|createConnection|createPool|createDataSource|new[[:space:]]+DataSource|DB_HOST|DB_PASSWORD|DB_USERNAME|DB_DATABASE|DB_PORT|process\.env\.DB_|getenv\([^)]*DB_'

# ── (3) 판정 ──────────────────────────────────────────────────────
emit_ask() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' \
    2>/dev/null
  exit 0
}

# (3-a) 쓰기 SQL → deny
hit=$(printf '%s' "$flat" | grep -ioE "$WRITE_SQL" 2>/dev/null | head -1 || true)
if [ -n "$hit" ]; then
  echo "[db-guard] DB 변경(쓰기) 시그니처 감지 — 차단했습니다." >&2
  echo "[db-guard] 근거: $hit" >&2
  echo "[db-guard] INSERT/UPDATE/DELETE/DDL 등 변경 쿼리는 AI 직접 실행 금지입니다. 사용자가 직접 실행하세요." >&2
  exit 2
fi

# (3-b) DB 접속(읽기 포함) → ask
if printf '%s' "$flat" | grep -iqE "$DB_CONN" 2>/dev/null; then
  emit_ask "node/python 스크립트가 DB에 접속합니다(SELECT 등 읽기 포함). CLAUDE.md 규칙상 쿼리는 확인 후 실행하세요."
fi

# (3-c) 실행 대상 코드를 확인 못 함(파이프/REPL 등) → ask
if [ "$file_read" -eq 0 ] && [ "$inline_present" -eq 0 ]; then
  emit_ask "실행 대상 스크립트 내용을 확인할 수 없어(파이프/REPL 등) DB 접속 여부를 검증하지 못했습니다."
fi

# (3-d) DB와 무관 → 통과
exit 0
