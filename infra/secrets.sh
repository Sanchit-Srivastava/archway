#!/usr/bin/env bash
set -euo pipefail

# Securely onboard the SOPS age key and decrypt Archway secrets.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt}"
VALIDATION_FILE="${REPO_ROOT}/secrets/ssh_config.local"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--prompt|--check]

  --prompt  Prompt for the age key when no working key exists (default)
  --check   Only verify that the existing key can decrypt repository secrets
EOF
}

can_decrypt() {
	[[ -s "$AGE_KEY_FILE" ]] &&
		command -v sops >/dev/null 2>&1 &&
		SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$VALIDATION_FILE" >/dev/null 2>&1
}

write_key_atomically() {
	local key="$1"
	local key_dir
	local tmp_key
	key_dir="$(dirname "$AGE_KEY_FILE")"
	mkdir -p "$key_dir"
	chmod 700 "$key_dir"
	tmp_key="$(mktemp "${key_dir}/.keys.txt.XXXXXX")"
	chmod 600 "$tmp_key"
	printf '%s\n' "$key" >"$tmp_key"

	if ! SOPS_AGE_KEY_FILE="$tmp_key" sops --decrypt "$VALIDATION_FILE" >/dev/null 2>&1; then
		rm -f "$tmp_key"
		log_error "That key could not decrypt $VALIDATION_FILE; the existing key was not changed."
		return 1
	fi

	mv "$tmp_key" "$AGE_KEY_FILE"
	chmod 600 "$AGE_KEY_FILE"
	log_info "Installed and validated the age key at $AGE_KEY_FILE"
}

prompt_for_key() {
	if [[ ! -t 0 ]]; then
		log_warn "No interactive terminal; skipping age-key setup."
		log_warn "Run 'just secrets' later from a terminal."
		return 2
	fi

	cat <<EOF

Age key setup
-------------
1. Open Bitwarden and copy the Archway age private key.
2. Return here and paste it at the hidden prompt.
3. The key will not be echoed or passed as a command-line argument.

Press Enter without a key to skip. You can run 'just secrets' later.
EOF

	local age_key=""
	IFS= read -r -s -p "Age private key: " age_key
	printf '\n'

	if [[ -z "$age_key" ]]; then
		log_warn "Age-key setup skipped."
		return 2
	fi
	if [[ "$age_key" != AGE-SECRET-KEY-* ]]; then
		unset age_key
		log_error "Input does not look like an age private key."
		return 1
	fi

	write_key_atomically "$age_key"
	unset age_key

	if command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
		if wl-copy --clear 2>/dev/null; then
			log_info "Cleared the Wayland clipboard."
		else
			log_warn "Could not clear the clipboard; clear it manually."
		fi
	fi
}

main() {
	local mode="prompt"
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--prompt) mode="prompt" ;;
		--check) mode="check" ;;
		-h | --help)
			usage
			return 0
			;;
		*)
			log_error "Unknown option: $1"
			usage
			return 1
			;;
		esac
		shift
	done

	if ! command -v sops >/dev/null 2>&1; then
		log_error "sops is not installed. Run 'just core' first."
		return 1
	fi
	if [[ ! -f "$VALIDATION_FILE" ]]; then
		log_error "Encrypted validation file not found: $VALIDATION_FILE"
		return 1
	fi

	if can_decrypt; then
		chmod 600 "$AGE_KEY_FILE"
		log_info "Existing age key successfully decrypts Archway secrets."
	elif [[ "$mode" == "check" ]]; then
		log_error "No working age key found at $AGE_KEY_FILE"
		return 1
	else
		if [[ -s "$AGE_KEY_FILE" ]]; then
			local replace=""
			log_warn "A nonempty but unusable key already exists at $AGE_KEY_FILE"
			IFS= read -r -p "Replace it after validating a new key? [y/N] " replace
			if [[ ! "$replace" =~ ^[Yy]$ ]]; then
				log_warn "Existing key left unchanged."
				return 0
			fi
		fi
		prompt_for_key || {
			local rc=$?
			[[ "$rc" -eq 2 ]] && return 0
			return "$rc"
		}
	fi

	if can_decrypt; then
		log_info "Applying dotfiles to decrypt secret targets..."
		"${SCRIPT_DIR}/dotfiles.sh"
	fi
}

main "$@"
