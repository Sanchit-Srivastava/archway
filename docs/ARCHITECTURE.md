# Architecture

archway is a configuration-as-code setup for a single Arch Linux workstation.
It is intentionally opinionated and optimized for reproducibility over flexibility.

## Scope

- Target: fresh Arch Linux install using systemd
- Audience: single-user laptop/desktop workstation
- Not a general-purpose distro installer

## Layered Model

archway uses three layers with clear ownership boundaries:

```
┌─────────────────────────────────────────────────────────────────┐
│                     DESKTOP SHELL                               │
│  DankMaterialShell (installed by its installer)                 │
│  Scope: Panel, launcher, notifications, lock screen, theming    │
│  Installs: shell, compositor, terminal, theming stack           │
├─────────────────────────────────────────────────────────────────┤
│                     USER ENVIRONMENT                            │
│  dots/* → ~/.config/*, ~/.zshrc, ~/.gitconfig, etc.             │
│  Scope: Shell, editor, CLI tools, user preferences              │
├─────────────────────────────────────────────────────────────────┤
│                     SYSTEM BASELINE                             │
│  pacman + AUR + systemd + /etc                                  │
│  Scope: Packages, services, PAM, portals, D-Bus providers       │
└─────────────────────────────────────────────────────────────────┘
```

### System Baseline

- Installs packages and enables services
- Configures PAM, portals, and system-wide settings
- Ensures D-Bus providers for desktop shell integrations

### User Environment

- Symlinks dotfiles into the home directory
- Manages shell/editor/CLI defaults

### Desktop Shell (DMS)

- Installs the compositor and shell components
- Owns its configuration and update flow
- Provides the graphical shell experience

## Idempotency

All scripts are safe to re-run. Package installs use `--needed`, services are checked before enabling,
and dotfiles use symlink-with-backup behavior.

## Package Lists

- `infra/pkgs.pacman.txt` for official packages
- `infra/pkgs.aur.txt` for AUR packages

## Services

- `infra/services.system.txt` is the source of truth for system services

## Dotfiles

- `infra/dotfiles.sh` symlinks all files from `dots/` into `~/`
- Edits should be made in `dots/` and will reflect immediately

## Secrets Management

Secrets (API keys, OAuth credentials, calendar IDs) are encrypted in the repo
using [SOPS](https://github.com/getsops/sops) with
[age](https://github.com/FiloSottile/age) encryption.

### How it works

```
secrets/opencode.env          ──decrypt──▶  ~/.config/opencode/.env
secrets/vdirsyncer.env        ──decrypt──▶  ~/.config/vdirsyncer/secrets
```

- Encrypted files live in `secrets/` — keys are visible, values are AES-256-GCM
- `dotfiles.sh` decrypts them automatically if an age key is present
- Without the key, `dotfiles.sh` falls back to creating empty templates
- Decrypted files persist on disk — no re-decryption needed between reboots

### Key management

- One age keypair per user: `~/.config/sops/age/keys.txt`
- The public key goes in `.sops.yaml` (committed to the repo)
- The private key stays on the machine (backed up in Bitwarden as a secure note)
- `dotfiles.sh` creates the empty key directory and file automatically on first run
- On a fresh machine: run `just dotfiles` (creates empty key file + templates),
  then paste the private key from Bitwarden, then `just dotfiles` again to decrypt

### Editing secrets

```bash
sops secrets/opencode.env       # decrypts → $EDITOR → re-encrypts on save
just secrets-edit opencode.env  # same thing via Justfile
```

### For users without the age key

If you fork this repo and don't have the original age key, the secrets files
are irrelevant to you. `dotfiles.sh` will create empty templates at the target
paths, and you can fill in your own values manually — the same workflow as
before SOPS was added.

### LaTeX and PDF Viewing

The LaTeX workflow uses **vimtex** in Neovim with LuaLaTeX and SyncTeX for
forward/inverse search between source and PDF.

- **PDF viewer**: zathura is the preferred viewer on **both** Linux and macOS.
  On macOS, if zathura is not installed, vimtex falls back to Skim.
- **Forward search** (source -> PDF): handled automatically by vimtex.
- **Inverse search** (PDF -> source): vimtex passes `-x` to zathura automatically.
  The `dots/zathura/zathurarc` also sets `synctex-editor-command` for standalone use.
- **macOS zathura install**: `bootstrap-mac.sh` taps `zathura-macos/zathura` and
  installs `zathura` + `zathura-pdf-mupdf` with the required plugin symlink.

## macOS Support

The primary target of archway is Arch Linux. However, the **User Environment** layer
(shell, editor, CLI tools, dotfiles) is also available on macOS so the terminal
experience is identical across both machines.

Only the User Environment layer is ported; the System Baseline and Desktop Shell
layers remain Arch-only.

macOS-specific files:

| File                          | Purpose                              |
| ----------------------------- | ------------------------------------ |
| `infra/bootstrap-mac.sh`     | Installs Homebrew, formulae, casks   |
| `infra/pkgs.brew.txt`        | Homebrew formulae (CLI tools)        |
| `infra/pkgs.brew-cask.txt`   | Homebrew casks (fonts, GUI apps)     |

Shared dotfiles use `uname` guards for platform-specific behavior (e.g., Wayland
env vars on Linux, Homebrew paths on macOS).

Usage on macOS:
```bash
just setup-mac          # bootstrap + dotfiles
# or individually:
just bootstrap-mac      # install Homebrew packages
just dotfiles           # symlink dotfiles
```
