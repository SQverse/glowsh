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

### 👋 Sapaan saat terminal dibuka

```
  ☀ Selamat sore, HP!   Sabtu, 21 November 2026  |  baterai 78%
  Tip: "glowsh wallpaper" membuat tema dari wallpaper kamu
```

### 🩺 Glowsh Doctor

Ikon tampil sebagai kotak? Font tidak berubah? `glowsh doctor` mengecek semuanya: font, Windows Terminal, profil, Execution Policy, Clink, sampai pengaturan per-profil yang diam-diam menimpa tema. Sebagian besar masalah **bisa diperbaiki otomatis** cukup dengan menjawab `Y`.

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
| `glowsh doctor` | cek & perbaiki masalah tampilan |
| `glowsh settings` | lihat semua fitur dan statusnya |
| `glowsh <fitur> on\|off` | nyalakan/matikan `greet`, `auto`, `seasonal`, `notify`, `typo`, `guard` |
| `glowsh notify <detik>` · `glowsh notify test` | batas waktu notifikasi / kirim notifikasi uji |
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
