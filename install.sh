#!/usr/bin/env bash
set -euo pipefail

# Single-entry installer with staged reboot + resume flow
# (autostart is best-effort; users reliably run "install.sh resume" manually)

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# shellcheck source=infra/lib/common.sh
. "${SCRIPT_DIR}/infra/lib/common.sh"
# shellcheck source=infra/lib/autologin.sh
. "${SCRIPT_DIR}/infra/lib/autologin.sh"

# Preserve the shared implementation from the library under a different name,
# because we override configure_sddm_autologin() with a local wrapper below.
if declare -f configure_sddm_autologin >/dev/null 2>&1; then
	eval "$(declare -f configure_sddm_autologin | sed 's/configure_sddm_autologin()/_shared_configure_sddm_autologin()/')"
fi

SCRIPT_VERSION="2026-06-21-1"

STATE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/archway"
STATE_FILE="${STATE_DIR}/install.state"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart"
AUTOSTART_FILE="${AUTOSTART_DIR}/archway-resume.desktop"

DEFAULT_REPO_DIR="${HOME}/archway"
if [[ -d "${REPO_ROOT}/.git" ]]; then
	DEFAULT_REPO_DIR="${REPO_ROOT}"
fi

# Colors + log_* provided by infra/lib/common.sh
# Local die kept for install.sh style (simpler message).

die() {
	log_error "$1"
	exit 1
}

usage() {
	cat <<EOF
archway installer (v${SCRIPT_VERSION})

Usage:
  ./install.sh [options]
  ./install.sh resume [options]

NOTE: The autostart desktop entry is best-effort only. After reboot you will
usually need to run "./install.sh resume" manually from a graphical terminal.

For remote installation, use remote-install.sh:
  bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)

Options:
  --dir <path>         Repo directory (default: ${DEFAULT_REPO_DIR})
  --profile <name>     Install profile (default: full)
                         minimal - tiers 1-2 (headless: base + shell, no GUI)
                         safe    - tiers 1-3 (adds KDE Plasma fallback, no AUR/DMS)
                         full    - all tiers (adds AUR + DankMaterialShell)
  --force              Re-run completed stages
  --skip-doctor        Skip infra/doctor.sh in stage 2
  -h, --help           Show this help
EOF
}

validate_profile() {
	case "$1" in
	minimal | safe | full) return 0 ;;
	*) die "Invalid --profile: $1 (expected: minimal, safe, full)" ;;
	esac
}

# Maps a profile to the bootstrap.sh tier flag(s).
# Echoes nothing for "full" (bootstrap defaults to all tiers).
profile_bootstrap_args() {
	case "$1" in
	minimal) echo "--up-to 2" ;;
	safe) echo "--up-to 3" ;;
	full) echo "" ;;
	esac
}

profile_includes_tier() {
	# profile_includes_tier <profile> <tier-num>
	local profile="$1" tier="$2"
	case "$profile" in
	minimal) [[ "$tier" -le 2 ]] ;;
	safe) [[ "$tier" -le 3 ]] ;;
	full) return 0 ;;
	esac
}

ensure_not_root() {
	if [[ $EUID -eq 0 ]]; then
		die "Do not run install.sh as root. Run as your regular user."
	fi
}

ensure_network() {
	log_info "Checking network connectivity..."
	if ! ping -c 1 -W 5 archlinux.org >/dev/null 2>&1; then
		die "No network connectivity to archlinux.org - check your internet connection"
	fi
}

is_graphical_session() {
	if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
		return 0
	fi
	return 1
}

load_state() {
	if [[ -f "$STATE_FILE" ]]; then
		# shellcheck disable=SC1090
		source "$STATE_FILE"
	fi
}

write_state() {
	mkdir -p "$STATE_DIR"
	cat >"$STATE_FILE" <<EOF
ARCHWAY_STAGE="${ARCHWAY_STAGE}"
ARCHWAY_REPO_DIR="${ARCHWAY_REPO_DIR}"
ARCHWAY_PROFILE="${ARCHWAY_PROFILE}"
EOF
}

clear_state() {
	rm -f "$STATE_FILE"
}

prompt_yes_no() {
	local prompt="$1"
	local default="$2"
	local response

	if [[ "$default" == "y" ]]; then
		read -r -p "${prompt} [Y/n] " response
		response=${response:-y}
	else
		read -r -p "${prompt} [y/N] " response
		response=${response:-n}
	fi

	if [[ "$response" =~ ^[Yy]$ ]]; then
		return 0
	fi
	return 1
}

ensure_repo_dir() {
	local repo_dir="$1"

	if [[ ! -d "$repo_dir/.git" ]]; then
		die "Not a git repo: $repo_dir. Use remote-install.sh for fresh installs."
	fi

	log_info "Using repo at $repo_dir"
}

