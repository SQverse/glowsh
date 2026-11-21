<#
    Glowsh - bikin PowerShell & CMD kamu lebih cantik dalam satu perintah.
    Glowsh - make PowerShell & CMD glow with one command.

    Install (PowerShell):
        irm https://raw.githubusercontent.com/SQverse/glowsh/main/install.ps1 | iex

    Install (CMD):
        powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/SQverse/glowsh/main/install.ps1 | iex"

    Opsi / options (environment variables):
        $env:GLOWSH_LANG  = 'id' | 'en'   # bahasa / language
        $env:GLOWSH_THEME = 'neon'        # tema tanpa menu / theme without the picker
        $env:GLOWSH_YES   = '1'           # pakai jawaban default / accept defaults

    Catatan developer: ASCII-only (aman untuk Windows PowerShell 5.1) dan dibungkus
    & { ... } supaya variabelnya tidak bocor ke sesi user saat dijalankan via iex.
    Semua logika ada di glowsh.ps1; file ini hanya mengatur urutan instalasi.
#>

$__glowshSource = $PSScriptRoot   # kosong kalau dijalankan lewat irm | iex
& {
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # Invoke-WebRequest jauh lebih cepat tanpa progress bar di PS 5.1
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$RepoRawUrl = 'https://raw.githubusercontent.com/SQverse/glowsh/main'
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
        else { Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawUrl/${f}?t=$([DateTime]::UtcNow.Ticks)" -OutFile (Join-Path $staging $f) }   # ?t= melewati cache GitHub
    }
} catch {
    Write-Host "  Gagal mengambil file Glowsh / could not download Glowsh: $($_.Exception.Message)" -ForegroundColor Red
    return
}
# Dimuat sebagai scriptblock supaya tidak terhalang Execution Policy
$GlowshAsLibrary = $true
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $staging 'glowsh.ps1'))))

# ============================================================ 1. bahasa, pembuka & tema
if ($env:GLOWSH_LANG -in 'id', 'en') { $GlowshLang = $env:GLOWSH_LANG }
elseif (-not (Get-GlowshConfig).lang) {
    Write-Host ''
    Write-Host '  Bahasa / Language:   [1] Bahasa Indonesia   [2] English' -ForegroundColor White
    $def = if ($GlowshLang -eq 'id') { '1' } else { '2' }
    $ans = if ($env:GLOWSH_YES -eq '1') { $def } else { (Read-Host "  Pilih / choose (1/2) [$def]").Trim() }
    if (-not $ans) { $ans = $def }
    $GlowshLang = if ($ans -eq '2') { 'en' } else { 'id' }
}

Write-Banner
if ($env:OS -ne 'Windows_NT') { Write-Bad (L 'Glowsh hanya untuk Windows.' 'Glowsh only runs on Windows.'); return }
if ($PSVersionTable.PSVersion -lt [version]'5.1') { Write-Bad (L 'Butuh PowerShell 5.1 atau lebih baru.' 'Requires PowerShell 5.1 or newer.'); return }

$themeId = Resolve-GlowshThemeId $env:GLOWSH_THEME
if (-not $themeId) {
    Write-Host ('  ' + (L 'Pertama, pilih tema favorit kamu. Tekan Enter untuk mulai...' 'First, pick your favorite theme. Press Enter to start...')) -ForegroundColor White
    [void](Read-Host)
    $themeId = Show-ThemePicker 'senja'
    if (-not $themeId) { Write-Note (L 'Dibatalkan. Tidak ada yang diubah.' 'Cancelled. Nothing was changed.'); return }
}
$theme = $GlowshThemes[$themeId]

