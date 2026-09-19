# CocukOS

Ubuntu 26.04 LTS AMD64 tabanli, cocuklara yonelik, ebeveyn kontrollu bir Linux
dagitimi derleme projesi.

A build project for a child-focused, parent-controlled Linux distribution
based on Ubuntu 26.04 LTS AMD64.

---

## ⚠️ Onemli / Important

Bu proje, resmi bir Ubuntu 26.04 LTS Desktop AMD64 ISO'sunu **girdi** olarak
alip onu ozellestirir (yeniden paketler). Internetten Ubuntu ISO'su indirmez;
kendi indirdiginiz ISO dosyasinin yolunu `build.sh`'a parametre olarak
vermeniz gerekir.

This project takes an official Ubuntu 26.04 LTS Desktop AMD64 ISO as
**input** and customizes (repacks) it. It does not download the Ubuntu ISO
itself — you must download it yourself and pass its path to `build.sh`.

Resmi ISO'yu indirmek icin / To download the official ISO:
https://releases.ubuntu.com/26.04/

---

## 🚀 Linux makineniz yoksa: GitHub Actions ile bulutta derleme / No Linux machine? Build in the cloud with GitHub Actions

Hicbir Linux makineniz, root erisiminiz veya indirilmis bir ISO'nuz yoksa,
projeye dahil edilen `.github/workflows/build-cocukos.yml` dosyasi
**tamamen ucretsiz** olarak GitHub'in bulut sunucularinda ISO'yu sizin
yerinize derler.

If you have no Linux machine, no root access, and no downloaded ISO, the
included `.github/workflows/build-cocukos.yml` builds the ISO for you on
GitHub's cloud servers, **completely free**.

**Adimlar / Steps:**

