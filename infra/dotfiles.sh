#!/usr/bin/env bash
set -euo pipefail

# Dotfiles installer: symlinks user dotfiles from dots/ to ~
# Safe to re-run (idempotent)

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTS_DIR="${REPO_ROOT}/dots"
SECRETS_DIR="${REPO_ROOT}/secrets"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

# log_* + colors from lib/common.sh (macOS compatible)

# ── SOPS + age secrets support ───────────────────────────────────────────────
# Check once whether we can decrypt secrets from the repo.
# Returns 0 (true) if sops is installed AND an age key file exists and is non-empty.
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt}"
can_decrypt_secrets() {
	command -v sops &>/dev/null && [[ -s "$AGE_KEY_FILE" ]]
}

# Ensure the age key directory and file exist so the user only needs to
# paste the key content (from Bitwarden secure note) on a fresh machine.
ensure_age_key_path() {
	local age_dir
	age_dir="$(dirname "$AGE_KEY_FILE")"
	if [[ ! -d "$age_dir" ]]; then
		mkdir -p "$age_dir"
		chmod 700 "$age_dir"
		log_info "Created age key directory: $age_dir"
	fi
	if [[ ! -f "$AGE_KEY_FILE" ]]; then
		touch "$AGE_KEY_FILE"
		chmod 600 "$AGE_KEY_FILE"
		log_warn "Created empty age key file: $AGE_KEY_FILE"
		log_warn "  Paste your age private key (AGE-SECRET-KEY-...) into this file"
		log_warn "  then re-run: just dotfiles"
	fi
}

# Decrypt a SOPS-encrypted file to a target path.
# Falls back to creating an empty template if decryption is unavailable.
# Usage: decrypt_secret <encrypted_src> <target> <template_content>
decrypt_secret() {
	local src="$1" target="$2" template="$3"

	mkdir -p "$(dirname "$target")"

	if can_decrypt_secrets && [[ -f "$src" ]]; then
		local tmp_target
		tmp_target="$(mktemp "$(dirname "$target")/.archway-secret.XXXXXX")"
		chmod 600 "$tmp_target"
		if ! SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$src" >"$tmp_target"; then
			rm -f "$tmp_target"
			log_error "Failed to decrypt $src; existing $target was not changed"
			return 1
		fi
		mv "$tmp_target" "$target"
		chmod 600 "$target"
		log_info "Decrypted: $target"
	elif [[ -f "$target" ]]; then
		log_info "Secrets file already exists: $target"
	else
		printf '%s\n' "$template" >"$target"
		chmod 600 "$target"
		log_warn "No age key found — created empty template: $target"
		log_warn "  To use SOPS decryption: place your age key at $AGE_KEY_FILE"
		log_warn "  Or fill in the values manually."
	fi
}

# Install the public key used for SSH between Archway-managed machines.
#
# The committed public key serves two purposes:
#   1. ~/.ssh/archway-access.pub selects the matching key from the SSH agent.
#   2. ~/.ssh/authorized_keys permits that key to log into this account.
#
# Existing authorized_keys entries are preserved. Match on key type + key data
# so changing a key's trailing comment does not append a duplicate.
install_ssh_access_key() {
	local src="${DOTS_DIR}/ssh/archway-access.pub"
	local selector="${HOME}/.ssh/archway-access.pub"
	local authorized_keys="${HOME}/.ssh/authorized_keys"
	local key_type
	local key_data

	if [[ ! -f "$src" ]]; then
		log_warn "No Archway SSH access key found: $src"
		log_warn "  See dots/ssh/README.md to enable SSH access deployment."
		return 0
	fi

	if [[ "$(awk 'NF { count++ } END { print count + 0 }' "$src")" -ne 1 ]]; then
		log_error "SSH access key file must contain exactly one public key: $src"
		return 1
	fi

	key_type="$(awk 'NF { print $1 }' "$src")"
	key_data="$(awk 'NF { print $2 }' "$src")"
	case "$key_type" in
	ssh-ed25519 | ssh-rsa | ecdsa-sha2-* | sk-ssh-ed25519@openssh.com | sk-ecdsa-sha2-*@openssh.com) ;;
	*)
		log_error "SSH access key is not an OpenSSH public key: $src"
		return 1
		;;
	esac

	if ! ssh-keygen -l -f "$src" >/dev/null 2>&1; then
		log_error "Invalid SSH public key: $src"
		return 1
	fi

	if [[ -z "$key_type" || -z "$key_data" ]]; then
		log_error "SSH public key must contain one OpenSSH public key: $src"
		return 1
	fi

	install -m 644 "$src" "$selector"
	log_info "Installed SSH identity selector: $selector"

	touch "$authorized_keys"
	chmod 600 "$authorized_keys"
	if awk -v key_type="$key_type" -v key_data="$key_data" \
		'$1 == key_type && $2 == key_data { found = 1 } END { exit !found }' \
		"$authorized_keys"; then
		log_info "SSH access key already authorized"
	else
		printf '%s\n' "$(cat "$src")" >>"$authorized_keys"
		log_info "Added Archway SSH access key to: $authorized_keys"
	fi
}