# ============================================================ 2. konfirmasi
$hasWT = Test-WindowsTerminal
Write-Host ''
Write-Host ((L '  Tema dipilih: ' '  Theme: ') + $theme.Title) -ForegroundColor Magenta
Write-Host ('  ' + (L 'Yang akan dilakukan (tanpa perlu admin):' 'What will happen (no admin needed):')) -ForegroundColor White
$plan = @(
    @('backup pengaturan lama ke ~\.glowsh\backup-original', 'back up your current settings to ~\.glowsh\backup-original'),
    @('download Oh My Posh (prompt cantik) ke ~\.glowsh\bin', 'download Oh My Posh (pretty prompt) to ~\.glowsh\bin'),
    @("install font '$FontFace' untuk user ini", "install the '$FontFace' font for this user"),
    @('install Terminal-Icons (ikon file) & update PSReadLine (saran perintah)', 'install Terminal-Icons (file icons) & update PSReadLine (suggestions)'),
    @('install Clink supaya CMD juga punya prompt cantik', 'install Clink so CMD gets the pretty prompt too'),
    @('menambah perintah "glowsh" & integrasi shell (sapaan, saran salah ketik, pengaman, notifikasi)', 'add the "glowsh" command & shell integration (greeting, typo help, guard, notifications)'),
    @('menambah blok Glowsh di profil PowerShell kamu', 'add a Glowsh block to your PowerShell profile'),
    @('set Execution Policy CurrentUser ke RemoteSigned (kalau masih Restricted)', 'set the CurrentUser Execution Policy to RemoteSigned (if Restricted)'),
    @('aktifkan saran salah ketik untuk git (help.autocorrect)', 'enable git typo suggestions (help.autocorrect)')
)
foreach ($p in $plan) { Write-Host ('    - ' + (L $p[0] $p[1])) }
if ($hasWT) { Write-Host ('    - ' + (L 'menerapkan tema, font & transparansi ke Windows Terminal' 'apply the theme, font & translucency to Windows Terminal')) }
else        { Write-Host ('    - ' + (L '(Windows Terminal belum ada - akan ditawarkan untuk install)' '(Windows Terminal is missing - you will be offered to install it)')) }
Write-Host ('    - ' + (L 'mengubah warna console klasik (cmd / powershell lama)' 'recolor the classic console (old cmd / powershell)'))
Write-Host ''
if (-not (Read-YesNo (L 'Lanjut?' 'Continue?'))) { Write-Note (L 'Dibatalkan. Tidak ada yang diubah.' 'Cancelled. Nothing was changed.'); return }

$warnings = 0
New-Item -ItemType Directory -Path $GlowHome, $BinDir, $BackupDir, $ThemeDir -Force | Out-Null
foreach ($f in 'glowsh.ps1', 'uninstall.ps1') { Copy-Item (Join-Path $staging $f) (Join-Path $GlowHome $f) -Force }
Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================ 3. backup (hanya sekali, saat pertama install)
Write-Step (L 'Backup pengaturan asli' 'Backing up your original settings')
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
    Write-Ok $BackupDir
} catch {
    Write-Bad ((L 'Backup gagal: ' 'Backup failed: ') + $_.Exception.Message)
    Write-Note (L 'Demi keamanan, instalasi dihentikan.' 'Stopping the installation to be safe.')
    return
}

# ============================================================ 4. execution policy
Write-Step (L 'Cek Execution Policy (supaya profil PowerShell boleh jalan)' 'Checking the Execution Policy (so your profile may run)')
try {
    $pol = Get-GlowshPolicyState
    if ($pol.Policy -in 'RemoteSigned', 'Unrestricted', 'Bypass') { Write-Ok $pol.Policy }
    elseif ($pol.Gpo) { Write-Note (L "Dikunci Group Policy ($($pol.Policy)). Profil mungkin tidak bisa jalan." "Locked by Group Policy ($($pol.Policy)). Your profile may not run."); $warnings++ }
    else { Set-GlowshPolicy; Write-Ok 'CurrentUser -> RemoteSigned' }
} catch { Write-Bad $_.Exception.Message; $warnings++ }

# ============================================================ 5. komponen
$stepFails = @{ n = 0 }
function Invoke-Step([string]$Title, [scriptblock]$Action) {
    Write-Step $Title
    try { $r = & $Action; Write-Ok $(if ($r) { [string]$r } else { (L 'Siap' 'Ready') }) }
    catch { Write-Bad ((L 'Gagal: ' 'Failed: ') + $_.Exception.Message); $stepFails.n++ }
}