1. Ucretsiz bir GitHub hesabi acin (yoksa) / Create a free GitHub account (if you don't have one): https://github.com/join
2. Yeni bir **PUBLIC** repo olusturun (public onerilir; ISO ~5GB oldugu icin
   private repolarin kucuk depolama kotasina takilmamak icin).
   Create a new **PUBLIC** repo (public is recommended so the ~5GB ISO
   doesn't hit private repos' small storage quota).
3. Bu proje klasorunun tum icerigini o repoya yukleyin (GitHub web
   arayuzunden surukle-birak ile veya `git push` ile).
   Upload this entire project folder to that repo (via drag-and-drop on the
   GitHub web UI, or `git push`).
4. Reponun **"Actions"** sekmesine gidin, **"CocukOS ISO Derle / Build
   CocukOS ISO"** workflow'unu secin, **"Run workflow"** butonuna basin.
   Go to the repo's **"Actions"** tab, select the **"CocukOS ISO Derle /
   Build CocukOS ISO"** workflow, click **"Run workflow"**.
5. Yaklasik 30-60 dakika bekleyin (Ubuntu ISO indirme + derleme suresi).
   Wait about 30-60 minutes (Ubuntu ISO download + build time).
6. Is bitince calisma sayfasinin altindaki **"Artifacts"** bolumunden
   `CocukOS-26.04.1-amd64-iso` dosyasini indirin — icinde ISO ve SHA256
   dosyasi bulunur.
   When it finishes, download `CocukOS-26.04.1-amd64-iso` from the
   **"Artifacts"** section at the bottom of the run page — it contains the
   ISO and its SHA256 file.

Bu sekilde hicbir sey kurmadan, kendi bilgisayarinizi kullanmadan, tarayici
uzerinden ISO'yu elde edebilirsiniz.

This way you get the ISO without installing anything or using your own
computer — entirely through the browser.

---

## Gereksinimler / Requirements

Derleme yalnizca bir **Linux (Ubuntu/Debian tabanli) host** uzerinde,
**root/sudo** ile calisir. Asagidaki paketler gereklidir:

The build only runs on a **Linux (Ubuntu/Debian-based) host**, with
**root/sudo**. The following packages are required:

```bash
sudo apt-get update && sudo apt-get install -y \
    squashfs-tools xorriso isolinux syslinux-utils rsync wget \
    qemu-system-x86 qemu-utils
```

- En az **20 GB** bos disk alani / at least **20 GB** free disk space
- En az **4 GB** RAM (derleme sirasinda) / at least **4 GB** RAM (during build)
- Internet baglantisi (chroot icinde paket kurulumu icin) / internet access
  (for package installation inside the chroot)

`build.sh` bu araclarin varligini otomatik olarak kontrol eder ve eksik olani
soyler (bkz. `scripts/00-check-host-requirements.sh`).
`build.sh` automatically checks for these tools and reports anything missing
(see `scripts/00-check-host-requirements.sh`).

---

## Proje Yapisi / Project Structure

```
CocukOS/
├── build.sh                          # Ana derleme scripti / Main build script
├── README.md
├── config/
│   └── whitelist.txt                 # Varsayilan izinli site listesi
├── scripts/
│   ├── lib/common.sh                 # Ortak fonksiyonlar (log, hata vb.)
│   ├── 00-check-host-requirements.sh # Host arac kontrolu
│   ├── 01-extract-iso.sh             # ISO -> squashfs-root cikartma
│   ├── 02-chroot-prepare.sh          # Chroot baglama + payload kopyalama
│   ├── 03-inside-chroot.sh           # Chroot icinde calisan asil kurulum
│   ├── 04-repack-iso.sh              # squashfs + ISO yeniden paketleme
│   ├── 05-checksum.sh                # SHA256 uretimi
│   └── 06-verify-lockdown.sh         # Guvenlik dogrulama (ISO'dan ONCE)
├── chroot-payload/                   # Chroot icine aynen kopyalanan dosyalar
│   ├── etc/cocukos/whitelist.txt
│   ├── etc/polkit-1/rules.d/51-cocukos.rules
│   ├── etc/skel-cocuk/Desktop/*.desktop
│   ├── etc/skel-ebeveyn/Desktop/*.desktop
│   └── usr/local/sbin/cocukos-*.sh
└── test/
    ├── qemu-test.sh                  # QEMU ile hizli test
    └── virtualbox-test.md            # VirtualBox ile test talimati
```

---

## Kullanim / Usage

```bash
chmod +x build.sh scripts/*.sh test/*.sh
sudo ./build.sh /path/to/ubuntu-26.04.1-desktop-amd64.iso
```

ISO'yu elle indirmek istemiyorsaniz, `auto` yazarak resmi ISO'nun otomatik
indirilmesini de saglayabilirsiniz (bu, GitHub Actions workflow'unun da
kullandigi moddur):

If you don't want to download the ISO by hand, pass `auto` to have the
official ISO downloaded automatically (this is also the mode the GitHub
Actions workflow uses):

```bash
sudo ./build.sh auto
```

Derleme basariyla tamamlaninca / When the build finishes successfully:

```
output/CocukOS-26.04.1-amd64.iso
output/CocukOS-26.04.1-amd64.iso.sha256
```

### Test etme / Testing

QEMU ile (hizli) / with QEMU (fast):
```bash
./test/qemu-test.sh output/CocukOS-26.04.1-amd64.iso
```

VirtualBox ile / with VirtualBox: `test/virtualbox-test.md` dosyasina bakin /
see `test/virtualbox-test.md`.

### USB'ye yazma / Writing to USB

ISO, `isohybrid` ile hibrit hale getirildigi icin dogrudan bir USB bellege
yazilabilir (Linux):

The ISO is made hybrid with `isohybrid`, so it can be written directly to a
USB drive (Linux):

```bash
sudo dd if=output/CocukOS-26.04.1-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

`/dev/sdX` yerine gercek USB aygitinizi yazin (ornegin `/dev/sdb`) — **yanlis
aygit secmek veri kaybina yol acar**, `lsblk` ile once dogrulayin.

Replace `/dev/sdX` with your actual USB device (e.g. `/dev/sdb`) — **choosing
the wrong device will cause data loss**, verify with `lsblk` first.

Windows'ta [Rufus](https://rufus.ie) ile "DD Image mode" secilerek de
yazilabilir.

---

## Internet Kisitlamasi Nasil Calisir? / How Does the Internet Restriction Work?

Kisitlama tek bir katmana degil, **uc bagimsiz katmana** dayanir; biri
atlatilsa bile digerleri devrede kalir:

The restriction relies on **three independent layers**, not just one; if one
is bypassed, the others still hold:

1. **DNS seviyesi (dnsmasq):** `cocuk` hesabinin kullandigi tek DNS sunucusu
   yerel `dnsmasq`'tir (`/etc/resolv.conf` -> `127.0.0.1`). Varsayilan olarak
   **her alan adi** `0.0.0.0`'a (yani "baglanti yok") cozulur; yalnizca
   `/etc/cocukos/whitelist.txt` icindeki alan adlari (ve alt alan adlari)
   gercek IP adreslerine cozulur.

   **DNS level (dnsmasq):** the only DNS server the `cocuk` account can use
   is the local `dnsmasq` (`/etc/resolv.conf` -> `127.0.0.1`). By default
   **every domain** resolves to `0.0.0.0` (i.e. "no connection"); only the
   domains listed in `/etc/cocukos/whitelist.txt` (and their subdomains)
   resolve to real IP addresses.

2. **Firewall seviyesi (nftables):** `cocuk` kullanicisinin UID'sine gore:
   - Yerel DNS (127.0.0.1:53) ve yerel proxy (127.0.0.1:3128/3129) disinda
     **dogrudan** 80/443 cikisi engellenir (`drop`) — yani sadece DNS'i
     atlatmak yetmez, trafik zaten yerel proxy'ye yonlendirilmek
     **zorundadir** (`redirect`).
   - DNS-over-HTTPS/DNS-over-TLS icin bilinen 853 portu ve baska DNS
     sunuculara (53) dogrudan sorgu **engellenir**, boylece filtre
     DNS seviyesinde atlatilamaz.

   **Firewall level (nftables):** based on the `cocuk` user's UID:
   - Direct 80/443 egress is dropped except to the local DNS
     (127.0.0.1:53) and local proxy (127.0.0.1:3128/3129) — traffic is
     forced through the local proxy via `redirect`, so bypassing DNS alone
     is not enough.
   - The well-known DoH/DoT port (853) and direct queries to other DNS
     servers (53) are dropped, so the filter cannot be bypassed at the DNS
     level either.

3. **Proxy seviyesi (Squid, SNI bazli):** HTTPS baglantilari `ssl_bump peek`
   ile **sertifika/icerik cozulmeden** yalnizca istenen sunucu adina (SNI)
   bakilarak beyaz listeye gore ya `splice` (izin ver, sifreli sekilde ilet)
   ya da sonlandirilir. Bu sayede tarayici IP adresi degistirilerek veya
   `/etc/hosts` manipule edilerek filtre atlatilmaya calisilsa bile, Squid
   bagimsiz olarak istenen alan adini kontrol eder.

   **Proxy level (Squid, SNI-based):** HTTPS connections are peeked via
   `ssl_bump peek` — **without decrypting certificates/content** — and
   either `splice`d (allowed, forwarded encrypted) or terminated based on
   the requested server name (SNI) against the whitelist. This means even
   if someone tries to bypass the filter by changing the browser's target
   IP or editing `/etc/hosts`, Squid independently checks the requested
   domain name.

Ayrica / Additionally:

- Firefox, `policies.json` ile proxy ayarlarini **kilitli** (`Locked: true`)
  sekilde kullanir; `cocuk` hesabi bu ayari degistiremez, `about:config`'e
  erisemez, gelistirici araclarini acamaz.
  Firefox uses the proxy settings **locked** via `policies.json`; the
  `cocuk` account cannot change this setting, access `about:config`, or open
  developer tools.
- `polkit` kurali, `cocuk` kullanicisinin **hicbir** yonetici yetkisi
  gerektiren islemi (agi degistirmek, paket kurmak, kullanici eklemek/
  silmek dahil) gerceklestirmesini engeller.
  A `polkit` rule blocks the `cocuk` user from performing **any** action
  that requires administrator authorization (including changing network
  settings, installing packages, adding/removing users).
- `cocuk` hesabinda `sudo`/`adm` grubu **yoktur**; bu, derleme sirasinda
  `scripts/06-verify-lockdown.sh` tarafindan otomatik olarak dogrulanir ve
  basarisiz olursa ISO **uretilmez**.
  The `cocuk` account is **not** in the `sudo`/`adm` group; this is
  automatically verified during the build by
  `scripts/06-verify-lockdown.sh`, and the ISO is **not** produced if the
  check fails.

### Izin listesini degistirme / Changing the allowed-sites list

Yalnizca **Ebeveyn** hesabindan / Only from the **Ebeveyn (parent)** account:

- Masaustundeki "CocukOS Internet Ayarlari" kisayolu (grafik arayuz), veya
  the "CocukOS Internet Settings" desktop shortcut (graphical), or
- Terminalden / from the terminal:
  ```bash
  sudo nano /etc/cocukos/whitelist.txt   # listeyi duzenle / edit the list
  sudo /usr/local/sbin/cocukos-guncelle-liste.sh   # degisikligi uygula / apply changes
  ```

---

## Bilinen Sinirlamalar / Known Limitations

- SNI bazli filtreleme, TLS 1.3 ile bazi tarayicilarda kullanilan
  "Encrypted Client Hello (ECH)" ozelligini henuz hesaba katmaz; ECH
  yayginlastikca ek bir Squid/DNS kurali guncellemesi gerekebilir.
  SNI-based filtering does not yet account for the "Encrypted Client Hello
  (ECH)" feature used by some browsers with TLS 1.3; as ECH becomes more
  widespread, an additional Squid/DNS rule update may be needed.
- Cocuk hesabina VPN/Tor gibi bir uygulama **elle** kurulursa (ki paket
  kurma yetkisi olmadigi icin normal kosullarda mumkun degildir) filtre
  atlatilabilir; bu yuzden paket kurma yetkisinin kisitli kalmasi kritik
  onemdedir.
  If a VPN/Tor-like application were **manually** installed on the child
  account (which is not normally possible since it lacks package-install
  rights), the filter could be bypassed; this is why keeping package
  installation restricted is critical.
