#!/usr/bin/env bash
# infra/lib/common.sh — shared helpers for archway scripts
#
# Usage in a script:
#   SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
#   SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
#   # shellcheck source=lib/common.sh
#   . "${SCRIPT_DIR}/lib/common.sh"
#
# This file provides:
# - Standard color variables (safe to source multiple times)
# - log_info / log_warn / log_error / log_fatal
# - A basic die() that honors CURRENT_PHASE when set
#
# Keep this file minimal and portable (Arch + macOS for dotfiles/bootstrap-mac).
# Scripts with rich error handling (banners, phase tracking) may still define
# their own on_error + trap after sourcing.

# Colors — only set if not already defined by caller.
# Other scripts that source this file use BLUE/BOLD.
# shellcheck disable=SC2034
if [[ -z "${RED:-}" ]]; then
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[1;33m'
	BLUE='\033[0;34m'
	BOLD='\033[1m'
	NC='\033[0m' # No Color
fi

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
log_fatal() { printf "${RED}[FATAL]${NC} %s\n" "$1" >&2; }

# Basic die. Callers that track CURRENT_PHASE get extra context.
# Richer scripts (bootstrap, fix-boot, mac) typically override on_error + trap.
die() {
	log_fatal "$1"
	if [[ -n "${CURRENT_PHASE:-}" ]]; then
		log_fatal "Phase: ${CURRENT_PHASE}"
	fi
	exit 1
}
