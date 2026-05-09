---
title: "Cyberpunk CTF Terminal Setup — Kali, tmux, Starship & Nerd Fonts"
date: 2026-05-09
tags: [kali, tmux, starship, nerdfonts, ctf, htb, dotfiles, cybersecurity]
description: "Build a hacker-aesthetic terminal optimized for CTF / HTB workflows: tmux Dracula custom palette, Nerd Font glyphs, Starship prompt, qterminal, multi-pane HTB wrapper. Full configs included."
---

# Cyberpunk CTF Terminal Setup

This is the full recipe for a **CTF/HackTheBox-grade terminal** running on Kali Linux ARM64. Goal: a single multi-pane workflow window that shows you, at a glance, your VPN tun0 IP, system load, current pane role, and a clean shell prompt — all wrapped in a hacker-matrix-neon palette that is easy on the eyes during 4 AM rooting sessions.

![tmux bar](screenshot-tmux-bar.png)

What you'll build:

- A **tmux** status bar with the Dracula theme on a custom **HACKER MATRIX NEON** palette, Nerd Font icons (` tun0 10.10.15.208`, ` CPU 4.2%`, ` RAM 3.7GB/5.8GB`, ` Sat 09/05 04:51`), and a left-icon with a stylized hacker prompt.
- A **multi-pane HTB layout** wrapper script (`htb.sh`) that opens one tmux window with four roles: `Claude / Attack / Notes / VPN`, all with red title labels and a magenta active border.
- **Nerd Fonts** (JetBrainsMono Nerd Font NL) rendering FontAwesome v4 glyphs in the terminal.
- A **Starship** prompt that shows a green globe `` only when `tun0` is up, with no IP duplication.
- **qterminal** as the host terminal emulator.

Stack: Kali Linux ARM64 / Linux 6.19+ / qterminal / zsh / tmux 3.x / TPM (Tmux Plugin Manager) / Dracula tmux theme / Starship / JetBrainsMono Nerd Font v3.4.0.

---

## 0. Why each piece

| Piece | Role |
|---|---|
| **qterminal** | Lightweight Qt terminal emulator — fast, scriptable config (`qterminal.ini`), no electron overhead. |
| **JetBrainsMono Nerd Font NL** | Patched font with 8000+ icon glyphs (FontAwesome, Material Design, Devicons). `NL` = no ligatures, important for reading scan output and regex/payload strings without `==` `!=` `->` getting visually merged. |
| **tmux** | Multi-pane workflow. Survives terminal crashes (`tmux-resurrect`), persists sessions across reboots (`tmux-continuum`). |
| **TPM** | Plugin manager for tmux. Declarative plugin install via `prefix + I`. |
| **Dracula tmux** | Theme with batteries-included status modules (CPU, RAM, VPN, network, git, time). We override its palette to a custom neon scheme. |
| **Starship** | Cross-shell prompt — declarative TOML config, fast Rust binary, supports custom modules (we use one to detect tun0). |
| **`htb.sh` wrapper** | Boot a target-specific tmux session with a 4-pane layout pre-arranged for HTB workflow. |

---

## 1. Install Nerd Fonts

We install one full patched family (JetBrainsMono) plus the Symbols-Only fallback (so any other font auto-substitutes glyphs from it).

```bash
mkdir -p ~/.local/share/fonts/NerdFonts
cd /tmp
curl -L -o JetBrainsMono.zip \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
curl -L -o NerdFontsSymbolsOnly.zip \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip"
unzip -oq JetBrainsMono.zip -d ~/.local/share/fonts/NerdFonts/JetBrainsMono/
unzip -oq NerdFontsSymbolsOnly.zip -d ~/.local/share/fonts/NerdFonts/SymbolsOnly/
fc-cache -f
fc-list | grep -i "jetbrains.*nerd" | wc -l   # should be ~96
rm /tmp/JetBrainsMono.zip /tmp/NerdFontsSymbolsOnly.zip
```

