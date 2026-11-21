<#
    Glowsh - perintah utama setelah install / main command after install.

        glowsh theme [nama|list]      pilih tema (dengan preview)
        glowsh wallpaper [file]       buat tema dari wallpaper
        glowsh share [nama]           bagikan tema sebagai kode
        glowsh import <kode> [nama]   pasang tema dari kode
        glowsh explain <perintah>     jelaskan sebuah perintah
        glowsh doctor                 cek & perbaiki masalah tampilan
        glowsh settings               lihat semua pengaturan
        glowsh <fitur> on|off         greet, auto, seasonal, notify, typo, guard
        glowsh lang id|en             ganti bahasa
        glowsh update | uninstall | version

    File ini juga dipakai sebagai "library" oleh install.ps1 (di-dot-source),
    jadi bagian utama di paling bawah hanya jalan kalau dipanggil langsung.
    Sengaja tanpa param() supaya argumen seperti "-rf" diteruskan apa adanya,
    dan sengaja ASCII-only supaya aman dibaca Windows PowerShell 5.1.
#>

# ============================================================ konfigurasi
$GlowshVersion = '0.3.3'
$GlowshRepoRaw = 'https://raw.githubusercontent.com/SQverse/glowsh/main'
$GlowHome      = Join-Path $HOME '.glowsh'
$BinDir        = Join-Path $GlowHome 'bin'
$OmpExe        = Join-Path $BinDir 'oh-my-posh.exe'
$ThemeFile     = Join-Path $GlowHome 'theme.omp.json'
$ThemeDir      = Join-Path $GlowHome 'themes'
$CustomDir     = Join-Path $GlowHome 'custom-themes'
$StateFile     = Join-Path $GlowHome 'current-theme.txt'
$ConfigFile    = Join-Path $GlowHome 'config.json'
$ShellFile     = Join-Path $GlowHome 'shell.ps1'
$BackupDir     = Join-Path $GlowHome 'backup-original'
$MarkStart     = '# >>> glowsh >>>'
$MarkEnd       = '# <<< glowsh <<<'
$FontFace      = 'MesloLGM Nerd Font'
$ConsoleKey    = 'HKCU:\Console'
$ClinkDir      = Join-Path $GlowHome 'clink'
$ClinkProfile  = Join-Path $GlowHome 'clink-profile'
$WtPortableDir = Join-Path $env:LOCALAPPDATA 'Programs\WindowsTerminal'
$WtPortableExe = Join-Path $WtPortableDir 'WindowsTerminal.exe'
$WtTargets = [ordered]@{
    stable     = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    preview    = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'
    unpackaged = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
}

# Fitur yang bisa dinyalakan/dimatikan: nama = (default, deskripsi id, deskripsi en)
$GlowshToggles = [ordered]@{
    greet    = @($true,  'sapaan saat terminal dibuka', 'greeting when a terminal opens')
    auto     = @($false, 'tema mengikuti waktu: pagi > senja > neon', 'theme follows the time: pagi > senja > neon')
    seasonal = @($true,  'tema musiman: 17 Agustus, Ramadan, Tahun Baru', 'seasonal themes: Aug 17, Ramadan, New Year')
    notify   = @($true,  'notifikasi saat perintah lama selesai', 'notification when a long command finishes')
    typo     = @($true,  'saran saat salah ketik perintah', 'suggestions for mistyped commands')
    guard    = @($true,  'peringatan sebelum perintah berbahaya', 'warning before dangerous commands')
}

# ============================================================ kode bersama (juga ditanam ke shell.ps1)
$GlowshSharedCode = @'
function Get-GlowshText([string]$Id, [string]$En) { if ($GlowshLang -eq 'en') { return $En } return $Id }

function Get-GlowshSeason([datetime]$Now = (Get-Date)) {
    if ($Now.Month -eq 8 -and $Now.Day -ge 16 -and $Now.Day -le 18) { return 'merdeka' }
    if (($Now.Month -eq 12 -and $Now.Day -eq 31) -or ($Now.Month -eq 1 -and $Now.Day -eq 1)) { return 'tahunbaru' }
    try { if ((New-Object Globalization.UmAlQuraCalendar).GetMonth($Now) -eq 9) { return 'ramadan' } } catch {}
    return $null
}

function Get-GlowshDesiredTheme($Config, [datetime]$Now = (Get-Date)) {
    if (-not $Config) { return $null }
    if ($Config.seasonal -ne $false) {
        $season = Get-GlowshSeason $Now
        if ($season -and $Config.seasonSkip -ne "$season-$($Now.Year)") { return $season }
    }
    if ($Config.auto -eq $true) {
        $m = $Now.Hour * 60 + $Now.Minute
        if ($m -ge 300 -and $m -lt 900) { return 'pagi' }      # 05:00 - 15:00
        if ($m -ge 900 -and $m -lt 1110) { return 'senja' }    # 15:00 - 18:30
        return 'neon'
    }
    if ($Config.baseTheme) { return [string]$Config.baseTheme }
    return $null
}

function Get-GlowshDanger([string]$Line) {
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    $rules = @(
        @{ P = '(?i)(^|[;|&(]\s*)(rm|del|erase|rd|rmdir|ri|remove-item)\b[^;|&]*\s(-r\w*|-recurse|/s)\b'
           Id = 'Menghapus folder beserta SELURUH isinya. Tidak masuk Recycle Bin dan tidak bisa di-undo.'
           En = 'Deletes a folder and ALL of its contents. Skips the Recycle Bin and cannot be undone.' }
        @{ P = '(?i)\b(format(\.com)?|format-volume)\s+(-\w+\s+)*[a-z]:'
           Id = 'Mem-format drive: SEMUA data di drive itu akan hilang.'
           En = 'Formats a drive: ALL data on that drive will be erased.' }
        @{ P = '(?i)\b(clear-disk|diskpart)\b'
           Id = 'Mengubah partisi/disk secara langsung. Salah langkah bisa menghapus seluruh disk.'
           En = 'Edits disks/partitions directly. One mistake can wipe an entire disk.' }
        @{ P = '(?i)\bgit\s+reset\b[^;|&]*--hard'
           Id = 'Membuang semua perubahan yang belum di-commit secara permanen.'
           En = 'Permanently discards all uncommitted changes.' }
        @{ P = '(?i)\bgit\s+push\b[^;|&]*(\s--force\b|\s-f\b)'
           Id = 'Menimpa riwayat di remote. Commit orang lain bisa hilang.'
           En = 'Overwrites history on the remote. Other people''s commits can be lost.' }
        @{ P = '(?i)\bgit\s+clean\b[^;|&]*\s-\w*f'
           Id = 'Menghapus permanen file yang belum di-track git.'
           En = 'Permanently deletes files that git is not tracking.' }
        @{ P = '(?i)\b(stop-computer|restart-computer)\b|\bshutdown(\.exe)?\s+[/-][srp]\b'
           Id = 'Mematikan / me-restart komputer. Pekerjaan yang belum disimpan bisa hilang.'
           En = 'Shuts down / restarts the computer. Unsaved work can be lost.' }
    )
    foreach ($r in $rules) { if ($Line -match $r.P) { return (Get-GlowshText $r.Id $r.En) } }
    return $null
}

function Format-GlowshDuration([TimeSpan]$T) {
    if ($T.TotalHours -ge 1) { return '{0}h {1}m' -f [int][Math]::Floor($T.TotalHours), $T.Minutes }
    if ($T.TotalMinutes -ge 1) { return '{0}m {1}s' -f [int][Math]::Floor($T.TotalMinutes), $T.Seconds }
    return '{0}s' -f [int]$T.TotalSeconds
}