install_dms() {
	log_info "Starting DankMaterialShell installer..."
	# DMS is the most fragile component (curl|sh from a third-party domain).
	# Failure here must NOT brick the install: the system remains usable on
	# the Plasma fallback session installed by tier 3.
	#
	# Wrap in `timeout 600` (10 min): the upstream installer occasionally
	# hangs forever if its CDN is misbehaving, which would otherwise block
	# Stage 1 indefinitely and require a manual SIGINT.
	#
	# `--foreground` is REQUIRED: install-dms.sh is interactive (`read -p`)
	# and the upstream curl|sh may also prompt. Without --foreground,
	# `timeout` puts the child in a new process group that is NOT the
	# terminal's foreground group, so the child is stopped with SIGTTIN
	# the moment it touches the TTY (symptom: typing y<enter> does nothing,
	# Ctrl+C is ignored). --foreground also makes SIGINT from the terminal
	# propagate to the child as expected.
	local rc=0
	timeout --foreground 600 "$ARCHWAY_REPO_DIR/install-dms.sh" || rc=$?
	if [[ $rc -ne 0 ]]; then
		if [[ $rc -eq 124 ]]; then
			log_warn "DMS installer exceeded 10-minute timeout — aborted."
		else
			log_warn "DMS install failed (exit code: $rc)."
		fi
		log_warn "System remains usable; log in to KDE Plasma at SDDM."
		log_warn "Retry later with: $ARCHWAY_REPO_DIR/install-dms.sh"
		return 0
	fi
}

maybe_auth_github() {
	if ! command -v gh >/dev/null 2>&1; then
		log_warn "GitHub CLI (gh) not found - skipping auth"
		return 0
	fi

	if prompt_yes_no "Authenticate GitHub now?" "y"; then
		log_info "Launching gh auth login (HTTPS)..."
		gh auth login --hostname github.com --git-protocol https

		if prompt_yes_no "Configure git to use HTTPS now?" "y"; then
			gh auth setup-git
		fi

		log_info "Reminder: After enabling Bitwarden SSH agent, run:"
		log_info "  gh config set git_protocol ssh"
	fi
}

# detect_sddm_session and configure_sddm_autologin now come from lib/autologin.sh
# The local wrapper below keeps install.sh-specific sudo prompting + user policy.

configure_sddm_autologin() {
	local autologin_conf="/etc/sddm.conf.d/autologin.conf"
	local autologin_user="$USER"
	local autologin_session
	autologin_session="$(detect_sddm_session)"

	if [[ -z "$autologin_session" ]]; then
		log_warn "No known SDDM session found (niri/plasma). Skipping autologin config."
		return 0
	fi

	log_info "Configuring SDDM autologin for ${autologin_user} (${autologin_session})"
	if ! sudo -n true 2>/dev/null; then
		log_info "Sudo password required"
		sudo -v
	fi

	# Delegate write + idempotency to shared helper (with "sudo" priv)
	_shared_configure_sddm_autologin "$autologin_user" "$autologin_session" "$autologin_conf" "sudo"
}

write_autostart_resume() {
	mkdir -p "$AUTOSTART_DIR"
	cat >"$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Archway Resume
Comment=Resume archway installer after reboot (best-effort; you will likely need to run install.sh resume manually)
Exec=bash -lc "${ARCHWAY_REPO_DIR}/install.sh resume"
Terminal=true
X-GNOME-Autostart-enabled=true
EOF
}

remove_autostart_resume() {
	rm -f "$AUTOSTART_FILE"
}

stage1() {
	if [[ "${ARCHWAY_STAGE:-}" == "stage2" && "$FORCE" == "0" ]]; then
		log_info "Stage 1 already completed. Use --force to re-run (or just run 'install.sh resume' after reboot)."
		return 0
	fi

	log_info "Starting Stage 1 (TTY)"
	log_info "Profile: ${ARCHWAY_PROFILE}"
	ensure_repo_dir "$ARCHWAY_REPO_DIR"

	log_info "Running bootstrap..."
	# shellcheck disable=SC2046
	# Word-splitting of profile_bootstrap_args output is intentional.
	ARCHWAY_SKIP_SDDM_AUTOLOGIN=1 "$ARCHWAY_REPO_DIR/infra/bootstrap.sh" \
		$(profile_bootstrap_args "$ARCHWAY_PROFILE")

	log_info "Running dotfiles..."
	"$ARCHWAY_REPO_DIR/infra/dotfiles.sh"

	if profile_includes_tier "$ARCHWAY_PROFILE" 4; then
		install_dms
	else
		log_info "Skipping DMS install (profile: ${ARCHWAY_PROFILE}, tier 4 disabled)"
	fi

	maybe_auth_github

	if profile_includes_tier "$ARCHWAY_PROFILE" 3; then
		if prompt_yes_no "Enable SDDM autologin into niri?" "y"; then
			configure_sddm_autologin
		else
			log_warn "Skipping SDDM autologin configuration"
		fi
	else
		log_info "Skipping SDDM autologin (profile: ${ARCHWAY_PROFILE}, no graphical tier)"
	fi

	ARCHWAY_STAGE="stage2"
	write_state
	write_autostart_resume

	log_info "Stage 1 complete."
	log_warn "==========================================================================="
	log_warn "REBOOT NOW, then run this command to continue:"
	log_warn "  ${ARCHWAY_REPO_DIR}/install.sh resume"
	log_warn "Autostart resume is best-effort and often does not trigger (known)."
	log_warn "Always run the resume command manually after reboot."
	log_warn "==========================================================================="
	if prompt_yes_no "Reboot now?" "y"; then
		sudo reboot
	else
		log_info "Reboot when ready. Then run: ${ARCHWAY_REPO_DIR}/install.sh resume"
	fi
}

