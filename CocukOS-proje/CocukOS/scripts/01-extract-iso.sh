#!/usr/bin/env bash
# =============================================================================
# 01-extract-iso.sh <kaynak-iso-yolu> <calisma-dizini>
# Verilen Ubuntu ISO'sunu mount edip icerigini ve squashfs dosya sistemini
# calisma dizinine cikartir.
#
# Mounts the given Ubuntu ISO and extracts its contents + squashfs filesystem
# into the working directory.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_root

SRC_ISO="${1:?Kullanim: $0 <kaynak.iso> <calisma-dizini> / Usage: $0 <source.iso> <workdir>}"
WORKDIR="${2:?Kullanim: $0 <kaynak.iso> <calisma-dizini> / Usage: $0 <source.iso> <workdir>}"

require_file "$SRC_ISO"
[[ "$SRC_ISO" == *.iso ]] || log_warn "Dosya uzantisi .iso degil, yine de devam ediliyor. / File extension is not .iso, continuing anyway."

MNT="$WORKDIR/iso-mount"
ISO_EXTRACT="$WORKDIR/iso-extract"
SQUASHROOT="$WORKDIR/squashfs-root"

mkdir -p "$MNT" "$ISO_EXTRACT"

log_info "ISO mount ediliyor: $SRC_ISO -> $MNT"
if mountpoint -q "$MNT"; then
    umount "$MNT" || die "Onceki mount noktasi kaldirilamiyor / cannot unmount stale mountpoint: $MNT"
fi
mount -o loop,ro "$SRC_ISO" "$MNT" || die "ISO mount edilemedi. Dosyanin gecerli bir ISO oldugunu kontrol edin.\n(Failed to mount ISO. Verify the file is a valid ISO image.)"
trap 'umount "$MNT" 2>/dev/null || true' EXIT

log_info "ISO icerigi kopyalaniyor (bu biraz surebilir)... / Copying ISO contents (this may take a while)..."
rsync -a --info=progress2 "$MNT"/ "$ISO_EXTRACT"/ || die "ISO icerigi kopyalanamadi. / Failed to copy ISO contents."

umount "$MNT"
trap - EXIT

# squashfs dosyasini bul (Ubuntu surumune gore konum degisebilir)
SQUASHFS_PATH=""
for candidate in \
    "$ISO_EXTRACT/casper/filesystem.squashfs" \
    "$ISO_EXTRACT/casper/ubuntu-server-minimal.squashfs" \
    "$ISO_EXTRACT/casper/filesystem.squashfs.img"
do
    if [[ -f "$candidate" ]]; then
        SQUASHFS_PATH="$candidate"
        break
    fi
done

if [[ -z "$SQUASHFS_PATH" ]]; then
    SQUASHFS_PATH="$(find "$ISO_EXTRACT" -iname '*.squashfs' | head -n1 || true)"
fi

[[ -n "$SQUASHFS_PATH" ]] || die "ISO icinde squashfs dosya sistemi bulunamadi (casper/filesystem.squashfs bekleniyordu).\n(No squashfs filesystem found inside the ISO; expected casper/filesystem.squashfs.)"

log_info "Squashfs bulundu: $SQUASHFS_PATH"
log_info "Squashfs cozuluyor / Extracting squashfs -> $SQUASHROOT ..."
rm -rf "$SQUASHROOT"
unsquashfs -d "$SQUASHROOT" "$SQUASHFS_PATH" || die "Squashfs cozulemedi. / Failed to extract squashfs."

echo "$SQUASHFS_PATH" > "$WORKDIR/.squashfs_source_path"

log_ok "ISO cikartma tamamlandi. / ISO extraction complete."
log_info "  Ham ISO icerigi / raw ISO tree : $ISO_EXTRACT"
log_info "  Kok dosya sistemi / rootfs      : $SQUASHROOT"