# Link a dotfile or directory
# Usage: link_dotfile <source> <destination>
link_dotfile() {
	local src="$1"
	local dst="$2"
	local backup

	# Ensure parent directory exists
	mkdir -p "$(dirname "$dst")"

	if [[ -L "$dst" ]]; then
		local current_target
		current_target="$(readlink "$dst")"
		if [[ "$current_target" == "$src" ]]; then
			log_info "Already linked: $dst"
			return 0
		fi
		log_warn "Removing old symlink: $dst -> $current_target"
		rm "$dst"
	elif [[ -e "$dst" ]]; then
		backup="${dst}.pre-archway.bak"
		if [[ -e "$backup" || -L "$backup" ]]; then
			backup="${backup}.$(date -u +%Y%m%dT%H%M%SZ)"
		fi
		log_warn "Backing up existing: $dst -> $backup"
		mv "$dst" "$backup"
	fi

	ln -s "$src" "$dst"
	log_info "Linked: $dst -> $src"
}

# Clone a git repo idempotently. Skip if the target dir already exists and
# looks like a valid clone (has .git). On failure (no network, git missing,
# etc.) returns non-zero so the caller can decide whether to abort.
# Usage: clone_if_missing <repo_url> <target_dir>
clone_if_missing() {
	local url="$1"
	local target="$2"

	if [[ -d "${target}/.git" ]]; then
		log_info "Already cloned: $target"
		return 0
	fi
	if [[ -e "$target" && ! -d "${target}/.git" ]]; then
		log_warn "Path exists but is not a git clone: $target — backing up"
		mv "$target" "${target}.bak.$(date +%s)"
	fi

	log_info "Cloning $url -> $target"
	if ! git clone --depth=1 "$url" "$target"; then
		log_error "Failed to clone $url"
		return 1
	fi
}

# Install oh-my-zsh + the plugins referenced by dots/zsh/.zshrc.
# Runs synchronously during `just dotfiles` (NOT lazily at shell startup) so
# that a fresh login terminal never lands in a half-broken state if the very
# first `zsh` invocation happens before networking is up or git is installed.
install_oh_my_zsh() {
	log_info "--- Oh-my-zsh + plugins ---"

	if ! command -v git >/dev/null 2>&1; then
		log_error "git is not installed — cannot bootstrap oh-my-zsh"
		log_error "Run 'just core' first, then re-run dotfiles"
		return 1
	fi

	local omz="${HOME}/.oh-my-zsh"
	local custom="${omz}/custom"

	clone_if_missing "https://github.com/ohmyzsh/ohmyzsh.git" "$omz" || return 1
	clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions" \
		"${custom}/plugins/zsh-autosuggestions" || return 1
	clone_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting" \
		"${custom}/plugins/zsh-syntax-highlighting" || return 1
	clone_if_missing "https://github.com/Aloxaf/fzf-tab" \
		"${custom}/plugins/fzf-tab" || return 1
}

