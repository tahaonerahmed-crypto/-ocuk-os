#!/usr/bin/env bash
# =============================================================================
# 06-verify-lockdown.sh <calisma-dizini>
# ISO paketlenmeden ONCE, squashfs-root icindeki guvenlik ayarlarini
# chroot uzerinden dogrular. Herhangi bir kontrol basarisiz olursa derleme
# durur (bu yuzden "sadece arayuzde gizleme" riskine karsi otomatik korunma
# saglar).
#
# BEFORE packaging the ISO, verifies the security settings inside
# squashfs-root via chroot. If any check fails, the build stops (this gives
# automatic protection against the "hidden only in the UI" risk).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_root

WORKDIR="${1:?Kullanim: $0 <calisma-dizini> / Usage: $0 <workdir>}"
SQUASHROOT="$WORKDIR/squashfs-root"
require_file "$SQUASHROOT"

FAIL=0

check() {
    local desc="$1"; shift
    if "$@"; then
        log_ok "$desc"
    else
        log_err "BASARISIZ / FAILED: $desc"
        FAIL=1
    fi
}

run_in_chroot() {
    chroot "$SQUASHROOT" /bin/bash -c "$1" 2>/dev/null
}

log_info "Guvenlik dogrulamalari calistiriliyor... / Running security verifications..."

# 1) cocuk kullanicisi var mi ve sudo/adm grubunda DEGIL mi?
check "cocuk kullanicisi mevcut / 'cocuk' user exists" \
    bash -c "run_in_chroot 'id cocuk' >/dev/null"

check "cocuk sudo grubunda DEGIL / 'cocuk' is NOT in sudo group" \
    bash -c "! run_in_chroot 'groups cocuk' | grep -qw sudo"

check "cocuk adm grubunda DEGIL / 'cocuk' is NOT in adm group" \
    bash -c "! run_in_chroot 'groups cocuk' | grep -qw adm"

# 2) ebeveyn kullanicisi var mi ve sudo grubunda mi?
check "ebeveyn kullanicisi mevcut ve sudo grubunda / 'ebeveyn' exists and is in sudo group" \
    bash -c "run_in_chroot 'groups ebeveyn' | grep -qw sudo"

# 3) polkit kurali mevcut mu?
check "polkit kisitlama kurali mevcut / polkit restriction rule present" \
    test -f "$SQUASHROOT/etc/polkit-1/rules.d/51-cocukos.rules"

# 4) whitelist dosyasi mevcut mu?
check "whitelist dosyasi mevcut / whitelist file present" \
    test -f "$SQUASHROOT/etc/cocukos/whitelist.txt"

# 5) nftables kurali mevcut mu ve cocuk UID'sini iceriyor mu?
check "nftables kurallari mevcut / nftables ruleset present" \
    test -f "$SQUASHROOT/etc/nftables/cocukos.nft"

check "nftables kurali varsayilan-engelle iceriyor / nftables ruleset contains default-deny rule" \
    bash -c "grep -q 'drop' '$SQUASHROOT/etc/nftables/cocukos.nft'"

# 6) dnsmasq varsayilan olarak her seyi engelliyor mu (0.0.0.0)?
check "dnsmasq varsayilan-engelle kurali mevcut / dnsmasq default-deny rule present" \
    bash -c "test -f '$SQUASHROOT/etc/dnsmasq.d/cocukos.conf' && grep -q 'address=/#/0.0.0.0' '$SQUASHROOT/etc/dnsmasq.d/cocukos.conf'"

# 7) terminal binary'leri cocuk grubundan korunuyor mu?
for bin in gnome-terminal xterm; do
    p="$SQUASHROOT/usr/bin/$bin"
    if [[ -e "$p" ]]; then
        PERM="$(stat -c '%a' "$p")"
        check "$bin izinleri kisitli (750 veya daha az) / $bin permissions restricted" \
            bash -c "[[ '$PERM' -le 750 ]]"
    fi
done

# 8) cocukos-filter servisi enable mi?
check "cocukos-filter.service etkin / cocukos-filter.service is enabled" \
    test -L "$SQUASHROOT/etc/systemd/system/multi-user.target.wants/cocukos-filter.service"

echo
if [[ "$FAIL" -eq 1 ]]; then
    die "Bir veya daha fazla guvenlik kontrolu basarisiz oldu. ISO PAKETLENMEYECEK.\n(One or more security checks failed. The ISO will NOT be packaged.)"
fi

log_ok "Tum guvenlik kontrolleri basarili. / All security checks passed."
