#!/usr/bin/env bash
# =============================================================================
# qemu-test.sh <iso-yolu>
# Uretilen CocukOS ISO'sunu QEMU icinde (gercek diske yazmadan) test eder.
# Tests the produced CocukOS ISO inside QEMU (without writing to a real disk).
# =============================================================================
set -euo pipefail

ISO="${1:?Kullanim: $0 <iso-dosyasi> / Usage: $0 <iso-file>}"
[[ -f "$ISO" ]] || { echo "[HATA] ISO bulunamadi: $ISO" >&2; exit 1; }

if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "[HATA] qemu-system-x86_64 bulunamadi. Kurulum: sudo apt-get install -y qemu-system-x86" >&2
    echo "[ERROR] qemu-system-x86_64 not found. Install with: sudo apt-get install -y qemu-system-x86" >&2
    exit 1
fi

RAM_MB=4096
DISK_GB=20
VM_DISK="/tmp/cocukos-test-disk.qcow2"

if [[ ! -f "$VM_DISK" ]]; then
    if command -v qemu-img &>/dev/null; then
        qemu-img create -f qcow2 "$VM_DISK" "${DISK_GB}G" >/dev/null
    fi
fi

echo "[BILGI] QEMU baslatiliyor / Starting QEMU..."
echo "  ISO   : $ISO"
echo "  RAM   : ${RAM_MB}MB"
echo "  Disk  : $VM_DISK (${DISK_GB}GB, kalici degil test amacli / persistent test disk)"
echo
echo "  Not: KVM hizlandirma varsa otomatik kullanilir. / KVM acceleration is used automatically if available."
echo

KVM_FLAG=""
if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    KVM_FLAG="-enable-kvm"
fi

exec qemu-system-x86_64 \
    $KVM_FLAG \
    -m "$RAM_MB" \
    -smp 2 \
    -cdrom "$ISO" \
    -drive file="$VM_DISK",format=qcow2,if=virtio \
    -boot d \
    -vga virtio \
    -display gtk,show-cursor=on \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -usb -device usb-tablet