# Main dotfile linking
main() {
	log_info "Installing dotfiles from ${DOTS_DIR}"
	log_info ""

	# Verify dots directory exists
	if [[ ! -d "$DOTS_DIR" ]]; then
		log_error "Dots directory not found: $DOTS_DIR"
		exit 1
	fi

	# Ensure the age key path exists for SOPS secrets decryption
	ensure_age_key_path

	# ==========================================================================
	# ZSH
	# ==========================================================================
	log_info "--- Zsh ---"
	# Bootstrap oh-my-zsh + plugins synchronously BEFORE linking .zshrc so the
	# first interactive shell always finds $ZSH/oh-my-zsh.sh present. Doing it
	# lazily in .zshrc (the old approach) failed silently on fresh installs
	# whenever network or git wasn't ready yet, leaving the user with a
	# broken shell ("no such file or directory: ~/.oh-my-zsh/oh-my-zsh.sh").
	install_oh_my_zsh

	link_dotfile "${DOTS_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
	link_dotfile "${DOTS_DIR}/zsh/.zshenv" "${HOME}/.zshenv"

	# ==========================================================================
	# STARSHIP
	# ==========================================================================
	log_info "--- Starship ---"
	link_dotfile "${DOTS_DIR}/starship/starship.toml" "${HOME}/.config/starship.toml"

	# ==========================================================================
	# TMUX
	# ==========================================================================
	log_info "--- Tmux ---"
	mkdir -p "${HOME}/.config/tmux"
	link_dotfile "${DOTS_DIR}/tmux/tmux.conf" "${HOME}/.config/tmux/tmux.conf"

	# ==========================================================================
	# NEOVIM
	# ==========================================================================
	log_info "--- Neovim ---"
	link_dotfile "${DOTS_DIR}/nvim" "${HOME}/.config/nvim"

	# ==========================================================================
	# GIT
	# ==========================================================================
	log_info "--- Git ---"
	link_dotfile "${DOTS_DIR}/git/.gitconfig" "${HOME}/.gitconfig"

	# Allowed signers file for SSH commit signature verification.
	# The signing key itself is supplied by the Bitwarden SSH agent (the
	# `key::ssh-ed25519 …` literal in .gitconfig); this file only enables
	# `git log --show-signature` to mark commits as "Good signature" locally.
	# The pubkey here must match the `user.signingkey` literal in .gitconfig
	# AND be registered as a Signing Key on the GitHub profile.
	mkdir -p "${HOME}/.config/git"
	local allowed_signers="${HOME}/.config/git/allowed_signers"
	local signer_line='sanchit.srivastava@uwaterloo.ca ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKm12jvyioTIcvXipYjl+s5tB6Xm/sVilqgJan5/4FMV github_axiom'
	if [[ ! -f "$allowed_signers" ]] || ! grep -qF "$signer_line" "$allowed_signers" 2>/dev/null; then
		printf '%s\n' "$signer_line" >"$allowed_signers"
		chmod 600 "$allowed_signers"
		log_info "Wrote git allowed_signers: $allowed_signers"
	else
		log_info "Git allowed_signers already up to date"
	fi

	# ==========================================================================
	# LAZYGIT
	# ==========================================================================
	log_info "--- Lazygit ---"
	mkdir -p "${HOME}/.config/lazygit"
	link_dotfile "${DOTS_DIR}/lazygit/config.yml" "${HOME}/.config/lazygit/config.yml"

	# ==========================================================================
	# SSH
	# ==========================================================================
	log_info "--- SSH ---"
	mkdir -p "${HOME}/.ssh/sockets"
	chmod 700 "${HOME}/.ssh"
	link_dotfile "${DOTS_DIR}/ssh/config" "${HOME}/.ssh/config"
	chmod 600 "${HOME}/.ssh/config" 2>/dev/null || true
	install_ssh_access_key

	# Decrypt machine-specific SSH host entries (config.local)
	# The main config already includes config.local via: Include config.local
	local ssh_config_local="${HOME}/.ssh/config.local"
	local ssh_config_local_template
	ssh_config_local_template="$(
		cat <<'TMPL'
# Machine-specific SSH host entries (decrypted from secrets/ssh_config.local)
# This file is included by ~/.ssh/config via: Include config.local
#
# Add your private hostnames, ForwardAgent, ProxyJump, etc. here.
# To edit the encrypted source:  just secrets-edit ssh_config.local
#
# Example:
#   Host my-server
#       HostName 192.168.1.100
#       User admin
#       IdentitiesOnly yes
#       IdentityFile ~/.ssh/archway-access.pub
TMPL
	)"
	decrypt_secret "${SECRETS_DIR}/ssh_config.local" "$ssh_config_local" "$ssh_config_local_template"

	# ==========================================================================
	# FUZZEL (Wayland launcher/dmenu)
	# ==========================================================================
	log_info "--- Fuzzel ---"
	mkdir -p "${HOME}/.config/fuzzel"
	link_dotfile "${DOTS_DIR}/fuzzel/fuzzel.ini" "${HOME}/.config/fuzzel/fuzzel.ini"

	# ==========================================================================
	# ZATHURA (PDF viewer with SyncTeX support)
	# ==========================================================================
	log_info "--- Zathura ---"
	mkdir -p "${HOME}/.config/zathura"
	link_dotfile "${DOTS_DIR}/zathura/zathurarc" "${HOME}/.config/zathura/zathurarc"

	# ==========================================================================
	# FASTFETCH
	# ==========================================================================
	log_info "--- Fastfetch ---"
	link_dotfile "${DOTS_DIR}/fastfetch/config.jsonc" "${HOME}/.config/fastfetch/config.jsonc"

	# ==========================================================================
	# BAT (theme config)
	# ==========================================================================
	log_info "--- Bat ---"
	mkdir -p "${HOME}/.config/bat"
	if [[ ! -f "${HOME}/.config/bat/config" ]]; then
		cat >"${HOME}/.config/bat/config" <<'EOF'
