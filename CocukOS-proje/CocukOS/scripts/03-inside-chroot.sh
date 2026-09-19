#!/usr/bin/env bash
# =============================================================================
# 03-inside-chroot.sh
# BU SCRIPT CHROOT ICINDE CALISIR (02-chroot-prepare.sh tarafindan cagrilir).
# THIS SCRIPT RUNS INSIDE THE CHROOT (invoked by 02-chroot-prepare.sh).
#
# Yapilanlar / What this does:
#   1. Turkce dil paketi ve varsayilan locale (tr_TR.UTF-8)
#   2. "ebeveyn" (admin/sudo) ve "cocuk" (standart, sudo YOK) kullanicilari
#   3. Firefox, dnsmasq, squid, nftables kurulumu
#   4. Gereksiz uygulamalarin kaldirilmasi
#   5. DNS + Squid (SNI bazli) beyaz liste filtresi
#   6. nftables ile "cocuk" kullanicisi icin agin varsayilan olarak kapatilmasi
#   7. polkit ile terminal/paket yoneticisi/sistem ayarlarinin kisitlanmasi
#   8. Cocuk masaustu (GNOME, buyuk ikonlu, sade)
#   9. Firefox politika dosyasi (sadece whitelist, proxy ayari sabit)
# =============================================================================
set -euo pipefail

