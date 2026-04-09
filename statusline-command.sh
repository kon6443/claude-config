#!/bin/sh
# Claude Code status line — 미니멀 이모지 스타일
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '(.context_window.remaining_percentage // (.context_window.used_percentage | if . then (100 - .) else null end)) // empty')
rate_5h_used=$(echo "$input" | jq -r 'if .rate_limits.five_hour.used_percentage != null then .rate_limits.five_hour.used_percentage else empty end')

duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

dir=$(basename "$cwd")

# Git branch
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Format duration (ms → Xm Ys)
duration=""
if [ -n "$duration_ms" ]; then
  total_sec=$((duration_ms / 1000))
  min=$((total_sec / 60))
  sec=$((total_sec % 60))
  if [ "$min" -gt 0 ]; then
    duration="${min}m${sec}s"
  else
    duration="${sec}s"
  fi
fi


# Format lines changed
lines=""
if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
  added="${lines_added:-0}"
  removed="${lines_removed:-0}"
  lines="+${added}/-${removed}"
fi

# Build output
parts="📂 ${dir}"

if [ -n "$git_branch" ]; then
  parts="${parts} · ⎇ ${git_branch}"
fi

if [ -n "$model" ]; then
  parts="${parts} · 🧠 ${model}"
fi

# Context window remaining
if [ -n "$remaining" ]; then
  parts="${parts} · ⏳ ${remaining}%"
else
  parts="${parts} · ⏳ --%"
fi

# Session rate limit (5h rolling) - Pro/Max only
if [ -n "$rate_5h_used" ]; then
  rate_5h_remain=$((100 - rate_5h_used))
  parts="${parts} · 🔋 session ${rate_5h_remain}%"
fi


if [ -n "$duration" ]; then
  parts="${parts} · ⏱ ${duration}"
fi

if [ -n "$lines" ]; then
  parts="${parts} · 📊 ${lines}"
fi

printf "%s" "$parts"
