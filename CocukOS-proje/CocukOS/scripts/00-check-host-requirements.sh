#!/usr/bin/env bash
# =============================================================================
# 00-check-host-requirements.sh
# Ana bilgisayarda ISO derlemek icin gereken tum araclari kontrol eder.
# Checks that the host machine has every tool required to build the ISO.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Host sistem gereksinimleri kontrol ediliyor... / Checking host requirements..."

require_root

MISSING=0
declare -A TOOLS=(
    [squashfs-tools]="unsquashfs mksquashfs"
    [xorriso]="xorriso"
    [rsync]="rsync"
    [coreutils]="sha256sum"
    [util-linux]="mount umount losetup"
    [isolinux]="isohdpfx.bin"
    [syslinux-utils]="isohybrid"
    [wget]="wget"
)

check_bin() {
    local bin="$1" pkg="$2"
    if command -v "$bin" &>/dev/null; then
        log_ok "$bin bulundu (paket: $pkg) / found (package: $pkg)"
    else
        log_warn "$bin BULUNAMADI (paket: $pkg) / NOT FOUND (package: $pkg)"
        MISSING=1
    fi
}

check_bin unsquashfs squashfs-tools
check_bin mksquashfs squashfs-tools
check_bin xorriso xorriso
check_bin rsync rsync
check_bin sha256sum coreutils
check_bin mount util-linux
check_bin isohybrid syslinux-utils
check_bin wget wget
check_bin qemu-system-x86_64 qemu-system-x86 || true

# isohdpfx.bin ozel: dosya konumunu ara
ISOHDR_FOUND=0
for p in /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/isohdpfx.bin /usr/lib/syslinux/bios/isohdpfx.bin; do
    if [[ -f "$p" ]]; then
        log_ok "isohdpfx.bin bulundu: $p"
        ISOHDR_FOUND=1
        break
    fi
done
if [[ "$ISOHDR_FOUND" -eq 0 ]]; then
    log_warn "isohdpfx.bin bulunamadi (paket: isolinux). / isohdpfx.bin not found (package: isolinux)."
    MISSING=1
fi

if [[ "$MISSING" -eq 1 ]]; then
    cat <<'EOF'

Eksik paketleri tek komutla kurmak icin (Ubuntu/Debian host):
To install all missing packages in one command (Ubuntu/Debian host):

  sudo apt-get update && sudo apt-get install -y \
      squashfs-tools xorriso isolinux syslinux-utils rsync wget \
      qemu-system-x86 qemu-utils

EOF
    die "Bir veya daha fazla gerekli arac eksik. Yukarida yazan komutu calistirip tekrar deneyin.\n(One or more required tools are missing. Run the command above and try again.)"
fi

log_ok "Tum gereksinimler saglandi. / All requirements satisfied."
