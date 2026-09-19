#!/usr/bin/env bash
# =============================================================================
# cocukos-guncelle-liste.sh
# SADECE root/sudo (yani "ebeveyn" hesabi) tarafindan calistirilabilir.
# /etc/cocukos/whitelist.txt dosyasindaki degisiklikleri dnsmasq ve squid'e
# uygular (DNS + firewall seviyesinde beyaz liste guncellemesi).
#
# Can only be run with root/sudo (i.e. from the "ebeveyn" account).
# Applies changes in /etc/cocukos/whitelist.txt to dnsmasq and squid
# (updates the DNS + firewall level whitelist).
# =============================================================================
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "[HATA] Bu komut sadece 'sudo' ile, Ebeveyn hesabindan calistirilabilir." >&2
    echo "[ERROR] This command can only be run with 'sudo', from the Ebeveyn account." >&2
    exit 1
fi

WL=/etc/cocukos/whitelist.txt
if [[ ! -f "$WL" ]]; then
    echo "[HATA] $WL bulunamadi. / [ERROR] $WL not found." >&2
    exit 1
fi

echo "[BILGI] Yeni izinli site listesi uygulaniyor... / Applying new allowed-site list..."
/etc/cocukos/generate-dnsmasq.sh
/etc/cocukos/generate-squid-acl.sh
nft -f /etc/nftables/cocukos.nft 2>/dev/null || true

echo "[OK] Liste basariyla guncellendi. Guncel izinli siteler:"
echo "[OK] List updated successfully. Currently allowed sites:"
grep -vE '^\s*(#|$)' "$WL"
