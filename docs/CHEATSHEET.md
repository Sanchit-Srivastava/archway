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

`SESSIONIZER_DIRS` (colon-separated) controls which directories `x` searches.
Default: `~/projects:~/work`. Override in `~/.zshrc.local` or `~/.zshenv`.

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

| Alias | Description |
|-------|-------------|
| `archway-sync` | Pull and re-run bootstrap + dotfiles (+ doctor on Arch) |
| `archway-doctor` | Run system health checks (Arch only) |
| `archway-audit` | Audit installed packages against repo lists (Arch only) |

---

## Tmux Keybindings

Prefix: `C-Space`

### Sessions

| Binding | Action |
|---------|--------|
| `prefix + f` | Sessionizer — fzf project picker, create or attach |
| `prefix + P` | Switch to previous session |
| `prefix + N` | Switch to next session |
| `M-Up` | Switch to previous session (no prefix) |
| `M-Down` | Switch to next session (no prefix) |
| `prefix + R` | Rename current session |
| `prefix + K` | Kill current session |

### Windows

| Binding | Action |
|---------|--------|
| `prefix + c` | New window (opens at current path) |
| `M-1` … `M-9` | Jump to window by number (no prefix) |
| `M-Left` | Previous window (no prefix) |
| `M-Right` | Next window (no prefix) |
| `M-S-Left` | Move window left (no prefix) |
| `M-S-Right` | Move window right (no prefix) |
| `prefix + r` | Rename current window |
| `prefix + X` | Kill current window |

### Panes

| Binding | Action |
|---------|--------|
| `prefix + \|` | Split horizontal (opens at current path) |
| `prefix + -` | Split vertical (opens at current path) |
| `prefix + h/j/k/l` | Navigate panes (vim-style) |
| `M-h/j/k/l` | Navigate panes without prefix |
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