log()  { echo "[CHROOT] $*"; }
err()  { echo "[CHROOT-HATA/ERROR] $*" >&2; }
die()  { err "$1"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

# systemctl bazi chroot ortamlarinda dbus'a erisemeyip "enable" islemini
# sessizce basarisiz kilabilir. Bu yuzden enable icin once systemctl denenir,
# olmazsa sembolik baglanti dogrudan elle olusturulur (guvenilir fallback).
#
# systemctl may silently fail to "enable" a unit in some chroot environments
# because it cannot reach dbus. So we try systemctl first, and if that
# doesn't produce the expected symlink, we create it by hand as a reliable
# fallback.
enable_unit() {
    local unit="$1"
    systemctl enable "$unit" 2>/dev/null || true
    if [[ ! -L "/etc/systemd/system/multi-user.target.wants/$unit" ]]; then
        mkdir -p /etc/systemd/system/multi-user.target.wants
        local unit_file=""
        for p in "/etc/systemd/system/$unit" "/usr/lib/systemd/system/$unit" "/lib/systemd/system/$unit"; do
            [[ -f "$p" ]] && unit_file="$p" && break
        done
        if [[ -n "$unit_file" ]]; then
            ln -sf "$unit_file" "/etc/systemd/system/multi-user.target.wants/$unit"
        fi
    fi
}

log "APT guncelleniyor... / Updating APT..."
apt-get update -y || die "apt-get update basarisiz / apt-get update failed"

# -----------------------------------------------------------------------------
# 1) TURKCE DIL / TURKISH LOCALE
# -----------------------------------------------------------------------------
log "Turkce dil destegi kuruluyor... / Installing Turkish language support..."
apt-get install -y --no-install-recommends \
    language-pack-tr language-pack-gnome-tr locales \
    || die "Dil paketleri kurulamadi / Failed to install language packages"

sed -i 's/^# *tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
grep -q '^tr_TR.UTF-8 UTF-8' /etc/locale.gen || echo 'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen tr_TR.UTF-8
update-locale LANG=tr_TR.UTF-8 LANGUAGE=tr_TR:tr

cat > /etc/default/locale <<'EOF'
LANG=tr_TR.UTF-8
LANGUAGE=tr_TR:tr
LC_ALL=tr_TR.UTF-8
EOF

# GDM/oturum icin de varsayilan dili ayarla (kullanicinin dil secim ekranini atlamasi icin)
mkdir -p /etc/gdm3
cat > /etc/gdm3/greeter.dconf-defaults <<'EOF'
[org/gnome/desktop/interface]
gtk-theme='Yaru'

[org/gnome/desktop/locale]
region='tr_TR.UTF-8'
EOF

# -----------------------------------------------------------------------------
# 2) KULLANICILAR / USER ACCOUNTS
# -----------------------------------------------------------------------------
log "Kullanicilar olusturuluyor... / Creating user accounts..."

# --- Ebeveyn: yonetici (sudo grubunda) ---
if ! id ebeveyn &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm -c "Ebeveyn Hesabi" ebeveyn
    echo "ebeveyn:ebeveyn123" | chpasswd
    log "  'ebeveyn' hesabi olusturuldu (gecici sifre: ebeveyn123 - ILK GIRISTE DEGISTIRIN)"
    log "  'ebeveyn' account created (temporary password: ebeveyn123 - CHANGE ON FIRST LOGIN)"
    chage -d 0 ebeveyn 2>/dev/null || true   # ilk girişte sifre degistirmeye zorla
fi

# --- Cocuk: standart kullanici, HICBIR yonetici/sudo grubunda degil ---
if ! id cocuk &>/dev/null; then
    useradd -m -s /bin/bash -c "Cocuk Hesabi" cocuk
    passwd -d cocuk || true   # sifresiz otomatik giris icin (guvenlik: yerel, internet filtresi ayrica saglanir)
    log "  'cocuk' hesabi olusturuldu (standart kullanici, sudo YOK) / 'cocuk' account created (standard user, NO sudo)"
fi

# Kesin dogrulama: cocuk kesinlikle sudo/admin grubunda olmamali
for g in sudo adm admin wheel lpadmin sambashare; do
    gpasswd -d cocuk "$g" 2>/dev/null || true
done

# cocuk kullanicisinin masaustune Turkce dili uygula
mkdir -p /home/cocuk
echo 'LANG=tr_TR.UTF-8' > /home/cocuk/.pam_environment 2>/dev/null || true

# skel-cocuk / skel-ebeveyn masaustu dosyalarini ilgili ev dizinlerine kopyala
mkdir -p /home/cocuk/Desktop /home/ebeveyn/Desktop
cp -a /etc/skel-cocuk/Desktop/. /home/cocuk/Desktop/ 2>/dev/null || true
cp -a /etc/skel-ebeveyn/Desktop/. /home/ebeveyn/Desktop/ 2>/dev/null || true
chown -R cocuk:cocuk /home/cocuk 2>/dev/null || true
chown -R ebeveyn:ebeveyn /home/ebeveyn 2>/dev/null || true

# cocukos yonetim scriptlerini sadece root/sudo grubu calistirabilsin
chmod 750 /usr/local/sbin/cocukos-guncelle-liste.sh /usr/local/sbin/cocukos-liste-gui.sh 2>/dev/null || true
chown root:sudo /usr/local/sbin/cocukos-guncelle-liste.sh /usr/local/sbin/cocukos-liste-gui.sh 2>/dev/null || true
chmod +x /home/cocuk/Desktop/*.desktop /home/ebeveyn/Desktop/*.desktop 2>/dev/null || true

# -----------------------------------------------------------------------------
# 3) PAKETLER / PACKAGES
# -----------------------------------------------------------------------------
log "Gerekli paketler kuruluyor... / Installing required packages..."
apt-get install -y --no-install-recommends \
    firefox \
    dnsmasq \
    squid \
    nftables \
    polkitd pkexec \
    zenity \
    xdotool \
    dconf-cli dconf-editor \
    fonts-dejavu \
    openssl \
    || die "Temel paketler kurulamadi / Failed to install core packages"

# systemd-resolved DNS'i devre disi birak (dnsmasq ile catisir)
systemctl disable --now systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.1
EOF

# -----------------------------------------------------------------------------
# 4) GEREKSIZ UYGULAMALARIN KALDIRILMASI / REMOVE UNNEEDED APPS
# -----------------------------------------------------------------------------
log "Gereksiz uygulamalar kaldiriliyor (sistem kararliligi korunarak)... / Removing unneeded apps (keeping system stable)..."
apt-get remove -y --purge \
    thunderbird* libreoffice* aisleriot gnome-mahjongg gnome-mines \
    gnome-sudoku transmission* rhythmbox* shotwell* remmina* \
    cheese* simple-scan* gnome-todo deja-dup \
    2>/dev/null || log "  (Bazi paketler zaten yoktu, atlaniyor / some packages were already absent, skipping)"

apt-get autoremove -y --purge || true
apt-get clean

# -----------------------------------------------------------------------------
# 5) DNS + SQUID BEYAZ LISTE FILTRESI / DNS + SQUID WHITELIST FILTER
# -----------------------------------------------------------------------------
log "Internet filtreleme sistemi kuruluyor... / Setting up internet filtering system..."

mkdir -p /etc/cocukos
[[ -f /etc/cocukos/whitelist.txt ]] || cat > /etc/cocukos/whitelist.txt <<'EOF'
# CocukOS Izin Verilen Siteler / Allowed Sites Whitelist
# Her satira bir alan adi yazin (alt alan adlari otomatik dahildir).
# One domain per line (subdomains are automatically included).
wikipedia.org
khanacademy.org
code.org
scratch.mit.edu
duolingo.com
tinkercad.com
pbskids.org
eba.gov.tr
nasa.gov
kodable.com
EOF
chmod 644 /etc/cocukos/whitelist.txt
chown root:root /etc/cocukos/whitelist.txt

# --- dnsmasq: sadece whitelist'teki alan adlarini cozer, geri kalanini NXDOMAIN yapar ---
mkdir -p /etc/dnsmasq.d
cat > /etc/cocukos/generate-dnsmasq.sh <<'GENEOF'
#!/usr/bin/env bash
# Whitelist dosyasindan dnsmasq yapilandirmasi uretir.
# Generates dnsmasq config from the whitelist file.
set -euo pipefail
WL=/etc/cocukos/whitelist.txt
OUT=/etc/dnsmasq.d/cocukos.conf
{
    echo "# OTOMATIK URETILDI - elle duzenlemeyin / AUTO-GENERATED - do not edit by hand"
    echo "# Duzenlemek icin /etc/cocukos/whitelist.txt dosyasini kullanin"
    echo "no-resolv"
    echo "server=1.1.1.1"
    echo "server=9.9.9.9"
    echo "# Varsayilan olarak HER SEYI engelle (0.0.0.0 -> baglanti kurulamaz)"
    echo "address=/#/0.0.0.0"
    while IFS= read -r domain; do
        [[ -z "$domain" || "$domain" == \#* ]] && continue
        echo "server=/$domain/1.1.1.1"
        echo "server=/$domain/9.9.9.9"
        # ust joker kaydini bu alan adi icin gecersiz kil (yani gercekten cozulsun)
        echo "address=/$domain/#"
    done < "$WL"
} > "$OUT"
systemctl restart dnsmasq 2>/dev/null || true
GENEOF
chmod 750 /etc/cocukos/generate-dnsmasq.sh
chown root:sudo /etc/cocukos/generate-dnsmasq.sh
/etc/cocukos/generate-dnsmasq.sh || log "  (dnsmasq henuz calisir durumda degil, ISO ilk aciliste calisacak)"

cat > /etc/dnsmasq.conf <<'EOF'
# CocukOS dnsmasq ana yapilandirmasi
listen-address=127.0.0.1
bind-interfaces
no-hosts
conf-dir=/etc/dnsmasq.d,*.conf
EOF

enable_unit dnsmasq.service

# --- Squid: HTTPS baglantilarinda SNI (sunucu adi) bazinda beyaz liste ---
# SSL sertifikalarini cozmeden (MITM olmadan) sadece hangi siteye baglanildigina bakar.
cat > /etc/cocukos/generate-squid-acl.sh <<'GENEOF'
#!/usr/bin/env bash
set -euo pipefail
WL=/etc/cocukos/whitelist.txt
OUT=/etc/squid/cocukos-whitelist.acl
{
    while IFS= read -r domain; do
        [[ -z "$domain" || "$domain" == \#* ]] && continue
        echo ".$domain"
        echo "$domain"
    done < "$WL"
} > "$OUT"
systemctl restart squid 2>/dev/null || true
GENEOF
chmod 750 /etc/cocukos/generate-squid-acl.sh
chown root:sudo /etc/cocukos/generate-squid-acl.sh
/etc/cocukos/generate-squid-acl.sh || true

cat > /etc/squid/squid.conf <<'EOF'
# CocukOS Squid yapilandirmasi - SNI bazli beyaz liste (MITM/sertifika gerekmez)
http_port 127.0.0.1:3128
https_port 127.0.0.1:3129 intercept ssl-bump cert=/etc/squid/squid-selfsigned.pem generate-host-certificates=off
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl CONNECT method CONNECT

acl izinli_siteler dstdomain "/etc/squid/cocukos-whitelist.acl"

# HTTPS: sertifikayi ACIP KAPATMADAN sadece SNI'a (istenen alan adina) bak, sonra trafigi ayni sekilde ilet (splice)
acl step1 at_step SslBump1
ssl_bump peek step1
ssl_bump splice izinli_siteler
ssl_bump terminate all

http_access allow CONNECT izinli_siteler
http_access allow izinli_siteler
http_access deny all

coredump_dir /var/spool/squid
EOF

# Squid SSL-bump icin gerekli self-signed sertifika altyapisi (icerigi cozmez, sadece intercept icin gerekli)
mkdir -p /etc/squid
if [[ ! -f /etc/squid/squid-selfsigned.pem ]]; then
    openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 \
        -subj "/C=TR/O=CocukOS/CN=CocukOS Local Filter" \
        -keyout /etc/squid/squid-selfsigned.pem \
        -out /etc/squid/squid-selfsigned.pem 2>/dev/null || log "  (openssl bulunamadi, ssl-bump sertifikasi uretilemedi)"
fi
enable_unit squid.service

# -----------------------------------------------------------------------------
# 6) NFTABLES: "cocuk" KULLANICISI ICIN AGI VARSAYILAN KAPAT
#    NFTABLES: default-deny network for the "cocuk" user
# -----------------------------------------------------------------------------
log "Guvenlik duvari (nftables) kurallari yaziliyor... / Writing firewall (nftables) rules..."

COCUK_UID="$(id -u cocuk)"

mkdir -p /etc/nftables
cat > /etc/nftables/cocukos.nft <<EOF
#!/usr/sbin/nft -f
# CocukOS - cocuk kullanicisi icin varsayilan-engelle agi kurallari
# CocukOS - default-deny network rules for the "cocuk" user

table inet cocukos_filter {
    chain output {
        type filter hook output priority 0; policy accept;

        # cocuk kullanicisinin sadece yerel dnsmasq (53) ve yerel squid'e (3128/3129) erismesine izin ver
        meta skuid $COCUK_UID ip daddr 127.0.0.1 udp dport 53 accept
        meta skuid $COCUK_UID ip daddr 127.0.0.1 tcp dport 53 accept
        meta skuid $COCUK_UID ip daddr 127.0.0.1 tcp dport { 3128, 3129 } accept
        meta skuid $COCUK_UID oif lo accept

        # cocuk: DNS-over-HTTPS/DoT ile filtreyi atlatmayi engelle (bilinen DoH/DoT portlari)
        meta skuid $COCUK_UID tcp dport 853 drop
        meta skuid $COCUK_UID udp dport 853 drop

        # cocuk: baska bir DNS sunucusuna dogrudan sorgu atmayi engelle
        meta skuid $COCUK_UID udp dport 53 drop
        meta skuid $COCUK_UID tcp dport 53 drop

        # cocuk: dogrudan (proxy'siz) 80/443 cikisini engelle -> her sey squid'den gecmek ZORUNDA
        meta skuid $COCUK_UID tcp dport { 80, 443 } ip daddr != 127.0.0.1 drop
    }

    chain prerouting {
        type nat hook prerouting priority -100; policy accept;
        # cocuk'un giden 80/443 trafigini yerel squid'e yonlendir (transparent proxy)
        meta skuid $COCUK_UID tcp dport 80 redirect to :3128
        meta skuid $COCUK_UID tcp dport 443 redirect to :3129
    }
}
EOF
chmod 640 /etc/nftables/cocukos.nft
chown root:root /etc/nftables/cocukos.nft

cat > /etc/systemd/system/cocukos-filter.service <<'EOF'
[Unit]
Description=CocukOS Internet Filtresi (nftables kurallarini yukler) / CocukOS Internet Filter
After=network-pre.target dnsmasq.service squid.service
Before=network-online.target
Wants=dnsmasq.service squid.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f /etc/nftables/cocukos.nft
ExecStart=/etc/cocukos/generate-dnsmasq.sh
ExecStart=/etc/cocukos/generate-squid-acl.sh

[Install]
WantedBy=multi-user.target
EOF
enable_unit cocukos-filter.service

# -----------------------------------------------------------------------------
# 7) POLKIT: TERMINAL / PAKET YONETICISI / SISTEM AYARLARINI KISITLA
#    POLKIT: restrict terminal / package manager / system settings
# -----------------------------------------------------------------------------
log "Yetki (polkit) kurallari yaziliyor... / Writing polkit authorization rules..."

mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/51-cocukos.rules <<'EOF'
// CocukOS: "cocuk" kullanicisi hicbir yonetici (root) yetkisi isteyen islemi
// gerceklestiremez - paket kurma/kaldirma, sistem ayarlari, kullanici yonetimi,
// ag/proxy ayarlari, disk bicimlendirme, vb.
//
// CocukOS: the "cocuk" user is denied every action that requires root
// authorization - package management, system settings, user administration,
// network/proxy settings, disk operations, etc.

polkit.addRule(function(action, subject) {
    if (subject.user == "cocuk") {
        return polkit.Result.NO;
    }
});
EOF

# Terminal uygulamalarini "cocuk" grubundan (yani herkesten, sudo grubu haric) gizle/calistiramaz yap
mkdir -p /etc/cocukos
groupadd -f yonetici_terminal
usermod -aG yonetici_terminal ebeveyn 2>/dev/null || true

for term_bin in /usr/bin/gnome-terminal /usr/bin/gnome-terminal.wrapper /usr/bin/xterm /usr/bin/x-terminal-emulator; do
    if [[ -e "$term_bin" ]]; then
        chown root:yonetici_terminal "$term_bin"
        chmod 750 "$term_bin"
    fi
done

# GNOME Terminal .desktop dosyasini cocuk icin masaustunden gizle (NoDisplay + kisitli menu)
mkdir -p /etc/skel-cocuk/.config
mkdir -p /home/cocuk/.local/share/applications
cat > /home/cocuk/.local/share/applications/org.gnome.Terminal.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Terminal (Devre Disi)
NoDisplay=true
Hidden=true
EOF
chown -R cocuk:cocuk /home/cocuk/.local 2>/dev/null || true

# Paket yoneticisi GUI'lerini (varsa) cocuk kullanicisindan gizle
for pm_desktop in gnome-software.desktop software-properties-gtk.desktop synaptic.desktop update-manager.desktop; do
    f="/usr/share/applications/$pm_desktop"
    if [[ -f "$f" ]]; then
        mkdir -p /home/cocuk/.local/share/applications
        cat > "/home/cocuk/.local/share/applications/$pm_desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Devre Disi
NoDisplay=true
Hidden=true
EOF
    fi
done
chown -R cocuk:cocuk /home/cocuk/.local 2>/dev/null || true

# GNOME ayarlarini (Settings) cocuk hesabinda sinirlandir: dconf ile
mkdir -p /etc/dconf/profile /etc/dconf/db/cocukos.d
cat > /etc/dconf/profile/cocuk <<'EOF'
user-db:user
system-db:cocukos
EOF
cat > /etc/dconf/db/cocukos.d/00-cocukos-locks <<'EOF'
[org/gnome/desktop/lockdown]
disable-command-line=true
disable-user-switching=false
user-administration-disabled=true

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/cocukos/cocukos-wallpaper.svg'
picture-uri-dark='file:///usr/share/backgrounds/cocukos/cocukos-wallpaper.svg'

[org/gnome/shell]
favorite-apps=['firefox.desktop']
EOF
mkdir -p /etc/dconf/db/cocukos.d/locks
cat > /etc/dconf/db/cocukos.d/locks/cocukos.lock <<'EOF'
/org/gnome/desktop/lockdown/disable-command-line
/org/gnome/desktop/lockdown/user-administration-disabled
EOF
dconf update 2>/dev/null || true

# -----------------------------------------------------------------------------
# 8) COCUK MASAUSTU / CHILD DESKTOP
# -----------------------------------------------------------------------------
log "Cocuk masaustu ayarlaniyor... / Configuring child desktop..."

mkdir -p /usr/share/backgrounds/cocukos
if [[ ! -f /usr/share/backgrounds/cocukos/cocukos-wallpaper.svg ]]; then
cat > /usr/share/backgrounds/cocukos/cocukos-wallpaper.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">
  <rect width="1920" height="1080" fill="#8ecae6"/>
  <circle cx="960" cy="500" r="220" fill="#ffb703"/>
  <text x="960" y="850" font-size="90" text-anchor="middle" fill="#023047" font-family="sans-serif">CocukOS</text>
</svg>
EOF
fi

# GDM otomatik giris: cocuk hesabi ile dogrudan masaustune gec
mkdir -p /etc/gdm3
cat >> /etc/gdm3/custom.conf <<'EOF'

[daemon]
AutomaticLoginEnable=true
AutomaticLogin=cocuk
EOF

# GNOME buyuk ikon / kolay kullanim ayarlari (cocukos dconf db'sine ekle)
cat >> /etc/dconf/db/cocukos.d/00-cocukos-locks <<'EOF'

[org/gnome/desktop/interface]
icon-size='large'
text-scaling-factor=1.25
cursor-size=32

[org/gnome/nautilus/icon-view]
default-zoom-level='large'
EOF
dconf update 2>/dev/null || true

# -----------------------------------------------------------------------------
# 9) FIREFOX: SADECE WHITELIST, PROXY SABIT VE DEGISTIRILEMEZ
# -----------------------------------------------------------------------------
log "Firefox kurumsal politikalari yaziliyor... / Writing Firefox enterprise policies..."

mkdir -p /etc/firefox/policies
cat > /etc/firefox/policies/policies.json <<'EOF'
{
  "policies": {
    "Homepage": {
      "URL": "https://www.wikipedia.org",
      "Locked": true,
      "StartPage": "homepage"
    },
    "Proxy": {
      "Mode": "manual",
      "HTTPProxy": "127.0.0.1:3128",
      "SSLProxy": "127.0.0.1:3129",
      "UseHTTPProxyForAllProtocols": true,
      "Locked": true
    },
    "DisableFirefoxAccounts": true,
    "DisablePocket": true,
    "DisableTelemetry": true,
    "DisableDeveloperTools": true,
    "DisablePrivateBrowsing": true,
    "DisableSetDesktopBackground": true,
    "DisableSecurityBypass": {
      "InvalidCertificate": false,
      "SafeBrowsing": false
    },
    "BlockAboutConfig": true,
    "BlockAboutAddons": true,
    "InstallAddonsPermission": {
      "Default": false
    },
    "PopupBlocking": { "Default": true, "Locked": true }
  }
}
EOF

log "Chroot ici kurulum basariyla tamamlandi. / In-chroot setup finished successfully."
