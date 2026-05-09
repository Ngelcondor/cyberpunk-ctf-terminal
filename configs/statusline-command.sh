#!/bin/sh
# Claude Code status line script — mirrors Starship Dracula CTF theme
# Fields: user@host, dir, git_branch, model, context%, rate_limits

input=$(cat)

# ---- Dracula-inspired ANSI colors ----
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
# Dracula palette approximated with standard 256-color codes
C_CYAN='\033[38;5;117m'      # #8be9fd  → cyan
C_GREEN='\033[38;5;84m'      # #50fa7b  → green
C_YELLOW='\033[38;5;228m'    # #f1fa8c  → yellow
C_PURPLE='\033[38;5;212m'    # #ff79c6  → purple
C_ORANGE='\033[38;5;215m'    # #ffb86c  → orange
C_RED='\033[38;5;203m'       # #ff5555  → red
C_BLUE='\033[38;5;141m'      # #bd93f9  → blue
C_FG='\033[38;5;253m'        # #f8f8f2  → foreground

# ---- User @ host (Kali style: user㉿host) ----
user_host=$(printf "${C_BOLD}${C_GREEN}%s㉿%s${C_RESET}" "$(whoami)" "$(hostname -s)")

# ---- Directory (up to 3 path components, like Starship truncation_length=3) ----
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_label=""
if [ -n "$cwd" ]; then
    # Replace $HOME with ~, then keep last 3 components
    home_dir="$HOME"
    short_cwd=$(printf '%s' "$cwd" | sed "s|^${home_dir}|~|")
    dir_label=$(printf '%s' "$short_cwd" | awk -F'/' '{
        n = NF
        if (n <= 3) { print $0 }
        else {
            out = ""
            for (i = n-2; i <= n; i++) {
                out = (out == "") ? $i : out "/" $i
            }
            print ".../" out
        }
    }')
fi

# ---- Git branch & status (skip optional lock) ----
git_branch=""
git_status_str=""
if [ -n "$cwd" ]; then
    git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$git_branch" ]; then
        # Check for modified, staged, untracked (fast, no lock)
        git_flags=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain 2>/dev/null | head -20)
        flags=""
        printf '%s' "$git_flags" | grep -q '^[MADRCU]' && flags="${flags}+"   # staged
        printf '%s' "$git_flags" | grep -q '^ [MD]'     && flags="${flags}!"   # modified
        printf '%s' "$git_flags" | grep -q '^??'         && flags="${flags}?"   # untracked
        [ -n "$flags" ] && git_status_str=" ${C_YELLOW}${flags}${C_RESET}"
    fi
fi

# ---- Model ----
model=$(printf '%s' "$input" | jq -r '.model.display_name // "unknown"')

# ---- Context window usage ----
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // empty')
ctx_str=""
if [ -n "$used_pct" ] && [ -n "$ctx_size" ]; then
    ctx_str=$(printf "ctx:%.0f%%/%dk" "$used_pct" "$((ctx_size / 1000))")
elif [ -n "$used_pct" ]; then
    ctx_str=$(printf "ctx:%.0f%%" "$used_pct")
fi

# ---- Rate limits ----
five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Format seconds-remaining as "Xh Ym" or "Xd Yh"
_fmt_remaining() {
    resets_at="$1"
    [ -z "$resets_at" ] && return
    now=$(date +%s)
    diff=$((resets_at - now))
    [ "$diff" -le 0 ] && printf "0m" && return
    days=$((diff / 86400))
    hours=$(( (diff % 86400) / 3600 ))
    mins=$(( (diff % 3600) / 60 ))
    if [ "$days" -gt 0 ]; then
        printf "%dd %dh" "$days" "$hours"
    else
        printf "%dh %dm" "$hours" "$mins"
    fi
}