Verify a glyph renders before continuing:

```bash
printf 'globe:  microchip:  database:  clock:\n'
```

If you see boxes — your terminal isn't using a Nerd Font yet. Move to step 2.

### Gotcha: codepoint availability varies

Not every Nerd Font ships every glyph. Material Design icons (`U+F0xxx`) are abundant but some FontAwesome 5 codepoints (e.g. `U+F54C` skull) are missing in JetBrainsMono Nerd Font v3.4.0. Always check before committing to a glyph:

```bash
fc-list ":charset=F132" | grep -i "JetBrainsMonoNL Nerd Font"
```

For maximum portability, prefer **FontAwesome v4** codepoints (`U+F000`–`U+F2FF`) — they're universal across Nerd Fonts.

---

## 2. Configure qterminal

Edit `~/.config/qterminal.org/qterminal.ini`:

```ini
[General]
fontFamily=JetBrainsMonoNL Nerd Font
fontSize=10
Term=xterm-256color
TerminalTransparency=0
ConfirmMultilinePaste=false
HistoryLimited=false
```

Close and reopen the qterminal window — the font is read at window creation, not on `SIGHUP`.

Verify:

```bash
echo "$TERM"   # xterm-256color
printf ' tun0\n'   # globe icon must render, not a square
```

---

## 3. Install tmux + TPM + plugins

```bash
sudo apt install -y tmux xclip
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

The `~/.tmux.conf` declares plugins; TPM clones them on `prefix + I` after the config is sourced.

---

## 4. The tmux config

Save as `~/.tmux.conf`. This is the core of the setup. Comments inline.

```bash
# ============================================================
# .tmux.conf — pentest / CTF / Claude Code dual-pane workflow
# ============================================================

# -----------------------------------------------------------
# 1. Base settings
# -----------------------------------------------------------
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -ag terminal-overrides ",screen-256color:RGB"
set -g mouse on
set -g history-limit 100000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g escape-time 0
setw -g monitor-activity on
set -g visual-activity off
set -g focus-events on
setw -g mode-keys vi

# -----------------------------------------------------------
# 2. Reload binding
# -----------------------------------------------------------
bind r source-file ~/.tmux.conf \; display-message "✓ tmux config reloaded"

# -----------------------------------------------------------
# 3. Splits keep cwd; vim-style pane navigation
# -----------------------------------------------------------
unbind '"'; unbind %
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# -----------------------------------------------------------
# 4. Copy mode (vi) — auto-copy to system clipboard via xclip
# -----------------------------------------------------------
bind-key -T copy-mode-vi v   send-keys -X begin-selection
bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
bind-key -T copy-mode-vi y   send-keys -X copy-pipe-and-cancel "xclip -selection clipboard -i"
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard -i"
bind-key -T copy-mode-vi DoubleClick1Pane select-pane \; send-keys -X select-word \; send-keys -X copy-pipe-and-cancel "xclip -selection clipboard -i"
bind-key -T copy-mode-vi TripleClick1Pane select-pane \; send-keys -X select-line \; send-keys -X copy-pipe-and-cancel "xclip -selection clipboard -i"

# -----------------------------------------------------------
# 5. Status bar — Dracula will override most of this
# -----------------------------------------------------------
set -g status-position bottom
set -g status-interval 1
set -g status-justify left
set -g status-left-length 100
set -g status-right-length 100

# -----------------------------------------------------------
# 6. Plugins (TPM)
# -----------------------------------------------------------
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-logging'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @resurrect-capture-pane-contents 'on'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
set -g @plugin 'laktak/extrakto'
set -g @extrakto_clip_tool 'xclip -selection clipboard'
set -g @extrakto_grab_area 'window recent'
set -g @plugin 'dracula/tmux'

