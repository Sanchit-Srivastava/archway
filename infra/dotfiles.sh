#!/usr/bin/env bash
set -euo pipefail

# Dotfiles installer: symlinks user dotfiles from dots/ to ~
# Safe to re-run (idempotent)

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTS_DIR="${REPO_ROOT}/dots"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

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

	# Create API key env file template if it doesn't exist yet.
	# The file is never committed (listed in .gitignore) — this just ensures
	# a fresh install has a ready-to-fill template rather than silently missing keys.
	local opencode_env="${HOME}/.config/opencode/.env"
	if [[ ! -f "$opencode_env" ]]; then
		cat >"$opencode_env" <<'EOF'
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
EOF
		chmod 600 "$opencode_env"
		log_info "Created API key template: $opencode_env"
		log_warn "ACTION REQUIRED: Fill in API keys in $opencode_env"
	else
		log_info "OpenCode env file already exists: $opencode_env"
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

		# Create secrets file template (never committed — holds OAuth credentials
		# and personal calendar IDs)
		local vdirsyncer_secrets="${HOME}/.config/vdirsyncer/secrets"
		if [[ ! -f "$vdirsyncer_secrets" ]]; then
			cat >"$vdirsyncer_secrets" <<'EOF'
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
EOF
			chmod 600 "$vdirsyncer_secrets"
			log_info "Created vdirsyncer secrets template: $vdirsyncer_secrets"
			log_warn "ACTION REQUIRED: Fill in Google OAuth credentials in $vdirsyncer_secrets"
		else
			log_info "Vdirsyncer secrets file already exists: $vdirsyncer_secrets"
		fi

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
	log_info "  - Fill in API keys: ~/.config/opencode/.env"
	log_info "  - Calendar setup: fill in ~/.config/vdirsyncer/secrets, then run:"
	log_info "      vdirsyncer discover google_calendar && vdirsyncer sync"
	log_info "      systemctl --user enable --now vdirsyncer.timer"
	log_info "  - Zen Browser manual steps after first launch:"
	log_info "      1. Sign into Mozilla Sync (syncs extensions, bookmarks, prefs)"
	log_info "      2. Set homepage to: file://${HOME}/.config/zen/startpage/index.html"
	log_info "      3. Import Zen Mods from: ~/.config/zen/zen-mods.json"
}

main "$@"
