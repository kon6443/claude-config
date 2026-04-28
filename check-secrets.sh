#!/bin/sh
# UserPromptSubmit hook: 프롬프트에 시크릿 패턴이 포함되면 차단
# stdin: { "session_id":"...", "transcript_path":"...", "prompt":"..." }
# exit 2 → prompt 차단(stderr 사용자 노출), exit 0 → 통과

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$prompt" ] && exit 0

PATTERNS='(sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{32,}|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|ghs_[A-Za-z0-9]{30,}|ghr_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN[ A-Z]*PRIVATE KEY-----)'

if printf '%s' "$prompt" | grep -qE "$PATTERNS"; then
  echo "[check-secrets] 프롬프트에서 시크릿 패턴이 감지되어 차단했습니다." >&2
  echo "[check-secrets] API key / 토큰 / 개인키 등 민감정보를 제거 후 다시 입력해주세요." >&2
  exit 2
fi

exit 0
