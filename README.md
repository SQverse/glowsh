# ✨ Glowsh

Bikin PowerShell & Command Prompt kamu jauh lebih cantik, **cukup dengan satu perintah**.

Tidak perlu admin, Microsoft Store, maupun winget, dan semua perubahan bisa dikembalikan seperti semula kapan saja.

## 🚀 Install

**PowerShell:**

```powershell
irm https://raw.githubusercontent.com/USERNAME/glowsh/main/install.ps1 | iex
```

**Command Prompt (CMD):**

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/USERNAME/glowsh/main/install.ps1 | iex"
```

Pilih tema pakai tombol panah (ada preview-nya), ketik `Y`, lalu buka **Windows Terminal**. Selesai! 🎉

## 🎨 Tema

**Tema khas Glowsh**, dengan prompt yang didesain khusus:

| Nama | Nuansa |
|---|---|
| `senja` | jingga & ungu langit sore |
| `neon` | cyberpunk, kota malam penuh lampu |
| `laut` | biru toska laut tropis & karang |

**Tema klasik:** `dracula`, `catppuccin`, `tokyonight`

Ganti tema kapan saja, tanpa install ulang:

```powershell
glowsh theme          # pilih dengan preview
glowsh theme neon     # langsung pakai
```

## 🩺 Glowsh Doctor

Ikon tampil sebagai kotak? Font tidak berubah? Jalankan:

```powershell
glowsh doctor
```

Doctor mengecek font, Windows Terminal, profil PowerShell, Execution Policy, Clink, sampai pengaturan per-profil yang diam-diam menimpa tema. Hasilnya dijelaskan dalam bahasa yang mudah dipahami, dan sebagian besar masalah **bisa diperbaiki otomatis** cukup dengan menjawab `Y`.

## 🔧 Apa saja yang dipasang?

- **Prompt cantik** dengan [Oh My Posh](https://ohmyposh.dev): ikon, git branch, status error, durasi perintah, dan jam
- **Nerd Font** (Meslo) supaya ikon tampil dengan benar
- **Ikon file & folder** saat `ls` / `dir` lewat [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
- **Autocomplete prediktif** dari riwayat perintah (PSReadLine)
- **CMD ikut cantik**: prompt yang sama + autocomplete lewat [Clink](https://github.com/chrisant996/clink)
- **Windows Terminal**: diinstall otomatis kalau belum ada (rilis resmi Microsoft dari GitHub), lengkap dengan skema warna, font, dan efek transparan
- **Perintah `glowsh`** untuk ganti tema, doctor, dan uninstall

Semua file Glowsh ada di `~\.glowsh`. Pengaturan asli kamu di-backup ke `~\.glowsh\backup-original` sebelum ada yang diubah.

> 💡 Ikon & font Nerd Font hanya tampil di **Windows Terminal**, tidak di jendela CMD/PowerShell klasik.

## 📋 Semua perintah

| Perintah | Fungsi |
|---|---|
| `glowsh theme` | pilih tema dengan preview |
| `glowsh theme <nama>` | langsung pakai tema |
| `glowsh theme list` | daftar tema |
| `glowsh doctor` | cek & perbaiki masalah tampilan |
| `glowsh uninstall` | kembalikan tampilan seperti semula |
| `glowsh version` | versi Glowsh |

## ↩️ Uninstall

```powershell
glowsh uninstall
```

Atau tanpa perintah `glowsh`:

```powershell
irm https://raw.githubusercontent.com/USERNAME/glowsh/main/uninstall.ps1 | iex
```

## 🔒 Keamanan

Menjalankan script dari internet selalu butuh kepercayaan. Karena itu, script Glowsh:

- ditulis polos tanpa obfuscation, jadi bisa kamu baca sendiri sebelum dijalankan ([install.ps1](install.ps1), [glowsh.ps1](glowsh.ps1)),
- menampilkan daftar perubahan dan meminta konfirmasi dulu,
- tidak butuh hak admin,
- membuat backup sebelum mengubah apa pun,
- hanya mengunduh dari sumber resmi (GitHub Microsoft, Oh My Posh, Clink, PowerShell Gallery).

## 🛠️ Development

| File | Isi |
|---|---|
| `install.ps1` | urutan instalasi (tipis, memanggil fungsi di `glowsh.ps1`) |
| `glowsh.ps1` | tema, penerapan tema, pemilih tema, doctor, perintah `glowsh` |
| `uninstall.ps1` | mengembalikan semuanya (berdiri sendiri, bisa jalan via `iex`) |

Test lokal tanpa GitHub:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Opsi non-interaktif: `$env:GLOWSH_THEME = 'neon'; $env:GLOWSH_YES = '1'`

## 🗺️ Roadmap

- [ ] Bilingual (Indonesia / English) otomatis mengikuti bahasa Windows
- [ ] `glowsh export` / `glowsh import` untuk berbagi tema
- [ ] Startup lebih cepat dengan cache prompt
- [ ] Lebih banyak tema khas Glowsh
