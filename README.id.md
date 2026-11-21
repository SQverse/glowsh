# ✨ Glowsh

[English](README.md) · **Bahasa Indonesia**

Bikin PowerShell & Command Prompt kamu jauh lebih cantik **cukup dengan satu perintah**, sekaligus jadi terminal yang benar-benar membantu.

Tidak perlu admin, Microsoft Store, maupun winget, dan semua perubahan bisa dikembalikan seperti semula kapan saja.

## 🚀 Install

**PowerShell:**

```powershell
irm https://raw.githubusercontent.com/SQverse/glowsh/main/install.ps1 | iex
```

**Command Prompt (CMD):**

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/SQverse/glowsh/main/install.ps1 | iex"
```

Pilih bahasa, pilih tema pakai tombol panah (ada preview-nya), ketik `Y`, lalu buka **Windows Terminal**. Selesai! 🎉

## ✨ Fitur

### 🎨 Tema dengan preview langsung

```powershell
glowsh theme          # pilih pakai panah, ada preview-nya
glowsh theme neon     # langsung pakai
```

| Nama | Nuansa |
|---|---|
| `senja` | jingga & ungu langit sore |
| `neon` | cyberpunk, kota malam penuh lampu |
| `laut` | biru toska laut tropis & karang |
| `pagi` | terang & segar untuk pagi hari |
| `dracula` · `catppuccin` · `tokyonight` | tema klasik |

### 🖼️ Tema dari wallpaper kamu

```powershell
glowsh wallpaper                 # pakai wallpaper desktop sekarang
glowsh wallpaper .\foto.jpg      # atau gambar apa saja
```

Glowsh membaca warna-warna dominan dari gambar, lalu membuat tema terminal yang serasi. Setiap orang dapat tema yang unik.

### 🔗 Bagikan tema lewat kode pendek

```powershell
glowsh share
# -> GLW-AQALChrg5v__LogA8P-4Tf__5F49_6L_Lohuap5OZW9u   (otomatis tersalin ke clipboard)

glowsh import GLW-AQALChrg5v__LogA8P-4Tf__5F49_6L_Lohuap5OZW9u
```

### 🌗 Tema yang mengikuti jam & kalender

- `glowsh auto on`: pagi pakai **Pagi**, sore **Senja**, malam **Neon**
- **Tema musiman** aktif dengan sendirinya: merah-putih tanggal 16–18 Agustus, hijau-emas selama Ramadan, dan kembang api saat Tahun Baru. Kalau kamu memilih tema sendiri, pilihanmu yang dipakai.

### 🧠 Bantuan salah ketik

```
❯ gti status
  Perintah 'gti' tidak dikenal. Mungkin maksud kamu: git
  Jalankan? [Y/n]
```

Kebiasaan Linux juga dibantu: ketik `touch`, `grep`, `which`, `nano`, `open`, dan lainnya, maka Glowsh menawarkan padanannya di Windows. Salah ketik git seperti `git pusj` dibantu fitur bawaan git ("maksudnya `push`?").

### 🛡️ Pengaman perintah berbahaya

```
❯ rm -rf node_modules
  [!] Menghapus folder beserta SELURUH isinya. Tidak masuk Recycle Bin dan tidak bisa di-undo.
  Tetap jalankan? [y/N]
```

Pengaman ini mencakup hapus rekursif, `format`, `diskpart`, `git reset --hard`, `git push --force`, `git clean -f`, dan perintah shutdown.

### 📖 Penjelasan perintah dalam bahasa awam

```
❯ glowsh explain git push -u origin main
  git push
  Mengirim commit ke remote (misalnya GitHub).
  Opsi yang dipakai:
    -u         set upstream: ingat remote/branch untuk push berikutnya
