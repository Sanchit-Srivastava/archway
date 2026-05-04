#!/usr/bin/env bash
set -euo pipefail

# Dotfiles installer: symlinks user dotfiles from dots/ to ~
# Safe to re-run (idempotent)

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTS_DIR="${REPO_ROOT}/dots"
SECRETS_DIR="${REPO_ROOT}/secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

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
		SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$src" >"$target"
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

# Link a dotfile or directory
# Usage: link_dotfile <source> <destination>
link_dotfile() {
	local src="$1"
	local dst="$2"

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
		log_warn "Backing up existing: $dst -> ${dst}.bak"
		mv "$dst" "${dst}.bak"
	fi

	ln -s "$src" "$dst"
	log_info "Linked: $dst -> $src"
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
#       ForwardAgent yes
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
	# OPENCODE (AI coding agent config)
	# ==========================================================================
	log_info "--- OpenCode ---"
	link_dotfile "${DOTS_DIR}/opencode/opencode.json" "${HOME}/.config/opencode/opencode.json"
	link_dotfile "${DOTS_DIR}/opencode/latex_server.py" "${HOME}/.config/opencode/latex_server.py"

	# Create API key env file — decrypted from repo if age key is available,
	# otherwise falls back to an empty template for manual population.
	local opencode_env="${HOME}/.config/opencode/.env"
	local opencode_template
	opencode_template="$(
		cat <<'TMPL'
# OpenCode MCP server API keys
# Fill in the values below, then open a new shell (or: source this file).
# This file is NOT tracked by git — keep your keys here, not in the repo.
#
# Get keys at:
#   Brave Search:      https://brave.com/search/api
#   Wolfram Alpha:     https://developer.wolframalpha.com
#   Semantic Scholar:  https://www.semanticscholar.org/product/api (optional)

export BRAVE_API_KEY=
export WOLFRAM_APP_ID=
export SEMANTIC_SCHOLAR_API_KEY=
TMPL
	)"
	decrypt_secret "${SECRETS_DIR}/opencode.env" "$opencode_env" "$opencode_template"

	# ==========================================================================
	# RESEARCH-TOOLS (Zotero RAG server credentials)
	# ==========================================================================
	log_info "--- Research-tools ---"

	# Deploy Zotero API credentials used by the research-tools RAG server.
	# Target: ~/research-tools/.env (loaded by python-dotenv at server startup)
	local rt_home="${RESEARCH_TOOLS_HOME:-${HOME}/research-tools}"
	local rt_env="${rt_home}/.env"
	local rt_template
	rt_template="$(
		cat <<'TMPL'
# research-tools RAG server credentials
# Used by ~/research-tools/server/research-rag-server.py for Zotero Web API access.
#
# Get your credentials at:
#   User ID:  https://www.zotero.org/settings/keys  (your numeric user ID)
#   API Key:  https://www.zotero.org/settings/keys  (create a new key with read access)
#
# To edit the encrypted source:  just secrets-edit research-tools.env  (in archway)

ZOTERO_USER_ID=
ZOTERO_API_KEY=
TMPL
	)"
	if [[ -d "$rt_home" ]]; then
		decrypt_secret "${SECRETS_DIR}/research-tools.env" "$rt_env" "$rt_template"
	else
		log_warn "research-tools not found at $rt_home — skipping .env deployment"
		log_warn "  Clone the repo first, then re-run: just dotfiles"
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

		# ==========================================================================
		# LOCAL BIN
		# ==========================================================================
		log_info "--- Local bin ---"
		mkdir -p "${HOME}/.local/bin"
		if [[ -f "${REPO_ROOT}/bin/archway-install" ]]; then
			chmod +x "${REPO_ROOT}/bin/archway-install"
			ln -sf "${REPO_ROOT}/bin/archway-install" "${HOME}/.local/bin/archway-install"
			log_info "Linked: ${HOME}/.local/bin/archway-install"
		else
			log_warn "archway-install wrapper not found, skipping"
		fi
	fi

	log_info ""
	log_info "=========================================="
	log_info "Dotfiles installation complete!"
	log_info "=========================================="
	log_info ""
	log_info "Notes:"
	log_info "  - Restart your shell or run: source ~/.zshrc"
	log_info "  - Oh-my-zsh and plugins will auto-install on first shell start"
	log_info "  - Edit dots/git/.gitconfig to set your name and email"
	log_info "  - Edit dots/ssh/config to add your SSH hosts"
	if can_decrypt_secrets; then
		log_info "  - Secrets decrypted from repo (SOPS + age)"
		log_info "  - Edit secrets: just secrets-edit opencode.env"
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
