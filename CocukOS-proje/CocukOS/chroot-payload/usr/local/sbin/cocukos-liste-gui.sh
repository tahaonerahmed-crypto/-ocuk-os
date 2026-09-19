#!/usr/bin/env bash
# =============================================================================
# cocukos-liste-gui.sh
# Ebeveyn hesabindan pkexec ile calistirilir; whitelist'i zenity penceresinde
# duzenlemeyi saglar ve kaydedince filtreleri otomatik uygular.
#
# Run via pkexec from the Ebeveyn account; lets the parent edit the whitelist
# in a zenity window and automatically applies the filters on save.
# =============================================================================
set -euo pipefail

WL=/etc/cocukos/whitelist.txt

if [[ "$(id -u)" -ne 0 ]]; then
    zenity --error --text="Bu arac yalnizca Ebeveyn hesabindan (yetkilendirme ile) calistirilabilir.\nThis tool can only be run from the Ebeveyn account (with authorization)." 2>/dev/null
    exit 1
fi

CURRENT="$(grep -vE '^\s*(#|$)' "$WL" || true)"

NEW_CONTENT="$(zenity --text-info --editable \
    --title="CocukOS - Internet Izin Listesi / Allowed Sites List" \
    --width=520 --height=480 \
    --filename=<(cat <<HEADER
# Her satira bir alan adi yazin. "#" ile baslayan satirlar yorumdur.
# One domain per line. Lines starting with "#" are comments.
$CURRENT
HEADER
) )" || { echo "Iptal edildi / Cancelled"; exit 0; }

echo "$NEW_CONTENT" | grep -vE '^\s*#' | grep -vE '^\s*$' > "$WL.tmp"
mv "$WL.tmp" "$WL"
chmod 644 "$WL"

/etc/cocukos/generate-dnsmasq.sh
/etc/cocukos/generate-squid-acl.sh
nft -f /etc/nftables/cocukos.nft 2>/dev/null || true

zenity --info --text="Izin verilen siteler listesi guncellendi.\nAllowed sites list updated." 2>/dev/null