# ===========================================================
# HACKER MATRIX NEON palette — overrides Dracula color names
# ===========================================================
set -g @dracula-colors "
white='#e0ffe6'
gray='#1a1a1f'
dark_gray='#0a0a0d'
light_purple='#bd00ff'
dark_purple='#7000ff'
cyan='#00ffff'
green='#00ff41'
orange='#ff8700'
red='#ff003c'
pink='#ff00aa'
yellow='#d7ff00'
"

# Active modules in status bar (left-to-right)
# network-vpn in verbose mode prints the tun0 IP directly — replaces
# the deprecated ip-address module which never existed.
set -g @dracula-plugins "network-vpn cpu-usage ram-usage git time"

# Module labels — Nerd Font glyphs MUST be injected via shell, not
# typed in this file directly (see step 4.1 below).
set -g @dracula-network-vpn-label " tun0 "        # globe
set -g @dracula-network-vpn-verbose true
set -g @dracula-network-vpn-colors "cyan dark_gray"

set -g @dracula-cpu-usage-label " CPU"            # microchip
set -g @dracula-cpu-usage-colors "pink dark_gray"

set -g @dracula-ram-usage-label " RAM"            # database
set -g @dracula-ram-usage-colors "yellow dark_gray"

set -g @dracula-git-colors "green dark_gray"
set -g @dracula-git-show-current-symbol "✓"
set -g @dracula-git-show-diff-symbol "!"
set -g @dracula-git-no-repo-message ""
set -g @dracula-git-no-untracked-files true

set -g @dracula-time-colors "light_purple dark_gray"
set -g @dracula-time-format " %a %d/%m %R"        # clock_o
set -g @dracula-show-fahrenheit false
set -g @dracula-show-timezone false
set -g @dracula-military-time true
set -g @dracula-day-month true

set -g @dracula-show-powerline true
set -g @dracula-left-icon-padding 1
set -g @dracula-border-contrast true
set -g @dracula-show-flags true
set -g @dracula-show-empty-plugins false
set -g @dracula-refresh-rate 5
set -g @dracula-show-edge-icons true
set -g @dracula-inactive-window-status-style "dim"

# ===========================================================
# LEFT-ICON full custom — user-secret + hacker prompt
# Components (left → right):
#   1.   user-secret (FA U+F21B) — Anonymous-style mask
#   2. ❯ / ⚠ PFX     — flashes red ⚠ when prefix is held
#   3. ▶ #S          — current session name (yellow)
#   4.   #panes     — pane count (FA columns U+F0DB, magenta)
# ===========================================================
set -g @dracula-show-left-icon "#[fg=#0a0a0d,bold] #[default] #{?client_prefix,#[fg=#ff003c#,bold]⚠ PFX,#[fg=#00ff41#,bold]❯}#[default] #[fg=#d7ff00,bold]#S#[default] #[fg=#ff00aa] #{window_panes}#[default]"

# === Pane / mode / message styling ===
set -g pane-border-style "fg=#1a1a1f"
set -g pane-active-border-style "fg=#7000ff,bold"

# Numbers shown by display-panes (prefix + q): all dark_purple
set -g display-panes-colour "#7000ff"
set -g display-panes-active-colour "#7000ff"

set -g mode-style    "fg=#e0ffe6,bg=#bd00ff,bold"
set -g message-style "fg=#00ff41,bg=#0a0a0d,bold"
set -g message-command-style "fg=#00ffff,bg=#0a0a0d,bold"
set -g status-style  "bg=#0a0a0d,fg=#00ff41"

# -----------------------------------------------------------
# 7. ⚠ TPM run — must be the LAST line before overrides
# -----------------------------------------------------------
run '~/.tmux/plugins/tpm/tpm'

# -----------------------------------------------------------
# 8. Post-Dracula overrides
# Dracula re-applies several options on load; overriding them
# AFTER `run tpm` ensures our values win.
# -----------------------------------------------------------
set -g status-interval 1
set -g status-right-length 100
set -g status-style "bg=#0a0a0d,fg=#00ff41"
set -g pane-active-border-style "fg=#7000ff,bold"
set -g pane-border-style "fg=#1a1a1f"