Invoke-Step 'Oh My Posh' { "v$(Install-GlowshOmp)" }
Invoke-Step (L 'Tema klasik (supaya bisa ganti tema tanpa internet)' 'Classic themes (so you can switch offline)') { Save-GlowshClassicThemes; $ThemeDir }
Invoke-Step "Font $FontFace" { if (Test-FontInstalled) { L 'Sudah terpasang' 'Already installed' } else { Install-GlowshFont; L 'Terpasang (per-user)' 'Installed (per-user)' } }
Invoke-Step 'Terminal-Icons' { Install-GlowshTerminalIcons }
Invoke-Step (L 'PSReadLine (saran perintah otomatis)' 'PSReadLine (inline suggestions)') {
    if (Test-GlowshPSReadLine) { L 'Sudah versi terbaru' 'Already up to date' } else { Install-GlowshPSReadLine; L 'Diperbarui (aktif di terminal baru)' 'Updated (active in new terminals)' }
}
Invoke-Step (L 'Prompt cantik di CMD (Clink)' 'Pretty prompt in CMD (Clink)') { Install-GlowshClink }
Invoke-Step (L 'Perintah "glowsh"' 'The "glowsh" command') { Install-GlowshCommand; L 'Bisa dipakai dari PowerShell & CMD' 'Works in PowerShell & CMD' }
Invoke-Step (L 'Integrasi shell & pengaturan' 'Shell integration & settings') { Install-GlowshShell; Initialize-GlowshConfig $themeId; $ShellFile }
Invoke-Step (L 'Profil PowerShell' 'PowerShell profile') { Install-GlowshProfile }
Invoke-Step (L 'Siapkan saran salah ketik' 'Preparing typo suggestions') { "$(Update-GlowshCommandCache) " + (L 'perintah dikenali' 'commands indexed') }
if (Get-Command git -ErrorAction SilentlyContinue) {
    Invoke-Step (L 'Saran salah ketik untuk git' 'Git typo suggestions') {
        if ((Get-GlowshSettingValue 'typo') -ne $false) { [void](Set-GlowshGitAutocorrect $true); 'git pusj -> git push' }
    }
}

$warnings += $stepFails.n

# ============================================================ 6. windows terminal
Write-Step 'Windows Terminal'
if ($hasWT) {
    Write-Ok (L 'Sudah terpasang' 'Already installed')
    try { if (Register-GlowshWtAlias) { Write-Ok (L 'Buka cepat: Win + R, ketik "wt"' 'Quick launch: Win + R, type "wt"') } } catch {}
}
else {
    Write-Note (L 'Windows Terminal belum terpasang. Ikon & tema paling bagus tampil di sana.' 'Windows Terminal is not installed. Icons & themes look best there.')
    if (Read-YesNo (L 'Install Windows Terminal sekarang? (rilis resmi Microsoft dari GitHub, tanpa Store, ~12 MB)' 'Install Windows Terminal now? (official Microsoft release from GitHub, no Store, ~12 MB)')) {
        try {
            $ver = Install-PortableTerminal
            $hasWT = $true
            Write-Ok "Windows Terminal $ver -> $WtPortableDir"
            Write-Ok (L 'Shortcut "Windows Terminal" dibuat di Start Menu & Desktop' '"Windows Terminal" shortcut added to the Start Menu & Desktop')
        } catch { Write-Bad ((L 'Gagal: ' 'Failed: ') + $_.Exception.Message); $warnings++ }
    }
}

# ============================================================ 7. terapkan tema
Write-Step ((L 'Terapkan tema ' 'Applying theme ') + $theme.Title)
$warnings += Set-GlowshTheme $themeId -Explicit

# ============================================================ selesai
Write-Host ''
if ($warnings -eq 0) { Write-Host ('  ' + (L 'Selesai! Terminal kamu sekarang lebih glowing.' 'Done! Your terminal is now glowing.')) -ForegroundColor Green }
else { Write-Host ('  ' + (L "Selesai dengan $warnings peringatan (lihat tanda [X] / [!] di atas)." "Done with $warnings warnings (see the [X] / [!] marks above).")) -ForegroundColor Yellow }
Write-Host ''
Write-Host ('  ' + (L 'PENTING: ikon & font hanya tampil di Windows Terminal, bukan di jendela CMD/PowerShell biasa.' 'IMPORTANT: icons & fonts only show in Windows Terminal, not in the classic CMD/PowerShell window.')) -ForegroundColor Yellow
Write-Host ''
Write-Host ('  ' + (L 'Coba di Windows Terminal:' 'Try these in Windows Terminal:')) -ForegroundColor White
$tryRows = @(
    @('glowsh theme     ', 'ganti tema dengan preview', 'switch themes with a preview'),
    @('glowsh wallpaper ', 'buat tema dari wallpaper kamu', 'build a theme from your wallpaper'),
    @('glowsh doctor    ', 'cek & perbaiki kalau ada yang aneh', 'diagnose & fix anything odd'),
    @('glowsh           ', 'lihat semua perintah', 'see every command')
)
foreach ($r in $tryRows) { Write-Host "    $($r[0])" -NoNewline -ForegroundColor Cyan; Write-Host (L $r[1] $r[2]) }
Write-Host ''
if ($hasWT -and (Read-YesNo (L 'Buka Windows Terminal sekarang untuk lihat hasilnya?' 'Open Windows Terminal now to see the result?'))) {
    try { Start-GlowshTerminal } catch { Write-Note (L 'Gagal membuka otomatis. Buka "Windows Terminal" dari Start Menu.' 'Could not open it automatically. Open "Windows Terminal" from the Start Menu.') }
}
Write-Host ''
}
