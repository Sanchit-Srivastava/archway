# Cheatsheet

Quick reference for shell aliases and tmux keybindings.

## Shell Aliases

### File & Directory

| Alias | Command | Notes |
|-------|---------|-------|
| `ls` | `eza --group-directories-first --icons` | |
| `ll` | `eza -la --group-directories-first --icons` | Long list with hidden files |
| `la` | `eza -a --group-directories-first --icons` | All files |
| `lt` | `eza --tree --level=2 --icons` | Tree view |
| `cat` | `bat --style=plain` | |
| `grep` | `rg` | ripgrep |
| `find` | `fd` | |
| `du` | `dust` | |
| `..` | `cd ..` | |
| `...` | `cd ../..` | |
| `....` | `cd ../../..` | |

### Git

| Alias | Command |
|-------|---------|
| `g` | `git` |
| `gs` | `git status` |
| `ga` | `git add` |
| `gc` | `git commit` |
| `gp` | `git push` |
| `gl` | `git pull` |
| `gd` | `git diff` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `glog` | `git log --oneline --graph --decorate` |
| `lg` | `lazygit` |

### Tmux Session Management

Candidates for `x` come from your zoxide history (frecency-ranked), the same list as `zi`.

| Command | Description |
|---------|-------------|
| `x` | Open fzf project picker → create or attach to session |
| `x <dir>` | Create or attach to session for `<dir>` directly |
| `xa` | fzf picker over existing sessions → attach |
| `xa <name>` | Attach to named session (`<tab>` completes session names) |
| `xn` | New session named after current directory |
| `xn <name>` | New session with explicit name |
| `xl` | `tmux ls` — list all sessions |

### Navigation

| Alias/Function | Description |
|----------------|-------------|
| `y` | Open yazi; cd to its working directory on exit |
| `z <query>` | Jump to frecent directory (zoxide) |

### System

| Alias | Description |
|-------|-------------|
| `update` | `pacman -Syu` (Arch) / `brew update && upgrade` (macOS) |
| `please` | `sudo` |
| `df` | `df -h` |
| `zshconfig` | Open `~/.zshrc` in `$EDITOR` |
| `hyprconfig` | Open `~/.config/hypr/hyprland.conf` in `$EDITOR` (Arch only) |

### Archway

Run commands from `~/archway`:

| Command | Description |
|---------|-------------|
| `just sync` | Pull and reapply core + dotfiles |
| `just dms-config` | Reapply portable DMS/niri and plugin preferences |
| `just extras` | Retry optional native/AUR packages |

---

## Tmux Keybindings

Prefix: `C-Space`

### Sessions

| Binding | Action |
|---------|--------|
| `prefix + f` | Sessionizer — fzf project picker, create or attach |
| `prefix + j` | Previous session |
| `prefix + k` | Next session |
| `prefix + R` | Rename current session |
| `prefix + Q` | Kill current session |

### Windows

| Binding | Action |
|---------|--------|
| `prefix + c` | New window (opens at current path) |
| `M-1` … `M-9` | Jump to window by number (no prefix) |
| `M-h` | Previous window (no prefix) |
| `M-l` | Next window (no prefix) |
| `M-p` / `M-n` | Previous / next window aliases (no prefix) |
| `prefix + r` | Rename current window |
| `prefix + X` | Kill current window |

### Panes

| Binding | Action |
|---------|--------|
| `prefix + \|` | Split horizontal (opens at current path) |
| `prefix + -` | Split vertical (opens at current path) |
| `M-S-h/j/k/l` | Navigate panes (Shift+Alt+hjkl, no prefix) |
| `M-Arrow` | Swap pane in direction (Alt+Arrow, no prefix) |
| `prefix + H/J/K/L` | Resize pane (Shift+hjkl, 5 cells) |
| `prefix + x` | Kill current pane |

### Copy Mode

| Binding | Action |
|---------|--------|
| `prefix + [` | Enter copy mode |
| `v` | Begin selection |
| `C-v` | Toggle rectangle selection |
| `y` | Yank selection and exit copy mode |

### Tools

| Binding | Action |
|---------|--------|
| `prefix + g` | Open lazygit in a floating popup (dismiss with `q`) |
| `prefix + e` | Reload tmux config |