# Recolor status-left blob: Dracula hard-codes matrix-green for the
# left-icon powerline blob. Swap it to dark_purple via sed so the LEFT
# side matches the active window indicator color.
run-shell 'tmux set -g status-left "$(tmux show-options -gv status-left | sed "s/#00ff41/#7000ff/g")"'
```

### 4.1. The Nerd Font label gotcha

Several lines above contain `" tun0 "`, `" CPU"`, etc. — those leading spaces hold a **Nerd Font codepoint** (`U+F0AC` globe, `U+F2DB` microchip, `U+F1C0` database, `U+F017` clock). Many editors and LSP/AI-assistant tools silently **strip Unicode Private Use Area characters** (`U+E000`–`U+F8FF` and `U+F0000`+) on write, leaving you with empty placeholders.

The robust way to inject them is via shell:

```bash
GLOBE=$(printf '\xef\x82\xac')  # U+F0AC
CHIP=$(printf  '\xef\x8b\x9b')  # U+F2DB
DB=$(printf    '\xef\x87\x80')  # U+F1C0
CLOCK=$(printf '\xef\x80\x97')  # U+F017
PANE=$(printf  '\xef\x83\x9b')  # U+F0DB
LEFT=$(printf  '\xef\x88\x9b')  # U+F21B (user-secret)

sed -i "s|@dracula-network-vpn-label \" tun0 \"|@dracula-network-vpn-label \"${GLOBE} tun0 \"|" ~/.tmux.conf
sed -i "s|@dracula-cpu-usage-label \" CPU\"|@dracula-cpu-usage-label \"${CHIP} CPU\"|" ~/.tmux.conf
sed -i "s|@dracula-ram-usage-label \" RAM\"|@dracula-ram-usage-label \"${DB} RAM\"|" ~/.tmux.conf
sed -i "s|@dracula-time-format \" %a %d/%m %R\"|@dracula-time-format \"${CLOCK} %a %d/%m %R\"|" ~/.tmux.conf

# Pane count icon and left-icon glyph in @dracula-show-left-icon
sed -i "s|fg=#ff00aa\\] #{window_panes}|fg=#ff00aa\\]${PANE} #{window_panes}|" ~/.tmux.conf
sed -i "s|fg=#0a0a0d,bold\\] #\\[default\\]|fg=#0a0a0d,bold\\]${LEFT} #\\[default\\]|" ~/.tmux.conf
```

Verify the bytes landed correctly:

```bash
grep "@dracula-network-vpn-label" ~/.tmux.conf | xxd | head
# expect:  ... 22ef 82ac 2074 756e 3020 22 ...   (EF 82 AC = U+F0AC globe)
```

### 4.2. Install plugins and reload

```bash
tmux start-server
tmux new-session -d -s temp
tmux send-keys -t temp "echo 'press prefix + I to install plugins'" C-m
tmux attach -t temp
# Inside tmux: prefix + I  (default prefix is Ctrl-b)
# After plugins clone, prefix + r reloads the config.
```

The bar should now match the screenshot. If a glyph renders as a box, your terminal isn't using a Nerd Font.

### 4.3. Why two `pane-active-border-style` blocks

Dracula re-applies its own pane-border colors when it runs. To make our `#7000ff` win, the same option must appear **both before and after** `run '~/.tmux/plugins/tpm/tpm'`. The first set is for any non-Dracula consumer; the second (post-TPM) is the one that actually persists.

### 4.4. The `sed` recolor trick

Dracula hard-codes its `green` for the left-icon powerline blob. Rather than fork the plugin, we run a one-shot `sed` after Dracula composes `status-left`, replacing every `#00ff41` (matrix green) with `#7000ff` (dark purple). Side effect: any other green directive in `status-left` flips too — but in practice that's only the blob arrows.

---

## 5. Starship prompt

Install:

```bash
curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc
```

Then `~/.config/starship.toml`:

```toml
add_newline = true
palette = "dracula"

format = """
$username$hostname$directory${custom.vpn}$git_branch$git_status$cmd_duration
$character"""

[username]
show_always = true
style_user = "bold green"
style_root = "bold red"
format = "[$user]($style)"

[hostname]
ssh_only = false
style = "bold green"
format = "@[$hostname]($style) "

[directory]
truncation_length = 3
truncate_to_repo = false
style = "bold cyan"
format = "[$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
style = "bold purple"
format = "on [$symbol$branch]($style) "

[git_status]
style = "bold yellow"
format = "[$all_status$ahead_behind]($style) "

[cmd_duration]
min_time = 2_000
style = "bold orange"
format = "took [$duration]($style) "

# tun0 indicator — green globe glyph appears only when VPN is up.
# IP itself is shown in the tmux bar, no need to duplicate it.
[custom.vpn]
command = "echo on"
when    = "ip link show tun0 2>/dev/null | grep -q UP"
shell   = ["bash", "--noprofile", "--norc"]
style   = "bold green"
format  = "[ ]($style) "
description = "Show globe icon when tun0 is up"

[palettes.dracula]
red          = "#ff5555"
green        = "#50fa7b"
yellow       = "#f1fa8c"
blue         = "#bd93f9"
purple       = "#bd93f9"
cyan         = "#8be9fd"
orange       = "#ffb86c"

[character]
success_symbol = "[❯](bold purple)"
error_symbol   = "[❯](bold red)"
```

Inject the globe glyph (same gotcha as tmux):

```bash
GLOBE=$(printf '\xef\x82\xac')
sed -i "s|format  = \"\\[ \\](\$style) \"|format  = \"[${GLOBE} ](\$style) \"|" ~/.config/starship.toml
```

Open a new shell — you should see the globe `` only when connected to an HTB VPN.

---

## 6. The HTB workflow wrapper — `htb.sh`

Save as `~/htb.sh` (`chmod +x ~/htb.sh`):

```bash
#!/usr/bin/env bash
# htb.sh — boot a 4-pane HTB workflow tmux session
# Usage: ./htb.sh <machine-name>
#   creates session "htb-<machine>" with panes:
#     1 Claude (Claude Code working pane)
#     2 Attack (the offensive shell)
#     3 Notes  (markdown notes for the writeup)
#     4 VPN    (openvpn / connection status)

set -euo pipefail
MACHINE="${1:?usage: $0 <machine-name>}"
SESSION="htb-${MACHINE}"
WORKDIR="${HOME}/htb/${MACHINE}"
mkdir -p "${WORKDIR}"

# Reuse session if already running
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# Layout: pane 1 left full-height, pane 2 top-right, pane 3 mid-right, pane 4 bottom-right
tmux new-session  -d -s "$SESSION" -n "claude" -c "$WORKDIR"
tmux split-window -h -t "${SESSION}:1.1" -c "$WORKDIR"
tmux split-window -v -t "${SESSION}:1.2" -c "$WORKDIR"
tmux split-window -v -t "${SESSION}:1.3" -c "$WORKDIR"

# Resize for ~63/37 horizontal split
tmux resize-pane -t "${SESSION}:1.1" -x 63%

# Pane titles in the border
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format \
  '#[fg=#ff003c,bold] #{?#{==:#{pane_index},1},Claude,#{?#{==:#{pane_index},2},Attack,#{?#{==:#{pane_index},3},Notes,VPN}}} '

# Bootstrap commands per pane
tmux send-keys -t "${SESSION}:1.1" "claude" C-m
tmux send-keys -t "${SESSION}:1.2" "echo '— Attack pane — ${MACHINE}'" C-m
tmux send-keys -t "${SESSION}:1.3" "test -f notes.md || touch notes.md && nvim notes.md" C-m
tmux send-keys -t "${SESSION}:1.4" "echo '— VPN pane — paste your openvpn cmd here'" C-m

tmux select-pane -t "${SESSION}:1.1"
exec tmux attach -t "$SESSION"
```