# Notifikasi Windows lewat proses Windows PowerShell tersembunyi (jalan juga dari PowerShell 7, tidak memblokir)
function Send-GlowshToast([string]$Title, [string]$Body) {
    $t = [Security.SecurityElement]::Escape($Title)
    $b = [Security.SecurityElement]::Escape($Body)
    $code = '$ErrorActionPreference = ''SilentlyContinue'';' +
        '[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null;' +
        '[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null;' +
        '$x = New-Object Windows.Data.Xml.Dom.XmlDocument;' +
        "`$x.LoadXml('<toast><visual><binding template=""ToastGeneric""><text>$t</text><text>$b</text></binding></visual></toast>');" +
        '$app = ''{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'';' +
        '[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show((New-Object Windows.UI.Notifications.ToastNotification $x))'
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden `
        -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-EncodedCommand', $enc
}
'@
. ([scriptblock]::Create($GlowshSharedCode))
function L([string]$Id, [string]$En) { Get-GlowshText $Id $En }

# ============================================================ konfigurasi pengguna
function Get-GlowshConfig {
    if (Test-Path $ConfigFile) { try { return ([IO.File]::ReadAllText($ConfigFile) | ConvertFrom-Json) } catch {} }
    return [pscustomobject]@{}
}

function Set-GlowshConfigValue([string]$Name, $Value) {
    $c = Get-GlowshConfig
    if ($null -eq $Value) { $c.PSObject.Properties.Remove($Name) } else { Set-JsonProp $c $Name $Value }
    New-Item -ItemType Directory -Path $GlowHome -Force | Out-Null
    Write-Utf8NoBom $ConfigFile ($c | ConvertTo-Json)
}

function Initialize-GlowshConfig([string]$BaseTheme) {
    $c = Get-GlowshConfig
    Set-JsonProp $c 'lang' $GlowshLang
    if ($BaseTheme) { Set-JsonProp $c 'baseTheme' $BaseTheme }
    foreach ($k in $GlowshToggles.Keys) { if ($null -eq $c.$k) { Set-JsonProp $c $k $GlowshToggles[$k][0] } }
    if ($null -eq $c.notifySeconds) { Set-JsonProp $c 'notifySeconds' 30 }
    New-Item -ItemType Directory -Path $GlowHome -Force | Out-Null
    Write-Utf8NoBom $ConfigFile ($c | ConvertTo-Json)
}

function Get-GlowshSettingValue([string]$Name) {
    $c = Get-GlowshConfig
    if ($null -ne $c.$Name) { return $c.$Name }
    if ($GlowshToggles.Contains($Name)) { return $GlowshToggles[$Name][0] }
    return $null
}

# Bahasa: dari config, kalau belum ada tebak dari pengaturan Windows
$GlowshLang = [string](Get-GlowshConfig).lang
if ($GlowshLang -notin 'id', 'en') {
    $GlowshLang = if ((Get-Culture).Name -like 'id*' -or (Get-UICulture).Name -like 'id*') { 'id' } else { 'en' }
}

# ============================================================ tema
# Signature = prompt khas Glowsh (dibuat dari palet Accents).
# Tema klasik memakai file prompt dari koleksi Oh My Posh (properti Omp).
# Tema dengan Palette (tanpa Scheme) dibuatkan 16 warna terminalnya otomatis.
$GlowshThemes = [ordered]@{
    senja = @{
        Title = 'Senja'; Signature = $true; Desc = @('jingga & ungu langit sore', 'dusk: orange & purple sunset sky')
        Accents = @{ a1 = '#FF8C61'; a2 = '#FF5F7E'; a3 = '#C774E8'; a4 = '#FFC66D'; ok = '#B8E986'; err = '#FF5F7E'; muted = '#8A7A9E' }
        Scheme = [ordered]@{
            name = 'Glowsh Senja'; background = '#1B1426'; foreground = '#F3E6F0'
            cursorColor = '#FFB86B'; selectionBackground = '#3A2A4D'
            black = '#2A2038'; red = '#FF5F7E'; green = '#B8E986'; yellow = '#FFC66D'
            blue = '#8C9EFF'; purple = '#E58FD8'; cyan = '#7FDBCA'; white = '#E6D6E8'
            brightBlack = '#5A4A6E'; brightRed = '#FF8FA3'; brightGreen = '#CFF5A8'; brightYellow = '#FFD89B'
            brightBlue = '#ADBBFF'; brightPurple = '#F5B5EC'; brightCyan = '#A8F0E0'; brightWhite = '#FFF5FB'
        }
    }
    neon = @{
        Title = 'Neon'; Signature = $true; Desc = @('cyberpunk, kota malam penuh lampu', 'cyberpunk city lights at night')
        Accents = @{ a1 = '#FF2E88'; a2 = '#00F0FF'; a3 = '#B84DFF'; a4 = '#FFE45E'; ok = '#3DFFA2'; err = '#FF2E88'; muted = '#6E6A9E' }
        Scheme = [ordered]@{
            name = 'Glowsh Neon'; background = '#0B0A1A'; foreground = '#E0E6FF'
            cursorColor = '#00F0FF'; selectionBackground = '#2A1B4D'
            black = '#1A1830'; red = '#FF2E88'; green = '#3DFFA2'; yellow = '#FFE45E'
            blue = '#4D7CFF'; purple = '#B84DFF'; cyan = '#00F0FF'; white = '#C8D0F0'
            brightBlack = '#4A4670'; brightRed = '#FF6EAE'; brightGreen = '#7DFFC4'; brightYellow = '#FFF09A'
            brightBlue = '#85A5FF'; brightPurple = '#D58CFF'; brightCyan = '#7AF8FF'; brightWhite = '#FFFFFF'
        }
    }
    laut = @{
        Title = 'Laut'; Signature = $true; Desc = @('biru toska laut tropis & karang', 'sea: tropical turquoise & coral')
        Accents = @{ a1 = '#3DDCD0'; a2 = '#4FB3FF'; a3 = '#FF7A70'; a4 = '#F7D774'; ok = '#5EE6A0'; err = '#FF7A70'; muted = '#5E8A94' }
        Scheme = [ordered]@{
            name = 'Glowsh Laut'; background = '#0A1C24'; foreground = '#D8F3F0'
            cursorColor = '#5EEAD4'; selectionBackground = '#16404D'
            black = '#12303B'; red = '#FF7A70'; green = '#5EE6A0'; yellow = '#F7D774'
            blue = '#4FB3FF'; purple = '#9D8CFF'; cyan = '#3DDCD0'; white = '#C2E4E2'
            brightBlack = '#3E6672'; brightRed = '#FFA49C'; brightGreen = '#8FF2BE'; brightYellow = '#FBE6A4'
            brightBlue = '#85CBFF'; brightPurple = '#BDB2FF'; brightCyan = '#7DEBE3'; brightWhite = '#F0FFFD'
        }
    }
    pagi = @{
        Title = 'Pagi'; Signature = $true; Desc = @('terang & segar untuk pagi hari', 'morning: bright & fresh light theme')
        Accents = @{ a1 = '#D9622B'; a2 = '#2F7FC1'; a3 = '#3E9C62'; a4 = '#C99A1E'; ok = '#3E9C62'; err = '#D2394B'; muted = '#8A8597' }
        Palette = @{ bg = '#FBF7F0'; fg = '#2B2A33'; light = $true }
    }
    dracula = @{
        Title = 'Dracula'; Desc = @('klasik: ungu & pink kontras tinggi', 'classic: high-contrast purple & pink'); Omp = 'dracula'
        Scheme = [ordered]@{
            name = 'Glowsh Dracula'; background = '#282A36'; foreground = '#F8F8F2'
            cursorColor = '#F8F8F2'; selectionBackground = '#44475A'
            black = '#21222C'; red = '#FF5555'; green = '#50FA7B'; yellow = '#F1FA8C'
            blue = '#BD93F9'; purple = '#FF79C6'; cyan = '#8BE9FD'; white = '#F8F8F2'
            brightBlack = '#6272A4'; brightRed = '#FF6E6E'; brightGreen = '#69FF94'; brightYellow = '#FFFFA5'
            brightBlue = '#D6ACFF'; brightPurple = '#FF92DF'; brightCyan = '#A4FFFF'; brightWhite = '#FFFFFF'
        }
    }
    catppuccin = @{
        Title = 'Catppuccin Mocha'; Desc = @('klasik: pastel lembut', 'classic: soft pastels'); Omp = 'catppuccin_mocha'
        Scheme = [ordered]@{
            name = 'Glowsh Catppuccin'; background = '#1E1E2E'; foreground = '#CDD6F4'
            cursorColor = '#F5E0DC'; selectionBackground = '#585B70'
            black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'; yellow = '#F9E2AF'
            blue = '#89B4FA'; purple = '#F5C2E7'; cyan = '#94E2D5'; white = '#BAC2DE'
            brightBlack = '#585B70'; brightRed = '#F38BA8'; brightGreen = '#A6E3A1'; brightYellow = '#F9E2AF'
            brightBlue = '#89B4FA'; brightPurple = '#F5C2E7'; brightCyan = '#94E2D5'; brightWhite = '#A6ADC8'
        }
    }
    tokyonight = @{
        Title = 'Tokyo Night'; Desc = @('klasik: biru malam', 'classic: night blue'); Omp = 'tokyonight_storm'
        Scheme = [ordered]@{
            name = 'Glowsh Tokyo Night'; background = '#1A1B26'; foreground = '#C0CAF5'
            cursorColor = '#C0CAF5'; selectionBackground = '#33467C'
            black = '#15161E'; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'
            blue = '#7AA2F7'; purple = '#BB9AF7'; cyan = '#7DCFFF'; white = '#A9B1D6'
            brightBlack = '#414868'; brightRed = '#F7768E'; brightGreen = '#9ECE6A'; brightYellow = '#E0AF68'
            brightBlue = '#7AA2F7'; brightPurple = '#BB9AF7'; brightCyan = '#7DCFFF'; brightWhite = '#C0CAF5'
        }
    }
    merdeka = @{
        Title = 'Merdeka'; Signature = $true; Season = $true
        Desc = @('musiman: merah putih, 16-18 Agustus', 'seasonal: red & white, Indonesian Independence Day (Aug 16-18)')
        Accents = @{ a1 = '#E8343F'; a2 = '#F4F1EE'; a3 = '#B71C2B'; a4 = '#FFD166'; ok = '#6FD08C'; err = '#FF5C6C'; muted = '#9C7A7E' }
        Palette = @{ bg = '#1A0E10'; fg = '#FFF4F2' }
    }
    ramadan = @{
        Title = 'Ramadan'; Signature = $true; Season = $true
        Desc = @('musiman: hijau & emas, bulan Ramadan', 'seasonal: green & gold for Ramadan')
        Accents = @{ a1 = '#2FBF71'; a2 = '#E8C15A'; a3 = '#178A57'; a4 = '#F2D98B'; ok = '#7FE0A8'; err = '#F0727A'; muted = '#6F8F7E' }
        Palette = @{ bg = '#0A1913'; fg = '#ECF6EE' }
    }
    tahunbaru = @{
        Title = 'Tahun Baru'; Signature = $true; Season = $true
        Desc = @('musiman: kembang api, 31 Des - 1 Jan', 'seasonal: New Year fireworks (Dec 31 - Jan 1)')
        Accents = @{ a1 = '#FF5DA2'; a2 = '#FFD23F'; a3 = '#3BCEAC'; a4 = '#7B61FF'; ok = '#3BCEAC'; err = '#FF5D73'; muted = '#7A78A8' }
        Palette = @{ bg = '#0A0B1E'; fg = '#F2F0FF' }
    }
}

$GlowshSeasonGreeting = @{
    merdeka   = @('Dirgahayu Republik Indonesia! Merdeka!', 'Happy Indonesian Independence Day! Merdeka!')
    ramadan   = @('Selamat menunaikan ibadah puasa Ramadan.', 'Ramadan Kareem!')
    tahunbaru = @('Selamat Tahun Baru!', 'Happy New Year!')
}

# Prompt khas Glowsh (format Oh My Posh v4). __XX__ diganti warna dari tema.
# Glyph ditulis sebagai escape JSON supaya file ini tetap ASCII.
$GlowshPromptTemplate = @'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 4,
  "final_space": true,
  "palette": {
    "bg": "__BG__", "a1": "__A1__", "a2": "__A2__", "a3": "__A3__", "a4": "__A4__",
    "ok": "__OK__", "err": "__ERR__", "muted": "__MUTED__"
  },
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        {
          "type": "os", "style": "diamond", "leading_diamond": "\ue0b6",
          "foreground": "p:bg", "background": "p:a1",
          "template": "{{ .Icon }} "
        },
        {
          "type": "session", "style": "powerline", "powerline_symbol": "\ue0b0",
          "foreground": "p:bg", "background": "p:a1",
          "template": "{{ .UserName }} "
        },
        {
          "type": "path", "style": "powerline", "powerline_symbol": "\ue0b0",
          "foreground": "p:bg", "background": "p:a2",
          "options": { "style": "folder" },
          "template": " \uf07c {{ .Path }} "
        },
        {
          "type": "git", "style": "powerline", "powerline_symbol": "\ue0b0",
          "foreground": "p:bg", "background": "p:a3",
          "background_templates": [ "{{ if or (.Working.Changed) (.Staging.Changed) }}p:a4{{ end }}" ],
          "options": { "fetch_status": true },
          "template": " {{ .HEAD }}{{ if .Working.Changed }} \uf044 {{ .Working.String }}{{ end }}{{ if .Staging.Changed }} \uf046 {{ .Staging.String }}{{ end }} "
        },
        {
          "type": "status", "style": "diamond", "trailing_diamond": "\ue0b4",
          "foreground": "p:bg", "background": "p:ok",
          "background_templates": [ "{{ if .Error }}p:err{{ end }}" ],
          "options": { "always_enabled": true },
          "template": " {{ if .Error }}\uf00d {{ .Code }}{{ else }}\uf00c{{ end }} "
        }
      ]
    },
    {
      "type": "rprompt",
      "segments": [
        {
          "type": "executiontime", "style": "plain", "foreground": "p:muted",
          "options": { "threshold": 500, "style": "austin" },
          "template": "\uf252 {{ .FormattedMs }}  "
        },
        {
          "type": "time", "style": "plain", "foreground": "p:muted",
          "options": { "time_format": "15:04" },
          "template": "\uf017 {{ .CurrentDate | date .Format }}"
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "text", "style": "plain", "foreground": "p:a1",
          "foreground_templates": [ "{{ if gt .Code 0 }}p:err{{ end }}" ],
          "template": "\u276f"
        }
      ]
    }
  ]
}
'@

# ============================================================ shell.ps1 (dimuat setiap PowerShell dibuka)
# #__SHARED__ diganti $GlowshSharedCode saat ditulis. Jaga supaya tetap cepat.
$GlowshShellTemplate = @'
# Glowsh shell integration - dibuat otomatis oleh Glowsh, jangan diedit (akan ditimpa).
# Glowsh shell integration - generated by Glowsh, do not edit (it will be overwritten).
$global:GlowshHome = Join-Path $HOME '.glowsh'
$global:GlowshConfig = $null
try {
    $__glowshCfg = Join-Path $GlowshHome 'config.json'
    if (Test-Path $__glowshCfg) { $global:GlowshConfig = [IO.File]::ReadAllText($__glowshCfg) | ConvertFrom-Json }
} catch {}
Remove-Variable __glowshCfg -ErrorAction SilentlyContinue

function Get-GlowshSetting([string]$Name, $Default) {
    if ($global:GlowshConfig -and $null -ne $global:GlowshConfig.$Name) { return $global:GlowshConfig.$Name }
    return $Default
}
$global:GlowshLang = [string](Get-GlowshSetting 'lang' 'id')

#__SHARED__

# ---------- prompt & tema otomatis
# Terminal modern (bisa Nerd Font) vs jendela console klasik (conhost) yang tidak bisa menampilkan ikon
function Test-GlowshModernTerminal {
    return [bool]($env:WT_SESSION -or $env:TERM_PROGRAM -or $env:ConEmuANSI -eq 'ON' -or $env:WEZTERM_PANE -or $env:ALACRITTY_LOG)
}

function Initialize-GlowshPrompt {
    $omp = Join-Path $GlowshHome 'bin\oh-my-posh.exe'
    if (-not (Test-Path $omp)) { return }
    # Di jendela klasik pakai prompt "lite" tanpa ikon supaya tidak muncul kotak-kotak
    $cfg = Join-Path $GlowshHome 'theme.omp.json'
    $lite = Join-Path $GlowshHome 'theme-lite.omp.json'
    if (-not (Test-GlowshModernTerminal) -and (Test-Path $lite)) { $cfg = $lite }
    & $omp init pwsh --config $cfg | Invoke-Expression
    if ($function:prompt -and $function:prompt.ToString() -notmatch 'Invoke-GlowshPromptHook') {
        $global:__glowshPrompt = $function:prompt
    }
    function global:prompt {
        $ok = $?
        $code = $global:LASTEXITCODE
        try { Invoke-GlowshPromptHook $ok } catch {}
        $global:LASTEXITCODE = $code
        if (-not $ok) { Write-Error 'glowsh' -ErrorAction Ignore }   # pertahankan status gagal untuk prompt
        & $global:__glowshPrompt
    }
}

function Sync-GlowshTheme([switch]$Startup) {
    $want = Get-GlowshDesiredTheme $global:GlowshConfig
    if (-not $want) { return }
    $cur = ''
    $state = Join-Path $GlowshHome 'current-theme.txt'
    if (Test-Path $state) { $cur = ([IO.File]::ReadAllText($state)).Trim() }
    if ($want -eq $cur) { return }
    & (Join-Path $GlowshHome 'glowsh.ps1') sync 6>$null | Out-Null
    if (-not $Startup) { Initialize-GlowshPrompt }
}

# ---------- notifikasi perintah lama
$global:__glowshLastId = 0
$global:__glowshNextSync = (Get-Date).AddMinutes(5)
function Invoke-GlowshPromptHook([bool]$Ok = $true) {
    $h = Get-History -Count 1
    if ($h -and $h.Id -ne $global:__glowshLastId) {
        $global:__glowshLastId = $h.Id
        if (Get-GlowshSetting 'notify' $true) {
            $dur = $h.EndExecutionTime - $h.StartExecutionTime
            if ($dur.TotalSeconds -ge [double](Get-GlowshSetting 'notifySeconds' 30)) {
                $cmd = [string]$h.CommandLine
                if ($cmd.Length -gt 60) { $cmd = $cmd.Substring(0, 57) + '...' }
                $title = if ($Ok) { Get-GlowshText 'Perintah selesai' 'Command finished' } else { Get-GlowshText 'Perintah gagal' 'Command failed' }
                Send-GlowshToast $title "$cmd  ($(Format-GlowshDuration $dur))"
            }
        }
    }
    if ((Get-Date) -ge $global:__glowshNextSync) {
        $global:__glowshNextSync = (Get-Date).AddMinutes(5)
        Sync-GlowshTheme
    }
}

# ---------- perintah glowsh
function glowsh {
    & (Join-Path $GlowshHome 'glowsh.ps1') @args
    try { $global:GlowshConfig = [IO.File]::ReadAllText((Join-Path $GlowshHome 'config.json')) | ConvertFrom-Json } catch {}
    $global:GlowshLang = [string](Get-GlowshSetting 'lang' 'id')
    if ($args.Count -gt 0 -and $args[0] -in 'theme', 'wallpaper', 'import', 'sync', 'auto', 'seasonal') { Initialize-GlowshPrompt }
}

# ---------- bantuan salah ketik
function Get-GlowshEditDistance([string]$A, [string]$B) {
    # Jarak Damerau-Levenshtein (OSA); tabel disimpan di array 1 dimensi: index = baris * lebar + kolom
    $w = $B.Length + 1
    $d = New-Object 'int[]' (($A.Length + 1) * $w)
    for ($i = 0; $i -le $A.Length; $i++) { $d[$i * $w] = $i }
    for ($j = 0; $j -le $B.Length; $j++) { $d[$j] = $j }
    for ($i = 1; $i -le $A.Length; $i++) {
        for ($j = 1; $j -le $B.Length; $j++) {
            $cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $del = $d[($i - 1) * $w + $j] + 1
            $ins = $d[$i * $w + $j - 1] + 1
            $sub = $d[($i - 1) * $w + $j - 1] + $cost
            $v = [Math]::Min([Math]::Min($del, $ins), $sub)
            if ($i -gt 1 -and $j -gt 1 -and $A[$i - 1] -eq $B[$j - 2] -and $A[$i - 2] -eq $B[$j - 1]) {
                $swap = $d[($i - 2) * $w + $j - 2] + 1
                $v = [Math]::Min($v, $swap)
            }
            $d[$i * $w + $j] = $v
        }
    }
    return $d[$A.Length * $w + $B.Length]
}

function Get-GlowshSuggestion([string]$Name) {
    $n = $Name.ToLower()
    $linux = @{
        'touch'    = @{ Show = 'New-Item -ItemType File <file>'; Run = { foreach ($f in $args) { if (Test-Path -LiteralPath $f) { (Get-Item -LiteralPath $f).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $f | Out-Null } } } }
        'grep'     = @{ Show = 'Select-String'; Run = { if ($MyInvocation.ExpectingInput) { $input | Select-String @args } else { Select-String @args } } }
        'which'    = @{ Show = 'Get-Command'; Run = { Get-Command @args } }
        'nano'     = @{ Show = 'notepad'; Run = { notepad @args } }
        'vim'      = @{ Show = 'notepad'; Run = { notepad @args } }
        'vi'       = @{ Show = 'notepad'; Run = { notepad @args } }
        'ifconfig' = @{ Show = 'ipconfig'; Run = { ipconfig @args } }
        'open'     = @{ Show = 'Invoke-Item'; Run = { foreach ($f in $args) { Invoke-Item $f } } }
        'xdg-open' = @{ Show = 'Invoke-Item'; Run = { foreach ($f in $args) { Invoke-Item $f } } }
        'df'       = @{ Show = 'Get-PSDrive -PSProvider FileSystem'; Run = { Get-PSDrive -PSProvider FileSystem } }
        'free'     = @{ Show = 'Get-CimInstance Win32_OperatingSystem'; Run = { $o = Get-CimInstance Win32_OperatingSystem; '{0:N1} GB / {1:N1} GB' -f ($o.FreePhysicalMemory / 1MB), ($o.TotalVisibleMemorySize / 1MB) } }
        'uname'    = @{ Show = '[Environment]::OSVersion'; Run = { [Environment]::OSVersion.VersionString } }
        'll'       = @{ Show = 'Get-ChildItem -Force'; Run = { Get-ChildItem -Force @args } }
        'top'      = @{ Show = 'Get-Process | Sort-Object CPU -Descending'; Run = { Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 } }
        'htop'     = @{ Show = 'Get-Process | Sort-Object CPU -Descending'; Run = { Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 } }
        'head'     = @{ Hint = @('Pakai: Get-Content <file> -TotalCount 10', 'Use: Get-Content <file> -TotalCount 10') }
        'tail'     = @{ Hint = @('Pakai: Get-Content <file> -Tail 10   (tambah -Wait untuk memantau)', 'Use: Get-Content <file> -Tail 10   (add -Wait to follow)') }
        'sudo'     = @{ Hint = @('Windows tidak punya sudo. Klik kanan Windows Terminal > Run as administrator.', 'Windows has no sudo. Right-click Windows Terminal > Run as administrator.') }
        'export'   = @{ Hint = @('Pakai: $env:NAMA = "nilai"', 'Use: $env:NAME = "value"') }
        'apt'      = @{ Hint = @('Di Windows pakai winget, contoh: winget install <nama>', 'On Windows use winget, e.g. winget install <name>') }
        'apt-get'  = @{ Hint = @('Di Windows pakai winget, contoh: winget install <nama>', 'On Windows use winget, e.g. winget install <name>') }
        'brew'     = @{ Hint = @('Di Windows pakai winget, contoh: winget install <nama>', 'On Windows use winget, e.g. winget install <name>') }
    }
    if ($linux.ContainsKey($n)) {
        $e = $linux[$n]
        if ($e.Run) {
            return @{ Message = (Get-GlowshText "'$Name' adalah perintah Linux. Padanannya di PowerShell:" "'$Name' is a Linux command. The PowerShell equivalent is:"); Display = $e.Show; Run = $e.Run }
        }
        return @{ Message = (Get-GlowshText "'$Name' adalah perintah Linux. " "'$Name' is a Linux command. ") + (Get-GlowshText $e.Hint[0] $e.Hint[1]) }
    }
    if ($n -match '[\\/:.]' -or $n.Length -lt 2) { return $null }
    if (-not $global:__glowshCommands) {
        # Mendata cmdlet & program itu lambat (beberapa detik), jadi hasilnya disimpan ke disk dan diperbarui tiap 7 hari
        $cacheFile = Join-Path $GlowshHome 'command-cache.txt'
        $disk = @()
        if ((Test-Path $cacheFile) -and ((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalDays -lt 7) {
            $disk = [IO.File]::ReadAllLines($cacheFile)
        } else {
            $disk = @(Get-Command -CommandType Cmdlet, Application -ErrorAction SilentlyContinue |
                ForEach-Object { if ($_.CommandType -eq 'Application') { [IO.Path]::GetFileNameWithoutExtension($_.Name).ToLower() } else { $_.Name } } |
                Sort-Object -Unique)
            try { [IO.File]::WriteAllLines($cacheFile, [string[]]$disk) } catch {}
        }
        $mem = @(Get-Command -CommandType Alias, Function -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        $global:__glowshCommands = @(@($disk) + $mem | Sort-Object -Unique)
    }
    $max = if ($n.Length -le 4) { 1 } else { 2 }
    $nSorted = -join ($n.ToCharArray() | Sort-Object)
    $best = $null; $bestD = 99; $bestScore = 99
    foreach ($c in $global:__glowshCommands) {
        if ([Math]::Abs($c.Length - $n.Length) -gt $max) { continue }
        $lc = $c.ToLower()
        if ($lc[0] -ne $n[0]) { continue }
        $dist = Get-GlowshEditDistance $n $lc
        if ($dist -gt $max) { continue }
        # Kalau jaraknya sama: utamakan huruf yang sama tapi tertukar (gti -> git), lalu yang panjangnya sama
        $score = $dist * 10 + [Math]::Abs($c.Length - $n.Length) * 2
        if ((-join ($lc.ToCharArray() | Sort-Object)) -ne $nSorted) { $score += 1 }
        if ($score -lt $bestScore) { $best = $c; $bestD = $dist; $bestScore = $score }
    }
    if (-not $best -or $bestD -eq 0 -or $bestD -gt $max) { return $null }
    $safe = $best.Replace("'", "''")
    return @{
        Message = (Get-GlowshText "Perintah '$Name' tidak dikenal. Mungkin maksud kamu:" "Unknown command '$Name'. Did you mean:")
        Display = $best
        Run = [scriptblock]::Create("if (`$MyInvocation.ExpectingInput) { `$input | & '$safe' @args } else { & '$safe' @args }")
    }
}

if (Get-GlowshSetting 'typo' $true) {
    $ExecutionContext.InvokeCommand.CommandNotFoundAction = {
        param($Name, $CmdArgs)
        try {
            if ($CmdArgs.CommandOrigin -ne 'Runspace') { return }
            # Pastikan nama ini memang diketik user (bukan pencarian internal PowerShell)
            try {
                $items = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems()
                if ($items.Count -gt 0) {
                    $line = $items[$items.Count - 1].CommandLine
                    if ($line -notmatch ('(^|[\s|;(&])' + [regex]::Escape($Name) + '(\s|$)')) { return }
                }
            } catch {}
            $s = Get-GlowshSuggestion $Name
            if (-not $s) { return }
            Write-Host ''
            Write-Host "  $($s.Message)" -ForegroundColor Yellow -NoNewline
            if ($s.Run) {
                Write-Host " $($s.Display)" -ForegroundColor Cyan
                Write-Host ('  ' + (Get-GlowshText 'Jalankan? [Y/n] ' 'Run it? [Y/n] ')) -NoNewline
                $k = [Console]::ReadKey($true)
                Write-Host $k.KeyChar
                if ($k.Key -eq 'Enter' -or $k.KeyChar -eq 'y' -or $k.KeyChar -eq 'Y') {
                    $CmdArgs.CommandScriptBlock = $s.Run
                    $CmdArgs.StopSearch = $true
                    return
                }
            } else { Write-Host '' }
            $CmdArgs.CommandScriptBlock = {}
            $CmdArgs.StopSearch = $true
        } catch {}
    }
}

# ---------- pengaman perintah berbahaya
if ((Get-GlowshSetting 'guard' $true) -and (Get-Module PSReadLine)) {
    Set-PSReadLineKeyHandler -Key Enter -BriefDescription GlowshGuard -Description 'Glowsh: confirm dangerous commands' -ScriptBlock {
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $warn = $null
        try { $warn = Get-GlowshDanger $line } catch {}
        if ($warn) {
            Write-Host ''
            Write-Host "  [!] $warn" -ForegroundColor Yellow
            Write-Host ('  ' + (Get-GlowshText 'Tetap jalankan? [y/N] ' 'Run anyway? [y/N] ')) -NoNewline
            $k = [Console]::ReadKey($true)
            Write-Host $k.KeyChar
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
            if ($k.KeyChar -ne 'y' -and $k.KeyChar -ne 'Y') { return }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

# ---------- mulai
# Jendela PowerShell klasik dari Start Menu memakai latar biru bawaan shortcut; ganti ke latar gelap
if (-not (Test-GlowshModernTerminal) -and $Host.Name -eq 'ConsoleHost') {
    try {
        if ($Host.UI.RawUI.BackgroundColor -ne 'Black') {
            $Host.UI.RawUI.BackgroundColor = 'Black'
            $Host.UI.RawUI.ForegroundColor = 'Gray'
            Clear-Host
        }
    } catch {}
}
Sync-GlowshTheme -Startup
Initialize-GlowshPrompt
# Terminal-Icons lambat dimuat (1-2 detik) dan baru dibutuhkan saat ls/dir, jadi dimuat setelah prompt tampil
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    try { Import-Module Terminal-Icons -Global -ErrorAction Stop } catch {}
}
try { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction Stop } catch {}

if (Get-GlowshSetting 'greet' $true) {
    try {
        $__now = Get-Date
        $__h = $__now.Hour
        $__greet = if ($__h -ge 4 -and $__h -lt 11) { Get-GlowshText 'Selamat pagi' 'Good morning' }
                   elseif ($__h -ge 11 -and $__h -lt 15) { Get-GlowshText 'Selamat siang' 'Good afternoon' }
                   elseif ($__h -ge 15 -and $__h -lt 18) { Get-GlowshText 'Selamat sore' 'Good afternoon' }
                   else { Get-GlowshText 'Selamat malam' 'Good evening' }
        $__culture = [Globalization.CultureInfo]::GetCultureInfo($(if ($GlowshLang -eq 'en') { 'en-US' } else { 'id-ID' }))
        $__info = $__now.ToString('dddd, d MMMM yyyy', $__culture)
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $__ps = [System.Windows.Forms.SystemInformation]::PowerStatus
            if ($__ps.BatteryChargeStatus.ToString() -notmatch 'NoSystemBattery|Unknown') {
                $__info += '  |  ' + (Get-GlowshText 'baterai ' 'battery ') + [int]($__ps.BatteryLifePercent * 100) + '%'
                if ($__ps.PowerLineStatus.ToString() -eq 'Online') { $__info += ' +' }
            }
        } catch {}
        $__icon = ''
        if ($env:WT_SESSION) { $__icon = [string][char]$(if ($__h -ge 6 -and $__h -lt 18) { 0xF185 } else { 0xF186 }) + ' ' }
        Write-Host ''
        Write-Host "  $__icon$__greet, $env:USERNAME!" -ForegroundColor Magenta -NoNewline
        Write-Host "   $__info" -ForegroundColor DarkGray
        $__season = Get-GlowshSeason $__now
        $__seasonText = @{
            merdeka   = @('Dirgahayu Republik Indonesia! Merdeka!', 'Happy Indonesian Independence Day! Merdeka!')
            ramadan   = @('Selamat menunaikan ibadah puasa Ramadan.', 'Ramadan Kareem!')
            tahunbaru = @('Selamat Tahun Baru!', 'Happy New Year!')
        }
        if ($__season -and (Get-GlowshSetting 'seasonal' $true)) {
            Write-Host ('  ' + (Get-GlowshText $__seasonText[$__season][0] $__seasonText[$__season][1])) -ForegroundColor Yellow
        }
        $__tips = @(
            @('ketik "glowsh theme" untuk ganti tema dengan preview', 'type "glowsh theme" to switch themes with a preview'),
            @('"glowsh wallpaper" membuat tema dari wallpaper kamu', '"glowsh wallpaper" builds a theme from your wallpaper'),
            @('"glowsh explain <perintah>" menjelaskan arti sebuah perintah', '"glowsh explain <command>" explains what a command does'),
            @('"glowsh auto on" membuat tema berganti mengikuti waktu', '"glowsh auto on" makes the theme follow the time of day'),
            @('"glowsh share" menghasilkan kode untuk berbagi tema', '"glowsh share" gives you a code to share your theme'),
            @('ada yang aneh? jalankan "glowsh doctor"', 'something looks off? run "glowsh doctor"'),
            @('tekan panah kanan untuk menerima saran perintah', 'press the right arrow to accept a command suggestion'),
            @('matikan sapaan ini dengan "glowsh greet off"', 'turn this greeting off with "glowsh greet off"')
        )
        $__tip = $__tips[(Get-Random -Maximum $__tips.Count)]
        Write-Host ('  Tip: ' + (Get-GlowshText $__tip[0] $__tip[1])) -ForegroundColor DarkGray
        Write-Host ''
    } catch {}
    Get-Variable -Name '__now', '__h', '__greet', '__culture', '__info', '__ps', '__icon', '__season', '__seasonText', '__tips', '__tip' -ErrorAction SilentlyContinue |
        Remove-Variable -ErrorAction SilentlyContinue
}
'@

# ============================================================ helper tampilan
function Write-Banner {
    $art = @'
   ____ _                   _
  / ___| | _____      _____| |__
 | |  _| |/ _ \ \ /\ / / __| '_ \
 | |_| | | (_) \ V  V /\__ \ | | |
  \____|_|\___/ \_/\_/ |___/_| |_|
'@
    $colors = 'Magenta', 'Magenta', 'Cyan', 'Cyan', 'Blue'
    $lines = $art -split "`r?`n"
    Write-Host ''
    for ($i = 0; $i -lt $lines.Count; $i++) { Write-Host $lines[$i] -ForegroundColor $colors[$i % $colors.Count] }
    Write-Host ('      ' + (L 'bikin terminal kamu lebih cantik - satu perintah saja' 'make your terminal glow - with one command')) -ForegroundColor DarkGray
    Write-Host ''
}
function Write-Step([string]$Text) { Write-Host ''; Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Note([string]$Text) { Write-Host "    [!]  $Text" -ForegroundColor Yellow }
function Write-Bad([string]$Text)  { Write-Host "    [X]  $Text" -ForegroundColor Red }

function Read-YesNo([string]$Question, [bool]$Default = $true) {
    if ($env:GLOWSH_YES -eq '1') { return $Default }
    $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "    $Question $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim().ToLower().StartsWith('y')
}

# ============================================================ helper umum
function Set-JsonProp($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Read-JsonLoose([string]$Path) {
    $raw = [IO.File]::ReadAllText($Path)
    try { return ($raw | ConvertFrom-Json) }
    catch {
        # settings.json Windows Terminal boleh berisi komentar // ; buang baris komentar lalu coba lagi
        $clean = ($raw -split "`r?`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
        return ($clean | ConvertFrom-Json)
    }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}

function Get-GlowshArch {
    $arch = $env:PROCESSOR_ARCHITEW6432
    if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
    switch ($arch) { 'ARM64' { return 'arm64' } 'x86' { return '386' } default { return 'amd64' } }
}

function Get-ProfileTargets {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $targets = @(Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
    $pwsh7 = Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'
    if ((Get-Command pwsh -ErrorAction SilentlyContinue) -or (Test-Path (Split-Path $pwsh7))) { $targets += $pwsh7 }
    return $targets
}

function Test-FontInstalled {
    foreach ($key in 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
                     'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if ($props -and ($props.PSObject.Properties.Name -match 'MesloLGM')) { return $true }
    }
    return $false
}

function Test-WindowsTerminal {
    if (Test-Path $WtPortableExe) { return $true }
    foreach ($p in $WtTargets.Values) { if (Test-Path (Split-Path $p)) { return $true } }
    try { if (Get-AppxPackage -Name 'Microsoft.WindowsTerminal*' -ErrorAction Stop) { return $true } } catch {}
    return $false
}

function Start-GlowshTerminal {
    if (Test-Path $WtPortableExe) { Start-Process $WtPortableExe } else { Start-Process 'wt.exe' }
}

function Get-GlowshCurrentTheme {
    if (Test-Path $StateFile) {
        $id = ([IO.File]::ReadAllText($StateFile)).Trim()
        if ($GlowshThemes.Contains($id)) { return $id }
    }
    return 'senja'
}

function Get-ThemeDesc($Theme) { return (L $Theme.Desc[0] $Theme.Desc[1]) }

function Resolve-GlowshThemeId([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $ids = @($GlowshThemes.Keys)
    $n = 0
    if ([int]::TryParse($Name, [ref]$n) -and $n -ge 1 -and $n -le $ids.Count) { return $ids[$n - 1] }
    foreach ($id in $ids) { if ($id -eq $Name -or $GlowshThemes[$id].Title -eq $Name) { return $id } }
    return $null
}

function Get-ThemeAccents($Theme) {
    if ($Theme.Accents) { return $Theme.Accents }
    $s = $Theme.Scheme
    return @{ a1 = $s.purple; a2 = $s.blue; a3 = $s.green; a4 = $s.yellow; ok = $s.green; err = $s.red; muted = $s.brightBlack }
}

# ============================================================ warna
function ConvertTo-Hex([double]$R, [double]$G, [double]$B) {
    $c = { param($v) [int][Math]::Round([Math]::Max(0, [Math]::Min(255, $v))) }
    return '#{0:X2}{1:X2}{2:X2}' -f (& $c $R), (& $c $G), (& $c $B)
}

function Get-RgbParts([string]$Hex) {
    $h = $Hex.TrimStart('#')
    return @([Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16))
}

function Get-Rgb([string]$Hex) { return (Get-RgbParts $Hex) -join ';' }

function ConvertTo-ConsoleColor([string]$Hex) {
    $p = Get-RgbParts $Hex
    return [int]($p[0] + ($p[1] -shl 8) + ($p[2] -shl 16))   # format registry conhost: 0x00BBGGRR
}

function ConvertTo-Hsl([string]$Hex) {
    $p = Get-RgbParts $Hex
    $r = $p[0] / 255.0; $g = $p[1] / 255.0; $b = $p[2] / 255.0
    $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b))
    $l = ($max + $min) / 2; $h = 0.0; $s = 0.0
    if ($max -ne $min) {
        $d = $max - $min
        $s = if ($l -gt 0.5) { $d / (2 - $max - $min) } else { $d / ($max + $min) }
        if ($max -eq $r) { $h = (($g - $b) / $d) + $(if ($g -lt $b) { 6 } else { 0 }) }
        elseif ($max -eq $g) { $h = (($b - $r) / $d) + 2 }
        else { $h = (($r - $g) / $d) + 4 }
        $h = $h * 60
    }
    return [pscustomobject]@{ H = $h; S = $s; L = $l }
}

function ConvertFrom-Hsl([double]$H, [double]$S, [double]$L) {
    $H = (($H % 360) + 360) % 360
    $c = (1 - [Math]::Abs(2 * $L - 1)) * $S
    $x = $c * (1 - [Math]::Abs((($H / 60) % 2) - 1))
    $m = $L - $c / 2
    $rgb = switch ([int][Math]::Floor($H / 60)) {
        0 { @($c, $x, 0) } 1 { @($x, $c, 0) } 2 { @(0, $c, $x) }
        3 { @(0, $x, $c) } 4 { @($x, 0, $c) } default { @($c, 0, $x) }
    }
    return ConvertTo-Hex (($rgb[0] + $m) * 255) (($rgb[1] + $m) * 255) (($rgb[2] + $m) * 255)
}

function Get-MixedColor([string]$From, [string]$To, [double]$T) {
    # Catatan: variabel PowerShell tidak case-sensitive, jadi nama lokal sengaja beda dari nama parameter
    $p = Get-RgbParts $From; $q = Get-RgbParts $To
    return ConvertTo-Hex ($p[0] + ($q[0] - $p[0]) * $T) ($p[1] + ($q[1] - $p[1]) * $T) ($p[2] + ($q[2] - $p[2]) * $T)
}

function Get-HueDistance([double]$A, [double]$B) {
    $d = [Math]::Abs($A - $B) % 360
    if ($d -gt 180) { return 360 - $d } else { return $d }
}

# Buat 16 warna terminal dari background, foreground & warna aksen.
# Warna dasar (merah, hijau, dst.) tetap di posisinya supaya output program tetap terbaca,
# tapi digeser ke arah aksen terdekat supaya serasi.
function New-GlowshScheme([string]$Name, [string]$Bg, [string]$Fg, [string[]]$Accents, [switch]$Light) {
    $s = [ordered]@{ name = $Name; background = $Bg; foreground = $Fg; cursorColor = $Accents[0]; selectionBackground = (Get-MixedColor $Bg $Accents[0] 0.3) }
    foreach ($k in 'black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white',
                   'brightBlack', 'brightRed', 'brightGreen', 'brightYellow', 'brightBlue', 'brightPurple', 'brightCyan', 'brightWhite') { $s[$k] = $null }
    $accHues = @($Accents | ForEach-Object { (ConvertTo-Hsl $_).H })
    $base = [ordered]@{ red = 355; green = 135; yellow = 42; blue = 215; purple = 280; cyan = 185 }
    foreach ($k in $base.Keys) {
        $h = $base[$k]
        $near = $accHues | Sort-Object { Get-HueDistance $_ $h } | Select-Object -First 1
        if ($null -ne $near -and (Get-HueDistance $near $h) -le 30) {
            $diff = (($near - $h + 540) % 360) - 180
            $h = ($h + $diff * 0.6 + 360) % 360
        }
        $bright = 'bright' + $k.Substring(0, 1).ToUpper() + $k.Substring(1)
        if ($Light) { $s[$k] = ConvertFrom-Hsl $h 0.62 0.40; $s[$bright] = ConvertFrom-Hsl $h 0.70 0.50 }
        else        { $s[$k] = ConvertFrom-Hsl $h 0.70 0.66; $s[$bright] = ConvertFrom-Hsl $h 0.80 0.76 }
    }
    if ($Light) {
        $s.black = $Fg; $s.white = Get-MixedColor $Bg $Fg 0.55
        $s.brightBlack = Get-MixedColor $Bg $Fg 0.45; $s.brightWhite = Get-MixedColor $Bg $Fg 0.75
    } else {
        $s.black = Get-MixedColor $Bg $Fg 0.12; $s.white = Get-MixedColor $Bg $Fg 0.85
        $s.brightBlack = Get-MixedColor $Bg $Fg 0.42; $s.brightWhite = $Fg
    }
    return $s
}

# ============================================================ tema kustom (wallpaper & import)
function ConvertTo-OrderedHash($Object) {
    $h = [ordered]@{}
    foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = [string]$p.Value }
    return $h
}

function Save-GlowshCustomTheme([string]$Id, $Theme) {
    if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $CustomDir -Force | Out-Null
    $o = [ordered]@{ title = $Theme.Title; desc = @($Theme.Desc); light = [bool]$Theme.Light; accents = $Theme.Accents; scheme = $Theme.Scheme }
    Write-Utf8NoBom (Join-Path $CustomDir "$Id.json") ($o | ConvertTo-Json -Depth 5)
}

function Initialize-GlowshThemes {
    foreach ($id in @($GlowshThemes.Keys)) {
        $t = $GlowshThemes[$id]
        if (-not $t.Scheme) {
            $t.Scheme = New-GlowshScheme "Glowsh $($t.Title)" $t.Palette.bg $t.Palette.fg @($t.Accents.a1, $t.Accents.a2, $t.Accents.a3, $t.Accents.a4) -Light:([bool]$t.Palette.light)
        }
    }
    if (Test-Path $CustomDir) {
        foreach ($f in Get-ChildItem $CustomDir -Filter '*.json') {
            try {
                $o = [IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json
                $GlowshThemes[$f.BaseName] = @{
                    Title = [string]$o.title; Desc = @($o.desc); Signature = $true; Custom = $true; Light = [bool]$o.light
                    Accents = ConvertTo-OrderedHash $o.accents; Scheme = ConvertTo-OrderedHash $o.scheme
                }
            } catch {}
        }
    }
}

function Get-WallpaperPath {
    $p = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).WallPaper
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    $t = Join-Path $env:APPDATA 'Microsoft\Windows\Themes\TranscodedWallpaper'
    if (Test-Path $t) { return $t }
    return $null
}

function New-ThemeFromImage([string]$Path, [string]$Title = 'Wallpaper') {
    Add-Type -AssemblyName System.Drawing
    $ms = New-Object IO.MemoryStream (, [IO.File]::ReadAllBytes($Path))
    $img = [System.Drawing.Image]::FromStream($ms)
    $W = 64; $H = 36
    $bmp = New-Object System.Drawing.Bitmap $img, $W, $H
    $img.Dispose(); $ms.Dispose()
    # Kelompokkan piksel ke "ember" warna (4 bit per channel), lalu ambil rata-rata tiap ember
    $buckets = @{}
    for ($x = 0; $x -lt $W; $x++) {
        for ($y = 0; $y -lt $H; $y++) {
            $c = $bmp.GetPixel($x, $y)
            $key = (($c.R -shr 4) -shl 8) -bor (($c.G -shr 4) -shl 4) -bor ($c.B -shr 4)
            $b = $buckets[$key]
            if (-not $b) { $b = @{ N = 0; R = 0; G = 0; B = 0 }; $buckets[$key] = $b }
            $b['N'] += 1; $b['R'] += $c.R; $b['G'] += $c.G; $b['B'] += $c.B
        }
    }
    $bmp.Dispose()
    $colors = @(foreach ($b in $buckets.Values) {
        $hex = ConvertTo-Hex ($b.R / $b.N) ($b.G / $b.N) ($b.B / $b.N)
        $hsl = ConvertTo-Hsl $hex
        [pscustomobject]@{ Hex = $hex; N = $b.N; H = $hsl.H; S = $hsl.S; L = $hsl.L }
    }) | Sort-Object N -Descending

    # Background: warna dominan, digelapkan & diredam
    $dom = $colors[0]
    $bgSat = if ($dom.S -lt 0.08) { 0.05 } else { [Math]::Min($dom.S, 0.45) * 0.7 }
    $bg = ConvertFrom-Hsl $dom.H $bgSat 0.10
    $fg = ConvertFrom-Hsl $dom.H ([Math]::Min($bgSat, 0.25)) 0.90

    # Aksen: warna yang paling "hidup" & banyak, dengan rona yang saling berbeda
    $cands = $colors | Where-Object { $_.S -ge 0.2 -and $_.L -ge 0.12 -and $_.L -le 0.92 } |
        Sort-Object { $_.N * (0.3 + $_.S) * (1 - [Math]::Abs($_.L - 0.5)) } -Descending
    $hues = @()
    foreach ($c in $cands) {
        if ($hues.Count -ge 4) { break }
        if (@($hues | Where-Object { (Get-HueDistance $_.H $c.H) -lt 35 }).Count -eq 0) { $hues += $c }
    }
    $acc = @($hues | ForEach-Object { ConvertFrom-Hsl $_.H ([Math]::Max(0.55, [Math]::Min(0.9, $_.S + 0.15))) 0.66 })
    $seedHue = if ($hues.Count) { $hues[0].H } else { $dom.H }
    $offsets = @(45, -45, 180, 90)
    $oi = 0
    while ($acc.Count -lt 4) { $acc += ConvertFrom-Hsl ($seedHue + $offsets[$oi]) 0.65 0.66; $oi++ }

    $scheme = New-GlowshScheme "Glowsh $Title" $bg $fg $acc
    return @{
        Title = $Title; Signature = $true; Custom = $true; Light = $false
        Desc = @('dibuat dari wallpaper kamu', 'generated from your wallpaper')
        Accents = [ordered]@{ a1 = $acc[0]; a2 = $acc[1]; a3 = $acc[2]; a4 = $acc[3]; ok = $scheme.green; err = $scheme.red; muted = (Get-MixedColor $bg $fg 0.45) }
        Scheme = $scheme
    }
}

# ============================================================ berbagi tema (kode pendek)
function ConvertTo-GlowshShareCode($Theme) {
    $a = Get-ThemeAccents $Theme
    $bytes = New-Object System.Collections.Generic.List[byte]
    $bytes.Add(1)                                         # versi format
    $bytes.Add([byte]$(if ($Theme.Light -or ($Theme.Palette -and $Theme.Palette.light)) { 1 } else { 0 }))
    foreach ($hex in @($Theme.Scheme.background, $Theme.Scheme.foreground, $a.a1, $a.a2, $a.a3, $a.a4, $a.ok, $a.err, $a.muted)) {
        foreach ($v in (Get-RgbParts $hex)) { $bytes.Add([byte]$v) }
    }
    $name = [Text.Encoding]::UTF8.GetBytes($Theme.Title)
    foreach ($v in ($name | Select-Object -First 24)) { $bytes.Add($v) }
    $b64 = [Convert]::ToBase64String($bytes.ToArray()).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    return "GLW-$b64"
}

function ConvertFrom-GlowshShareCode([string]$Code) {
    if ($Code -notmatch '^GLW-([A-Za-z0-9_-]+)$') { throw (L 'Kode tidak valid (harus diawali GLW-)' 'Invalid code (must start with GLW-)') }
    $b64 = $Matches[1].Replace('-', '+').Replace('_', '/')
    while ($b64.Length % 4) { $b64 += '=' }
    $bytes = [Convert]::FromBase64String($b64)
    if ($bytes.Length -lt 29 -or $bytes[0] -ne 1) { throw (L 'Kode tidak valid atau versinya tidak dikenal' 'Invalid code or unknown version') }
    $hex = for ($i = 0; $i -lt 9; $i++) { ConvertTo-Hex $bytes[2 + $i * 3] $bytes[3 + $i * 3] $bytes[4 + $i * 3] }
    $title = if ($bytes.Length -gt 29) { [Text.Encoding]::UTF8.GetString($bytes, 29, $bytes.Length - 29) } else { 'Shared' }
    $light = $bytes[1] -eq 1
    $scheme = New-GlowshScheme "Glowsh $title" $hex[0] $hex[1] @($hex[2], $hex[3], $hex[4], $hex[5]) -Light:$light
    return @{
        Title = $title; Signature = $true; Custom = $true; Light = $light
        Desc = @('tema hasil import', 'imported theme')
        Accents = [ordered]@{ a1 = $hex[2]; a2 = $hex[3]; a3 = $hex[4]; a4 = $hex[5]; ok = $hex[6]; err = $hex[7]; muted = $hex[8] }
        Scheme = $scheme
    }
}

# ============================================================ execution policy
function Get-GlowshPolicyState {
    $list = @{}
    Get-ExecutionPolicy -List | ForEach-Object { $list[$_.Scope.ToString()] = $_.ExecutionPolicy.ToString() }
    $gpo = @($list['MachinePolicy'], $list['UserPolicy']) | Where-Object { $_ -and $_ -ne 'Undefined' } | Select-Object -First 1
    if ($gpo) { return [pscustomobject]@{ Policy = $gpo; Gpo = $true } }
    $p = if ($list['CurrentUser'] -ne 'Undefined') { $list['CurrentUser'] }
         elseif ($list['LocalMachine'] -ne 'Undefined') { $list['LocalMachine'] }
         else { 'Restricted' }
    return [pscustomobject]@{ Policy = $p; Gpo = $false }
}

function Set-GlowshPolicy {
    # Bisa "error" walau berhasil kalau ada policy level Process (mis. -ExecutionPolicy Bypass); cek ulang
    try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force } catch {}
    if ((Get-ExecutionPolicy -Scope CurrentUser).ToString() -ne 'RemoteSigned') { throw (L 'Gagal mengubah Execution Policy' 'Could not change the Execution Policy') }
}

# ============================================================ komponen yang di-install
function Install-GlowshOmp {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $tmp = Join-Path $env:TEMP "glowsh-omp-$PID.exe"
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-$(Get-GlowshArch).exe" -OutFile $tmp
    try { Move-Item $tmp $OmpExe -Force }
    catch {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        if (Test-Path $OmpExe) { return (L 'lama (file sedang dipakai, tidak diperbarui)' 'old (file in use, not updated)') }
        throw
    }
    return [string](& $OmpExe version)
}

function Save-GlowshClassicThemes {
    New-Item -ItemType Directory -Path $ThemeDir -Force | Out-Null
    foreach ($t in $GlowshThemes.Values) {
        if (-not $t.Omp) { continue }
        Invoke-WebRequest -UseBasicParsing -OutFile (Join-Path $ThemeDir "$($t.Omp).omp.json") `
            -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$($t.Omp).omp.json"
    }
}

