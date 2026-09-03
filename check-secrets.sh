#!/bin/sh
# UserPromptSubmit hook: 프롬프트에 시크릿 패턴이 포함되면 차단
# stdin: { "session_id":"...", "transcript_path":"...", "prompt":"..." }
# exit 2 → prompt 차단(stderr 사용자 노출), exit 0 → 통과
# jq 부재 시 fail-open (sessionstart.sh가 경고 표시)

input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$prompt" ] && exit 0

# 출처: gitleaks 기본 규칙 중 오탐 낮은 고정 프리픽스형만 채택
PATTERNS='(sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{32,}|sk_live_[0-9A-Za-z]{20,}|rk_live_[0-9A-Za-z]{20,}|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|ghs_[A-Za-z0-9]{30,}|ghr_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|glpat-[0-9A-Za-z_-]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]{10,}|xapp-[0-9]-[A-Z0-9]+-[0-9]+-[a-z0-9]+|hooks\.slack\.com/services/T[A-Za-z0-9_]+/B[A-Za-z0-9_]+/[A-Za-z0-9_]+|npm_[A-Za-z0-9]{36}|hf_[A-Za-z0-9]{30,}|AGE-SECRET-KEY-1[A-Z0-9]{50,}|eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}|-----BEGIN[ A-Z]*PRIVATE KEY-----)'

if printf '%s' "$prompt" | grep -qE "$PATTERNS"; then
  echo "[check-secrets] 프롬프트에서 시크릿 패턴이 감지되어 차단했습니다." >&2
  echo "[check-secrets] API key / 토큰 / 개인키 / webhook URL 등 민감정보를 제거 후 다시 입력해주세요." >&2
  exit 2
fi

exit 0
