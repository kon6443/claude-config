#!/bin/sh
# 저장소 무결성 검사 — 설정을 바꿀 때마다, 그리고 CI에서 실행한다.
#   sh scripts/check.sh            # 전체 (심링크 검사는 ~/.claude 가 있을 때만)
#   sh scripts/check.sh --no-tests # 훅 회귀 테스트 생략
# 종료 코드: 실패 항목이 하나라도 있으면 1
# shellcheck disable=SC2015  # ok()/bad() 는 항상 성공하므로 A && ok || bad 패턴이 안전하다
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
fail=0
ok()  { printf '  OK   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
run_tests=1; [ "${1:-}" = "--no-tests" ] && run_tests=0

echo "═══ 1. 필수 파일 ═══"
for f in CLAUDE.md settings.json README.md .gitignore .gitattributes \
         sessionstart.sh audit-log.sh check-secrets.sh db-guard.sh statusline-command.sh \
         scripts/strip-orca.sh scripts/setup.sh scripts/check.sh tests/hooks/run.sh \
         rules/workflow.md rules/context.md rules/engineering.md rules/error-recovery.md rules/git-hygiene.md \
         rules/shell-portability.md \
         skills/pr-desc/SKILL.md skills/review/SKILL.md skills/tasks-dashboard/SKILL.md \
         skills/plan/SKILL.md skills/bugfix/SKILL.md \
         docs/claude-code-concepts.md docs/decisions.md; do
  [ -e "$f" ] && ok "$f" || bad "MISSING $f"
done

echo "═══ 2. JSON / 셸 문법 ═══"
jq empty settings.json 2>/dev/null && ok "settings.json 파싱" || bad "settings.json 파싱 실패"
for f in ./*.sh scripts/*.sh tests/hooks/*.sh; do sh -n "$f" 2>/dev/null && ok "sh -n $f" || bad "sh -n $f"; done
if command -v shellcheck >/dev/null 2>&1; then
  # severity 를 고정한다 — info 진단은 shellcheck 버전마다 달라 CI 만 빨개진다
  # (로컬 0.11.0 은 통과하는데 우분투 apt 의 0.9.0 이 SC2015 를 info 로 잡는 식)
  shellcheck -s sh --severity=warning ./*.sh scripts/*.sh tests/hooks/*.sh && ok "shellcheck" || bad "shellcheck"
else echo "  skip shellcheck (미설치)"; fi

echo "═══ 3. 실행 권한 (git 인덱스 기준) ═══"
for f in ./*.sh scripts/*.sh tests/hooks/*.sh; do
  mode=$(git ls-files -s "$f" 2>/dev/null | cut -c1-6)
  case "$mode" in 100755) ok "$f" ;; '') echo "  skip $f (미추적)" ;; *) bad "$f 실행비트 없음 ($mode) → git update-index --chmod=+x $f" ;; esac
done

echo "═══ 4. settings.json 정합성 ═══"
for s in sessionstart.sh audit-log.sh db-guard.sh check-secrets.sh statusline-command.sh; do
  grep -q "$s" settings.json && ok "hook 등록: $s" || bad "settings.json 에 $s 참조 없음"
done
jq -e '.hooks.SessionStart[0].matcher | test("^\\*$")' settings.json >/dev/null 2>&1 \
  && bad 'SessionStart matcher "*" — compact/fork 마다 훅이 재실행됨. startup|resume 권장' \
  || ok "SessionStart matcher 제한됨"
jq -e '.permissions.allow | index("Bash(curl:*)") or index("Bash(claude:*)") or index("Bash(gh:*)")' settings.json >/dev/null 2>&1 \
  && bad 'allow 에 curl/claude/gh 무제한 허용 — deny 우회 경로' || ok "allow 에 무제한 curl/claude/gh 없음"
jq -e '.sandbox.enabled == true' settings.json >/dev/null 2>&1 && ok "sandbox 활성" || bad "sandbox.enabled 가 true 가 아님"

echo "═══ 5. 지시문 정합성 ═══"
# rules/ 와 skills/ 는 Claude Code 가 스스로 로드한다 → "파일을 Read 하라"는 지시가 남아 있으면 이중 로드
h=$(grep -nE '즉시 (Read|읽)|파일을 Read' CLAUDE.md || true)
[ -z "$h" ] && ok "CLAUDE.md 에 파일 Read 강제 지시 없음" || bad "Read 강제 지시 잔존: $h"
# templates/ 는 skills/ 로 이관됐다 — 되살아나면 SSOT 가 둘로 갈라진다
if [ -d templates ]; then bad "templates/ 디렉토리 부활 — skills/plan, skills/bugfix 로 이관됨"; else ok "templates/ 미존재 (skills 로 이관)"; fi
# 지시문 표면(CLAUDE.md·rules·skills)에만 적용한다.
# README 는 "예전에 templates 에 있었다" 같은 이관 경위를 적는 곳이라 언급이 정상이다.
h=$(grep -rn 'templates/' CLAUDE.md rules/ skills/ 2>/dev/null || true)
[ -z "$h" ] && ok "지시문에 templates 참조 없음" || bad "templates 참조 잔존: $h"
# rules 는 자동 로드된다 — 파일 헤더가 "즉시 로드"를 주장하면 문서가 실제 동작과 어긋난다
h=$(grep -n '즉시 로드' rules/*.md 2>/dev/null || true)
[ -z "$h" ] && ok "rules 헤더가 자동 로드 모델과 일치" || bad "rules 헤더가 폐기된 라우팅을 주장: $h"
# paths: 조건부 규칙은 frontmatter 가 1행에서 열리고 닫혀야 한다 — 어긋나면 조용히 무조건 로드된다
for r in rules/*.md; do
  [ -f "$r" ] || continue
  grep -q '^paths:' "$r" || continue
  n=$(basename "$r")
  if [ "$(head -1 "$r")" = "---" ] && [ "$(grep -c '^---$' "$r")" -ge 2 ] && grep -qE '^  - "' "$r"; then
    ok "경로 한정 규칙 frontmatter: $n"
  else
    bad "$n 의 paths: frontmatter 형식 오류 — 조건이 무시되고 상시 로드된다"
  fi
done

n=$(grep -rc '^## Definition of Done' CLAUDE.md rules/ skills/ 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
[ "$n" = "1" ] && ok "DoD 정의 1곳" || bad "DoD 정의가 $n 곳"

for d in skills/*/; do
  [ -d "$d" ] || continue
  f="$d/SKILL.md"; n=$(basename "$d")
  if [ ! -f "$f" ]; then bad "skills/$n 에 SKILL.md 없음"; continue; fi
  miss=""
  for k in name description; do grep -qE "^$k:" "$f" || miss="$miss $k"; done
  grep -qE "^name: $n\$" "$f" || miss="$miss name≠디렉토리($n)"
  [ -z "$miss" ] && ok "skills/$n frontmatter" || bad "skills/$n frontmatter 누락:$miss"
done

echo "═══ 6. 프로젝트 특화 잔재 / 개인정보 ═══"
# skills/ 는 제외 — tasks-dashboard 는 프로젝트 타입 감지가 기능이라 프레임워크 이름이 정상이다
h=$(grep -rniE 'mobisell' CLAUDE.md README.md rules/ skills/ 2>/dev/null || true)
[ -z "$h" ] && ok "특정 사내 프로젝트명 없음" || bad "사내 프로젝트명 노출: $h"
h=$(grep -rniE 'laravel|nestjs|swagger' CLAUDE.md README.md rules/ 2>/dev/null || true)
[ -z "$h" ] && ok "글로벌 지침에 프레임워크 전제 없음" || bad "프레임워크 전제 혼입: $h"
if git ls-files -z | xargs -0 grep -lE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' 2>/dev/null | grep -v '^\.github/' | grep -q .; then
  bad "추적 파일에 이메일 주소 포함: $(git ls-files -z | xargs -0 grep -lE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' | tr '\n' ' ')"; else ok "이메일 주소 없음"; fi

echo "═══ 7. .gitignore 동작 ═══"
git status --porcelain 2>/dev/null | grep -qE '\.bak(\.|$)' && bad "백업 파일이 추적됨" || ok "백업 파일 미추적"

echo "═══ 8. ~/.claude 심링크 (로컬에서만) ═══"
if [ -d "$HOME/.claude" ]; then
  # 대상을 하드코딩하지 않고 setup.sh 와 같은 방식(글롭)으로 만든다.
  # 하드코딩하면 새 훅을 추가했을 때 setup.sh 는 연결하지만 여기서는 검사되지 않는다.
  link_targets="CLAUDE.md settings.json agents rules"
  for s in "$ROOT"/*.sh; do
    [ -e "$s" ] || continue
    link_targets="$link_targets $(basename "$s")"
  done
  for f in $link_targets; do
    link="$HOME/.claude/$f"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$ROOT/$f" ]; then ok "$f"
    elif [ -L "$link" ]; then bad "$f → $(readlink "$link") (다른 대상)"
    elif [ -e "$link" ]; then bad "$f 가 심링크가 아님"
    else bad "$f 심링크 없음 → sh scripts/setup.sh"; fi
  done
  for d in skills/*/; do
    [ -d "$d" ] || continue   # 글롭 미매칭 시 리터럴 유입 방지
    n=$(basename "$d"); link="$HOME/.claude/skills/$n"
    [ -L "$link" ] && [ "$(readlink "$link")" = "$ROOT/skills/$n" ] && ok "skills/$n" || bad "skills/$n 심링크 없음 → sh scripts/setup.sh"
  done
  [ -L "$HOME/.claude/commands" ] && bad "commands 심링크 잔존 (skills/ 로 이관됨) → sh scripts/setup.sh"
  command -v jq >/dev/null 2>&1 && ok "jq 설치됨" || bad "jq 미설치 — 훅 가드 전부 무력화됨"
else echo "  skip (~/.claude 없음 — CI)"; fi

echo "═══ 9. OS 이식성 (macOS / Linux / WSL 공통) ═══"
# 검사 대상에서 이 파일 자신은 뺀다 — 패턴 문자열이 자기 자신에 매칭된다
port_files=""
for f in ./*.sh scripts/setup.sh scripts/strip-orca.sh tests/hooks/run.sh settings.json; do
  [ -e "$f" ] && port_files="$port_files $f"
done
# 주석 줄은 제외한다 — 규칙을 설명하는 주석이 그 규칙에 걸리면 안 된다
# shellcheck disable=SC2086
port_grep() { grep -nE "$1" $port_files 2>/dev/null | grep -vE ':[[:space:]]*#' || true; }

h=$(port_grep '/Users/|/home/[a-z]|/mnt/c/|C:\\')
[ -z "$h" ] && ok "기기·사용자 하드코딩 경로 없음 (\$HOME/~ 기반)" || bad "하드코딩 경로: $h"

h=$(port_grep '<\(|\[\[ |declare -|=\(\)|\$\{[A-Za-z_]+\^\^|\$\{[A-Za-z_]+,,')
[ -z "$h" ] && ok "bash 전용 문법 없음 (프로세스 치환·[[·배열)" || bad "bash 전용 문법: $h"

h=$(port_grep 'date -v' | grep -v 'date -d' || true)
[ -z "$h" ] && ok "date -v 는 모두 GNU date -d 폴백 동반" || bad "폴백 없는 date -v: $h"

# GNU stat -f 는 실패해도 파일시스템 정보를 stdout 에 뱉는다.
# 따라서 BSD 전용 stat -f 는 반드시 이식 가능한 명령(stat -c / date -r) 뒤에 와야 한다.
h=$(port_grep "stat -f" | grep -vE '(stat -c|date -r)[^|]*\|\|[^|]*stat -f' || true)
[ -z "$h" ] && ok "BSD 전용 stat -f 는 모두 이식 가능한 명령 뒤에 위치" || bad "앞에 폴백이 없는 stat -f: $h"

# BSD 는 sed -i '' 를, GNU 는 sed -i 를 요구한다 — 이식 가능한 형태가 없으므로 금지
h=$(port_grep 'sed -i')
[ -z "$h" ] && ok "sed -i 미사용 (BSD/GNU 인자 불일치)" || bad "sed -i 사용: $h"

h=""
for c in osascript notify-send; do
  x=$(port_grep "$c" | grep -v "command -v $c" || true); [ -n "$x" ] && h="$h $x"
done
[ -z "$h" ] && ok "OS 전용 알림 명령은 command -v 로 가드됨" || bad "가드 없는 OS 전용 명령:$h"

if [ "$run_tests" -eq 1 ]; then
  echo "═══ 10. 훅 회귀 테스트 ═══"
  # 파이프라인 종료코드는 마지막 명령(sed)의 것이라 `run.sh | sed || fail=1` 은 실패를 삼킨다.
  # 명령 치환으로 받아야 run.sh 의 종료코드가 보존된다.
  hook_out=$(sh tests/hooks/run.sh "$ROOT" 2>&1) || fail=1
  printf '%s\n' "$hook_out" | sed 's/^/  /'
  case "$hook_out" in
    *"테스트 실행 불가"*)
      echo "  ⚠ 훅 테스트를 실행하지 못했습니다 — 코드 결함이 아니라 실행 환경 제약입니다." ;;
  esac
fi

echo
if [ "$fail" -eq 0 ]; then echo "✅ 모든 검사 통과"; else echo "❌ 실패 항목 있음"; fi
exit "$fail"