function Install-GlowshFont {
    if (-not (Test-Path $OmpExe)) { throw (L 'Oh My Posh belum terpasang' 'Oh My Posh is not installed') }
    # Tanpa hak admin, Oh My Posh otomatis menginstall font untuk user ini saja
    & $OmpExe font install Meslo
    if ($LASTEXITCODE -ne 0) { throw "oh-my-posh exit code $LASTEXITCODE" }
}

function Initialize-GlowshNuGet {
    if ($PSVersionTable.PSVersion.Major -ge 6) { return }
    $nuget = Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue |
             Where-Object { $_.Version -ge [version]'2.8.5.201' }
    if (-not $nuget) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null }
}

function Install-GlowshTerminalIcons {
    if (Get-Module -ListAvailable -Name Terminal-Icons) { return }
    Initialize-GlowshNuGet
    Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
}

function Test-GlowshPSReadLine {
    $v = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
    return ($v -and $v.Version -ge [version]'2.1.0')
}

function Install-GlowshPSReadLine {
    if (Test-GlowshPSReadLine) { return }
    Initialize-GlowshNuGet
    Install-Module -Name PSReadLine -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
}

function Install-GlowshClink {
    $exeName = switch (Get-GlowshArch) { 'arm64' { 'clink_arm64.exe' } '386' { 'clink_x86.exe' } default { 'clink_x64.exe' } }
    $clinkExe = Join-Path $ClinkDir $exeName
    if (-not (Test-Path $clinkExe)) {
        $rel = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/chrisant996/clink/releases/latest'
        $zipAsset = $rel.assets | Where-Object { $_.name -match '^clink\.[\d.]+\.[0-9a-f]+\.zip$' } | Select-Object -First 1
        if (-not $zipAsset) { throw (L 'File rilis Clink tidak ditemukan' 'Clink release file not found') }
        $zip = Join-Path $env:TEMP "glowsh-clink-$PID.zip"
        Invoke-WebRequest -UseBasicParsing -Uri $zipAsset.browser_download_url -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $ClinkDir -Force
        Remove-Item $zip -ErrorAction SilentlyContinue
        if (-not (Test-Path $clinkExe)) { $clinkExe = Join-Path $ClinkDir 'clink_x64.exe' }   # ARM64 bisa emulasi x64
    }
    New-Item -ItemType Directory -Path $ClinkProfile -Force | Out-Null
    # Dimuat Clink setiap CMD dibuka -> menjalankan prompt Oh My Posh.
    # Tanda kutip ganda di luar diperlukan karena io.popen memakai "cmd /c".
    $lua = @'
-- Glowsh: prompt Oh My Posh untuk CMD (versi lite tanpa ikon di jendela console klasik)
local glow = os.getenv("USERPROFILE") .. "\\.glowsh"
local cfg = glow .. "\\theme.omp.json"
if not os.getenv("WT_SESSION") and not os.getenv("TERM_PROGRAM") and os.isfile(glow .. "\\theme-lite.omp.json") then
    cfg = glow .. "\\theme-lite.omp.json"
end
local f = io.popen('""' .. glow .. '\\bin\\oh-my-posh.exe" init cmd --config "' .. cfg .. '""')
if f then
    local script = f:read("*a")
    f:close()
    local chunk = load(script)
    if chunk then chunk() end
end
'@
    Write-Utf8NoBom (Join-Path $ClinkProfile 'glowsh.lua') $lua
    & $clinkExe autorun install -- --quiet --profile "$ClinkProfile" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "clink autorun exit code $LASTEXITCODE" }
}

