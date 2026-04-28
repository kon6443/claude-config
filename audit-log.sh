#!/bin/sh
# Bash 명령어 감사 로그 — Claude Code PreToolUse hook 전용
# 입력: hook payload (JSON, stdin)
# 출력: ~/.claude/audit.log 에 1줄 추가
#
# 형식: [YYYY-MM-DD HH:MM:SS] [cwd] command
input=$(cat)

ts=$(date '+%Y-%m-%d %H:%M:%S')
cwd=$(echo "$input" | jq -r '.cwd // "?"' 2>/dev/null)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -n "$cmd" ] && echo "[$ts] [$cwd] $cmd" >> "$HOME/.claude/audit.log"

# hook은 항상 정상 종료 (실패해도 본 작업 막지 않음)
exit 0
