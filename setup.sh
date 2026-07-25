#!/bin/sh
# setup.sh — dotfiles/claude-config → ~/.claude 심링크 셋업 (멱등 — 재실행 안전)
#
# 사용법:
#   [ -d ~/dotfiles/claude-config ] || git clone <repo> ~/dotfiles/claude-config
#   sh ~/dotfiles/claude-config/setup.sh
#
# 설계:
#   * 링크 대상을 하드코딩 목록이 아닌 *.sh 글롭 + 고정 항목으로 동적 구성
#     → 새 훅 스크립트를 repo에 추가해도 이 파일 갱신 불필요 (db-guard.sh 누락 사고 재발 방지)
#   * 기존 실파일/잘못된 링크는 .bak.<ts>로 백업 후 교체
#   * 마지막에 settings.json이 참조하는 ~/.claude/*.sh 훅 경로 무결성 검증
set -eu

repo="$HOME/dotfiles/claude-config"
[ -d "$repo" ] || { echo "✗ $repo 없음 — 먼저 git clone 하세요." >&2; exit 1; }
mkdir -p "$HOME/.claude"
TS=$(date +%Y%m%d_%H%M%S)

# ── 링크 대상 구성: 고정 항목 + repo의 모든 *.sh (setup.sh 자신 제외) ──
targets="CLAUDE.md settings.json agents commands rules templates"
for s in "$repo"/*.sh; do
  [ -e "$s" ] || continue
  n=$(basename "$s")
  case "$n" in setup.sh|verify.sh) continue ;; esac   # repo에서 직접 실행 — 링크 불필요
  targets="$targets $n"
done

# ── 심링크 생성 (멱등) ──
for f in $targets; do
  src="$repo/$f"
  dst="$HOME/.claude/$f"
  [ -e "$src" ] || { echo "⚠ $f: repo에 없음 — 건너뜀"; continue; }
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "✓ $f: 이미 연결됨"
    continue
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak.$TS"
    echo "  $f: 기존 항목 백업 → $f.bak.$TS"
  fi
  ln -s "$src" "$dst"
  echo "✓ $f: 연결됨"
done

chmod +x "$repo"/*.sh

# ── settings.json 훅 참조 무결성 검증 ──
# settings.json이 가리키는 ~/.claude/*.sh 가 실제로 존재하는지 확인.
# 하나라도 없으면 세션 시작/Bash 실행이 통째로 막힐 수 있다.
missing=0
for hook in $(grep -oE '~/.claude/[A-Za-z0-9._-]+\.sh' "$repo/settings.json" | sort -u); do
  real="$HOME/${hook#"~/"}"
  if [ ! -e "$real" ]; then
    echo "✗ 훅 파일 누락: $hook — settings.json이 참조하지만 ~/.claude에 없음" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] && echo "✓ settings.json 훅 참조 무결성 OK"
exit "$missing"
