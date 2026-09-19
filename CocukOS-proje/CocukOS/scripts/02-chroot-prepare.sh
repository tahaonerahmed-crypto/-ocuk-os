#!/usr/bin/env bash
# =============================================================================
# 02-chroot-prepare.sh <calisma-dizini> <proje-kok-dizini>
# squashfs-root icine chroot olmak icin gerekli baglamalari yapar,
# CocukOS payload dosyalarini kopyalar ve 03-inside-chroot.sh'i chroot
# icinde calistirir. Islem bitince baglamalari temizler.
#
# Sets up bind mounts to chroot into squashfs-root, copies the CocukOS
# payload files in, runs 03-inside-chroot.sh inside the chroot, and
# always tears the mounts back down afterwards.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_root

WORKDIR="${1:?Kullanim: $0 <calisma-dizini> <proje-kok> / Usage: $0 <workdir> <project-root>}"
PROJECT_ROOT="${2:?Kullanim: $0 <calisma-dizini> <proje-kok> / Usage: $0 <workdir> <project-root>}"

SQUASHROOT="$WORKDIR/squashfs-root"
require_file "$SQUASHROOT"
require_file "$PROJECT_ROOT/chroot-payload"
require_file "$PROJECT_ROOT/config/whitelist.txt"

cleanup() {
    log_info "Chroot baglamalari temizleniyor... / Tearing down chroot bind mounts..."
    for m in dev/pts dev proc sys; do
        if mountpoint -q "$SQUASHROOT/$m"; then
            umount -lf "$SQUASHROOT/$m" 2>/dev/null || true
        fi
    done
}
trap cleanup EXIT

log_info "CocukOS payload dosyalari chroot'a kopyalaniyor... / Copying CocukOS payload into chroot..."
rsync -a "$PROJECT_ROOT/chroot-payload"/ "$SQUASHROOT"/
install -Dm644 "$PROJECT_ROOT/config/whitelist.txt" "$SQUASHROOT/etc/cocukos/whitelist.txt"
install -Dm755 "$PROJECT_ROOT/scripts/03-inside-chroot.sh" "$SQUASHROOT/tmp/03-inside-chroot.sh"

log_info "Sanal dosya sistemleri baglaniyor... / Mounting virtual filesystems..."
mount --bind /dev "$SQUASHROOT/dev"
mount --bind /dev/pts "$SQUASHROOT/dev/pts"
mount -t proc proc "$SQUASHROOT/proc"
mount -t sysfs sysfs "$SQUASHROOT/sys"

# DNS'in chroot icinde calismasi icin (paket kurulumlari indirme yapabilsin diye)
cp -L /etc/resolv.conf "$SQUASHROOT/etc/resolv.conf" 2>/dev/null || true

log_info "Chroot icine giriliyor ve kurulum calistiriliyor... / Entering chroot and running setup..."
chroot "$SQUASHROOT" /bin/bash /tmp/03-inside-chroot.sh \
    || die "Chroot ici kurulum basarisiz oldu. / In-chroot setup failed."

rm -f "$SQUASHROOT/tmp/03-inside-chroot.sh"

log_ok "Chroot kurulumu tamamlandi. / Chroot setup complete."