# Windows Terminal versi unpackaged (zip resmi dari GitHub Microsoft): tanpa Store, winget, maupun admin.
function Install-PortableTerminal {
    $arch = switch (Get-GlowshArch) { 'arm64' { 'arm64' } '386' { 'x86' } default { 'x64' } }
    $rel = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/microsoft/terminal/releases/latest'
    $zipAsset = $rel.assets | Where-Object { $_.name -like "Microsoft.WindowsTerminal_*_$arch.zip" } | Select-Object -First 1
    if (-not $zipAsset) { throw "Windows Terminal ($arch) not found in release $($rel.tag_name)" }
    $zip    = Join-Path $env:TEMP "glowsh-wt-$PID.zip"
    $tmpDir = Join-Path $env:TEMP "glowsh-wt-$PID"
    Invoke-WebRequest -UseBasicParsing -Uri $zipAsset.browser_download_url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmpDir -Force
    $exe = Get-ChildItem $tmpDir -Recurse -Filter 'WindowsTerminal.exe' | Select-Object -First 1
    if (-not $exe) { throw 'WindowsTerminal.exe not found in zip' }
    if (Test-Path $WtPortableDir) { Remove-Item $WtPortableDir -Recurse -Force }
    New-Item -ItemType Directory -Path (Split-Path $WtPortableDir) -Force | Out-Null
    Move-Item $exe.DirectoryName $WtPortableDir
    Remove-Item $zip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

    $shell = New-Object -ComObject WScript.Shell
    foreach ($dir in [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop')) {
        $lnk = $shell.CreateShortcut((Join-Path $dir 'Windows Terminal.lnk'))
        $lnk.TargetPath = $WtPortableExe
        $lnk.WorkingDirectory = $HOME
        $lnk.IconLocation = "$WtPortableExe,0"
        $lnk.Save()
    }
    [void](Register-GlowshWtAlias)
    return $rel.tag_name
}

function Install-GlowshShell {
    New-Item -ItemType Directory -Path $GlowHome -Force | Out-Null
    $text = $GlowshShellTemplate.Replace('#__SHARED__', $GlowshSharedCode)
    [IO.File]::WriteAllText($ShellFile, $text, (New-Object Text.UTF8Encoding $true))
}

function Install-GlowshProfile {
    $block = @'
# >>> glowsh >>>
# Ditambahkan oleh Glowsh / added by Glowsh. Hapus dengan / remove with: glowsh uninstall
$__glowshShell = Join-Path $HOME '.glowsh\shell.ps1'
if (Test-Path $__glowshShell) { . $__glowshShell }
Remove-Variable __glowshShell -ErrorAction SilentlyContinue
# <<< glowsh <<<
'@
    $pattern = '(?s)' + [regex]::Escape($MarkStart) + '.*?' + [regex]::Escape($MarkEnd)
    foreach ($p in Get-ProfileTargets) {
        $dir = Split-Path $p
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $content = if (Test-Path $p) { [IO.File]::ReadAllText($p) } else { '' }
        $content = [regex]::Replace($content, $pattern, '').TrimEnd()
        $content = if ($content) { $content + "`r`n`r`n" + $block + "`r`n" } else { $block + "`r`n" }
        [IO.File]::WriteAllText($p, $content, (New-Object Text.UTF8Encoding $true))
        Write-Ok $p
    }
}

function Test-GlowshUserPath {
    $cur = [string](Get-Item 'HKCU:\Environment').GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    return [bool](@($cur -split ';') | Where-Object { $_ -and $_.TrimEnd('\') -eq $BinDir.TrimEnd('\') })
}

function Add-GlowshUserPath {
    if (Test-GlowshUserPath) { return }
    $cur = [string](Get-Item 'HKCU:\Environment').GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $parts = @($cur -split ';' | Where-Object { $_ }) + $BinDir
    Set-ItemProperty -Path 'HKCU:\Environment' -Name 'Path' -Value ($parts -join ';') -Type ExpandString
    # Set lalu hapus variabel dummy supaya Windows menyebarkan perubahan PATH ke jendela baru
    [Environment]::SetEnvironmentVariable('GLOWSH_REFRESH', '1', 'User')
    [Environment]::SetEnvironmentVariable('GLOWSH_REFRESH', $null, 'User')
    if (-not (@($env:Path -split ';') -contains $BinDir)) { $env:Path += ";$BinDir" }
}

function Install-GlowshCommand {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $cmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\.glowsh\glowsh.ps1`" %*`r`n"
    [IO.File]::WriteAllText((Join-Path $BinDir 'glowsh.cmd'), $cmd, (New-Object Text.ASCIIEncoding))
    Add-GlowshUserPath
}

# Daftar perintah untuk saran salah ketik (sama dengan yang dibuat shell.ps1); dibuat saat install supaya saran pertama cepat
function Update-GlowshCommandCache {
    $names = @(Get-Command -CommandType Cmdlet, Application -ErrorAction SilentlyContinue |
        ForEach-Object { if ($_.CommandType -eq 'Application') { [IO.Path]::GetFileNameWithoutExtension($_.Name).ToLower() } else { $_.Name } } |
        Sort-Object -Unique)
    [IO.File]::WriteAllLines((Join-Path $GlowHome 'command-cache.txt'), [string[]]$names)
    return $names.Count
}

# Saran salah ketik untuk git (git pusj -> git push) memakai fitur bawaan git: help.autocorrect
function Set-GlowshGitAutocorrect([bool]$On) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
    $bk = Join-Path $BackupDir 'git-autocorrect.txt'
    if (-not (Test-Path $bk)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        $orig = [string](git config --global --get help.autocorrect)
        Write-Utf8NoBom $bk $(if ($orig) { $orig } else { '<unset>' })
    }
    if ($On) {
        $ver = [version]'0.0'
        if ((git --version) -match '(\d+\.\d+)') { $ver = [version]$Matches[1] }
        git config --global help.autocorrect $(if ($ver -ge [version]'2.34') { 'prompt' } else { '20' })
    } else {
        $orig = ([IO.File]::ReadAllText($bk)).Trim()
        if ($orig -eq '<unset>') { git config --global --unset help.autocorrect } else { git config --global help.autocorrect $orig }
    }
    return $true
}

# ============================================================ menerapkan tema
function New-SignaturePrompt($Theme) {
    $a = Get-ThemeAccents $Theme
    return $GlowshPromptTemplate.Replace('__BG__', $Theme.Scheme.background).Replace('__A1__', $a.a1).Replace('__A2__', $a.a2).
        Replace('__A3__', $a.a3).Replace('__A4__', $a.a4).Replace('__OK__', $a.ok).Replace('__ERR__', $a.err).Replace('__MUTED__', $a.muted)
}

# Versi tanpa glyph Nerd Font untuk jendela console klasik: warna tetap, ikon diganti teks biasa
function New-LitePrompt($Theme) {
    $j = New-SignaturePrompt $Theme
    $map = [ordered]@{
        '"template": "{{ .Icon }} "' = '"template": "{{ if .WSL }}WSL {{ end }}"'   # template kosong = OMP pakai default (berikon)
        '"options": { "fetch_status": true }' = '"options": { "fetch_status": true, "branch_icon": "", "commit_icon": "@", "tag_icon": "#" }'
        '\uf00d ' = 'x '; '\uf00c' = 'ok'; '\uf044' = '~'; '\uf046' = '+'
        ' \uf07c ' = ' '; '\uf252 ' = ''; '\uf017 ' = ''; '\u276f' = '>'
        '\ue0b6' = ''; '\ue0b4' = ''; '\ue0b0' = ''
    }
    foreach ($k in $map.Keys) { $j = $j.Replace($k, $map[$k]) }
    return $j
}

# Supaya "wt" bisa dipakai dari Win+R / Start untuk Windows Terminal versi portable
function Register-GlowshWtAlias {
    if (-not (Test-Path $WtPortableExe)) { return $false }
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\wt.exe'
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name '(default)' -Value $WtPortableExe
    Set-ItemProperty -Path $key -Name 'Path' -Value $WtPortableDir
    return $true
}

# Daftar tombol yang sudah dipakai di settings.json (format lama "actions" maupun format baru "keybindings")
function Get-WTBoundKeys($Json) {
    $keys = @()
    foreach ($list in @($Json.actions, $Json.keybindings)) {
        foreach ($a in @($list)) { if ($a -and $a.keys) { $keys += ([string]$a.keys).ToLower() } }
    }
    return $keys
}

# Windows Terminal hanya punya Ctrl+Shift+C/V bawaan; Ctrl+C/V biasanya ditambahkan di settings.json buatan WT sendiri.
# File minimal buatan Glowsh tidak punya itu, jadi tambahkan di sini (hanya kalau tombolnya belum dipakai user).
# Ctrl+C tetap menghentikan perintah kalau tidak ada teks yang diseleksi.
function Add-WTCopyPasteKeys($Json) {
    $bound = Get-WTBoundKeys $Json
    $wanted = @(
        @{ Keys = 'ctrl+c'; Id = 'Terminal.CopyToClipboard'; Legacy = [pscustomobject]@{ action = 'copy'; singleLine = $false } },
        @{ Keys = 'ctrl+v'; Id = 'Terminal.PasteFromClipboard'; Legacy = 'paste' }
    )
    $newFormat = [bool]$Json.PSObject.Properties['keybindings']
    foreach ($w in $wanted) {
        if ($bound -contains $w.Keys) { continue }
        if ($newFormat) {
            Set-JsonProp $Json 'keybindings' (@(@($Json.keybindings) | Where-Object { $_ }) + [pscustomobject]@{ id = $w.Id; keys = $w.Keys })
        } else {
            Set-JsonProp $Json 'actions' (@(@($Json.actions) | Where-Object { $_ }) + [pscustomobject]@{ command = $w.Legacy; keys = $w.Keys })
        }
    }
}

function Update-WTSettings($Theme) {
    $fails = 0
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        # Bug PS 5.1: tanpa ini, array bisa diserialisasi jadi {"value":[...],"Count":n}
        Remove-TypeData System.Array -ErrorAction SilentlyContinue
    }
    # Windows Terminal portable yang belum pernah dibuka belum punya settings.json -> buat versi minimal.
    $unp = $WtTargets['unpackaged']
    if ((Test-Path $WtPortableExe) -and -not (Test-Path $unp)) {
        New-Item -ItemType Directory -Path (Split-Path $unp) -Force | Out-Null
        Write-Utf8NoBom $unp '{ "$schema": "https://aka.ms/terminal-profiles-schema", "keybindings": [], "profiles": { "defaults": {}, "list": [] }, "schemes": [] }'
    }
    $applied = 0
    foreach ($key in @($WtTargets.Keys)) {
        $path = $WtTargets[$key]
        if (-not (Test-Path $path)) { continue }
        try {
            $json = Read-JsonLoose $path
            # Semua skema Glowsh dimasukkan, jadi bisa juga dipilih dari menu Settings Windows Terminal
            $schemes = @()
            if ($json.PSObject.Properties['schemes'] -and $json.schemes) {
                $schemes = @($json.schemes | Where-Object { $_ -and ($_.name -notlike 'Glowsh *') })
            }
            foreach ($t in $GlowshThemes.Values) { $schemes += [pscustomobject]$t.Scheme }
            Set-JsonProp $json 'schemes' $schemes

            if (-not $json.PSObject.Properties['profiles'] -or $null -eq $json.profiles) {
                Set-JsonProp $json 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() })
            } elseif ($json.profiles -is [array]) {
                Set-JsonProp $json 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = $json.profiles })
            }
            if (-not $json.profiles.PSObject.Properties['defaults'] -or $null -eq $json.profiles.defaults) {
                Set-JsonProp $json.profiles 'defaults' ([pscustomobject]@{})
            }
            $d = $json.profiles.defaults
            if ($d.PSObject.Properties['font'] -and $d.font) { Set-JsonProp $d.font 'face' $FontFace }
            else { Set-JsonProp $d 'font' ([pscustomobject]@{ face = $FontFace }) }
            Set-JsonProp $d 'colorScheme' $Theme.Scheme.name
            Set-JsonProp $d 'opacity' 92
            Set-JsonProp $d 'useAcrylic' $true
            Add-WTCopyPasteKeys $json

            Write-Utf8NoBom $path ($json | ConvertTo-Json -Depth 32)
            $applied++
        } catch { Write-Bad "Windows Terminal ($key): $($_.Exception.Message)"; $fails++ }
    }
    if ($applied -gt 0) { Write-Ok (L 'Windows Terminal: warna, font & transparansi' 'Windows Terminal: colors, font & translucency') }
    elseif (Test-WindowsTerminal) { Write-Note (L 'Pengaturan Windows Terminal belum ada. Buka Windows Terminal sekali, lalu jalankan: glowsh theme' 'Windows Terminal has no settings yet. Open it once, then run: glowsh theme') }
    return $fails
}

function Clear-WTProfileOverrides([string]$Path) {
    if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }
    $json = Read-JsonLoose $Path
    $list = if ($json.profiles -is [array]) { $json.profiles } else { $json.profiles.list }
    foreach ($p in @($list)) {
        if (-not $p) { continue }
        if ($p.PSObject.Properties['fontFace']) { $p.PSObject.Properties.Remove('fontFace') }
        if ($p.PSObject.Properties['font'] -and $p.font -and $p.font.PSObject.Properties['face']) {
            $p.font.PSObject.Properties.Remove('face')
            if (@($p.font.PSObject.Properties).Count -eq 0) { $p.PSObject.Properties.Remove('font') }
        }
        if ($p.PSObject.Properties['colorScheme'] -and ([string]$p.colorScheme) -notlike 'Glowsh *') {
            $p.PSObject.Properties.Remove('colorScheme')
        }
    }
    Write-Utf8NoBom $Path ($json | ConvertTo-Json -Depth 32)
}

function Set-ConsoleColors($Theme) {
    # Urutan ColorTable00..15 console klasik. Index 0 = background, index 7 = teks default.
    $map = 'background', 'blue', 'green', 'cyan', 'red', 'purple', 'yellow', 'foreground',
           'brightBlack', 'brightBlue', 'brightGreen', 'brightCyan', 'brightRed', 'brightPurple', 'brightYellow', 'brightWhite'
    for ($i = 0; $i -lt 16; $i++) {
        Set-ItemProperty -Path $ConsoleKey -Name ('ColorTable{0:D2}' -f $i) -Value (ConvertTo-ConsoleColor $Theme.Scheme[$map[$i]]) -Type DWord
    }
    Set-ItemProperty -Path $ConsoleKey -Name 'ScreenColors' -Value 0x07 -Type DWord
}

# -Explicit = dipilih langsung oleh user (bukan oleh mode auto/musiman)
function Set-GlowshTheme([string]$Id, [switch]$Explicit) {
    $t = $GlowshThemes[$Id]
    if (-not $t) { throw (L "Tema '$Id' tidak dikenal" "Unknown theme '$Id'") }
    New-Item -ItemType Directory -Path $GlowHome, $ThemeDir -Force | Out-Null
    $fails = 0
    try {
        if ($t.Omp) {
            $cached = Join-Path $ThemeDir "$($t.Omp).omp.json"
            if (-not (Test-Path $cached)) {
                Invoke-WebRequest -UseBasicParsing -OutFile $cached `
                    -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$($t.Omp).omp.json"
            }
            Copy-Item $cached $ThemeFile -Force
        } else { Write-Utf8NoBom $ThemeFile (New-SignaturePrompt $t) }
        Write-Utf8NoBom (Join-Path $GlowHome 'theme-lite.omp.json') (New-LitePrompt $t)
        Write-Ok "Prompt: $($t.Title)"
    } catch { Write-Bad "Prompt: $($_.Exception.Message)"; $fails++ }
    $fails += Update-WTSettings $t
    try { Set-ConsoleColors $t; Write-Ok (L 'Warna console klasik' 'Classic console colors') }
    catch { Write-Bad "Console: $($_.Exception.Message)"; $fails++ }
    Write-Utf8NoBom $StateFile $Id

    if ($Explicit) {
        Set-GlowshConfigValue 'baseTheme' $Id
        if ((Get-GlowshConfig).auto -eq $true) {
            Set-GlowshConfigValue 'auto' $false
            Write-Note (L 'Mode auto dimatikan karena kamu memilih tema sendiri. Nyalakan lagi: glowsh auto on' 'Auto mode turned off because you picked a theme. Turn it back on: glowsh auto on')
        }
        $season = Get-GlowshSeason
        if ($season -and $season -ne $Id) { Set-GlowshConfigValue 'seasonSkip' "$season-$((Get-Date).Year)" }
    }
    return $fails
}

function Invoke-GlowshSync {
    $want = Get-GlowshDesiredTheme (Get-GlowshConfig)
    if ($want -and $GlowshThemes.Contains($want) -and $want -ne (Get-GlowshCurrentTheme)) { [void](Set-GlowshTheme $want) }
}

# ============================================================ pemilih tema dengan preview
function Enable-VirtualTerminal {
    # Pastikan console lama (conhost) memproses kode warna ANSI
    try {
        if (-not ('GlowshNative.Console' -as [type])) {
            Add-Type -Namespace GlowshNative -Name Console -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        }
        $h = [GlowshNative.Console]::GetStdHandle(-11)
        [uint32]$mode = 0
        if ([GlowshNative.Console]::GetConsoleMode($h, [ref]$mode)) { [void][GlowshNative.Console]::SetConsoleMode($h, $mode -bor 4) }
    } catch {}
}

function Format-PreviewLine([string]$Bg, [string]$Fg, [object[]]$Parts, [int]$Width = 52) {
    $e = [char]27
    $out = '    '
    $len = 0
    foreach ($p in $Parts) {
        $pb = if ($p.B) { $p.B } else { $Bg }
        $pf = if ($p.F) { $p.F } else { $Fg }
        $out += "$e[48;2;$(Get-Rgb $pb)m$e[38;2;$(Get-Rgb $pf)m$($p.T)"
        $len += $p.T.Length
    }
    return $out + "$e[48;2;$(Get-Rgb $Bg)m" + (' ' * [Math]::Max(0, $Width - $len)) + "$e[0m"
}

function Get-ThemePreview($Theme) {
    $s = $Theme.Scheme
    $a = Get-ThemeAccents $Theme
    $bg = $s.background; $fg = $s.foreground
    $lines = @()
    $lines += Format-PreviewLine $bg $fg @()
    $lines += Format-PreviewLine $bg $fg @(
        @{ T = '  ' }, @{ T = ' HP '; F = $bg; B = $a.a1 }, @{ T = ' ~\proyek '; F = $bg; B = $a.a2 },
        @{ T = ' main '; F = $bg; B = $a.a3 }, @{ T = ' ok '; F = $bg; B = $a.ok }, @{ T = '        14:32'; F = $a.muted })
    $lines += Format-PreviewLine $bg $fg @(@{ T = '  > '; F = $a.a1 }, @{ T = 'ls' })
    $lines += Format-PreviewLine $bg $fg @(
        @{ T = '  folder/  '; F = $s.blue }, @{ T = 'skrip.ps1  '; F = $s.green },
        @{ T = 'catatan.txt  '; F = $s.yellow }, @{ T = 'foto.png'; F = $s.purple })
    $lines += Format-PreviewLine $bg $fg @(@{ T = '  > '; F = $a.err }, @{ T = 'git pusj' })
    $lines += Format-PreviewLine $bg $fg @(@{ T = "  git: 'pusj' is not a git command"; F = $s.red })
    $lines += Format-PreviewLine $bg $fg @()
    foreach ($row in @(('black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white'),
                       ('brightBlack', 'brightRed', 'brightGreen', 'brightYellow', 'brightBlue', 'brightPurple', 'brightCyan', 'brightWhite'))) {
        $parts = @(@{ T = '  ' })
        foreach ($c in $row) { $parts += @{ T = '      '; B = $s[$c] } }
        $lines += Format-PreviewLine $bg $fg $parts
    }
    $lines += Format-PreviewLine $bg $fg @()
    return $lines
}

function Get-ThemeTag($Theme) {
    if ($Theme.Season) { return '~' }
    if ($Theme.Custom) { return '+' }
    if ($Theme.Signature) { return '*' }
    return ' '
}

function Show-ThemePicker([string]$CurrentId = 'senja') {
    $ids = @($GlowshThemes.Keys)
    $idx = [Math]::Max(0, [Array]::IndexOf($ids, $CurrentId))
    $interactive = $true
    try { if ([Console]::IsInputRedirected -or $Host.Name -ne 'ConsoleHost') { $interactive = $false } } catch { $interactive = $false }

    if (-not $interactive) {
        # Cadangan untuk host yang tidak mendukung tombol panah: menu bernomor
        for ($i = 0; $i -lt $ids.Count; $i++) {
            $t = $GlowshThemes[$ids[$i]]
            Write-Host ("    [{0}] {1} - {2}" -f ($i + 1), $t.Title, (Get-ThemeDesc $t))
        }
        return Resolve-GlowshThemeId (Read-Host ('    ' + (L 'Nomor tema' 'Theme number')))
    }

    Enable-VirtualTerminal
    $e = [char]27
    [Console]::Write("$e[?1049h$e[?25l")   # layar alternatif + sembunyikan kursor
    try {
        while ($true) {
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append("$e[H$e[2J")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("  $e[1;35mGlowsh$e[0m - " + (L 'pilih tema' 'pick a theme'))
            [void]$sb.AppendLine("  $e[90m" + (L '[atas/bawah] pilih   [Enter] pakai   [Esc] batal' '[up/down] move   [Enter] apply   [Esc] cancel') + "$e[0m")
            [void]$sb.AppendLine('')
            for ($i = 0; $i -lt $ids.Count; $i++) {
                $t = $GlowshThemes[$ids[$i]]
                $now = if ($ids[$i] -eq $CurrentId) { '  (' + (L 'aktif' 'active') + ')' } else { '' }
                $name = ('{0} {1}' -f (Get-ThemeTag $t), $t.Title).PadRight(20)
                if ($i -eq $idx) {
                    $acc = Get-Rgb (Get-ThemeAccents $t).a1
                    [void]$sb.AppendLine("  $e[1;38;2;${acc}m> $name$e[0m$e[37m$(Get-ThemeDesc $t)$now$e[0m")
                } else {
                    [void]$sb.AppendLine("    $name$e[90m$(Get-ThemeDesc $t)$now$e[0m")
                }
            }
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("  $e[90m" + (L '* khas Glowsh   ~ musiman   + buatanmu' '* Glowsh signature   ~ seasonal   + your own') + "$e[0m")
            [void]$sb.AppendLine('')
            foreach ($l in (Get-ThemePreview $GlowshThemes[$ids[$idx]])) { [void]$sb.AppendLine($l) }
            [Console]::Write($sb.ToString())

            $k = [Console]::ReadKey($true)
            switch ($k.Key) {
                'UpArrow'   { $idx = ($idx - 1 + $ids.Count) % $ids.Count }
                'DownArrow' { $idx = ($idx + 1) % $ids.Count }
                'Enter'     { return $ids[$idx] }
                'Escape'    { return $null }
                'Q'         { return $null }
                default {
                    $n = 0
                    if ([int]::TryParse([string]$k.KeyChar, [ref]$n) -and $n -ge 1 -and $n -le $ids.Count) { $idx = $n - 1 }
                }
            }
        }
    } finally { [Console]::Write("$e[?25h$e[?1049l") }
}

function Show-ThemeCard($Theme) {
    Enable-VirtualTerminal
    Write-Host ''
    foreach ($l in (Get-ThemePreview $Theme)) { [Console]::WriteLine($l) }
    Write-Host ''
}

# ============================================================ explain
$GlowshExplain = @{
    'set-location'        = @('Pindah ke folder lain.', 'Changes the current folder.')
    'get-childitem'       = @('Menampilkan isi folder (daftar file & subfolder).', 'Lists the files and folders inside a folder.')
    'copy-item'           = @('Menyalin file atau folder.', 'Copies files or folders.')
    'move-item'           = @('Memindahkan atau mengganti nama file/folder.', 'Moves or renames files/folders.')
    'remove-item'         = @('Menghapus file atau folder.', 'Deletes files or folders.')
    'new-item'            = @('Membuat file atau folder baru.', 'Creates a new file or folder.')
    'get-content'         = @('Menampilkan isi file teks.', 'Shows the contents of a text file.')
    'set-content'         = @('Menulis (menimpa) isi file teks.', 'Writes (overwrites) the contents of a text file.')
    'write-output'        = @('Menampilkan teks / meneruskan data ke perintah berikutnya.', 'Prints text / passes data down the pipeline.')
    'clear-host'          = @('Membersihkan layar terminal.', 'Clears the terminal screen.')
    'get-process'         = @('Menampilkan program yang sedang berjalan.', 'Lists running programs.')
    'stop-process'        = @('Menghentikan paksa program yang sedang berjalan.', 'Force-stops a running program.')
    'select-string'       = @('Mencari teks di dalam file atau output (seperti grep).', 'Searches for text in files or output (like grep).')
    'get-command'         = @('Mencari tahu sebuah perintah ada di mana / apa jenisnya (seperti which).', 'Finds where a command lives / what it is (like which).')
    'get-help'            = @('Menampilkan bantuan untuk sebuah perintah.', 'Shows help for a command.')
    'invoke-webrequest'   = @('Mengakses atau mengunduh sesuatu dari internet.', 'Fetches or downloads something from the internet.')
    'invoke-restmethod'   = @('Mengakses API/URL dan langsung membaca hasilnya.', 'Calls an API/URL and parses the result.')
    'invoke-expression'   = @('Menjalankan teks sebagai perintah. Hati-hati dengan teks dari sumber tak dikenal.', 'Runs text as a command. Be careful with text from unknown sources.')
    'set-executionpolicy' = @('Mengatur izin menjalankan script PowerShell.', 'Controls whether PowerShell scripts may run.')
    'stop-computer'       = @('Mematikan komputer.', 'Shuts down the computer.')
    'restart-computer'    = @('Me-restart komputer.', 'Restarts the computer.')
    'ping'                = @('Mengecek apakah komputer/server lain bisa dihubungi.', 'Checks whether another computer/server is reachable.')
    'ipconfig'            = @('Menampilkan info jaringan seperti alamat IP.', 'Shows network info such as your IP address.')
    'shutdown'            = @('Mematikan, me-restart, atau log off komputer.', 'Shuts down, restarts or logs off the computer.')
    'format'              = @('Mem-format drive (menghapus semua isinya).', 'Formats a drive (erases everything on it).')
    'winget'              = @('Package manager Windows: install, update, dan hapus aplikasi.', 'Windows package manager: install, update and remove apps.')
    'npm'                 = @('Package manager Node.js untuk library JavaScript.', 'Node.js package manager for JavaScript libraries.')
    'pip'                 = @('Package manager Python untuk library Python.', 'Python package manager.')
    'code'                = @('Membuka Visual Studio Code ("code ." = buka folder ini).', 'Opens Visual Studio Code ("code ." opens this folder).')
    'git'                 = @('Sistem kontrol versi untuk melacak perubahan kode.', 'Version control system that tracks changes to your code.')
    'git status'          = @('Melihat file apa saja yang berubah.', 'Shows which files have changed.')
    'git add'             = @('Menandai perubahan untuk dimasukkan ke commit berikutnya.', 'Stages changes for the next commit.')
    'git commit'          = @('Menyimpan perubahan yang sudah di-add sebagai satu "titik simpan".', 'Saves staged changes as a snapshot.')
    'git push'            = @('Mengirim commit ke remote (misalnya GitHub).', 'Uploads your commits to the remote (e.g. GitHub).')
    'git pull'            = @('Mengambil & menggabungkan perubahan terbaru dari remote.', 'Downloads and merges the latest changes from the remote.')
    'git clone'           = @('Mengunduh salinan sebuah repository.', 'Downloads a copy of a repository.')
    'git checkout'        = @('Pindah branch atau mengembalikan file ke versi tertentu.', 'Switches branches or restores files.')
    'git switch'          = @('Pindah ke branch lain.', 'Switches to another branch.')
    'git reset'           = @('Memundurkan commit atau membatalkan staging.', 'Moves the branch back or unstages changes.')
    'git log'             = @('Melihat riwayat commit.', 'Shows the commit history.')
    'git clean'           = @('Menghapus file yang tidak dilacak git.', 'Deletes files git is not tracking.')
    'glowsh'              = @('Glowsh! Pengatur tampilan terminal kamu. Coba: glowsh help', 'Glowsh! Your terminal makeover tool. Try: glowsh help')
}

$GlowshFlags = @{
    '-recurse' = @('ikut memproses semua isi folder & subfolder', 'also processes everything inside subfolders')
    '-r'       = @('rekursif: ikut memproses semua isi folder', 'recursive: includes everything inside folders')
    '-force'   = @('paksa, tanpa banyak konfirmasi (juga menyentuh file tersembunyi)', 'force it, fewer confirmations (also touches hidden files)')
    '-f'       = @('paksa (force)', 'force')
    '-rf'      = @('-r + -f: hapus semua isi folder secara paksa', '-r + -f: forcefully delete everything inside')
    '-whatif'  = @('hanya simulasi: tampilkan apa yang AKAN terjadi tanpa menjalankannya', 'dry run: show what WOULD happen without doing it')
    '-confirm' = @('minta konfirmasi sebelum menjalankan', 'ask for confirmation first')
    '/s'       = @('termasuk semua subfolder', 'include all subfolders')
    '/q'       = @('diam-diam, tanpa konfirmasi', 'quiet mode, no confirmation')
    '--hard'   = @('buang semua perubahan yang belum di-commit', 'throw away all uncommitted changes')
    '--force'  = @('paksa, timpa yang ada', 'force, overwrite what is there')
    '-m'       = @('pesan (misalnya pesan commit)', 'message (e.g. a commit message)')
    '-a'       = @('semua (all)', 'all')
    '-u'       = @('set upstream: ingat remote/branch untuk push berikutnya', 'set upstream: remember the remote/branch for next time')
    '-b'       = @('buat branch baru', 'create a new branch')
}

function Show-GlowshExplain([string[]]$Words) {
    $Words = @($Words | Where-Object { $_ })
    if ($Words.Count -eq 0) { Write-Host (L '  Pakai: glowsh explain <perintah>   contoh: glowsh explain rm -rf folder' '  Usage: glowsh explain <command>   e.g. glowsh explain rm -rf folder'); return }
    $line = $Words -join ' '
    $first = $Words[0]
    $two = if ($Words.Count -gt 1) { "$first $($Words[1])".ToLower() } else { '' }
    $key = $null; $title = $first; $cmd = $null
    if ($two -and $GlowshExplain.ContainsKey($two)) { $key = $two; $title = "$first $($Words[1])" }
    elseif ($GlowshExplain.ContainsKey($first.ToLower())) { $key = $first.ToLower() }
    else {
        $cmd = Get-Command $first -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.CommandType -eq 'Alias') {
            $res = [string]$cmd.ResolvedCommandName
            if (-not $res) { $res = [string]$cmd.Definition }
            $title = "$first  (alias: $res)"
            if ($GlowshExplain.ContainsKey($res.ToLower())) { $key = $res.ToLower() }
            else { $cmd = Get-Command $res -ErrorAction SilentlyContinue | Select-Object -First 1 }
        }
    }
    Write-Host ''
    Write-Host "  $title" -ForegroundColor Cyan
    if ($key) { Write-Host ('  ' + (L $GlowshExplain[$key][0] $GlowshExplain[$key][1])) }
    elseif ($cmd -and $cmd.CommandType -eq 'Application') { Write-Host ('  ' + (L 'Program di: ' 'Program at: ') + $cmd.Source) }
    elseif ($cmd) {
        $syn = $null
        try { $syn = [string](Get-Help $cmd.Name -ErrorAction Stop).Synopsis } catch {}
        if ($syn -and $syn.Trim()) { Write-Host ('  ' + $syn.Trim()) -NoNewline; Write-Host (L '  (dari Get-Help)' '  (from Get-Help)') -ForegroundColor DarkGray }
        else { Write-Host ('  ' + (L "Perintah jenis $($cmd.CommandType)." "A $($cmd.CommandType) command.")) }
    } else { Write-Host ('  ' + (L 'Perintah ini tidak dikenal di komputer ini.' 'This command is not known on this computer.')) -ForegroundColor Yellow }

    $flagLines = @()
    foreach ($w in ($Words | Select-Object -Skip 1)) {
        if ($w -match '^(-|/)' -and $GlowshFlags.ContainsKey($w.ToLower())) {
            $f = $GlowshFlags[$w.ToLower()]
            $flagLines += ('    {0,-10} {1}' -f $w, (L $f[0] $f[1]))
        }
    }
    if ($flagLines.Count) {
        Write-Host ''
        Write-Host ('  ' + (L 'Opsi yang dipakai:' 'Options used:')) -ForegroundColor White
        $flagLines | ForEach-Object { Write-Host $_ }
    }
    $danger = Get-GlowshDanger $line
    if ($danger) { Write-Host ''; Write-Host "  [!] $danger" -ForegroundColor Red }
    Write-Host ''
}