Run with: `./htb.sh lame` — you get `htb-lame` session with the 4-pane layout and red title labels (`Claude / Attack / Notes / VPN`) on every pane border.

---

## 7. Claude Code inside tmux — the AI co-pilot pattern

This is where the whole layout earns its keep. The `Claude` pane in `htb.sh` is meant to host **Claude Code** — Anthropic's terminal-native coding agent — running side-by-side with your manual offensive shell. It's the difference between *a CTF box* and *a CTF box with a context-aware engineer pair-working with you on the same filesystem*.

### 7.1. Why pair Claude Code with tmux specifically

Claude Code is a CLI: it inherits the tmux pane's `cwd`, `$TMUX`, environment variables, and any file you've created in `/tmp` or the loot folder. Three properties of tmux turn this into something more than "AI in a terminal":

| tmux feature | What it gives the agent |
|---|---|
| Shared working directory across panes | Run a `nmap -oA scans/lame` in pane 2; ask Claude in pane 1 "summarize what's exploitable in `scans/lame.nmap`" — it just opens the file, no copy-paste. |
| `tmux-resurrect` + `tmux-continuum` | Lay box dies at 3 AM, your laptop reboots. Reopen tmux and the session restores — Claude resumes the conversation from its on-disk transcript, you resume from where the loot folder left off. |
| `prefix + Tab` (extrakto) | Highlight an IP / hash / URL from the Attack pane output and paste it into Claude's prompt with one chord. No mouse, no manual selection. |
| `pane-border-format` titles | At a glance you know which pane is the agent and which is your hand-on-keyboard surface. Wrong-pane errors (paste a sudo password into Claude vs. into the actual shell) drop to zero. |
| `xclip` clipboard integration | Flags / credentials Claude finds in scan output flow straight to system clipboard via the copy-mode binding. |
| Persistent history (`history-limit 100000`) | Claude can read the entire scrollback of your Attack pane via `tmux capture-pane -p -S -100000` — full forensic context of every command you ran. |

The 4-pane `htb.sh` layout makes the division of labor explicit:

```
┌────────────────────────────────────┬─────────────────────┐
│  Claude     (1)                    │  Attack     (2)     │
│  ─────────                         │  ─────────          │
│  AI co-pilot — reads scan output,  │  Human pilot —      │
│  drafts payloads, suggests next    │  the shell where    │
│  enum step, writes the writeup,    │  YOU run nmap,      │
│  remembers what you've tried.      │  msfconsole, nc.    │
│                                    │                     │
│                                    ├─────────────────────┤
│                                    │  Notes      (3)     │
│                                    │  ─────────          │
│                                    │  nvim notes.md —    │
│                                    │  the writeup grows  │
│                                    │  here in real time. │
│                                    │                     │
│                                    ├─────────────────────┤
│                                    │  VPN        (4)     │
│                                    │  ─────────          │
│                                    │  openvpn process    │
│                                    │  live, kill -9 ready│
└────────────────────────────────────┴─────────────────────┘
[ ❯ htb-lame  4]            tun0 10.10.15.208   CPU 4%   RAM 3.7G/5.8G   Sat 04:51
```

The Claude pane is wider on purpose — it carries the conversation transcript and any tool output (Read/Edit/Bash) the agent runs on your behalf. The right column is your three single-purpose human surfaces.