```

### 🔔 Notifikasi saat perintah lama selesai

Perintah yang berjalan 30 detik atau lebih akan memunculkan notifikasi Windows seperti *"✅ Perintah selesai: npm install (2m 14s)"*. Batasnya bisa diubah dengan `glowsh notify 60`.

### 👋 Dashboard sapaan

Setiap terminal dibuka, muncul **logo GLOWSH** dari huruf blok dengan gradasi warna tema kamu, ditambah panel-panel yang tersusun otomatis mengikuti lebar jendela:

- **Sistem**: versi Windows, bar RAM dan disk, lama laptop menyala, serta jumlah perintah dan streak hari ini
- **Jadwal sholat** sesuai kotamu (metode Kemenag RI: Subuh 20°, Isya 18°, ihtiyath 2 menit), waktu sholat berikutnya disorot dengan hitung mundur, dihitung tanpa internet
- **Kalender**: bulan ini, tanggal hari ini disorot, hari Minggu dan libur nasional bertanggal tetap berwarna merah, **tanggal hijriah** (berganti saat Maghrib), dan **gambar bulan** yang mengikuti fase bulan hari itu
- **Quote harian** dengan 4 kategori: *lucu* (humor programmer), *hidup*, *agama*, dan *diri* (self development)
- **Folder terakhir** lengkap dengan branch git-nya; lompat lagi dengan `glowsh go 1`

```powershell
glowsh lokasi Bandung         # kota untuk jadwal sholat (atau: glowsh lokasi -6.91 107.61 Rumah)
glowsh sholat                 # jadwal sholat hari ini
glowsh hijri +1               # koreksi tanggal hijriah kalau beda dengan penetapan di Indonesia
glowsh name Abid              # nama di prompt & sapaan
glowsh quote agama            # quote acak dari satu kategori
glowsh quote kinds lucu,hidup # kategori yang dipakai quote harian
glowsh quote mode acak        # quote baru setiap terminal dibuka (bawaan: harian)
glowsh go                     # daftar folder terakhir, lalu: glowsh go 2 / glowsh go web
glowsh calendar off           # tiap panel bisa dimatikan: logo, sysinfo, calendar, quote, recent
```

### 🩺 Glowsh Doctor

Ikon tampil sebagai kotak? Font tidak berubah? `glowsh doctor` mengecek semuanya: font, Windows Terminal, profil, Execution Policy, Clink, sampai pengaturan per-profil yang diam-diam menimpa tema. Sebagian besar masalah **bisa diperbaiki otomatis** cukup dengan menjawab `Y`.

### 🎁 Glowsh Wrapped: rekap tahunan terminal kamu

```powershell
glowsh wrapped
```

Mirip Spotify Wrapped, tapi untuk terminal: total perintah, 5 perintah favorit, subperintah andalan, streak terpanjang, jam paling produktif, tingkat sukses, salah ketik yang diselamatkan Glowsh, dan persona terminal kamu (*Anak Malam*, *Raja Commit*, ...). Glowsh juga bisa menyimpannya sebagai **gambar 1080×1920** untuk story IG.

> 🔒 Glowsh hanya mencatat **nama perintahnya** (misalnya `git push` atau `curl`), tidak pernah argumennya, jadi token atau password yang terketik di perintah tidak pernah tersimpan. Datanya hanya ada di laptop kamu, di `~\.glowsh\stats.log`. Matikan dengan `glowsh stats off`.

### 🩹 `glowsh why`: penjelasan error terakhir

```
❯ npm start
  Error: listen EADDRINUSE: address already in use :::3000
❯ glowsh why
  Port sedang dipakai
  Port 3000 sudah dipakai program lain, biasanya server yang masih jalan di tab lain.
  Coba ini:
    1. Cari pemakainya: Get-NetTCPConnection -LocalPort 3000 | Select-Object OwningProcess
    2. Hentikan: Stop-Process -Id <OwningProcess>
