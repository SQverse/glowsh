<#
    Glowsh - bikin PowerShell & CMD kamu lebih cantik dalam satu perintah.

    Install (dari PowerShell):
        irm https://raw.githubusercontent.com/USERNAME/glowsh/main/install.ps1 | iex

    Install (dari CMD):
        powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/USERNAME/glowsh/main/install.ps1 | iex"

    Opsi (opsional, lewat environment variable):
        $env:GLOWSH_THEME = 'neon'  # pilih tema langsung tanpa menu (nama atau nomor)
        $env:GLOWSH_YES   = '1'     # jawab semua pertanyaan dengan pilihan default

    Catatan untuk developer: file ini sengaja ASCII-only supaya aman dibaca
    Windows PowerShell 5.1, dan isinya dibungkus & { ... } supaya variabelnya
    tidak "bocor" ke sesi user saat dijalankan via iex. Semua logika ada di
    glowsh.ps1; file ini hanya mengatur urutan instalasi.
#>

$__glowshSource = $PSScriptRoot   # kosong kalau dijalankan lewat irm | iex
& {
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # Invoke-WebRequest jauh lebih cepat tanpa progress bar di PS 5.1
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$RepoRawUrl = 'https://raw.githubusercontent.com/USERNAME/glowsh/main'
$src = $__glowshSource
Remove-Variable -Name __glowshSource -Scope 1 -ErrorAction SilentlyContinue

# ============================================================ 0. ambil file Glowsh
# Dari folder lokal kalau installer dijalankan sebagai file, kalau tidak dari GitHub.
$staging = Join-Path $env:TEMP "glowsh-setup-$PID"
New-Item -ItemType Directory -Path $staging -Force | Out-Null
try {
    foreach ($f in 'glowsh.ps1', 'uninstall.ps1') {
        $local = if ($src) { Join-Path $src $f } else { $null }
        if ($local -and (Test-Path $local)) { Copy-Item $local (Join-Path $staging $f) -Force }
        else { Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawUrl/$f" -OutFile (Join-Path $staging $f) }
    }
} catch {
    Write-Host "  Gagal mengambil file Glowsh: $($_.Exception.Message)" -ForegroundColor Red
    return
}
# Dimuat sebagai scriptblock supaya tidak terhalang Execution Policy
$GlowshAsLibrary = $true
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $staging 'glowsh.ps1'))))

# ============================================================ 1. pembuka & pilih tema
Write-Banner
if ($env:OS -ne 'Windows_NT') { Write-Bad 'Glowsh hanya untuk Windows.'; return }
if ($PSVersionTable.PSVersion -lt [version]'5.1') { Write-Bad 'Butuh PowerShell 5.1 atau lebih baru.'; return }

$themeId = Resolve-GlowshThemeId $env:GLOWSH_THEME
if (-not $themeId) {
    Write-Host '  Pertama, pilih tema favorit kamu. Tekan Enter untuk mulai...' -ForegroundColor White
    [void](Read-Host)
    $themeId = Show-ThemePicker 'senja'
    if (-not $themeId) { Write-Note 'Dibatalkan. Tidak ada yang diubah.'; return }
}
$theme = $GlowshThemes[$themeId]

# ============================================================ 2. konfirmasi
$hasWT = Test-WindowsTerminal
Write-Host ''
Write-Host "  Tema dipilih: $($theme.Title)" -ForegroundColor Magenta
Write-Host '  Yang akan dilakukan (tanpa perlu admin):' -ForegroundColor White
Write-Host '    - backup pengaturan lama ke ~\.glowsh\backup-original'
Write-Host '    - download Oh My Posh (prompt cantik) ke ~\.glowsh\bin'
Write-Host "    - install font '$FontFace' untuk user ini"
Write-Host '    - install modul Terminal-Icons (ikon file saat ls / dir)'
Write-Host '    - install Clink supaya CMD juga punya prompt cantik + autocomplete'
Write-Host '    - menambah perintah "glowsh" (ganti tema, doctor, uninstall)'
Write-Host '    - menambah blok Glowsh di profil PowerShell kamu'
Write-Host '    - set Execution Policy CurrentUser ke RemoteSigned (kalau masih Restricted)'
if ($hasWT) { Write-Host '    - menerapkan tema, font & transparansi ke Windows Terminal' }
else        { Write-Host '    - (Windows Terminal belum ada - akan ditawarkan untuk install)' }
Write-Host '    - mengubah warna console klasik (cmd / powershell lama)'
Write-Host ''
if (-not (Read-YesNo 'Lanjut?')) { Write-Note 'Dibatalkan. Tidak ada yang diubah.'; return }

