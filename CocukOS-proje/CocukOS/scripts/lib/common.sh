#!/usr/bin/env bash
# =============================================================================
# CocukOS - ortak yardımcı fonksiyonlar / common helper functions
# Bu dosya diğer scriptler tarafından "source" edilir, doğrudan çalıştırılmaz.
# This file is sourced by other scripts, not executed directly.
# =============================================================================

set -o pipefail

# --- Renkler / Colors ---
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_RESET='\033[0m'

log_info()  { echo -e "${C_BLUE}[BILGI/INFO]${C_RESET} $*"; }
log_ok()    { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
log_warn()  { echo -e "${C_YELLOW}[UYARI/WARNING]${C_RESET} $*"; }
log_err()   { echo -e "${C_RED}[HATA/ERROR]${C_RESET} $*" >&2; }

die() {
    log_err "$1"
    echo -e "${C_RED}[HATA/ERROR]${C_RESET} Islem durduruldu / Build aborted." >&2
    exit "${2:-1}"
}

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "Bu script root (sudo) ile calistirilmalidir. / This script must be run as root (sudo)."
    fi
}

require_cmd() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        die "Gerekli komut bulunamadi: '$cmd'. Kurulum icin: sudo apt-get install -y $pkg\n(Missing required command: '$cmd'. Install with: sudo apt-get install -y $pkg)"
    fi
}

require_file() {
    local f="$1"
    [[ -e "$f" ]] || die "Gerekli dosya/klasor bulunamadi: $f / Required file/dir not found: $f"
}

confirm_or_die() {
    local msg="$1"
    read -r -p "$msg [e/h - y/n]: " ans
    case "$ans" in
        e|E|y|Y|evet|yes) return 0 ;;
        *) die "Kullanici islemi iptal etti. / User cancelled the operation." ;;
    esac
}

# CocukOS proje kök dizinini bulur (bu dosyanin iki ust dizini)
project_root() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    (cd "$here/../.." && pwd)
}