# ============================================================ doctor
function Invoke-GlowshDoctor {
    Write-Host ''
    Write-Host '  Glowsh Doctor' -ForegroundColor Magenta -NoNewline
    Write-Host (L ' - cek kesehatan tampilan terminal kamu' ' - checking the health of your terminal setup') -ForegroundColor DarkGray
    Write-Host ''
    $checks = New-Object System.Collections.ArrayList
    function Add-Check([string]$Status, [string]$Title, [string]$Hint = '', [scriptblock]$Fix = $null, [string]$FixLabel = '', $FixArg = $null) {
        $color = @{ OK = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }[$Status]
        $tag   = @{ OK = '[OK] '; WARN = '[!]  '; FAIL = '[X]  ' }[$Status]
        Write-Host "  $tag" -NoNewline -ForegroundColor $color
        Write-Host $Title
        if ($Hint) { Write-Host "       -> $Hint" -ForegroundColor DarkGray }
        [void]$checks.Add([pscustomobject]@{ Status = $Status; Fix = $Fix; FixLabel = $FixLabel; FixArg = $FixArg })
    }
    $reapply = { [void](Set-GlowshTheme (Get-GlowshCurrentTheme)) }

    # 1. Windows Terminal
    if (Test-WindowsTerminal) { Add-Check OK (L 'Windows Terminal terpasang' 'Windows Terminal is installed') }
    else {
        Add-Check FAIL (L 'Windows Terminal belum terpasang' 'Windows Terminal is not installed') (L 'Ikon & font Nerd Font paling bagus tampil di Windows Terminal.' 'Nerd Font icons look best in Windows Terminal.') `
            { [void](Install-PortableTerminal); [void](Set-GlowshTheme (Get-GlowshCurrentTheme)) } (L 'Install Windows Terminal (resmi Microsoft, tanpa Store)' 'Install Windows Terminal (official Microsoft build, no Store)')
    }

    # 2. Font
    if (Test-FontInstalled) { Add-Check OK (L "Font $FontFace terpasang" "Font $FontFace is installed") }
    else { Add-Check FAIL (L "Font $FontFace belum terpasang" "Font $FontFace is missing") (L 'Tanpa font ini ikon tampil sebagai kotak.' 'Without it, icons show up as boxes.') { Install-GlowshFont } (L 'Install font' 'Install the font') }

    # 3. Pengaturan Windows Terminal
    $foundSettings = $false
    foreach ($key in @($WtTargets.Keys)) {
        $path = $WtTargets[$key]
        if (-not (Test-Path $path)) { continue }
        $foundSettings = $true
        try { $json = Read-JsonLoose $path }
        catch { Add-Check FAIL (L "Pengaturan Windows Terminal ($key) tidak bisa dibaca" "Windows Terminal settings ($key) cannot be read") $path; continue }
        $d = $null
        if ($json.profiles -and -not ($json.profiles -is [array])) { $d = $json.profiles.defaults }
        $face = if ($d -and $d.font -and $d.font.face) { [string]$d.font.face } else { 'default' }
        $scheme = if ($d -and $d.colorScheme) { [string]$d.colorScheme } else { 'default' }
        if ($face -eq $FontFace -and $scheme -like 'Glowsh *') {
            Add-Check OK (L "Windows Terminal ($key) memakai font & tema Glowsh" "Windows Terminal ($key) uses the Glowsh font & theme")
        } else {
            Add-Check FAIL (L "Windows Terminal ($key) belum memakai Glowsh" "Windows Terminal ($key) is not using Glowsh") "font: $face, theme: $scheme" $reapply (L 'Terapkan ulang tema Glowsh' 'Re-apply the Glowsh theme')
        }
        $list = if ($json.profiles -is [array]) { $json.profiles } else { $json.profiles.list }
        $over = @($list | Where-Object {
            $_ -and (($_.PSObject.Properties['fontFace']) -or
                     ($_.font -and $_.font.face -and $_.font.face -ne $FontFace) -or
                     ($_.colorScheme -and ([string]$_.colorScheme) -notlike 'Glowsh *'))
        })
        if ($over.Count -gt 0) {
            $names = ($over | ForEach-Object { $_.name }) -join ', '
            Add-Check WARN (L "Profil ini memakai font/tema sendiri sehingga mengabaikan Glowsh: $names" "These profiles have their own font/theme and ignore Glowsh: $names") `
                (L 'Pengaturan per-profil selalu menang atas pengaturan default.' 'Per-profile settings always win over the defaults.') `
                { param($p) Clear-WTProfileOverrides $p } (L "Hapus font/tema khusus di profil: $names" "Remove the custom font/theme from: $names") $path
        }
        $bound = Get-WTBoundKeys $json
        if (($bound -contains 'ctrl+c') -and ($bound -contains 'ctrl+v')) {
            Add-Check OK (L "Windows Terminal ($key): Ctrl+C / Ctrl+V untuk copy-paste" "Windows Terminal ($key): Ctrl+C / Ctrl+V copy & paste")
        } else {
            Add-Check WARN (L "Windows Terminal ($key): Ctrl+C / Ctrl+V belum bisa copy-paste" "Windows Terminal ($key): Ctrl+C / Ctrl+V do not copy & paste yet") `
                (L 'Sementara pakai Ctrl+Shift+C / Ctrl+Shift+V.' 'Meanwhile use Ctrl+Shift+C / Ctrl+Shift+V.') $reapply (L 'Aktifkan Ctrl+C / Ctrl+V' 'Enable Ctrl+C / Ctrl+V')
        }
    }
    if (-not $foundSettings -and (Test-WindowsTerminal)) {
        Add-Check WARN (L 'Pengaturan Windows Terminal belum ada' 'Windows Terminal has no settings yet') (L 'Biasanya karena Windows Terminal belum pernah dibuka.' 'Usually because it has never been opened.') $reapply (L 'Buat pengaturan & terapkan tema' 'Create settings & apply the theme')
    }

    # 4. Oh My Posh & tema prompt
    if (Test-Path $OmpExe) {
        try { $v = [string](& $OmpExe version); Add-Check OK "Oh My Posh $v" }
        catch { Add-Check FAIL (L 'Oh My Posh tidak bisa dijalankan' 'Oh My Posh does not run') $_.Exception.Message { [void](Install-GlowshOmp) } (L 'Download ulang Oh My Posh' 'Re-download Oh My Posh') }
    } else { Add-Check FAIL (L 'Oh My Posh belum terpasang' 'Oh My Posh is not installed') '' { [void](Install-GlowshOmp) } (L 'Download Oh My Posh' 'Download Oh My Posh') }

    $title = $GlowshThemes[(Get-GlowshCurrentTheme)].Title
    $themeOk = $false
    if (Test-Path $ThemeFile) { try { $null = [IO.File]::ReadAllText($ThemeFile) | ConvertFrom-Json; $themeOk = $true } catch {} }
    if ($themeOk) { Add-Check OK (L "Tema aktif: $title" "Active theme: $title") }
    else { Add-Check FAIL (L 'File tema prompt hilang atau rusak' 'The prompt theme file is missing or broken') '' $reapply (L "Pasang ulang tema $title" "Reinstall theme $title") }

    # 5. Profil PowerShell, shell.ps1 & Execution Policy
    foreach ($p in Get-ProfileTargets) {
        $has = (Test-Path $p) -and ([IO.File]::ReadAllText($p) -match [regex]::Escape($MarkStart))
        $label = Split-Path (Split-Path $p) -Leaf
        if ($has) { Add-Check OK (L "Profil $label berisi Glowsh" "Profile $label loads Glowsh") }
        else { Add-Check FAIL (L "Profil $label belum berisi Glowsh" "Profile $label does not load Glowsh") $p { Install-GlowshProfile } (L 'Pasang ulang profil PowerShell' 'Reinstall the PowerShell profile') }
    }
    if (Test-Path $ShellFile) { Add-Check OK (L 'Integrasi shell (shell.ps1) ada' 'Shell integration (shell.ps1) is present') }
    else { Add-Check FAIL (L 'shell.ps1 hilang' 'shell.ps1 is missing') '' { Install-GlowshShell } (L 'Buat ulang shell.ps1' 'Recreate shell.ps1') }
    $pol = Get-GlowshPolicyState
    if ($pol.Policy -in 'RemoteSigned', 'Unrestricted', 'Bypass') { Add-Check OK "Execution Policy: $($pol.Policy)" }
    elseif ($pol.Gpo) { Add-Check FAIL (L "Execution Policy dikunci Group Policy ($($pol.Policy))" "Execution Policy is locked by Group Policy ($($pol.Policy))") (L 'Profil PowerShell tidak bisa jalan. Hubungi admin komputer ini.' 'Your PowerShell profile cannot run. Ask this computer''s admin.') }
    else { Add-Check FAIL (L "Execution Policy $($pol.Policy) memblokir profil PowerShell" "Execution Policy $($pol.Policy) blocks your PowerShell profile") '' { Set-GlowshPolicy } (L 'Set Execution Policy CurrentUser ke RemoteSigned' 'Set the CurrentUser Execution Policy to RemoteSigned') }

    # 6. Ikon file, PSReadLine, CMD, perintah glowsh
    if (Get-Module -ListAvailable -Name Terminal-Icons) { Add-Check OK (L 'Terminal-Icons terpasang (ikon saat ls / dir)' 'Terminal-Icons is installed (icons in ls / dir)') }
    else { Add-Check WARN (L 'Terminal-Icons belum terpasang' 'Terminal-Icons is not installed') (L 'ls / dir belum menampilkan ikon.' 'ls / dir will not show icons.') { Install-GlowshTerminalIcons } (L 'Install Terminal-Icons' 'Install Terminal-Icons') }

    if (Test-GlowshPSReadLine) { Add-Check OK (L 'PSReadLine mendukung saran perintah otomatis' 'PSReadLine supports inline command suggestions') }
    else { Add-Check WARN (L 'PSReadLine terlalu lama untuk saran perintah otomatis' 'PSReadLine is too old for inline suggestions') '' { Install-GlowshPSReadLine } (L 'Update PSReadLine' 'Update PSReadLine') }

    $autorun = (Get-ItemProperty 'HKCU:\Software\Microsoft\Command Processor' -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    if ($autorun -match 'clink') { Add-Check OK (L 'Clink aktif (prompt cantik di CMD)' 'Clink is active (pretty prompt in CMD)') }
    else { Add-Check WARN (L 'Clink belum aktif, CMD belum punya prompt cantik' 'Clink is not active, CMD has no pretty prompt') '' { Install-GlowshClink } (L 'Pasang Clink' 'Install Clink') }

    if (Test-GlowshUserPath) { Add-Check OK (L 'Perintah glowsh tersedia di CMD' 'The glowsh command works in CMD') }
    else { Add-Check WARN (L 'Perintah glowsh belum tersedia di CMD' 'The glowsh command is not available in CMD') '' { Install-GlowshCommand } (L 'Tambahkan perintah glowsh ke PATH' 'Add glowsh to PATH') }

    # 7. Terminal yang sedang dipakai (paling sering jadi penyebab "kok ikonnya nggak muncul?")
    if ($env:WT_SESSION) { Add-Check OK (L 'Kamu sedang memakai Windows Terminal' 'You are using Windows Terminal') }
    elseif ($env:TERM_PROGRAM -eq 'vscode') {
        Add-Check WARN (L 'Kamu sedang memakai terminal VS Code' 'You are in the VS Code terminal') (L "Agar ikon tampil, set terminal.integrated.fontFamily ke '$FontFace' di Settings VS Code." "For icons, set terminal.integrated.fontFamily to '$FontFace' in VS Code settings.")
    } else {
        $fix = if (Test-WindowsTerminal) { { Start-GlowshTerminal } } else { $null }
        Add-Check FAIL (L 'Kamu sedang di jendela console lama, bukan Windows Terminal' 'You are in the classic console window, not Windows Terminal') `
            (L 'Ikon & font tidak bisa tampil di sini. Buka "Windows Terminal" dari Start Menu / Desktop.' 'Icons & fonts cannot show here. Open "Windows Terminal" from the Start Menu / Desktop.') $fix (L 'Buka Windows Terminal' 'Open Windows Terminal')
    }

    # Ringkasan + perbaikan otomatis
    $nFail = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count
    $nWarn = @($checks | Where-Object { $_.Status -eq 'WARN' }).Count
    $nOk   = @($checks | Where-Object { $_.Status -eq 'OK' }).Count
    $color = if ($nFail) { 'Red' } elseif ($nWarn) { 'Yellow' } else { 'Green' }
    Write-Host ''
    Write-Host ('  ' + (L "Hasil: $nOk OK, $nWarn peringatan, $nFail masalah" "Result: $nOk OK, $nWarn warnings, $nFail problems")) -ForegroundColor $color
    $fixable = @($checks | Where-Object { $_.Status -ne 'OK' -and $_.Fix })
    if ($fixable.Count -gt 0) {
        Write-Host ''
        Write-Host ('  ' + (L 'Bisa diperbaiki otomatis:' 'Can be fixed automatically:')) -ForegroundColor White
        foreach ($c in $fixable) { Write-Host "    - $($c.FixLabel)" }
        Write-Host ''
        if (Read-YesNo (L 'Perbaiki sekarang?' 'Fix now?')) {
            foreach ($c in $fixable) {
                Write-Step $c.FixLabel
                try { & $c.Fix $c.FixArg; Write-Ok (L 'Selesai' 'Done') } catch { Write-Bad $_.Exception.Message }
            }
            Write-Host ''
            Write-Host ('  ' + (L 'Buka tab terminal baru, lalu jalankan "glowsh doctor" lagi untuk memastikan.' 'Open a new terminal tab and run "glowsh doctor" again to confirm.')) -ForegroundColor White
        }
    } elseif ($nFail -eq 0 -and $nWarn -eq 0) {
        Write-Host ('  ' + (L 'Semua beres! Terminal kamu sudah glowing.' 'All good! Your terminal is glowing.')) -ForegroundColor Green
    }
    Write-Host ''
}

# ============================================================ bantuan & pengaturan
function Show-GlowshHelp {
    $t = $GlowshThemes[(Get-GlowshCurrentTheme)]
    Write-Host ''
    Write-Host '  Glowsh' -ForegroundColor Magenta -NoNewline
    Write-Host " $GlowshVersion" -ForegroundColor DarkGray -NoNewline
    Write-Host ('   ' + (L 'tema aktif: ' 'active theme: ') + $t.Title)
    Write-Host ''
    $nm = L 'nama' 'name'; $cd = L 'kode' 'code'; $pr = L 'perintah' 'command'
    $rows = @(
        @('glowsh theme',              'pilih tema dengan preview',            'pick a theme with a live preview'),
        @("glowsh theme <$nm>",        'langsung pakai tema',                  'apply a theme directly'),
        @('glowsh theme list',         'daftar semua tema',                    'list all themes'),
        @('glowsh wallpaper [file]',   'buat tema dari wallpaper',             'build a theme from your wallpaper'),
        @("glowsh share [$nm]",        'bagikan tema sebagai kode',            'share a theme as a code'),
        @("glowsh import <$cd>",       'pasang tema dari kode',                'install a theme from a code'),
        @("glowsh explain <$pr>",      'jelaskan sebuah perintah',             'explain what a command does'),
        @('glowsh doctor',             'cek & perbaiki masalah tampilan',      'diagnose & fix display problems'),
        @('glowsh settings',           'lihat & ubah fitur (on/off)',          'view & toggle features'),
        @('glowsh lang id|en',         'ganti bahasa',                         'switch language'),
        @('glowsh update',             'update Glowsh ke versi terbaru',       'update Glowsh to the latest version'),
        @('glowsh uninstall',          'kembalikan tampilan seperti semula',   'restore your terminal to how it was')
    )
    Write-Host ('  ' + (L 'Perintah:' 'Commands:')) -ForegroundColor White
    foreach ($r in $rows) {
        Write-Host ('    {0,-27}' -f $r[0]) -NoNewline -ForegroundColor Cyan
        Write-Host (L $r[1] $r[2])
    }
    Write-Host ''
}

function Show-GlowshSettings {
    Write-Host ''
    Write-Host ('  ' + (L 'Pengaturan Glowsh' 'Glowsh settings')) -ForegroundColor Magenta
    Write-Host ''
    foreach ($k in $GlowshToggles.Keys) {
        $on = [bool](Get-GlowshSettingValue $k)
        Write-Host ('    {0,-10}' -f $k) -NoNewline -ForegroundColor Cyan
        Write-Host ('{0,-5}' -f $(if ($on) { 'on' } else { 'off' })) -NoNewline -ForegroundColor $(if ($on) { 'Green' } else { 'DarkGray' })
        Write-Host (L $GlowshToggles[$k][1] $GlowshToggles[$k][2])
    }
    Write-Host ('    {0,-10}{1,-5}{2}' -f 'lang', $GlowshLang, (L 'bahasa (id / en)' 'language (id / en)'))
    Write-Host ''
    Write-Host ('  ' + (L 'Ubah: glowsh <nama> on|off   contoh: glowsh greet off' 'Change: glowsh <name> on|off   e.g. glowsh greet off')) -ForegroundColor DarkGray
    Write-Host ('  ' + (L 'Batas notifikasi: glowsh notify <detik>   uji: glowsh notify test' 'Notification threshold: glowsh notify <seconds>   test: glowsh notify test')) -ForegroundColor DarkGray
    Write-Host ''
}

# ============================================================ siapkan daftar tema
Initialize-GlowshThemes

# ============================================================ main (hanya kalau dipanggil langsung)
if (-not $GlowshAsLibrary -and $MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
    $Command = if ($args.Count) { ([string]$args[0]).ToLower() } else { 'help' }
    $Arguments = @($args | Select-Object -Skip 1 | ForEach-Object { [string]$_ })
    $arg1 = if ($Arguments.Count) { $Arguments[0] } else { '' }

    switch ($Command) {
        'theme' {
            if ($arg1 -eq 'list') {
                $cur = Get-GlowshCurrentTheme
                Write-Host ''
                foreach ($id in $GlowshThemes.Keys) {
                    $t = $GlowshThemes[$id]
                    $mark = if ($id -eq $cur) { '  <- ' + (L 'aktif' 'active') } else { '' }
                    Write-Host ('  {0} {1,-12} {2}{3}' -f (Get-ThemeTag $t), $id, (Get-ThemeDesc $t), $mark)
                }
                Write-Host ''
                Write-Host ('  ' + (L '* khas Glowsh   ~ musiman   + buatanmu.  Pakai: glowsh theme <nama>' '* Glowsh signature   ~ seasonal   + your own.  Use: glowsh theme <name>')) -ForegroundColor DarkGray
                Write-Host ''
                break
            }
            $id = if ($arg1) { Resolve-GlowshThemeId $arg1 } else { Show-ThemePicker (Get-GlowshCurrentTheme) }
            if ($arg1 -and -not $id) { Write-Bad (L "Tema '$arg1' tidak ada. Lihat daftar: glowsh theme list" "Theme '$arg1' does not exist. See: glowsh theme list"); break }
            if (-not $id) { Write-Note (L 'Dibatalkan, tema tidak diubah.' 'Cancelled, theme unchanged.'); break }
            Write-Step ((L 'Menerapkan tema ' 'Applying theme ') + $GlowshThemes[$id].Title)
            $fails = Set-GlowshTheme $id -Explicit
            Write-Host ''
            if ($fails -eq 0) { Write-Host ('  ' + (L 'Tema diganti! Windows Terminal langsung berubah.' 'Theme switched! Windows Terminal updates instantly.')) -ForegroundColor Green }
            else { Write-Host ('  ' + (L "Tema diganti dengan $fails masalah. Coba: glowsh doctor" "Theme switched with $fails problems. Try: glowsh doctor")) -ForegroundColor Yellow }
            Write-Host ''
        }
        'wallpaper' {
            $path = if ($arg1) { $arg1 } else { Get-WallpaperPath }
            if (-not $path -or -not (Test-Path -LiteralPath $path)) { Write-Bad (L 'Wallpaper tidak ditemukan. Coba: glowsh wallpaper C:\path\gambar.jpg' 'Wallpaper not found. Try: glowsh wallpaper C:\path\image.jpg'); break }
            Write-Step (L 'Membaca warna dari wallpaper...' 'Reading colors from your wallpaper...')
            try { $t = New-ThemeFromImage $path } catch { Write-Bad (L "Gambar tidak bisa dibaca: $($_.Exception.Message)" "Cannot read the image: $($_.Exception.Message)"); break }
            Show-ThemeCard $t
            if (Read-YesNo (L 'Pakai tema ini?' 'Use this theme?')) {
                Save-GlowshCustomTheme 'wallpaper' $t
                $GlowshThemes['wallpaper'] = $t
                [void](Set-GlowshTheme 'wallpaper' -Explicit)
                Write-Host ''
                Write-Host ('  ' + (L 'Tema dari wallpaper terpasang! Bagikan ke teman: glowsh share' 'Wallpaper theme applied! Share it: glowsh share')) -ForegroundColor Green
                Write-Host ''
            }
        }
        'share' {
            $id = if ($arg1) { Resolve-GlowshThemeId $arg1 } else { Get-GlowshCurrentTheme }
            if (-not $id) { Write-Bad (L "Tema '$arg1' tidak ada." "Theme '$arg1' does not exist."); break }
            $code = ConvertTo-GlowshShareCode $GlowshThemes[$id]
            Write-Host ''
            Write-Host ('  ' + (L 'Kode tema ' 'Theme code for ') + $GlowshThemes[$id].Title + ':') -ForegroundColor White
            Write-Host ''
            Write-Host "    $code" -ForegroundColor Cyan
            Write-Host ''
            Write-Host ('  ' + (L 'Teman kamu tinggal menjalankan:' 'Your friend just runs:')) -ForegroundColor DarkGray
            Write-Host "    glowsh import $code" -ForegroundColor DarkGray
            try { Set-Clipboard -Value $code; Write-Host ('  ' + (L '(sudah disalin ke clipboard)' '(copied to clipboard)')) -ForegroundColor DarkGray } catch {}
            Write-Host ''
        }
        'import' {
            if (-not $arg1) { Write-Bad (L 'Pakai: glowsh import <kode> [nama]' 'Usage: glowsh import <code> [name]'); break }
            try { $t = ConvertFrom-GlowshShareCode $arg1 } catch { Write-Bad $_.Exception.Message; break }
            if ($Arguments.Count -gt 1) {
                $t.Title = ($Arguments | Select-Object -Skip 1) -join ' '
                $t.Scheme.name = "Glowsh $($t.Title)"
            }
            $slug = ($t.Title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
            if (-not $slug) { $slug = 'shared' }
            $id = $slug
            $n = 2
            while ($GlowshThemes.Contains($id) -and -not $GlowshThemes[$id].Custom) { $id = "$slug-$n"; $n++ }
            Write-Host ''
            Write-Host "  $($t.Title)" -ForegroundColor Cyan
            Show-ThemeCard $t
            if (Read-YesNo (L 'Pasang & pakai tema ini?' 'Install & use this theme?')) {
                Save-GlowshCustomTheme $id $t
                $GlowshThemes[$id] = $t
                [void](Set-GlowshTheme $id -Explicit)
                Write-Host ''
                Write-Host ('  ' + (L "Tema '$id' terpasang!" "Theme '$id' installed!")) -ForegroundColor Green
                Write-Host ''
            }
        }
        'explain' { Show-GlowshExplain $Arguments }
        'doctor' { Invoke-GlowshDoctor }
        'sync' { Invoke-GlowshSync }
        'settings' { Show-GlowshSettings }
        'config' { Show-GlowshSettings }
        'lang' {
            if ($arg1 -notin 'id', 'en') { Write-Host (L '  Pakai: glowsh lang id   atau   glowsh lang en' '  Usage: glowsh lang id   or   glowsh lang en'); break }
            Set-GlowshConfigValue 'lang' $arg1
            $GlowshLang = $arg1
            Write-Ok (L 'Bahasa diganti ke Bahasa Indonesia. Buka tab baru untuk melihat perubahannya.' 'Language switched to English. Open a new tab to see it everywhere.')
        }
        'update' {
            Write-Step (L 'Mengunduh Glowsh terbaru...' 'Downloading the latest Glowsh...')
            # Installer diunduh ke folder sementara lalu dijalankan dengan -File (tanpa iex & tanpa urusan tanda kutip).
            # Folder itu hanya berisi install.ps1, jadi installer akan mengunduh glowsh.ps1 terbaru dari GitHub.
            # ?t=... mencegah GitHub memberi salinan lama dari cache.
            $tmpDir = Join-Path $env:TEMP "glowsh-update-$PID"
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
            $tmpInstaller = Join-Path $tmpDir 'install.ps1'
            $env:GLOWSH_THEME = [string](Get-GlowshConfig).baseTheme
            if (-not $env:GLOWSH_THEME) { $env:GLOWSH_THEME = Get-GlowshCurrentTheme }
            $env:GLOWSH_LANG = $GlowshLang
            try {
                Invoke-WebRequest -UseBasicParsing -Uri "$GlowshRepoRaw/install.ps1?t=$([DateTime]::UtcNow.Ticks)" -OutFile $tmpInstaller
                & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $tmpInstaller
            } catch {
                Write-Bad (L "Update gagal: $($_.Exception.Message)" "Update failed: $($_.Exception.Message)")
            } finally {
                Remove-Item Env:GLOWSH_THEME, Env:GLOWSH_LANG -ErrorAction SilentlyContinue
                Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        'uninstall' {
            $u = Join-Path $GlowHome 'uninstall.ps1'
            if (Test-Path $u) { & $u } else { Write-Bad (L "File $u tidak ditemukan. Jalankan: irm $GlowshRepoRaw/uninstall.ps1 | iex" "File $u not found. Run: irm $GlowshRepoRaw/uninstall.ps1 | iex") }
        }
        { $_ -in 'version', '--version', '-v' } { Write-Host "Glowsh $GlowshVersion" }
        { $GlowshToggles.Contains($_) } {
            $feature = $Command
            if ($feature -eq 'notify' -and $arg1 -eq 'test') {
                Write-Ok (L 'Mengirim notifikasi uji...' 'Sending a test notification...')
                Send-GlowshToast (L 'Glowsh: notifikasi berfungsi!' 'Glowsh: notifications work!') (L 'Kamu akan dapat notifikasi seperti ini saat perintah lama selesai.' 'You will get one of these when a long command finishes.')
                break
            }
            $secs = 0
            if ($feature -eq 'notify' -and [int]::TryParse($arg1, [ref]$secs) -and $secs -gt 0) {
                Set-GlowshConfigValue 'notifySeconds' $secs
                Set-GlowshConfigValue 'notify' $true
                Write-Ok (L "Notifikasi untuk perintah yang berjalan >= $secs detik." "Notifications for commands running >= $secs seconds.")
                break
            }
            if ($arg1 -notin 'on', 'off') {
                $on = [bool](Get-GlowshSettingValue $feature)
                Write-Host ("  $feature = " + $(if ($on) { 'on' } else { 'off' }) + '   (' + (L $GlowshToggles[$feature][1] $GlowshToggles[$feature][2]) + ')')
                Write-Host ('  ' + (L "Ubah: glowsh $feature on|off" "Change: glowsh $feature on|off")) -ForegroundColor DarkGray
                break
            }
            $on = $arg1 -eq 'on'
            Set-GlowshConfigValue $feature $on
            if ($feature -eq 'typo') { [void](Set-GlowshGitAutocorrect $on) }
            if ($feature -eq 'seasonal' -and $on) { Set-GlowshConfigValue 'seasonSkip' $null }
            $label = L $GlowshToggles[$feature][1] $GlowshToggles[$feature][2]
            Write-Ok ($(if ($on) { (L 'Aktif: ' 'On: ') } else { (L 'Nonaktif: ' 'Off: ') }) + $label)
            if ($feature -in 'auto', 'seasonal') { Invoke-GlowshSync }
            if ($feature -eq 'auto' -and $on) { Write-Host ('  ' + (L 'Jadwal: 05:00 Pagi, 15:00 Senja, 18:30 Neon.' 'Schedule: 05:00 Pagi, 15:00 Senja, 18:30 Neon.')) -ForegroundColor DarkGray }
            if ($feature -in 'greet', 'typo', 'guard', 'notify') { Write-Host ('  ' + (L 'Berlaku di tab terminal baru.' 'Takes effect in new terminal tabs.')) -ForegroundColor DarkGray }
        }
        default { Show-GlowshHelp }
    }
}
