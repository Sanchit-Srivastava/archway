#!/usr/bin/env bash
# infra/lib/autologin.sh — shared SDDM autologin helpers
#
# Source after common.sh:
#   # shellcheck source=lib/autologin.sh
#   . "${SCRIPT_DIR}/lib/autologin.sh"
#
# Provides:
#   detect_sddm_session()   — returns the best session name or empty
#   configure_sddm_autologin <user> <session> [conf_path]
#
# The writing logic is idempotent. Callers decide *when* and *which* user/session
# based on their policy (e.g. install.sh prompts, bootstrap tier logic + env vars).

# Detect available SDDM sessions on disk.
# Preference: niri (primary), then plasma (wayland or x11), then older plasmawayland.
detect_sddm_session() {
	if [[ -f "/usr/share/wayland-sessions/niri.desktop" ]]; then
		echo "niri"
		return 0
	fi
	# Plasma 6 wayland session lives in wayland-sessions/plasma.desktop
	# X11 fallback (and older) in xsessions/plasma.desktop
	if [[ -f "/usr/share/wayland-sessions/plasma.desktop" ]] ||
		[[ -f "/usr/share/xsessions/plasma.desktop" ]]; then
		echo "plasma"
		return 0
	fi
	if [[ -f "/usr/share/wayland-sessions/plasmawayland.desktop" ]]; then
		echo "plasmawayland"
		return 0
	fi
	echo ""
}

# Write (or update) the SDDM autologin conf for the given user+session.
# Idempotent: skips if already set exactly to this user+session.
# priv may be "sudo" (or "sudo ") to run privileged; empty for current user.
# Returns 0 on success (or no-op).
configure_sddm_autologin() {
	local autologin_user="${1:?configure_sddm_autologin requires user}"
	local autologin_session="${2:?configure_sddm_autologin requires session}"
	local autologin_conf="${3:-/etc/sddm.conf.d/autologin.conf}"
	local priv="${4:-}"

	if [[ -z "$autologin_session" ]]; then
		log_warn "No session provided for autologin"
		return 0
	fi

	if [[ -z "$autologin_user" || "$autologin_user" == "root" ]]; then
		log_warn "Cannot determine autologin user (got '$autologin_user') — skipping"
		log_warn "Create $autologin_conf manually with:"
		log_warn "  [Autologin]"
		log_warn "  User=yourusername"
		log_warn "  Session=$autologin_session"
		return 0
	fi

	# Check if already configured exactly for this user+session
	if [[ -f "$autologin_conf" ]]; then
		local current_user current_session
		current_user=$(grep -E '^User=' "$autologin_conf" 2>/dev/null | cut -d= -f2- | head -n1 || true)
		current_session=$(grep -E '^Session=' "$autologin_conf" 2>/dev/null | cut -d= -f2- | head -n1 || true)
		if [[ "$current_user" == "$autologin_user" && "$current_session" == "$autologin_session" ]]; then
			log_info "SDDM autologin already configured for $autologin_user → $autologin_session"
			return 0
		fi
		log_warn "Updating SDDM autologin (was: ${current_user:-?}/${current_session:-?})"
	fi

	log_info "Configuring SDDM autologin for user: $autologin_user"
	log_info "Session: $autologin_session"

	# mkdir with optional priv
	if [[ -n "$priv" ]]; then
		$priv mkdir -p "$(dirname "$autologin_conf")"
	else
		mkdir -p "$(dirname "$autologin_conf")" 2>/dev/null || true
	fi

	# Write using priv if provided
	if [[ -n "$priv" ]]; then
		$priv tee "$autologin_conf" >/dev/null <<EOF
# SDDM Autologin Configuration
# Managed by archway
[Autologin]
User=$autologin_user
Session=$autologin_session
EOF
	else
		cat >"$autologin_conf" <<EOF
# SDDM Autologin Configuration
# Managed by archway
[Autologin]
User=$autologin_user
Session=$autologin_session
EOF
	fi

	log_info "SDDM autologin configured"
}