--theme="TwoDark"
--pager="less -FR"
EOF
		log_info "Created bat config"
	else
		log_info "Bat config already exists"
	fi

	# ==========================================================================
	# GITHUB CLI
	# ==========================================================================
	log_info "--- GitHub CLI ---"
	mkdir -p "${HOME}/.config/gh"
	if [[ ! -f "${HOME}/.config/gh/config.yml" ]]; then
		cat >"${HOME}/.config/gh/config.yml" <<'EOF'
git_protocol: ssh
editor: nvim
EOF
		log_info "Created gh config"
	else
		log_info "GitHub CLI config already exists"
	fi

	# ==========================================================================
	# VALE (prose linter config)
	# ==========================================================================
	log_info "--- Vale ---"
	link_dotfile "${DOTS_DIR}/vale/.vale.ini" "${HOME}/.vale.ini"

	# ==========================================================================
	# ZEN BROWSER (startpage + config files for manual import)
	# ==========================================================================
	log_info "--- Zen Browser ---"

	# Startpage: symlink to a stable path for the homepage URL
	link_dotfile "${DOTS_DIR}/startpage" "${HOME}/.config/zen/startpage"

	# Zen Mods export: placed where the user can find it for manual import
	if [[ -f "${DOTS_DIR}/zen/zen-mods.json" ]]; then
		link_dotfile "${DOTS_DIR}/zen/zen-mods.json" "${HOME}/.config/zen/zen-mods.json"
	fi

	# ==========================================================================
	# USER SCRIPTS (~/bin)
	# ==========================================================================
	log_info "--- User scripts ---"
	mkdir -p "${HOME}/bin"
	for script in "${DOTS_DIR}"/bin/*; do
		[[ -f "$script" ]] || continue
		chmod +x "$script"
		script_name="$(basename "$script")"
		link_dotfile "$script" "${HOME}/bin/${script_name}"
	done

	# zk-index lives in the notes repo (.githooks/zk-index) as the single
	# source of truth. Symlink it to ~/bin so it is available on $PATH for
	# standalone use (e.g., quick-note, manual invocation).
	local notes_zk_index="${HOME}/notes/.githooks/zk-index"
	if [[ -f "$notes_zk_index" ]]; then
		link_dotfile "$notes_zk_index" "${HOME}/bin/zk-index"
	else
		log_warn "zk-index not found at $notes_zk_index — clone ~/notes first, then re-run"
	fi

	# ==========================================================================
	# LINUX-ONLY SECTIONS
	# ==========================================================================
	if [[ "$(uname)" != "Darwin" ]]; then
		# Remove Archway's retired KWallet mask. KDE owns its credential service,
		# and disabling it globally can break the otherwise-stable Plasma
		# fallback. Never remove a user-owned file at this path.
		local retired_kwallet_mask="${HOME}/.config/autostart/kwalletd6.desktop"
		if [[ -L "$retired_kwallet_mask" ]] &&
			[[ "$(readlink "$retired_kwallet_mask")" == "${DOTS_DIR}/autostart/kwalletd6.desktop" ]]; then
			rm "$retired_kwallet_mask"
			log_info "Removed retired Archway KWallet autostart mask."
		fi

		# ==========================================================================
		# ENVIRONMENT.D (systemd user session environment)
		# ==========================================================================
		log_info "--- Environment.d ---"
		mkdir -p "${HOME}/.config/environment.d"
		link_dotfile "${DOTS_DIR}/environment.d/50-archway.conf" "${HOME}/.config/environment.d/50-archway.conf"

		# ==========================================================================
		# VDIRSYNCER (CalDAV/CardDAV sync — Google Calendar)
		# ==========================================================================
		log_info "--- Vdirsyncer ---"

		# Decrypt or create secrets file (OAuth credentials + calendar IDs)
		local vdirsyncer_secrets="${HOME}/.config/vdirsyncer/secrets"
		local vdirsyncer_template
		vdirsyncer_template="$(
			cat <<'TMPL'
# vdirsyncer Google OAuth2 credentials & calendar list
# Fill in the values below after creating a Google Cloud project:
#   1. Go to https://console.developers.google.com
#   2. Create a project, enable the "CalDAV API"
#   3. Create OAuth 2.0 credentials (Desktop application type)
#   4. Paste client_id and client_secret here
#   5. List the calendar IDs you want to sync in COLLECTIONS
#
# Then run:  vdirsyncer discover google_calendar
#            vdirsyncer sync

VDIRSYNCER_GOOGLE_CLIENT_ID=
VDIRSYNCER_GOOGLE_CLIENT_SECRET=

# Comma-separated list of Google Calendar IDs to sync.
# Run `vdirsyncer discover google_calendar` first, then pick from the
# discovered calendars.  Example:
#   VDIRSYNCER_GOOGLE_COLLECTIONS=user@gmail.com,work@group.calendar.google.com
VDIRSYNCER_GOOGLE_COLLECTIONS=

# Default calendar for khal (used when adding new events).
# Must match one of the calendar names from `khal printcalendars`.  Example:
#   KHAL_DEFAULT_CALENDAR=user@gmail.com
KHAL_DEFAULT_CALENDAR=
TMPL
		)"
		decrypt_secret "${SECRETS_DIR}/vdirsyncer.env" "$vdirsyncer_secrets" "$vdirsyncer_template"

		# Render vdirsyncer config from template + secrets
		# (The template contains @@COLLECTIONS@@ which is replaced with the
		# calendar list from the secrets file.)
		mkdir -p "${HOME}/.config/vdirsyncer"
		local vdirsyncer_conf="${HOME}/.config/vdirsyncer/config"
		# shellcheck source=/dev/null
		source "$vdirsyncer_secrets"
		# Remove stale symlink so we don't write through it into the repo template
		if [[ -L "$vdirsyncer_conf" ]]; then
			rm "$vdirsyncer_conf"
			log_info "Removed stale symlink at $vdirsyncer_conf"
		fi
		if [[ -z "${VDIRSYNCER_GOOGLE_COLLECTIONS:-}" ]]; then
			log_warn "VDIRSYNCER_GOOGLE_COLLECTIONS is empty in $vdirsyncer_secrets"
			log_warn "Skipping vdirsyncer config render — fill in calendar IDs first"
		else
			# Convert comma-separated IDs to Python list:
			#   a@b.com,c@d.com  →  ["a@b.com", "c@d.com"]
			local py_list
			py_list=$(printf '%s' "$VDIRSYNCER_GOOGLE_COLLECTIONS" |
				tr ',' '\n' |
				sed 's/^[[:space:]]*//;s/[[:space:]]*$//' |
				sed 's/.*/"&"/' |
				paste -sd ',' - |
				sed 's/^/[/;s/$/]/')
			sed "s|@@COLLECTIONS@@|${py_list}|" \
				"${DOTS_DIR}/vdirsyncer/config" >"$vdirsyncer_conf"
			chmod 600 "$vdirsyncer_conf"
			log_info "Rendered vdirsyncer config with $(echo "$VDIRSYNCER_GOOGLE_COLLECTIONS" | tr ',' '\n' | wc -l) calendar(s)"
		fi

		# ==========================================================================
		# KHAL (terminal calendar UI)
		# ==========================================================================
		log_info "--- Khal ---"
		mkdir -p "${HOME}/.config/khal"
		local khal_conf="${HOME}/.config/khal/config"
		# Remove stale symlink so we don't write through it into the repo template
		if [[ -L "$khal_conf" ]]; then
			rm "$khal_conf"
			log_info "Removed stale symlink at $khal_conf"
		fi
		if [[ -z "${KHAL_DEFAULT_CALENDAR:-}" ]]; then
			log_warn "KHAL_DEFAULT_CALENDAR is empty in $vdirsyncer_secrets"
			log_warn "Rendering khal config without a default calendar"
			sed '/@@DEFAULT_CALENDAR@@/d' \
				"${DOTS_DIR}/khal/config" >"$khal_conf"
		else
			sed "s|@@DEFAULT_CALENDAR@@|${KHAL_DEFAULT_CALENDAR}|" \
				"${DOTS_DIR}/khal/config" >"$khal_conf"
			log_info "Rendered khal config with default calendar: $KHAL_DEFAULT_CALENDAR"
		fi

		# ==========================================================================
		# SYSTEMD USER UNITS
		# ==========================================================================
		log_info "--- Systemd user units ---"
		mkdir -p "${HOME}/.config/systemd/user"
		for unit in "${DOTS_DIR}"/systemd-user/*; do
			[[ -f "$unit" ]] || continue
			unit_name="$(basename "$unit")"
			link_dotfile "$unit" "${HOME}/.config/systemd/user/${unit_name}"
		done

	fi

	log_info ""
	log_info "=========================================="
	log_info "Dotfiles installation complete!"
	log_info "=========================================="
	log_info ""
	log_info "Notes:"
	log_info "  - Restart your shell or run: source ~/.zshrc"
	log_info "  - Oh-my-zsh + plugins installed by dotfiles (see install_oh_my_zsh)"
	log_info "  - Edit dots/git/.gitconfig to set your name and email"
	log_info "  - Edit dots/ssh/config to add your SSH hosts"
	if can_decrypt_secrets; then
		log_info "  - Available secrets decrypted from repo (SOPS + age)"
	else
		log_info "  - Secrets not decrypted (no age key found)"
		log_info "    Paste your age private key into: $AGE_KEY_FILE"
		log_info "    Then re-run: just dotfiles"
	fi
	if [[ -n "${VDIRSYNCER_GOOGLE_COLLECTIONS:-}" ]]; then
		log_info "  - Calendar: run vdirsyncer discover google_calendar && vdirsyncer sync"
		log_info "      systemctl --user enable --now vdirsyncer.timer"
	fi
	log_info "  - Zen Browser manual steps after first launch:"
	log_info "      1. Sign into Mozilla Sync (syncs extensions, bookmarks, prefs)"
	log_info "      2. Set homepage to: file://${HOME}/.config/zen/startpage/index.html"
	log_info "      3. Import Zen Mods from: ~/.config/zen/zen-mods.json"
}

main "$@"
