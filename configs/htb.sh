#!/bin/bash
# HackTheBox machine session
# Usage: htb [machine]

MACHINE="${1:-lame}"
SESSION="htb-$MACHINE"

mkdir -p ~/htb/$MACHINE/{notes,loot,scans,exploits}

# Helper: dentro tmux usa switch-client, fuori attach
attach_or_switch() {
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach -t "$SESSION"
  fi
}

# Se sessione esiste, attach/switch
if tmux has-session -t "$SESSION" 2>/dev/null; then
  attach_or_switch
  exit 0
fi

# Crea sessione detached con dimensioni iniziali fisse (calcoli tmux prevedibili)
tmux new-session -d -s "$SESSION" -c ~/htb -x 250 -y 70

# === Cattura pane ID (%N) — robusto a qualsiasi pane-base-index ===
PANE_CLAUDE=$(tmux display-message -t "$SESSION" -p '#{pane_id}')

# Pane Attack — split orizzontale a destra (35% width), top
PANE_ATTACK=$(tmux split-window -h -l 35% -c ~/htb -t "$PANE_CLAUDE" -P -F '#{pane_id}')

# Pane Notes — split verticale sotto Attack
PANE_NOTES=$(tmux split-window -v -c ~/htb/$MACHINE/notes -t "$PANE_ATTACK" -P -F '#{pane_id}')

# Pane VPN — split verticale sotto Notes (ultimo, in basso)
PANE_VPN=$(tmux split-window -v -c ~/htb -t "$PANE_NOTES" -P -F '#{pane_id}')

# === Titoli sui bordi pane (basato su pane_index, resiste alle sovrascritture di zsh) ===
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format "#[fg=#ff003c,bold] #{?#{==:#{pane_index},1},Claude,#{?#{==:#{pane_index},2},Attack,#{?#{==:#{pane_index},3},Notes,VPN}}} "

# === Resize forzato ===
# Ordine: prima Notes (sopra VPN), poi VPN per ultimo. Se invertito, Notes
# crescendo riassorbe le righe sottratte a VPN.
WIN_HEIGHT=$(tmux display-message -t "$SESSION" -p '#{window_height}')
VPN_HEIGHT=5
NOTES_HEIGHT=$(( (WIN_HEIGHT - VPN_HEIGHT) * 30 / 100 ))
tmux resize-pane -t "$PANE_NOTES" -y $NOTES_HEIGHT
tmux resize-pane -t "$PANE_VPN"   -y $VPN_HEIGHT

# === Echoes informativi nei pane di destra ===
tmux send-keys -t "$PANE_ATTACK" "clear; echo '⚔️  ATTACK pane — $MACHINE'; echo 'Working dir: ~/htb'" C-m
tmux send-keys -t "$PANE_NOTES"  "clear; echo '📝 Notes — $MACHINE'; ls" C-m
tmux send-keys -t "$PANE_VPN"    "clear; echo '🌐 VPN'; ip a show tun0 2>/dev/null | grep inet || echo '⚠️  not connected'" C-m

# === Lancia claude per ultimo (shell stabile, layout finalizzato) ===
tmux send-keys -t "$PANE_CLAUDE" "claude --remote-control htb-$MACHINE" C-m

# Focus su Claude
tmux select-pane -t "$PANE_CLAUDE"

attach_or_switch
