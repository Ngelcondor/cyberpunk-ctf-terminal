#!/usr/bin/env sh
# Mullvad VPN status for tmux Dracula custom plugin.
# Outputs "🛡 XX" (country code) when up, empty when down.
# Country cached 30s in /tmp to avoid mullvad CLI cost per refresh.

export LC_ALL=en_US.UTF-8

[ -e /sys/class/net/wg0-mullvad ] || exit 0

cache=/tmp/.statusline-mullvad-country
age=999
if [ -f "$cache" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
fi

if [ "$age" -lt 30 ]; then
    country=$(cat "$cache" 2>/dev/null)
else
    country=$(mullvad status 2>/dev/null | awk '/^[[:space:]]*Relay:/ {print $2}' | cut -d- -f1 | tr 'a-z' 'A-Z')
    printf '%s' "$country" > "$cache"
fi

if [ -n "$country" ]; then
    printf "🛡 %s" "$country"
else
    printf "🛡"
fi