post_install_guidance() {
	log_info "Post-install SSH guidance:"
	log_info "  1. Enable Bitwarden SSH agent in the Bitwarden Desktop app"
	log_info "  2. Open a new terminal"
	log_info "  3. ssh -T git@github.com"
	log_info "  4. gh config set git_protocol ssh"
}

stage2() {
	if [[ "${ARCHWAY_STAGE:-}" != "stage2" && "$FORCE" == "0" ]]; then
		log_info "Stage 2 not ready yet. Run Stage 1 first."
		return 0
	fi

	# Stage 2's graphical bits only apply to profiles that install a desktop.
	# For minimal (T1+T2 headless), skip session check and post-DMS hooks.
	if profile_includes_tier "$ARCHWAY_PROFILE" 3; then
		if ! is_graphical_session; then
			log_warn "Stage 2 expects a graphical session (after login to DMS or Plasma)."
			log_warn "From a graphical terminal run: ${ARCHWAY_REPO_DIR}/install.sh resume"
			log_warn "If you just rebooted, make sure you are logged into a graphical session."
			return 1
		fi

		log_info "Starting Stage 2 (Graphical)"
		if profile_includes_tier "$ARCHWAY_PROFILE" 4; then
			"$ARCHWAY_REPO_DIR/infra/post-dms-install.sh"
		else
			log_info "Skipping post-DMS hooks (profile: ${ARCHWAY_PROFILE}, tier 4 disabled)"
		fi
	else
		log_info "Starting Stage 2 (headless profile: ${ARCHWAY_PROFILE})"
	fi

	if [[ "$SKIP_DOCTOR" == "0" ]]; then
		# doctor.sh validates runtime/config/boot state for the whole system
		# (it no longer takes tier flags — those were removed in the
		# simplification; package presence is covered by --audit-packages).
		"$ARCHWAY_REPO_DIR/infra/doctor.sh"
	else
		log_info "Skipping infra/doctor.sh"
	fi

	remove_autostart_resume
	clear_state
	post_install_guidance

	log_info "Stage 2 complete."
}

main() {
	ensure_not_root
	ensure_network

	load_state

	local mode="run"
	if [[ "${1:-}" == "resume" ]]; then
		mode="resume"
		shift
	fi

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dir)
			ARCHWAY_REPO_DIR="$2"
			shift 2
			;;
		--profile)
			validate_profile "$2"
			ARCHWAY_PROFILE="$2"
			shift 2
			;;
		--force)
			FORCE="1"
			shift
			;;
		--skip-doctor)
			SKIP_DOCTOR="1"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			usage
			exit 1
			;;
		esac
	done

	ARCHWAY_REPO_DIR="${ARCHWAY_REPO_DIR:-$DEFAULT_REPO_DIR}"
	ARCHWAY_PROFILE="${ARCHWAY_PROFILE:-full}"
	validate_profile "$ARCHWAY_PROFILE"
	FORCE="${FORCE:-0}"
	SKIP_DOCTOR="${SKIP_DOCTOR:-0}"

	# Ensure stdin is a terminal for interactive prompts.
	# If not (e.g. piped from curl), reconnect from /dev/tty.
	if [[ ! -t 0 ]]; then
		if [[ -c /dev/tty ]]; then
			log_warn "stdin is not a terminal - redirecting from /dev/tty"
			exec </dev/tty
		else
			die "stdin is not a terminal and /dev/tty is unavailable. Cannot run interactively."
		fi
	fi

	if [[ "$mode" == "resume" ]]; then
		stage2
		return 0
	fi

	if [[ "${ARCHWAY_STAGE:-}" == "stage2" ]]; then
		log_info "Stage 1 completed previously (state file present). Running Stage 2."
		stage2
	else
		log_info "Running Stage 1."
		stage1
	fi
}

main "$@"
