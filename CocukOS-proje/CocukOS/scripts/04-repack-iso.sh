#!/usr/bin/env bash
# =============================================================================
# 04-repack-iso.sh <calisma-dizini> <cikti-iso-yolu>
# squashfs-root'u yeniden squashfs'e paketler, manifest/size dosyalarini
# gunceller ve xorriso ile onyuklenebilir (BIOS+UEFI) bir ISO uretir.
#
# Repacks squashfs-root back into squashfs, updates manifest/size files,
# and produces a bootable (BIOS+UEFI) ISO with xorriso.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_root

WORKDIR="${1:?Kullanim: $0 <calisma-dizini> <cikti.iso> / Usage: $0 <workdir> <output.iso>}"
OUT_ISO="${2:?Kullanim: $0 <calisma-dizini> <cikti.iso> / Usage: $0 <workdir> <output.iso>}"

SQUASHROOT="$WORKDIR/squashfs-root"
ISO_EXTRACT="$WORKDIR/iso-extract"
require_file "$SQUASHROOT"
require_file "$ISO_EXTRACT"

[[ -f "$WORKDIR/.squashfs_source_path" ]] || die ".squashfs_source_path bulunamadi, once 01-extract-iso.sh calistirin.\n(.squashfs_source_path missing, run 01-extract-iso.sh first.)"
ORIG_SQUASHFS_REL="$(cat "$WORKDIR/.squashfs_source_path" | sed "s#^$ISO_EXTRACT/##")"
NEW_SQUASHFS="$ISO_EXTRACT/$ORIG_SQUASHFS_REL"

log_info "Yeni squashfs olusturuluyor (bu islem uzun surebilir)... / Building new squashfs (this can take a while)..."
rm -f "$NEW_SQUASHFS"
mksquashfs "$SQUASHROOT" "$NEW_SQUASHFS" -comp xz -noappend \
    || die "mksquashfs basarisiz oldu / mksquashfs failed"

log_info "filesystem.size guncelleniyor... / Updating filesystem.size..."
SIZE_FILE="$(dirname "$NEW_SQUASHFS")/filesystem.size"
du -sx --block-size=1 "$SQUASHROOT" | cut -f1 > "$SIZE_FILE" 2>/dev/null || printf '0' > "$SIZE_FILE"

log_info "manifest guncelleniyor... / Updating manifest..."
MANIFEST="$(dirname "$NEW_SQUASHFS")/filesystem.manifest"
if command -v chroot &>/dev/null; then
    chroot "$SQUASHROOT" dpkg-query -W --showformat='${Package}\t${Version}\n' > "$MANIFEST" 2>/dev/null || true
fi

log_info "MD5 toplam listesi yeniden hesaplaniyor (md5sum.txt)... / Recomputing md5sum.txt..."
(
    cd "$ISO_EXTRACT"
    find . -type f -not -path './md5sum.txt' -exec md5sum {} \; > md5sum.txt 2>/dev/null || true
)

log_info "ISO uretiliyor / Building ISO -> $OUT_ISO"
mkdir -p "$(dirname "$OUT_ISO")"

ISOHDPFX=""
for p in /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/isohdpfx.bin /usr/lib/syslinux/bios/isohdpfx.bin; do
    [[ -f "$p" ]] && ISOHDPFX="$p" && break
done
[[ -n "$ISOHDPFX" ]] || die "isohdpfx.bin bulunamadi (paket: isolinux) / isohdpfx.bin not found (package: isolinux)"

EFI_IMG=""
for p in "$ISO_EXTRACT/boot/grub/efi.img" "$ISO_EXTRACT/EFI/boot/efi.img"; do
    [[ -f "$p" ]] && EFI_IMG="$p" && break
done

pushd "$ISO_EXTRACT" >/dev/null

if [[ -n "$EFI_IMG" ]]; then
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "COCUKOS" \
        -eltorito-boot boot/grub/i386-pc/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --eltorito-catalog boot.catalog \
        --grub2-boot-info \
        --grub2-mbr "$ISOHDPFX" \
        -eltorito-alt-boot \
        -e "${EFI_IMG#./}" \
        -no-emul-boot \
        -append_partition 2 0xef "$EFI_IMG" \
        -output "$OUT_ISO" \
        -m md5sum.txt \
        . || die "xorriso ISO uretimi basarisiz (EFI modu) / xorriso ISO build failed (EFI mode)"
else
    log_warn "EFI onyukleme imaji bulunamadi, yalnizca BIOS/legacy onyukleme ile devam ediliyor.\n(EFI boot image not found, continuing with BIOS/legacy boot only.)"
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "COCUKOS" \
        -eltorito-boot boot/grub/i386-pc/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --eltorito-catalog boot.catalog \
        --grub2-boot-info \
        --grub2-mbr "$ISOHDPFX" \
        -output "$OUT_ISO" \
        -m md5sum.txt \
        . || die "xorriso ISO uretimi basarisiz (BIOS modu) / xorriso ISO build failed (BIOS mode)"
fi

popd >/dev/null

if command -v isohybrid &>/dev/null; then
    log_info "ISO hybrid (USB-yazilabilir) hale getiriliyor... / Making ISO hybrid (USB-writable)..."
    isohybrid --uefi "$OUT_ISO" 2>/dev/null || isohybrid "$OUT_ISO" 2>/dev/null || log_warn "isohybrid uygulanamadi, ISO yine de VM'de calisir ama USB'de EFI sorunlu olabilir.\n(isohybrid failed, ISO still works in a VM but USB EFI boot may be affected.)"
fi

require_file "$OUT_ISO"
log_ok "ISO basariyla uretildi / ISO built successfully: $OUT_ISO"
