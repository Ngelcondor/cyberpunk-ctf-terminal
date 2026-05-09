# Cyberpunk CTF Terminal — Configs

Companion config files for the writeup
[`2026-05-09-cyberpunk-ctf-terminal-setup.md`](../2026-05-09-cyberpunk-ctf-terminal-setup.md).

## Files

| File | Destination | Description |
|---|---|---|
| `tmux.conf` | `~/.tmux.conf` | tmux config — Dracula theme, HACKER MATRIX NEON palette, Nerd Font icons, post-TPM overrides. |
| `starship.toml` | `~/.config/starship.toml` | Starship prompt — Dracula palette, custom.vpn module showing  globe when tun0 is up. |
| `htb.sh` | `~/htb.sh` (chmod +x) | HTB workflow wrapper — boots a 4-pane tmux session (Claude / Attack / Notes / VPN) with red title labels. Usage: `./htb.sh <machine>`. |
| `qterminal.ini` | `~/.config/qterminal.org/qterminal.ini` | qterminal terminal emulator — sets JetBrainsMonoNL Nerd Font. |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` (chmod +x) | Claude Code statusline — mirrors the Starship prompt with rate-limit countdown. |

## Quick install

```bash
# Backup anything you have first
for f in ~/.tmux.conf ~/.config/starship.toml ~/htb.sh \
         ~/.config/qterminal.org/qterminal.ini ~/.claude/statusline-command.sh; do
  [ -f "$f" ] && cp "$f" "$f.bak.$(date +%s)"
done

# Drop the configs in place
cp tmux.conf            ~/.tmux.conf
cp starship.toml        ~/.config/starship.toml
cp htb.sh               ~/htb.sh && chmod +x ~/htb.sh
cp qterminal.ini        ~/.config/qterminal.org/qterminal.ini
cp statusline-command.sh ~/.claude/statusline-command.sh && chmod +x ~/.claude/statusline-command.sh
```

After dropping the configs:

1. Install JetBrainsMono Nerd Font (writeup §1).
2. Install TPM: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`.
3. Reload qterminal (close window, reopen) — fonts apply only on window creation.
4. Start tmux, press `prefix + I` (default prefix `Ctrl-b`) to install Dracula + plugins.
5. `prefix + r` to reload.

## Verify Nerd Font glyphs are present

If any label looks like a empty space (e.g. `tun0 IP` instead of ` tun0 IP`), the Edit tool / your editor stripped the Unicode Private Use Area characters. Verify with:

```bash
grep '@dracula-network-vpn-label' tmux.conf | xxd | head
# expect: ... 22ef 82ac 2074 756e 30 ...   (EF 82 AC = U+F0AC globe)
```

If the bytes are missing, re-inject via:

```bash
GLOBE=$(printf '\xef\x82\xac')
sed -i "s|@dracula-network-vpn-label \" tun0 \"|@dracula-network-vpn-label \"${GLOBE} tun0 \"|" ~/.tmux.conf
```

(Same trick for the other glyphs — see writeup §4.1 for the full list.)

## License

WTFPL — fork, remix, ship.