# Pick color based on usage level: green < 60, yellow 60-84, red >= 85
_limit_color() {
    val="$1"
    if [ -z "$val" ]; then printf '%s' "$C_GREEN"; return; fi
    bucket=$(printf '%s' "$val" | awk '{if ($1 >= 85) print "red"; else if ($1 >= 60) print "yellow"; else print "green"}')
    case "$bucket" in
        red)    printf '%s' "$C_RED" ;;
        yellow) printf '%s' "$C_YELLOW" ;;
        *)      printf '%s' "$C_GREEN" ;;
    esac
}

# Build an 8-cell block progress bar
_progress_bar() {
    val="$1"
    col="$2"
    bar_width=8
    filled=$(printf '%s' "$val" | awk -v w="$bar_width" '{printf "%d", int($1/100*w + 0.5)}')
    empty=$((bar_width - filled))
    filled_str=""
    i=0
    while [ "$i" -lt "$filled" ]; do filled_str="${filled_str}█"; i=$((i+1)); done
    empty_str=""
    i=0
    while [ "$i" -lt "$empty" ]; do empty_str="${empty_str}░"; i=$((i+1)); done
    printf "${col}%s${C_RESET}%s" "$filled_str" "$empty_str"
}

five_str=""
if [ -n "$five_pct" ]; then
    five_col=$(_limit_color "$five_pct")
    five_bar=$(_progress_bar "$five_pct" "$five_col")
    five_reset_str=$(_fmt_remaining "$five_resets")
    if [ -n "$five_reset_str" ]; then
        five_str=$(printf "${five_col}5h${C_RESET}[%s]${five_col}$(printf '%.0f' "$five_pct")%%${C_RESET} ${C_DIM}%s${C_RESET}" "$five_bar" "$five_reset_str")
    else
        five_str=$(printf "${five_col}5h${C_RESET}[%s]${five_col}$(printf '%.0f' "$five_pct")%%${C_RESET}" "$five_bar")
    fi
fi

week_str=""
if [ -n "$week_pct" ]; then
    week_col=$(_limit_color "$week_pct")
    week_bar=$(_progress_bar "$week_pct" "$week_col")
    week_reset_str=$(_fmt_remaining "$week_resets")
    if [ -n "$week_reset_str" ]; then
        week_str=$(printf "${week_col}7d${C_RESET}[%s]${week_col}$(printf '%.0f' "$week_pct")%%${C_RESET} ${C_DIM}%s${C_RESET}" "$week_bar" "$week_reset_str")
    else
        week_str=$(printf "${week_col}7d${C_RESET}[%s]${week_col}$(printf '%.0f' "$week_pct")%%${C_RESET}" "$week_bar")
    fi
fi

# ---- Assemble line ----
# Format: user㉿host  dir  on  branch [flags]  model  ctx:X%/200k  5h[bar]X% Xh Ym  7d[bar]X% Xd Yh

out=$(printf "%b" "$user_host")

# Directory
if [ -n "$dir_label" ]; then
    out=$(printf "%b  ${C_BOLD}${C_CYAN}%s${C_RESET}" "$out" "$dir_label")
fi

# Git branch + status flags
if [ -n "$git_branch" ]; then
    out=$(printf "%b  ${C_DIM}on${C_RESET} ${C_PURPLE} %s${C_RESET}%b" "$out" "$git_branch" "$git_status_str")
fi

# Model
out=$(printf "%b  ${C_DIM}${C_BLUE}%s${C_RESET}" "$out" "$model")

# Context
if [ -n "$ctx_str" ]; then
    ctx_col=$(_limit_color "$used_pct")
    out=$(printf "%b  ${ctx_col}%s${C_RESET}" "$out" "$ctx_str")
fi

# 5-hour limit
if [ -n "$five_str" ]; then
    out=$(printf "%b  %b" "$out" "$five_str")
fi

# 7-day limit
if [ -n "$week_str" ]; then
    out=$(printf "%b  %b" "$out" "$week_str")
fi

printf "%b\n" "$out"
