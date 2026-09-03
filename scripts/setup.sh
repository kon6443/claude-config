#!/bin/sh
# 새 머신 셋업 / 재동기화 — 멱등(재실행 안전)
#   sh scripts/setup.sh
# 하는 일:
#   1) ~/.claude 아래 심링크 생성 (기존 파일은 타임스탬프 백업 후 교체)
#   2) skills/* 를 ~/.claude/skills/<name> 에 개별 심링크 (기존 외부 스킬과 공존)
#   3) commands/ → skills/ 이관에 따라 낡은 ~/.claude/commands 심링크 제거
#   4) Orca 훅 제거용 git clean 필터 등록 (clone 마다 필요 — git config 는 커밋되지 않음)
#   5) 실행 권한 + 필수 의존성(jq) 확인
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DST="$HOME/.claude"
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p "$DST" "$DST/skills"

link() { # link <repo 상대경로> <~/.claude 상대경로>
  src="$ROOT/$1"; dst="$DST/$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then echo "  ✓ $2 (skip)"; return; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.bak.$TS"; echo "  ↪ $2 기존 항목 백업: $2.bak.$TS"; fi
  ln -s "$src" "$dst"; echo "  ✓ $2 연결"
}

echo "── 심링크 ──"
# 훅 스크립트는 하드코딩하지 않고 글롭으로 잡는다.
# (과거 db-guard.sh 를 목록에 넣는 걸 잊어 링크가 빠진 적이 있다)
targets="CLAUDE.md settings.json agents rules"
for s in "$ROOT"/*.sh; do
  [ -e "$s" ] || continue
  targets="$targets $(basename "$s")"
done
for f in $targets; do
  link "$f" "$f"
done
for d in "$ROOT"/skills/*/; do
  # 글롭이 안 맞으면 리터럴 "…/skills/*/" 가 그대로 들어와 '*' 이름의 깨진 링크가 생긴다
  [ -d "$d" ] || continue
  n=$(basename "$d"); link "skills/$n" "skills/$n"
done
if [ -L "$DST/commands" ] && [ "$(readlink "$DST/commands")" = "$ROOT/commands" ]; then
  rm "$DST/commands"; echo "  ✗ commands 심링크 제거 (skills/ 로 이관)"
fi

echo "── git clean 필터 (Orca 훅 커밋 제외) ──"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$ROOT" config filter.strip-orca.clean "sh scripts/strip-orca.sh" && echo "  ✓ filter.strip-orca.clean"
else
  echo "  · git 저장소가 아니어서 필터 등록을 건너뜁니다 (clone 대신 압축본을 받은 경우)"
fi

echo "── 실행 권한 ──"
chmod +x "$ROOT"/*.sh "$ROOT"/scripts/*.sh "$ROOT"/tests/hooks/*.sh && echo "  ✓ chmod +x"

echo "── 의존성 ──"
if command -v jq >/dev/null 2>&1; then echo "  ✓ jq $(jq --version)"; else
  echo "  ⚠ jq 미설치 — check-secrets / db-guard / audit-log 훅이 무력화됩니다. brew install jq 또는 apt install jq"; fi
command -v shellcheck >/dev/null 2>&1 && echo "  ✓ shellcheck" || echo "  · shellcheck 없음 (선택, scripts/check.sh 정적검사용)"

echo "── settings.json 훅 참조 무결성 ──"
# settings.json 이 가리키는 ~/.claude/*.sh 가 실제로 존재하지 않으면
# 세션 시작이나 모든 Bash 호출이 통째로 막힐 수 있다.
missing=0
# shellcheck disable=SC2088  # 물결표는 확장 대상이 아니라 settings.json 안의 문자열 패턴이다
for hook in $(grep -oE '~/\.claude/[A-Za-z0-9._-]+\.sh' "$ROOT/settings.json" | sort -u); do
  real="$HOME/${hook#"~/"}"
  if [ -e "$real" ]; then echo "  ✓ $hook"
  else echo "  ✗ $hook — settings.json 이 참조하지만 존재하지 않음" >&2; missing=1; fi
done
[ "$missing" -eq 0 ] || echo "  ⚠ 누락된 훅이 있습니다. repo 에 파일이 있는지 확인 후 재실행하세요." >&2

echo; echo "완료. 검증: sh scripts/check.sh"
exit "$missing"