### 7.2. Install Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
# or: npm install -g @anthropic-ai/claude-code
claude --version
```

Login on first run:

```bash
claude
# follow the auth flow — opens browser, drops a token in ~/.claude/
```

### 7.3. Operational benefits during a real box

These are the wins that show up after a few HTBs. Each one would be possible without tmux — but tmux is the substrate that makes them effortless.

**1. Loot folder as shared memory.**
`htb.sh` cd's every pane into `~/htb/<machine>/`. Drop scan output, downloaded binaries, captured hashes there. Claude `Read`s them by relative path: `Read scans/lame.nmap`, `Read loot/shadow`. No file uploads, no context limits on attachments.

**2. The conversation IS the writeup draft.**
Notes pane is just `nvim notes.md`. When Claude summarizes "we found Samba 3.0.20, exploited via username map script, got root, captured `/root/root.txt`" — the prose is already polished. Copy → paste → ship the writeup. The agent's transcript at `~/.claude/projects/-home-parallels-htb-<machine>/*.jsonl` is also a forensic record of every step you took.

**3. Memory across machines.**
Claude Code's per-project memory (`~/.claude/projects/<path>/memory/`) survives reboots and reinstalls. Save `feedback`-type memories like *"don't recommend metasploit modules unless I ask — I'm preparing for OSCP and need manual exploitation"* once, and it sticks. After ten boxes Claude knows your preferences, your tooling, and the gotchas you've hit before.

**4. Concurrent enumeration.**
Run a slow `gobuster` in pane 2 while Claude is hex-decoding a payload in pane 1. tmux activity monitor (`monitor-activity on`) flashes the pane title when gobuster finishes. You context-switch in 100ms instead of 30 seconds.

**5. Replayable post-incident debugging.**
Pop quiz: which exact `cewl` flags did you use to seed that hashcat run two boxes ago? Answer: `tmux-resurrect`'s saved transcript + Claude's project memory. Both written to disk continuously, both readable in plaintext.

### 7.4. tmux bindings that pair specifically well with Claude Code

Add these to `~/.tmux.conf`. They turn tmux into an AI-aware editor.

```bash
# Pipe the active pane's last 200 lines into Claude in a new prompt.
# Useful: get an instant "what did this nmap find?" without copy-paste.
bind A run-shell 'tmux capture-pane -p -S -200 -t :. | xclip -selection clipboard -i; \
                  tmux display "Pane history → clipboard, paste into Claude with Ctrl-V"'

# Send the current selection straight into Claude's pane (assumes Claude is :1.1).
bind C run-shell 'sel=$(xclip -selection clipboard -o); \
                  tmux send-keys -t :1.1 "$sel"'

# Quick toggle: zoom Claude pane fullscreen for big-output reads, then back.
# (default tmux already has prefix + z, this is just a reminder.)
```

Press `prefix + A` after a noisy scan to drop its output on the clipboard, then `Ctrl-V` in Claude's pane to ask "what's in here?".

### 7.5. The statusline closes the loop

The Claude Code statusline (next section) shows model name, context fill %, and rate-limit countdowns inside the agent's pane. Combined with the tmux bar's `tun0 IP / CPU / RAM / time` at the bottom of the screen, you have a full HUD: **agent state above, system state below, your work in the middle.**

That's the actual delivered value of the setup — every metric you'd context-switch a window to check is now in your peripheral vision.

---

## 8. (Bonus) Claude Code statusline

If you're using [Claude Code](https://www.anthropic.com/claude-code) in one of the panes, `~/.claude/statusline-command.sh` can mirror the Starship prompt:

```bash
#!/usr/bin/env bash
# Claude Code statusline — reads JSON on stdin, prints one line.
read -r INPUT
WORKDIR=$(jq -r '.workspace.current_dir // "."' <<<"$INPUT")
MODEL=$(jq -r '.model.display_name // "Claude"' <<<"$INPUT")
CTX_PCT=$(jq -r '.context.percent_used // 0' <<<"$INPUT")
RL5_PCT=$(jq -r '.rate_limits.five_hour.percent_used // 0' <<<"$INPUT")
RL5_RST=$(jq -r '.rate_limits.five_hour.resets_at // 0' <<<"$INPUT")
RL7_PCT=$(jq -r '.rate_limits.seven_day.percent_used // 0' <<<"$INPUT")
RL7_RST=$(jq -r '.rate_limits.seven_day.resets_at // 0' <<<"$INPUT")

_fmt_remaining() {
  local rest=$(( $1 - $(date +%s) ))
  ((rest <= 0)) && { printf '0m'; return; }
  if (( rest < 86400 )); then printf '%dh %dm' $((rest/3600)) $(((rest%3600)/60))
  else                        printf '%dd %dh' $((rest/86400)) $(((rest%86400)/3600)); fi
}

# ... (build segments: user@host, dir, git, model, ctx bar, RL bars + countdowns)
```

Full script in this gist: [statusline-command.sh](#).

---

## 9. Backup strategy

After every meaningful change, snapshot the configs:

```bash
TS=$(date +%Y%m%d-%H%M)
cp ~/.tmux.conf            ~/.tmux.conf.final.$TS
cp ~/.config/starship.toml ~/.config/starship.toml.final.$TS
cp ~/htb.sh                ~/htb.sh.final.$TS
```

Or commit them to a private dotfiles repo:

```bash
git init ~/dotfiles
cd ~/dotfiles
ln -sf ~/.tmux.conf            tmux.conf
ln -sf ~/.config/starship.toml starship.toml
ln -sf ~/htb.sh                htb.sh
ln -sf ~/.config/qterminal.org/qterminal.ini qterminal.ini
git add . && git commit -m 'cyberpunk ctf setup'
```

---

## 10. Result

![full window](screenshot-full-window.png)

Final reference:

| Element | Value |
|---|---|
| Left blob | `[ ❯ <session>  <pane_count>]` — purple `#7000ff` |
| Right modules | ` tun0 <ip>` cyan │ ` CPU` pink │ ` RAM` yellow │ ` time` purple |
| Active pane border | dark purple `#7000ff` |
| Pane title (all) | red `#ff003c` bold |
| Window indicator | `[N name*]` highlighted purple `#7000ff` when active |
| Prompt | `user@host dir on  branch [...]` then `❯` on next line — globe `` only if tun0 up |

Total install time: ~10 minutes (excluding Nerd Font download). All settings declarative, all configs in plaintext, all backed up.

---

## 11. Troubleshooting

**The bar shows boxes instead of icons.**
The terminal isn't loading the Nerd Font. Run `fc-list | grep -i "JetBrainsMonoNL Nerd Font"` to confirm install, then close and reopen the terminal window (qterminal reads `fontFamily` only on window creation).

**Dracula keeps overwriting my `pane-active-border-style`.**
The TPM `run '~/.tmux/plugins/tpm/tpm'` line evaluates the Dracula plugin synchronously, which sets several options. Place your overrides AFTER that line — see section 4 step 8.

**The status-left blob shows as green even after I set the color in `@dracula-show-left-icon`.**
Dracula hard-codes the wrapper background color from its palette name `green`, ignoring the embedded `#[fg=...]` directives in the left-icon string. Use the `sed` recolor trick (section 4.4) to swap it post-load.

**My `@dracula-network-vpn-label "tun0 "` lost its glyph and now shows just `tun0 `.**
The Edit tool you used (text editor / IDE / AI assistant) silently stripped the Unicode Private Use Area codepoint. Inject it via `printf '\xHH\xHH\xHH'` + `sed` (section 4.1) and verify with `xxd`.

**`tmux source-file` reloaded the config but values look stale.**
Some Dracula options apply only on plugin load. After editing `@dracula-*` settings, re-trigger Dracula explicitly:
```bash
tmux source-file ~/.tmux.conf
~/.tmux/plugins/tmux/dracula.tmux
```
Or just `tmux kill-server` and reopen.

**Session-level `status-left` overrides keep winning.**
Some startup script may have run `tmux set status-left "..."` (without `-g`) on the current session — that beats the global option. Unset with `tmux set -u status-left`.

---

## License

All configs in this writeup are released under WTFPL — fork, remix, and ship.

---

*Setup tested on Kali Linux ARM64 (kernel 6.19+), tmux 3.4, Starship 1.x, JetBrainsMono Nerd Font v3.4.0.*
