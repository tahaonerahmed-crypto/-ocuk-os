#!/usr/bin/env bash
# =============================================================================
# build.sh - CocukOS ana derleme scripti
#
# Kullanim / Usage:
#   sudo ./build.sh /path/to/ubuntu-26.04.1-desktop-amd64.iso
#
# Bu script sirasiyla:
#   0) Host arac gereksinimlerini kontrol eder
#   1) Verilen Ubuntu ISO'sunu cikartir
#   2) Chroot ortamini hazirlar ve CocukOS kurulumunu chroot icinde calistirir
#   3) Dosya sistemini yeniden paketleyip bootable ISO uretir
#   4) SHA256 checksum dosyasi uretir
#
# This script, in order:
#   0) Checks host tool requirements
#   1) Extracts the given Ubuntu ISO
#   2) Prepares the chroot and runs the CocukOS setup inside it
#   3) Repacks the filesystem into a bootable ISO
#   4) Generates a SHA256 checksum file
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$PROJECT_ROOT/scripts"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPTS/lib/common.sh"

ISO_NAME="CocukOS-26.04.1-amd64.iso"
WORKDIR="${COCUKOS_WORKDIR:-$PROJECT_ROOT/build-work}"
OUTDIR="${COCUKOS_OUTDIR:-$PROJECT_ROOT/output}"
OUT_ISO="$OUTDIR/$ISO_NAME"

# Resmi Ubuntu ISO'sunun varsayilan indirme adresi (SRC_ISO "auto" verilirse kullanilir).
# Baska bir surumu denemek icin COCUKOS_UBUNTU_ISO_URL ortam degiskenini gecersiz kilin.
# Default download URL for the official Ubuntu ISO (used when SRC_ISO is "auto").
# Override with the COCUKOS_UBUNTU_ISO_URL env var to try a different release.
DEFAULT_UBUNTU_ISO_URL="https://releases.ubuntu.com/26.04/ubuntu-26.04.1-desktop-amd64.iso"
UBUNTU_ISO_URL="${COCUKOS_UBUNTU_ISO_URL:-$DEFAULT_UBUNTU_ISO_URL}"

usage() {
    cat <<EOF
Kullanim / Usage:
  sudo $0 <kaynak-ubuntu.iso>
  sudo $0 auto              # Resmi ISO'yu otomatik indirir / auto-downloads the official ISO

Ornek / Example:
  sudo $0 /home/user/Downloads/ubuntu-26.04.1-desktop-amd64.iso
  sudo $0 auto

Ortam degiskenleri / Environment variables:
  COCUKOS_WORKDIR           Calisma dizini (varsayilan: ./build-work) / working dir (default: ./build-work)
  COCUKOS_OUTDIR            Cikti dizini (varsayilan: ./output) / output dir (default: ./output)
  COCUKOS_UBUNTU_ISO_URL    "auto" ile indirilecek ISO adresi / ISO URL used with "auto"

Notlar / Notes:
  - Kaynak ISO resmi Ubuntu 26.04 LTS Desktop amd64 imaji olmalidir.
    (Source ISO must be an official Ubuntu 26.04 LTS Desktop amd64 image.)
  - En az 20 GB bos disk alani onerilir.
    (At least 20 GB of free disk space is recommended.)
  - Bu script ROOT (sudo) gerektirir.
    (This script requires ROOT/sudo.)
EOF
}

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 1
fi

SRC_ISO="$1"

mkdir -p "$WORKDIR" "$OUTDIR"

if [[ "$SRC_ISO" == "auto" ]]; then
    SRC_ISO="$WORKDIR/ubuntu-source.iso"
    if [[ ! -f "$SRC_ISO" ]]; then
        echo
        echo "----- ADIM -1/5: Resmi Ubuntu ISO indiriliyor / STEP -1/5: Downloading official Ubuntu ISO -----"
        log_info "Indiriliyor / Downloading: $UBUNTU_ISO_URL"
        wget --progress=bar:force -O "$SRC_ISO" "$UBUNTU_ISO_URL" \
            || die "Ubuntu ISO indirilemedi. URL'yi kontrol edin veya ISO'yu elle indirip yolunu verin.\n(Failed to download Ubuntu ISO. Check the URL, or download it manually and pass its path.)"
    else
        log_info "Daha once indirilmis ISO kullaniliyor / Reusing previously downloaded ISO: $SRC_ISO"
    fi
fi

echo "============================================================"
echo "  CocukOS Derleme Sistemi / CocukOS Build System"
echo "  Taban / Base   : Ubuntu 26.04 LTS AMD64"
echo "  Kaynak ISO      : $SRC_ISO"
echo "  Cikti ISO       : $OUT_ISO"
echo "============================================================"
echo

require_root
require_file "$SRC_ISO"

# Disk alani kontrolu (yaklasik) / rough disk space check
AVAIL_KB="$(df -Pk "$WORKDIR" | tail -1 | awk '{print $4}')"
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
if [[ "$AVAIL_GB" -lt 15 ]]; then
    log_warn "Sadece ${AVAIL_GB}GB bos alan var. En az 15-20GB onerilir, islem basarisiz olabilir."
    log_warn "Only ${AVAIL_GB}GB free space available. 15-20GB+ is recommended; the build may fail."
    if [[ "${CI:-}" == "true" ]]; then
        log_warn "CI ortami tespit edildi, onay istenmeden devam ediliyor. / CI environment detected, continuing without confirmation."
    else
        confirm_or_die "Yine de devam etmek istiyor musunuz? / Continue anyway?"
    fi
fi

echo
echo "----- ADIM 0/5: Gereksinim kontrolu / STEP 0/5: Requirement check -----"
bash "$SCRIPTS/00-check-host-requirements.sh"

echo
echo "----- ADIM 1/5: ISO cikartiliyor / STEP 1/5: Extracting ISO -----"
bash "$SCRIPTS/01-extract-iso.sh" "$SRC_ISO" "$WORKDIR"

echo
echo "----- ADIM 2/5: Chroot kurulumu / STEP 2/5: Chroot setup -----"
bash "$SCRIPTS/02-chroot-prepare.sh" "$WORKDIR" "$PROJECT_ROOT"

echo
echo "----- ADIM 3/5: Guvenlik dogrulamasi / STEP 3/5: Security verification -----"
bash "$SCRIPTS/06-verify-lockdown.sh" "$WORKDIR"

echo
echo "----- ADIM 4/5: ISO yeniden paketleniyor / STEP 4/5: Repacking ISO -----"
bash "$SCRIPTS/04-repack-iso.sh" "$WORKDIR" "$OUT_ISO"

echo
echo "----- ADIM 5/5: SHA256 checksum / STEP 5/5: SHA256 checksum -----"
bash "$SCRIPTS/05-checksum.sh" "$OUT_ISO"

echo
echo "============================================================"
log_ok "CocukOS basariyla derlendi! / CocukOS built successfully!"
echo "  ISO      : $OUT_ISO"
echo "  SHA256   : ${OUT_ISO}.sha256"
echo
echo "  Test icin / To test:"
echo "    ./test/qemu-test.sh \"$OUT_ISO\""
echo "============================================================"
