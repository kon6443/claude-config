#!/bin/sh
# verify.sh — claude-config 전수조사 (설정 변경 후 무결성 검증)
#
# 사용법: sh ~/dotfiles/claude-config/verify.sh
# 종료 코드: 0 = 전체 통과, 1 이상 = 실패 항목 수
#
# 검사 항목:
#   1. 필수 파일 존재 + 크기          6. DoD SSOT (정의 1곳)
#   2. ~/.claude 심링크               7. 프로젝트 특화 잔재
#   3. JSON / shell 문법              8. 실행 권한
#   4. settings.json 훅 참조 실재     9. .gitignore 동작 (백업 추적 방지)
#   5. CLAUDE.md 라우팅 표 동기화    10. OS 이식성 (하드코딩 경로·OS 전용 명령·bashism)
#
# POSIX sh 전용으로 작성 — bash 확장(프로세스 치환 등) 사용 금지 (macOS/Linux/WSL 공통 실행)

repo=$(cd "$(dirname "$0")" && pwd)
cd "$repo" || exit 1

FAIL=0
ok()   { printf '  OK   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); }

# 검사기 자신은 grep 대상에서 제외 (패턴 문자열 자기 매칭 방지)
scan_files=$(ls ./*.sh ./*.md ./*.json rules/*.md templates/*.md commands/*.md agents/*.md 2>/dev/null | grep -v 'verify\.sh$')

echo "═══ 1. 필수 파일 존재 + 크기 ═══"
for f in CLAUDE.md settings.json README.md TASKS.md .gitignore \
         rules/workflow.md rules/context.md rules/engineering.md rules/error-recovery.md rules/git-hygiene.md \
         templates/plan.md templates/bugfix.md *.sh; do
  if [ -e "$f" ]; then
    printf '  OK   %-28s %6s bytes %4s lines\n' "$f" "$(wc -c < "$f" | tr -d ' ')" "$(wc -l < "$f" | tr -d ' ')"
  else
    fail "$f 없음"
  fi
done

echo "═══ 2. ~/.claude 심링크 ═══"
link_targets="CLAUDE.md settings.json agents commands rules templates"
for s in ./*.sh; do
  n=$(basename "$s")
  case "$n" in setup.sh|verify.sh) continue ;; esac   # repo에서 직접 실행 — 링크 불필요
  link_targets="$link_targets $n"
done
for f in $link_targets; do
  link="$HOME/.claude/$f"
  if [ -L "$link" ] && [ -e "$link" ]; then ok "$f"
  elif [ -L "$link" ]; then fail "$f — 깨진 링크"
  elif [ -e "$link" ]; then fail "$f — 실파일 (심링크 아님: setup.sh 재실행 필요)"
  else fail "$f — 없음 (setup.sh 실행 필요)"; fi
done

echo "═══ 3. JSON / shell 문법 ═══"
if jq empty settings.json 2>/dev/null; then ok "settings.json"; else fail "settings.json — jq 파싱 실패"; fi
for f in ./*.sh; do
  if sh -n "$f" 2>/dev/null; then ok "$(basename "$f")"; else fail "$(basename "$f") — 문법 오류"; fi
done

echo "═══ 4. settings.json 훅 참조 → 실재 여부 ═══"
for hook in $(grep -oE '~/.claude/[A-Za-z0-9._-]+\.sh' settings.json | sort -u); do
  real="$HOME/${hook#"~/"}"
  if [ -e "$real" ]; then ok "$hook"; else fail "$hook — 참조되지만 ~/.claude에 없음 (훅 통째 차단 위험)"; fi
done

echo "═══ 5. CLAUDE.md 라우팅 표 ↔ rules/ 동기화 ═══"
have=$(ls rules/*.md | sed 's|.*/||' | sort)
refd=$(grep -oE 'rules/[a-z-]+\.md' CLAUDE.md | sed 's|.*/||' | sort -u)
if [ "$have" = "$refd" ]; then
  ok "rules/*.md $(printf '%s\n' "$have" | wc -l | tr -d ' ')개 모두 라우팅 표에 존재"
else
  fail "rules/ 파일과 라우팅 표 불일치 — 실제: [$(echo $have)] / 참조: [$(echo $refd)]"
fi
for t in templates/*.md; do
  if grep -q "$(basename "$t")" CLAUDE.md; then ok "$t 참조됨"; else fail "$t — CLAUDE.md에서 미참조"; fi
done

echo "═══ 6. DoD SSOT (정의 1곳 — CLAUDE.md) ═══"
dod=$(grep -l "^## Definition of Done" CLAUDE.md rules/*.md templates/*.md 2>/dev/null)
if [ "$dod" = "CLAUDE.md" ]; then ok "CLAUDE.md 단독 정의"; else fail "DoD 정의 위치 이상: [$(echo $dod)]"; fi

echo "═══ 7. 프로젝트 특화·개인정보 잔재 ═══"
hits=$(grep -niE 'mobisell|laravel|nestjs|swagger' CLAUDE.md rules/*.md templates/*.md README.md TASKS.md 2>/dev/null || true)
if [ -z "$hits" ]; then ok "프로젝트 특화 없음"; else fail "발견: $hits"; fi
# 개인 식별자(이메일) — 공용 repo에 개인정보 커밋 방지
hits=$(grep -nE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' $scan_files 2>/dev/null || true)
if [ -z "$hits" ]; then ok "이메일 주소 없음"; else fail "이메일 발견: $hits"; fi

echo "═══ 8. 실행 권한 ═══"
for f in ./*.sh; do
  if [ -x "$f" ]; then ok "$(basename "$f")"; else fail "$(basename "$f") — chmod +x 필요"; fi
done

echo "═══ 9. .gitignore 동작 (백업 추적 방지) ═══"
if git status --porcelain 2>/dev/null | grep -qE '\.bak(\.|$)'; then
  fail "백업 파일이 git에 추적됨"
else
  ok "백업 미추적"
fi

echo "═══ 10. OS 이식성 (macOS/Linux/WSL 공통) ═══"
# (a) 기기·사용자·OS 하드코딩 경로
hits=$(grep -nE '/Users/|/home/[a-z]|/mnt/c|C:\\' $scan_files 2>/dev/null || true)
if [ -z "$hits" ]; then ok "하드코딩 경로 없음 (\$HOME/~ 기반)"; else fail "하드코딩 경로: $hits"; fi
# (b) sh 스크립트 내 bash 전용 문법 (프로세스 치환)
hits=$(grep -n '<(' ./*.sh 2>/dev/null | grep -v 'verify\.sh' || true)
if [ -z "$hits" ]; then ok "bashism(프로세스 치환) 없음"; else fail "bash 전용 문법: $hits"; fi
# (c) macOS 전용 date -v — GNU date -d fallback 동반 필수
hits=$(grep -n 'date -v' ./*.sh 2>/dev/null | grep -v 'verify\.sh' | grep -v 'date -d' || true)
if [ -z "$hits" ]; then ok "date -v 사용처는 모두 date -d fallback 동반"; else fail "fallback 없는 date -v: $hits"; fi
# (d) OS 전용 알림 명령 — command -v 가드 필수 (실행 파일만 검사 — 문서 언급은 무해)
guard_miss=""
for c in osascript notify-send; do
  h=$(grep -n "$c" ./*.sh settings.json 2>/dev/null | grep -v 'verify\.sh' | grep -v "command -v $c" || true)
  [ -n "$h" ] && guard_miss="$guard_miss $h"
done
if [ -z "$guard_miss" ]; then ok "OS 전용 명령(osascript/notify-send)은 모두 가드됨"; else fail "가드 없는 OS 전용 명령:$guard_miss"; fi

echo "───────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ 전체 통과"
else
  echo "❌ 실패 $FAIL건"
fi
exit "$FAIL"