```

Mengenali sekitar 20 error umum: port terpakai, modul tidak ditemukan, push ditolak, merge conflict, login git gagal, script diblokir, masalah jaringan dan SSL, dan lainnya. Untuk error dari program lain, copy pesannya (seleksi lalu Ctrl+C) lalu jalankan `glowsh why`, atau tempel langsung: `glowsh why "pesan error"`.

### 🖼️ Galeri tema komunitas

```powershell
glowsh browse          # jelajahi & pasang tema buatan komunitas, ada preview-nya
glowsh submit          # kirim tema kamu ke galeri
```

`glowsh submit` membuka GitHub Issue yang sudah terisi kode temamu. Tema yang disetujui dimasukkan ke [`themes/community.json`](themes/community.json) dan muncul di `glowsh browse` semua orang.

### 🌏 Dua bahasa

Seluruh tampilan tersedia dalam **Bahasa Indonesia** dan **English**. Ganti kapan saja dengan `glowsh lang id` / `glowsh lang en`.

## 📋 Semua perintah

| Perintah | Fungsi |
|---|---|
| `glowsh theme [nama\|list]` | pilih / pakai / daftar tema |
| `glowsh wallpaper [file]` | buat tema dari wallpaper |
| `glowsh share [nama]` | bagikan tema sebagai kode |
| `glowsh import <kode> [nama]` | pasang tema dari kode |
| `glowsh explain <perintah>` | jelaskan sebuah perintah |
| `glowsh why ["error"]` | jelaskan error terakhir dan solusinya |
| `glowsh wrapped [tahun]` | rekap tahunan terminal kamu (+ gambar story IG) |
| `glowsh browse` | galeri tema komunitas |
| `glowsh submit [nama]` | kirim tema ke galeri |
| `glowsh doctor` | cek & perbaiki masalah tampilan |
| `glowsh settings` | lihat semua fitur dan statusnya |
| `glowsh quote [kategori]` · `glowsh quote kinds <daftar>` | quote acak / pilih kategori quote harian |
| `glowsh go [nomor\|nama]` | lompat ke folder yang baru dibuka |
| `glowsh lokasi <kota>` · `glowsh sholat` | atur lokasi / lihat jadwal sholat hari ini |
| `glowsh hijri [+1\|-1\|0]` | tanggal hijriah dan koreksinya |
| `glowsh <fitur> on\|off` | nyalakan/matikan `greet`, `logo`, `sysinfo`, `sholat`, `calendar`, `moon`, `quote`, `recent`, `auto`, `seasonal`, `notify`, `typo`, `guard`, `stats` |
| `glowsh notify <detik>` · `glowsh notify test` | batas waktu notifikasi / kirim notifikasi uji |
| `glowsh name <nama>` · `glowsh name reset` | ganti nama di prompt & sapaan (tersimpan, bisa diubah kapan saja) |
| `glowsh lang id\|en` | ganti bahasa |
| `glowsh update` | update ke versi terbaru |
| `glowsh uninstall` | kembalikan tampilan seperti semula |

## 🔧 Apa saja yang dipasang?

- **Prompt cantik** dengan [Oh My Posh](https://ohmyposh.dev): ikon, git branch, status error, durasi perintah, dan jam
- **Nerd Font** (Meslo) supaya ikon tampil dengan benar
- **Ikon file & folder** saat `ls` / `dir` lewat [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
- **Saran perintah otomatis** dari riwayat ([PSReadLine](https://github.com/PowerShell/PSReadLine), diperbarui kalau perlu)
- **CMD ikut cantik** dengan prompt yang sama + autocomplete lewat [Clink](https://github.com/chrisant996/clink)
- **Windows Terminal**: diinstall otomatis kalau belum ada (rilis resmi Microsoft dari GitHub), lengkap dengan skema warna, font, dan efek transparan
- **Perintah `glowsh`**, bisa dipakai di PowerShell maupun CMD

Semua file Glowsh ada di `~\.glowsh`. Pengaturan asli kamu di-backup ke `~\.glowsh\backup-original` sebelum ada yang diubah.

> 💡 Ikon & font Nerd Font hanya tampil di **Windows Terminal**, tidak di jendela CMD/PowerShell klasik.

## ↩️ Uninstall

```powershell
glowsh uninstall
```

Atau tanpa perintah `glowsh`:

```powershell
irm https://raw.githubusercontent.com/SQverse/glowsh/main/uninstall.ps1 | iex
```

## 🔒 Keamanan

Menjalankan script dari internet selalu butuh kepercayaan. Karena itu, script Glowsh:

- ditulis polos tanpa obfuscation, jadi bisa kamu baca sendiri sebelum dijalankan ([install.ps1](install.ps1), [glowsh.ps1](glowsh.ps1)),
- menampilkan daftar perubahan dan meminta konfirmasi dulu,
- tidak butuh hak admin,
- membuat backup sebelum mengubah apa pun (termasuk nilai `help.autocorrect` git kamu),
- hanya mengunduh dari sumber resmi (GitHub Microsoft, Oh My Posh, Clink, PowerShell Gallery).

## ✅ Kebutuhan

- Windows 10 (build 19041+) atau Windows 11
- Windows PowerShell 5.1 (bawaan Windows) atau PowerShell 7+

## 🛠️ Development

| File | Isi |
|---|---|
| `install.ps1` | urutan instalasi (tipis, memanggil fungsi di `glowsh.ps1`) |
| `glowsh.ps1` | semua logika: tema, pemilih tema, wallpaper, share, explain, doctor, pengaturan, dan template `~\.glowsh\shell.ps1` |
| `uninstall.ps1` | mengembalikan semuanya (berdiri sendiri, bisa jalan via `iex`) |

`shell.ps1` dibuat dari `glowsh.ps1` saat install, dan file inilah yang dimuat oleh profil PowerShell. Isinya sapaan, bantuan salah ketik, pengaman, notifikasi, dan pergantian tema otomatis.

Test lokal tanpa GitHub:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Opsi non-interaktif: `$env:GLOWSH_LANG = 'id'; $env:GLOWSH_THEME = 'neon'; $env:GLOWSH_YES = '1'`

## 🗺️ Roadmap

- [ ] Lebih banyak tema khas Glowsh
- [ ] Jadwal kustom untuk `glowsh auto`
- [ ] Startup lebih cepat dengan cache prompt