$warnings = 0
New-Item -ItemType Directory -Path $GlowHome, $BinDir, $BackupDir, $ThemeDir -Force | Out-Null
foreach ($f in 'glowsh.ps1', 'uninstall.ps1') { Copy-Item (Join-Path $staging $f) (Join-Path $GlowHome $f) -Force }
Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================ 3. backup (hanya sekali, saat pertama install)
Write-Step 'Backup pengaturan asli'
try {
    $consoleBackup = Join-Path $BackupDir 'console.json'
    if (-not (Test-Path $consoleBackup)) {
        $orig = [ordered]@{}
        foreach ($n in (@(0..15 | ForEach-Object { 'ColorTable{0:D2}' -f $_ }) + 'ScreenColors')) {
            $orig[$n] = (Get-ItemProperty -Path $ConsoleKey -Name $n -ErrorAction SilentlyContinue).$n
        }
        Write-Utf8NoBom $consoleBackup ($orig | ConvertTo-Json)
    }
    $policyBackup = Join-Path $BackupDir 'executionpolicy.txt'
    if (-not (Test-Path $policyBackup)) {
        Write-Utf8NoBom $policyBackup ([string](Get-ExecutionPolicy -Scope CurrentUser))
    }
    foreach ($key in $WtTargets.Keys) {
        $from = $WtTargets[$key]; $to = Join-Path $BackupDir "wt-$key.json"
        if ((Test-Path $from) -and -not (Test-Path $to)) { Copy-Item $from $to }
    }
    $i = 0
    foreach ($p in Get-ProfileTargets) {
        $i++; $to = Join-Path $BackupDir "profile-$i.ps1"
        if ((Test-Path $p) -and -not (Test-Path $to)) { Copy-Item $p $to }
    }
    Write-Ok "Tersimpan di $BackupDir"
} catch { Write-Bad "Backup gagal: $($_.Exception.Message)"; Write-Note 'Demi keamanan, instalasi dihentikan.'; return }

# ============================================================ 4. execution policy
Write-Step 'Cek Execution Policy (supaya profil PowerShell boleh jalan)'
try {
    $pol = Get-GlowshPolicyState
    if ($pol.Policy -in 'RemoteSigned', 'Unrestricted', 'Bypass') { Write-Ok "Sudah oke ($($pol.Policy))" }
    elseif ($pol.Gpo) { Write-Note "Dikunci Group Policy ($($pol.Policy)). Profil mungkin tidak bisa jalan."; $warnings++ }
    else { Set-GlowshPolicy; Write-Ok 'CurrentUser -> RemoteSigned' }
} catch { Write-Bad $_.Exception.Message; $warnings++ }

# ============================================================ 5. komponen
Write-Step 'Download Oh My Posh'
try { Write-Ok "Versi $(Install-GlowshOmp)" } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }

Write-Step 'Download tema klasik (supaya bisa ganti tema tanpa internet)'
try { Save-GlowshClassicThemes; Write-Ok $ThemeDir } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }

Write-Step "Install font $FontFace"
if (Test-FontInstalled) { Write-Ok 'Sudah terpasang' }
else {
    try { Install-GlowshFont; Write-Ok 'Font terpasang (per-user)' }
    catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }
}

Write-Step 'Install modul Terminal-Icons'
try { Install-GlowshTerminalIcons; Write-Ok 'Siap' } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }

Write-Step 'Pasang prompt cantik di CMD (via Clink)'
try { Install-GlowshClink; Write-Ok 'Clink aktif untuk jendela CMD baru' } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }

Write-Step 'Pasang perintah "glowsh"'
try { Install-GlowshCommand; Write-Ok 'Bisa dipakai dari PowerShell & CMD' } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }

Write-Step 'Pasang Glowsh di profil PowerShell'
try { Install-GlowshProfile } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }

# ============================================================ 6. windows terminal
Write-Step 'Windows Terminal'
if ($hasWT) { Write-Ok 'Sudah terpasang' }
else {
    Write-Note 'Windows Terminal belum terpasang. Ikon & tema paling bagus tampil di sana.'
    if (Read-YesNo 'Install Windows Terminal sekarang? (rilis resmi Microsoft dari GitHub, tanpa Store, ~12 MB)') {
        try {
            $ver = Install-PortableTerminal
            $hasWT = $true
            Write-Ok "Windows Terminal $ver terpasang di $WtPortableDir"
            Write-Ok 'Shortcut "Windows Terminal" dibuat di Start Menu & Desktop'
        } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }
    }
}

# ============================================================ 7. terapkan tema
Write-Step "Terapkan tema $($theme.Title)"
$warnings += Set-GlowshTheme $themeId

# ============================================================ selesai
Write-Host ''
if ($warnings -eq 0) { Write-Host '  Selesai! Terminal kamu sekarang lebih glowing.' -ForegroundColor Green }
else { Write-Host "  Selesai dengan $warnings peringatan (lihat tanda [X] / [!] di atas)." -ForegroundColor Yellow }
Write-Host ''
Write-Host '  PENTING: ikon & font hanya tampil di Windows Terminal, bukan di jendela CMD/PowerShell biasa.' -ForegroundColor Yellow
Write-Host ''
Write-Host '  Coba perintah ini di Windows Terminal:' -ForegroundColor White
Write-Host '    glowsh theme    ' -NoNewline -ForegroundColor Cyan; Write-Host 'ganti tema dengan preview'
Write-Host '    glowsh doctor   ' -NoNewline -ForegroundColor Cyan; Write-Host 'cek & perbaiki kalau ada yang aneh'
Write-Host '    glowsh          ' -NoNewline -ForegroundColor Cyan; Write-Host 'lihat semua perintah'
Write-Host ''
if ($hasWT -and (Read-YesNo 'Buka Windows Terminal sekarang untuk lihat hasilnya?')) {
    try { Start-GlowshTerminal } catch { Write-Note 'Gagal membuka otomatis. Buka "Windows Terminal" dari Start Menu.' }
}
Write-Host ''
}
