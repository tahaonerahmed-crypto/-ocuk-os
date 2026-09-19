# CocukOS - VirtualBox ile Test / Testing with VirtualBox

## Turkce

1. VirtualBox'i acin, "Yeni" (New) diyerek yeni bir sanal makine olusturun.
   - Tur: Linux, Surum: Ubuntu (64-bit)
   - RAM: en az 4096 MB
   - Disk: en az 20 GB (VDI, dinamik ayrilan)
2. Sanal makineyi olusturduktan sonra Ayarlar (Settings) > Depolama (Storage)
   kismina gidin.
3. "Bos" (Empty) optik surucuye tiklayin, sag tarafta disk simgesine tiklayip
   uretilen `CocukOS-26.04.1-amd64.iso` dosyasini secin.
4. Ayarlar > Sistem > Islemci kisminda en az 2 cekirdek ayirin.
5. Ayarlar > Ekran kisminda video bellegini en az 64MB yapin ve
   3D hizlandirmayi etkinlestirin (varsa).
6. Sanal makineyi baslatin. Sistem otomatik olarak "cocuk" hesabiyla
   masaustune gececektir (varsayilan otomatik giris).
7. Ebeveyn hesabina gecmek icin: sag ust kullanici menusunden oturumu kapatip
   giris ekraninda "ebeveyn" kullanicisini secin.
   - Ilk sifre: `ebeveyn123` (ilk giriste degistirmeniz istenecektir)

## English

1. Open VirtualBox and click "New" to create a virtual machine.
   - Type: Linux, Version: Ubuntu (64-bit)
   - RAM: at least 4096 MB
   - Disk: at least 20 GB (VDI, dynamically allocated)
2. After creating the VM, go to Settings > Storage.
3. Click the "Empty" optical drive, then click the disk icon on the right
   and select the built `CocukOS-26.04.1-amd64.iso` file.
4. In Settings > System > Processor, allocate at least 2 cores.
5. In Settings > Display, set video memory to at least 64MB and enable
   3D acceleration if available.
6. Start the VM. It should boot straight to the "cocuk" (child) desktop
   (automatic login is enabled by default).
7. To switch to the parent account: log out from the top-right user menu,
   then select "ebeveyn" on the login screen.
   - Initial password: `ebeveyn123` (you'll be asked to change it on first login)

## Test edilmesi gereken noktalar / What to verify

- [ ] Cocuk hesabinda terminal acilamiyor / Terminal cannot be opened from the child account
- [ ] Cocuk hesabinda `sudo` calismiyor / `sudo` does not work from the child account
- [ ] Firefox sadece whitelist'teki siteleri aciyor / Firefox only opens whitelisted sites
- [ ] Whitelist disi bir site (ornegin youtube.com) acilamiyor / A non-whitelisted site (e.g. youtube.com) cannot be opened
- [ ] Ebeveyn hesabindan whitelist duzenlenip degisiklik hemen etkili oluyor
      / Editing the whitelist from the Ebeveyn account takes effect immediately
- [ ] Ebeveyn hesabi sudo ile paket kurabiliyor / Ebeveyn account can install packages with sudo
