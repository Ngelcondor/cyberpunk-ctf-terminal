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
C_WHITE='\033[38;5;255m'     # #ffffff  → bright white

# ---- User @ host (Kali style: user㉿host) ----
user_host=$(printf "${C_BOLD}${C_GREEN}%s㉿%s${C_RESET}" "$(whoami)" "$(hostname -s)")

# ---- Mullvad VPN status (interface presence + cached country code) ----
vpn_str=""
if [ -e /sys/class/net/wg0-mullvad ]; then
    vpn_cache=/tmp/.statusline-mullvad-country
    cache_age=999
    if [ -f "$vpn_cache" ]; then
        cache_age=$(( $(date +%s) - $(stat -c %Y "$vpn_cache" 2>/dev/null || echo 0) ))
    fi
    if [ "$cache_age" -lt 30 ]; then
        country=$(cat "$vpn_cache" 2>/dev/null)
    else
        country=$(mullvad status 2>/dev/null | awk '/^[[:space:]]*Relay:/ {print $2}' | cut -d- -f1 | tr 'a-z' 'A-Z')
        printf '%s' "$country" > "$vpn_cache"
    fi
    if [ -n "$country" ]; then
        vpn_str=$(printf "${C_GREEN}🛡 %s${C_RESET}" "$country")
    else
        vpn_str=$(printf "${C_GREEN}🛡${C_RESET}")
    fi
else
    vpn_str=$(printf "${C_BOLD}${C_RED}⚠ no-vpn${C_RESET}")
fi

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
week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Pick color based on usage level: white < 60, orange 60-84, red >= 85
_limit_color() {
    val="$1"
    if [ -z "$val" ]; then printf '%s' "$C_WHITE"; return; fi
    bucket=$(printf '%s' "$val" | awk '{if ($1 >= 85) print "red"; else if ($1 >= 60) print "orange"; else print "white"}')
    case "$bucket" in
        red)    printf '%s' "$C_RED" ;;
        orange) printf '%s' "$C_ORANGE" ;;
        *)      printf '%s' "$C_WHITE" ;;
    esac
}

five_str=""
if [ -n "$five_pct" ]; then
    five_col=$(_limit_color "$five_pct")
    five_str=$(printf "⏱ ${five_col}%.0f%%${C_RESET}" "$five_pct")
fi

week_str=""
if [ -n "$week_pct" ]; then
    week_col=$(_limit_color "$week_pct")
    week_str=$(printf "📅 ${week_col}%.0f%%${C_RESET}" "$week_pct")
fi

# ---- Assemble line ----
out=""

# VPN status (Mullvad)
if [ -n "$vpn_str" ]; then
    out=$(printf "%b" "$vpn_str")
fi

# Directory
if [ -n "$dir_label" ]; then
    if [ -n "$out" ]; then
        out=$(printf "%b  ${C_BOLD}${C_CYAN}%s${C_RESET}" "$out" "$dir_label")
    else
        out=$(printf "${C_BOLD}${C_CYAN}%s${C_RESET}" "$dir_label")
    fi
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
