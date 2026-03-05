#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten cwd: replace $HOME with ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# User and hostname (matching fish prompt style)
user=$(whoami)
host=$(hostname -s)

# Git branch (skip optional locks)
git_info=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_info=" ($branch)"
    fi
fi

# Context usage
ctx_info=""
if [ -n "$used_pct" ]; then
    ctx_info=" ctx:${used_pct}%"
fi

printf '\033[32m%s\033[0m@\033[32m%s\033[0m \033[34m%s\033[0m\033[36m%s\033[0m \033[33m[%s]\033[0m\033[35m%s\033[0m' \
    "$user" "$host" "$short_cwd" "$git_info" "$model" "$ctx_info"
