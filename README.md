# 🟪 Cyberpunk CTF Terminal

> A hacker-aesthetic terminal setup for **Kali Linux** optimized for **CTF / HackTheBox** workflows — tmux + Dracula custom palette, Nerd Fonts, Starship, and a 4-pane HTB layout designed to pair with [Claude Code](https://www.anthropic.com/claude-code) as an AI co-pilot.

[![Kali Linux](https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge&logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![tmux](https://img.shields.io/badge/tmux-1BB91F?style=for-the-badge&logo=tmux&logoColor=white)](https://github.com/tmux/tmux)
[![Starship](https://img.shields.io/badge/Starship-DD0B78?style=for-the-badge&logo=starship&logoColor=white)](https://starship.rs/)
[![Nerd Fonts](https://img.shields.io/badge/Nerd_Fonts-000000?style=for-the-badge&logo=nerdfonts&logoColor=white)](https://www.nerdfonts.com/)
[![License: WTFPL](https://img.shields.io/badge/License-WTFPL-brightgreen.svg?style=for-the-badge)](http://www.wtfpl.net/)

![tmux bar screenshot](screenshots/tmux-bar.png?v=2)

---

## What you get

A full multi-pane workflow window that shows you, at a glance, your VPN tun0 IP, system load, current pane role, and a clean shell prompt — all wrapped in a hacker-matrix-neon palette designed to be easy on the eyes during 4 AM rooting sessions.

- 🟪 **tmux Dracula** with a custom **HACKER MATRIX NEON** palette (purple `#7000ff` blob + neon accents on pure black)
- 🌐 **Real-time `tun0` IP** in the status bar (live)
-  **Nerd Font glyphs** for every module ( CPU,  RAM,  globe-tun0,  clock,  user-secret left-icon)
- 🚀 **Starship prompt** with a green globe `` indicator that lights up only when the VPN is up
- 🤖 **Claude Code-aware layout** — `htb.sh` boots a 4-pane workflow (Claude / Attack / Notes / VPN) with red title labels and a magenta active border, designed for AI-paired CTF work
- 💾 **Persistence**: tmux-resurrect + tmux-continuum keep the session alive across reboots
- 📋 **Universal clipboard** via xclip — copy from any pane to system clipboard with a mouse drag
- 🎯 **One-script HTB workflow**: `./htb.sh <machine>` and you're ready

![full window](screenshots/full-window.png?v=2)

---

## Quick start

> Tested on Kali Linux ARM64 (kernel 6.19+), tmux 3.x, Starship 1.x, JetBrainsMono Nerd Font v3.4.0.

### 1. Install dependencies

```bash
sudo apt install -y tmux xclip qterminal git curl unzip
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc
```

### 2. Install Nerd Fonts

```bash
mkdir -p ~/.local/share/fonts/NerdFonts
cd /tmp
curl -L -o JetBrainsMono.zip \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
unzip -oq JetBrainsMono.zip -d ~/.local/share/fonts/NerdFonts/JetBrainsMono/
fc-cache -f
```

### 3. Drop the configs

```bash
git clone https://github.com/Ngelcondor/cyberpunk-ctf-terminal.git
cd cyberpunk-ctf-terminal

# Backup whatever you already have
for f in ~/.tmux.conf ~/.config/starship.toml ~/htb.sh \
         ~/.config/qterminal.org/qterminal.ini ~/.claude/statusline-command.sh; do
  [ -f "$f" ] && cp "$f" "$f.bak.$(date +%s)"
done

# Install
cp configs/tmux.conf             ~/.tmux.conf
cp configs/starship.toml         ~/.config/starship.toml
cp configs/htb.sh                ~/htb.sh && chmod +x ~/htb.sh
cp configs/qterminal.ini         ~/.config/qterminal.org/qterminal.ini
mkdir -p ~/.claude
cp configs/statusline-command.sh ~/.claude/statusline-command.sh && chmod +x ~/.claude/statusline-command.sh
```

### 4. Activate

1. Close and reopen `qterminal` (font is read at window creation, not on `SIGHUP`).
2. Start tmux, press `prefix + I` to install plugins (default prefix is `Ctrl-b`).
3. Press `prefix + r` to reload.
4. `~/htb.sh <machine-name>` to boot a CTF session.

---

## The 4-pane HTB layout

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
│                                    │  openvpn live       │
└────────────────────────────────────┴─────────────────────┘
```

Pane 1 hosts **Claude Code** — the agent shares the cwd, env, and filesystem with the Attack pane, so it can read your scan output by relative path (`Read scans/lame.nmap`) instead of fighting with copy-paste. The right column is your three single-purpose human surfaces.

See the [WRITEUP](WRITEUP.md#7-claude-code-inside-tmux--the-ai-co-pilot-pattern) for the full pattern.

---

## What's inside `configs/`

| File | Destination | Description |
|---|---|---|
| `tmux.conf` | `~/.tmux.conf` | tmux + Dracula HACKER MATRIX NEON palette + Nerd Font icons + post-TPM overrides |
| `starship.toml` | `~/.config/starship.toml` | Starship prompt with `custom.vpn` globe indicator |
| `htb.sh` | `~/htb.sh` | 4-pane HTB workflow launcher |
| `qterminal.ini` | `~/.config/qterminal.org/qterminal.ini` | qterminal — JetBrainsMonoNL Nerd Font |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude Code statusline mirroring the Starship prompt + rate-limit countdowns |

---

## The full writeup

[**📖 Read the full setup writeup →**](WRITEUP.md)

It walks through every piece (Nerd Fonts → qterminal → tmux → Dracula palette → Starship → Claude Code integration → backup strategy), explains every gotcha I hit while building this (Edit-tool stripping Unicode PUA, Dracula plugin order, `sed` recolor trick), and ships full troubleshooting.

Sections:

0. Why each piece
1. Install Nerd Fonts
2. Configure qterminal
3. Install tmux + TPM + plugins
4. The tmux config (with the Nerd Font label injection gotcha)
5. Starship prompt
6. The HTB workflow wrapper — `htb.sh`
7. **Claude Code inside tmux — the AI co-pilot pattern**
8. (Bonus) Claude Code statusline
9. Backup strategy
10. Result
11. Troubleshooting

---

## Color palette — HACKER MATRIX NEON

| Name | Hex | Usage |
|---|---|---|
| `dark_gray` | `#0a0a0d` | Bar background (pure near-black) |
| `gray` | `#1a1a1f` | Secondary background |
| `dark_purple` | `#7000ff` | Active pane border, status-left blob, window indicator |
| `light_purple` | `#bd00ff` | Time module, mode-style |
| `cyan` | `#00ffff` | tun0 IP |
| `green` | `#00ff41` | Matrix-green prompt arrow |
| `pink` | `#ff00aa` | CPU, pane count icon |
| `yellow` | `#d7ff00` | Session name, RAM |
| `red` | `#ff003c` | Pane title labels (Claude/Attack/Notes/VPN), prefix indicator |

---

## Compatibility

| OS / shell | Status |
|---|---|
| Kali Linux ARM64 (6.19+) | ✅ Tested |
| Kali Linux x86_64 | ✅ Should work — same packages |
| Debian 12+ / Ubuntu 24.04+ | ✅ Tested |
| zsh + Starship | ✅ Primary target |
| bash + Starship | ✅ Works (Starship is shell-agnostic) |
| qterminal | ✅ Primary target |
| Other Qt/GTK terminals (Konsole, kitty, alacritty, foot) | ✅ Set the font manually in their config |
| WSL2 | ⚠️ Untested — should work with a Nerd-Font-aware Windows terminal |
| macOS | ⚠️ Untested — replace qterminal with iTerm2/Ghostty/Alacritty |

---

## Why pair this with Claude Code?

Claude Code (Anthropic's terminal-native coding agent) inherits the tmux pane's `cwd`, environment, and filesystem. Drop a scan output in `~/htb/lame/scans/` and ask Claude in the next pane "what's exploitable in `scans/lame.nmap`?" — no upload, no copy-paste, no context limits.

Combined with `tmux-resurrect`, your CTF session survives reboots: Claude resumes its conversation transcript, you resume your loot folder. The conversation itself becomes the **draft of your writeup** — paste, polish, ship.

[Full pattern in §7 of the writeup →](WRITEUP.md#7-claude-code-inside-tmux--the-ai-co-pilot-pattern)

---

## License

[WTFPL](http://www.wtfpl.net/) — fork it, remix it, ship it.

---

<sub>Built during a real HTB session. If you find a bug or want to suggest a new module / glyph, [open an issue](https://github.com/Ngelcondor/cyberpunk-ctf-terminal/issues) or PR.</sub>
