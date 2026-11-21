<#
    Glowsh - perintah utama setelah install.

        glowsh theme            pilih tema (dengan preview, pakai panah atas/bawah)
        glowsh theme <nama>     langsung pakai tema, contoh: glowsh theme neon
        glowsh theme list       daftar semua tema
        glowsh doctor           cek & perbaiki masalah tampilan terminal
        glowsh uninstall        kembalikan tampilan terminal seperti semula
        glowsh version

    File ini juga dipakai sebagai "library" oleh install.ps1 (di-dot-source),
    jadi bagian utama di paling bawah hanya jalan kalau dipanggil langsung.
    Sengaja ASCII-only supaya aman dibaca Windows PowerShell 5.1.
#>
param(
    [Parameter(Position = 0)][string]$Command = 'help',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Arguments
)

# ============================================================ konfigurasi
$GlowshVersion = '0.2.0'
$GlowshRepoRaw = 'https://raw.githubusercontent.com/SQverse/glowsh/main'
$GlowHome      = Join-Path $HOME '.glowsh'
$BinDir        = Join-Path $GlowHome 'bin'
$OmpExe        = Join-Path $BinDir 'oh-my-posh.exe'
$ThemeFile     = Join-Path $GlowHome 'theme.omp.json'
$ThemeDir      = Join-Path $GlowHome 'themes'
$StateFile     = Join-Path $GlowHome 'current-theme.txt'
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

# ============================================================ tema
# Signature = tema khas Glowsh (prompt dibuat sendiri dari palet "Accents").
# Tema klasik memakai file prompt dari koleksi Oh My Posh (properti Omp).
$GlowshThemes = [ordered]@{
    senja = @{
        Title = 'Senja'; Signature = $true; Desc = 'jingga & ungu langit sore'
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
        Title = 'Neon'; Signature = $true; Desc = 'cyberpunk, kota malam penuh lampu'
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
        Title = 'Laut'; Signature = $true; Desc = 'biru toska laut tropis & karang'
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
    dracula = @{
        Title = 'Dracula'; Desc = 'klasik: ungu & pink kontras tinggi'; Omp = 'dracula'
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
        Title = 'Catppuccin Mocha'; Desc = 'klasik: pastel lembut'; Omp = 'catppuccin_mocha'
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
        Title = 'Tokyo Night'; Desc = 'klasik: biru malam'; Omp = 'tokyonight_storm'
        Scheme = [ordered]@{
            name = 'Glowsh Tokyo Night'; background = '#1A1B26'; foreground = '#C0CAF5'
            cursorColor = '#C0CAF5'; selectionBackground = '#33467C'
            black = '#15161E'; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'
            blue = '#7AA2F7'; purple = '#BB9AF7'; cyan = '#7DCFFF'; white = '#A9B1D6'
            brightBlack = '#414868'; brightRed = '#F7768E'; brightGreen = '#9ECE6A'; brightYellow = '#E0AF68'
            brightBlue = '#7AA2F7'; brightPurple = '#BB9AF7'; brightCyan = '#7DCFFF'; brightWhite = '#C0CAF5'
        }
    }
}

# Prompt khas Glowsh (format Oh My Posh v4). __XX__ diganti warna dari tema.
# Glyph ditulis sebagai escape JSON (\uXXXX) supaya file ini tetap ASCII.
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
    Write-Host '      bikin terminal kamu lebih cantik - satu perintah saja' -ForegroundColor DarkGray
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

function Get-Rgb([string]$Hex) {
    $h = $Hex.TrimStart('#')
    return '{0};{1};{2}' -f [Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16)
}

function ConvertTo-ConsoleColor([string]$Hex) {
    $h = $Hex.TrimStart('#')
    $r = [Convert]::ToInt32($h.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($h.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($h.Substring(4, 2), 16)
    return [int]($r + ($g -shl 8) + ($b -shl 16))   # format registry conhost: 0x00BBGGRR
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
    if ((Get-ExecutionPolicy -Scope CurrentUser).ToString() -ne 'RemoteSigned') { throw 'Gagal mengubah Execution Policy' }
}

# ============================================================ komponen yang di-install
function Install-GlowshOmp {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $tmp = Join-Path $env:TEMP "glowsh-omp-$PID.exe"
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-$(Get-GlowshArch).exe" -OutFile $tmp
    try { Move-Item $tmp $OmpExe -Force }
    catch {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        if (Test-Path $OmpExe) { return 'lama (file sedang dipakai, tidak diperbarui)' }
        throw
    }
    return [string](& $OmpExe version)
}

function Save-GlowshClassicThemes {
    New-Item -ItemType Directory -Path $ThemeDir -Force | Out-Null
    foreach ($t in $GlowshThemes.Values) {
        if ($t.Signature) { continue }
        Invoke-WebRequest -UseBasicParsing -OutFile (Join-Path $ThemeDir "$($t.Omp).omp.json") `
            -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$($t.Omp).omp.json"
    }
}

function Install-GlowshFont {
    if (-not (Test-Path $OmpExe)) { throw 'Oh My Posh belum terpasang' }
    # Tanpa hak admin, Oh My Posh otomatis menginstall font untuk user ini saja
    & $OmpExe font install Meslo
    if ($LASTEXITCODE -ne 0) { throw "oh-my-posh keluar dengan kode $LASTEXITCODE" }
}

function Install-GlowshTerminalIcons {
    if (Get-Module -ListAvailable -Name Terminal-Icons) { return }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $nuget = Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue |
                 Where-Object { $_.Version -ge [version]'2.8.5.201' }
        if (-not $nuget) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null }
    }
    Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
}

function Install-GlowshClink {
    $exeName = switch (Get-GlowshArch) { 'arm64' { 'clink_arm64.exe' } '386' { 'clink_x86.exe' } default { 'clink_x64.exe' } }
    $clinkExe = Join-Path $ClinkDir $exeName
    if (-not (Test-Path $clinkExe)) {
        $rel = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/chrisant996/clink/releases/latest'
        $zipAsset = $rel.assets | Where-Object { $_.name -match '^clink\.[\d.]+\.[0-9a-f]+\.zip$' } | Select-Object -First 1
        if (-not $zipAsset) { throw 'File rilis Clink tidak ditemukan' }
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
-- Glowsh: prompt Oh My Posh untuk CMD
local glow = os.getenv("USERPROFILE") .. "\\.glowsh"
local f = io.popen('""' .. glow .. '\\bin\\oh-my-posh.exe" init cmd --config "' .. glow .. '\\theme.omp.json""')
if f then
    local script = f:read("*a")
    f:close()
    local chunk = load(script)
    if chunk then chunk() end
end
'@
    Write-Utf8NoBom (Join-Path $ClinkProfile 'glowsh.lua') $lua
    & $clinkExe autorun install -- --quiet --profile "$ClinkProfile" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "clink autorun keluar dengan kode $LASTEXITCODE" }
}

# Windows Terminal versi unpackaged (zip resmi dari GitHub Microsoft): tanpa Store, winget, maupun admin.
function Install-PortableTerminal {
    $arch = switch (Get-GlowshArch) { 'arm64' { 'arm64' } '386' { 'x86' } default { 'x64' } }
    $rel = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/microsoft/terminal/releases/latest'
    $zipAsset = $rel.assets | Where-Object { $_.name -like "Microsoft.WindowsTerminal_*_$arch.zip" } | Select-Object -First 1
    if (-not $zipAsset) { throw "File Windows Terminal untuk $arch tidak ditemukan di rilis $($rel.tag_name)" }
    $zip    = Join-Path $env:TEMP "glowsh-wt-$PID.zip"
    $tmpDir = Join-Path $env:TEMP "glowsh-wt-$PID"
    Invoke-WebRequest -UseBasicParsing -Uri $zipAsset.browser_download_url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmpDir -Force
    $exe = Get-ChildItem $tmpDir -Recurse -Filter 'WindowsTerminal.exe' | Select-Object -First 1
    if (-not $exe) { throw 'WindowsTerminal.exe tidak ditemukan di dalam zip' }
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
    return $rel.tag_name
}

function Install-GlowshProfile {
    $block = @'
# >>> glowsh >>>
# Ditambahkan oleh Glowsh. Jalankan "glowsh uninstall" (atau hapus blok ini) untuk menonaktifkan.
$__glow = Join-Path $HOME '.glowsh'
if (Test-Path "$__glow\bin\oh-my-posh.exe") {
    & "$__glow\bin\oh-my-posh.exe" init pwsh --config "$__glow\theme.omp.json" | Invoke-Expression
}
if (Get-Module -ListAvailable -Name Terminal-Icons) { Import-Module Terminal-Icons }
try { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction Stop } catch {}
function glowsh {
    $g = Join-Path $HOME '.glowsh'
    & "$g\glowsh.ps1" @args
    if ($args.Count -gt 0 -and $args[0] -eq 'theme' -and (Test-Path "$g\bin\oh-my-posh.exe")) {
        & "$g\bin\oh-my-posh.exe" init pwsh --config "$g\theme.omp.json" | Invoke-Expression
    }
}
Remove-Variable __glow -ErrorAction SilentlyContinue
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

# ============================================================ menerapkan tema
function New-SignaturePrompt($Theme) {
    $a = $Theme.Accents
    return $GlowshPromptTemplate.Replace('__BG__', $Theme.Scheme.background).Replace('__A1__', $a.a1).Replace('__A2__', $a.a2).
        Replace('__A3__', $a.a3).Replace('__A4__', $a.a4).Replace('__OK__', $a.ok).Replace('__ERR__', $a.err).Replace('__MUTED__', $a.muted)
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
        Write-Utf8NoBom $unp '{ "$schema": "https://aka.ms/terminal-profiles-schema", "profiles": { "defaults": {}, "list": [] }, "schemes": [] }'
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

            Write-Utf8NoBom $path ($json | ConvertTo-Json -Depth 32)
            $applied++
        } catch { Write-Bad "Windows Terminal ($key): $($_.Exception.Message)"; $fails++ }
    }
    if ($applied -gt 0) { Write-Ok 'Windows Terminal: warna, font & transparansi' }
    elseif (Test-WindowsTerminal) { Write-Note 'Pengaturan Windows Terminal belum ada. Buka Windows Terminal sekali, lalu jalankan: glowsh theme' }
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

function Set-GlowshTheme([string]$Id) {
    $t = $GlowshThemes[$Id]
    if (-not $t) { throw "Tema '$Id' tidak dikenal" }
    New-Item -ItemType Directory -Path $GlowHome, $ThemeDir -Force | Out-Null
    $fails = 0
    try {
        if ($t.Signature) { Write-Utf8NoBom $ThemeFile (New-SignaturePrompt $t) }
        else {
            $cached = Join-Path $ThemeDir "$($t.Omp).omp.json"
            if (-not (Test-Path $cached)) {
                Invoke-WebRequest -UseBasicParsing -OutFile $cached `
                    -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$($t.Omp).omp.json"
            }
            Copy-Item $cached $ThemeFile -Force
        }
        Write-Ok "Prompt: $($t.Title)"
    } catch { Write-Bad "Prompt: $($_.Exception.Message)"; $fails++ }
    $fails += Update-WTSettings $t
    try { Set-ConsoleColors $t; Write-Ok 'Warna console klasik' }
    catch { Write-Bad "Console klasik: $($_.Exception.Message)"; $fails++ }
    Write-Utf8NoBom $StateFile $Id
    return $fails
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
    $lines += Format-PreviewLine $bg $fg @(@{ T = "  git: 'pusj' bukan perintah git"; F = $s.red })
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

function Show-ThemePicker([string]$CurrentId = 'senja') {
    $ids = @($GlowshThemes.Keys)
    $idx = [Math]::Max(0, [Array]::IndexOf($ids, $CurrentId))
    $interactive = $true
    try { if ([Console]::IsInputRedirected -or $Host.Name -ne 'ConsoleHost') { $interactive = $false } } catch { $interactive = $false }

    if (-not $interactive) {
        # Cadangan untuk host yang tidak mendukung tombol panah: menu bernomor
        for ($i = 0; $i -lt $ids.Count; $i++) {
            $t = $GlowshThemes[$ids[$i]]
            Write-Host ("    [{0}] {1} - {2}" -f ($i + 1), $t.Title, $t.Desc)
        }
        return Resolve-GlowshThemeId (Read-Host '    Nomor tema')
    }

    Enable-VirtualTerminal
    $e = [char]27
    [Console]::Write("$e[?1049h$e[?25l")   # layar alternatif + sembunyikan kursor
    try {
        while ($true) {
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append("$e[H$e[2J")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("  $e[1;35mGlowsh$e[0m - pilih tema")
            [void]$sb.AppendLine("  $e[90m[atas/bawah] pilih   [Enter] pakai   [Esc] batal$e[0m")
            [void]$sb.AppendLine('')
            for ($i = 0; $i -lt $ids.Count; $i++) {
                $t = $GlowshThemes[$ids[$i]]
                $star = if ($t.Signature) { '*' } else { ' ' }
                $now = if ($ids[$i] -eq $CurrentId) { '  (aktif)' } else { '' }
                $name = ('{0} {1}' -f $star, $t.Title).PadRight(20)
                if ($i -eq $idx) {
                    $acc = Get-Rgb (Get-ThemeAccents $t).a1
                    [void]$sb.AppendLine("  $e[1;38;2;${acc}m> $name$e[0m$e[37m$($t.Desc)$now$e[0m")
                } else {
                    [void]$sb.AppendLine("    $name$e[90m$($t.Desc)$now$e[0m")
                }
            }
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("  $e[90m* = tema khas Glowsh$e[0m")
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

# ============================================================ doctor
function Invoke-GlowshDoctor {
    Write-Host ''
    Write-Host '  Glowsh Doctor' -ForegroundColor Magenta -NoNewline
    Write-Host ' - cek kesehatan tampilan terminal kamu' -ForegroundColor DarkGray
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
    if (Test-WindowsTerminal) { Add-Check OK 'Windows Terminal terpasang' }
    else {
        Add-Check FAIL 'Windows Terminal belum terpasang' 'Ikon & font Nerd Font paling bagus tampil di Windows Terminal.' `
            { [void](Install-PortableTerminal); [void](Set-GlowshTheme (Get-GlowshCurrentTheme)) } 'Install Windows Terminal (resmi Microsoft, tanpa Store)'
    }

    # 2. Font
    if (Test-FontInstalled) { Add-Check OK "Font $FontFace terpasang" }
    else { Add-Check FAIL "Font $FontFace belum terpasang" 'Tanpa font ini ikon tampil sebagai kotak.' { Install-GlowshFont } 'Install font' }

    # 3. Pengaturan Windows Terminal
    $foundSettings = $false
    foreach ($key in @($WtTargets.Keys)) {
        $path = $WtTargets[$key]
        if (-not (Test-Path $path)) { continue }
        $foundSettings = $true
        try { $json = Read-JsonLoose $path }
        catch { Add-Check FAIL "Pengaturan Windows Terminal ($key) tidak bisa dibaca" $path; continue }
        $d = $null
        if ($json.profiles -and -not ($json.profiles -is [array])) { $d = $json.profiles.defaults }
        $face = if ($d -and $d.font -and $d.font.face) { [string]$d.font.face } else { 'bawaan' }
        $scheme = if ($d -and $d.colorScheme) { [string]$d.colorScheme } else { 'bawaan' }
        if ($face -eq $FontFace -and $scheme -like 'Glowsh *') {
            Add-Check OK "Windows Terminal ($key) memakai font & tema Glowsh"
        } else {
            Add-Check FAIL "Windows Terminal ($key) belum memakai Glowsh" "Sekarang: font $face, tema $scheme" $reapply 'Terapkan ulang tema Glowsh'
        }
        $list = if ($json.profiles -is [array]) { $json.profiles } else { $json.profiles.list }
        $over = @($list | Where-Object {
            $_ -and (($_.PSObject.Properties['fontFace']) -or
                     ($_.font -and $_.font.face -and $_.font.face -ne $FontFace) -or
                     ($_.colorScheme -and ([string]$_.colorScheme) -notlike 'Glowsh *'))
        })
        if ($over.Count -gt 0) {
            $names = ($over | ForEach-Object { $_.name }) -join ', '
            Add-Check WARN "Profil ini memakai font/tema sendiri sehingga mengabaikan Glowsh: $names" `
                'Pengaturan per-profil selalu menang atas pengaturan default.' `
                { param($p) Clear-WTProfileOverrides $p } "Hapus font/tema khusus di profil: $names" $path
        }
    }
    if (-not $foundSettings -and (Test-WindowsTerminal)) {
        Add-Check WARN 'Pengaturan Windows Terminal belum ada' 'Biasanya karena Windows Terminal belum pernah dibuka.' $reapply 'Buat pengaturan & terapkan tema'
    }

    # 4. Oh My Posh & tema prompt
    if (Test-Path $OmpExe) {
        try { $v = [string](& $OmpExe version); Add-Check OK "Oh My Posh $v" }
        catch { Add-Check FAIL 'Oh My Posh tidak bisa dijalankan' $_.Exception.Message { [void](Install-GlowshOmp) } 'Download ulang Oh My Posh' }
    } else { Add-Check FAIL 'Oh My Posh belum terpasang' '' { [void](Install-GlowshOmp) } 'Download Oh My Posh' }

    $title = $GlowshThemes[(Get-GlowshCurrentTheme)].Title
    $themeOk = $false
    if (Test-Path $ThemeFile) { try { $null = [IO.File]::ReadAllText($ThemeFile) | ConvertFrom-Json; $themeOk = $true } catch {} }
    if ($themeOk) { Add-Check OK "Tema aktif: $title" }
    else { Add-Check FAIL 'File tema prompt hilang atau rusak' '' $reapply "Pasang ulang tema $title" }

    # 5. Profil PowerShell & Execution Policy
    foreach ($p in Get-ProfileTargets) {
        $has = (Test-Path $p) -and ([IO.File]::ReadAllText($p) -match [regex]::Escape($MarkStart))
        $label = Split-Path (Split-Path $p) -Leaf
        if ($has) { Add-Check OK "Profil $label berisi Glowsh" }
        else { Add-Check FAIL "Profil $label belum berisi Glowsh" $p { Install-GlowshProfile } 'Pasang ulang profil PowerShell' }
    }
    $pol = Get-GlowshPolicyState
    if ($pol.Policy -in 'RemoteSigned', 'Unrestricted', 'Bypass') { Add-Check OK "Execution Policy: $($pol.Policy)" }
    elseif ($pol.Gpo) { Add-Check FAIL "Execution Policy dikunci Group Policy ($($pol.Policy))" 'Profil PowerShell tidak bisa jalan. Hubungi admin komputer ini.' }
    else { Add-Check FAIL "Execution Policy $($pol.Policy) memblokir profil PowerShell" '' { Set-GlowshPolicy } 'Set Execution Policy CurrentUser ke RemoteSigned' }

    # 6. Ikon file, CMD, perintah glowsh
    if (Get-Module -ListAvailable -Name Terminal-Icons) { Add-Check OK 'Terminal-Icons terpasang (ikon saat ls / dir)' }
    else { Add-Check WARN 'Terminal-Icons belum terpasang' 'ls / dir belum menampilkan ikon.' { Install-GlowshTerminalIcons } 'Install Terminal-Icons' }

    $autorun = (Get-ItemProperty 'HKCU:\Software\Microsoft\Command Processor' -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    if ($autorun -match 'clink') { Add-Check OK 'Clink aktif (prompt cantik di CMD)' }
    else { Add-Check WARN 'Clink belum aktif, CMD belum punya prompt cantik' '' { Install-GlowshClink } 'Pasang Clink' }

    if (Test-GlowshUserPath) { Add-Check OK 'Perintah glowsh tersedia di CMD' }
    else { Add-Check WARN 'Perintah glowsh belum tersedia di CMD' '' { Install-GlowshCommand } 'Tambahkan perintah glowsh ke PATH' }

    # 7. Terminal yang sedang dipakai (paling sering jadi penyebab "kok ikonnya nggak muncul?")
    if ($env:WT_SESSION) { Add-Check OK 'Kamu sedang memakai Windows Terminal' }
    elseif ($env:TERM_PROGRAM -eq 'vscode') {
        Add-Check WARN 'Kamu sedang memakai terminal VS Code' "Agar ikon tampil, set terminal.integrated.fontFamily ke '$FontFace' di Settings VS Code."
    } else {
        $fix = if (Test-WindowsTerminal) { { Start-GlowshTerminal } } else { $null }
        Add-Check FAIL 'Kamu sedang di jendela console lama, bukan Windows Terminal' `
            'Ikon & font tidak bisa tampil di sini. Buka "Windows Terminal" dari Start Menu / Desktop.' $fix 'Buka Windows Terminal'
    }

    # Ringkasan + perbaikan otomatis
    $nFail = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count
    $nWarn = @($checks | Where-Object { $_.Status -eq 'WARN' }).Count
    $nOk   = @($checks | Where-Object { $_.Status -eq 'OK' }).Count
    $color = if ($nFail) { 'Red' } elseif ($nWarn) { 'Yellow' } else { 'Green' }
    Write-Host ''
    Write-Host "  Hasil: $nOk OK, $nWarn peringatan, $nFail masalah" -ForegroundColor $color
    $fixable = @($checks | Where-Object { $_.Status -ne 'OK' -and $_.Fix })
    if ($fixable.Count -gt 0) {
        Write-Host ''
        Write-Host '  Bisa diperbaiki otomatis:' -ForegroundColor White
        foreach ($c in $fixable) { Write-Host "    - $($c.FixLabel)" }
        Write-Host ''
        if (Read-YesNo 'Perbaiki sekarang?') {
            foreach ($c in $fixable) {
                Write-Step $c.FixLabel
                try { & $c.Fix $c.FixArg; Write-Ok 'Selesai' } catch { Write-Bad $_.Exception.Message }
            }
            Write-Host ''
            Write-Host '  Buka tab terminal baru, lalu jalankan "glowsh doctor" lagi untuk memastikan.' -ForegroundColor White
        }
    } elseif ($nFail -eq 0 -and $nWarn -eq 0) {
        Write-Host '  Semua beres! Terminal kamu sudah glowing.' -ForegroundColor Green
    }
    Write-Host ''
}

# ============================================================ bantuan
function Show-GlowshHelp {
    $t = $GlowshThemes[(Get-GlowshCurrentTheme)]
    Write-Host ''
    Write-Host '  Glowsh' -ForegroundColor Magenta -NoNewline
    Write-Host " $GlowshVersion" -ForegroundColor DarkGray -NoNewline
    Write-Host "   tema aktif: $($t.Title)"
    Write-Host ''
    Write-Host '  Perintah:' -ForegroundColor White
    Write-Host '    glowsh theme            pilih tema dengan preview'
    Write-Host '    glowsh theme <nama>     langsung pakai tema (contoh: glowsh theme neon)'
    Write-Host '    glowsh theme list       daftar semua tema'
    Write-Host '    glowsh doctor           cek & perbaiki masalah tampilan'
    Write-Host '    glowsh uninstall        kembalikan tampilan terminal seperti semula'
    Write-Host '    glowsh version          versi Glowsh'
    Write-Host ''
}

# ============================================================ main (hanya kalau dipanggil langsung)
if (-not $GlowshAsLibrary -and $MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    switch ($Command.ToLower()) {
        'theme' {
            $arg = if ($Arguments) { $Arguments[0] } else { '' }
            if ($arg -eq 'list') {
                $cur = Get-GlowshCurrentTheme
                Write-Host ''
                foreach ($id in $GlowshThemes.Keys) {
                    $t = $GlowshThemes[$id]
                    $star = if ($t.Signature) { '*' } else { ' ' }
                    $mark = if ($id -eq $cur) { '  <- aktif' } else { '' }
                    Write-Host ('  {0} {1,-12} {2}{3}' -f $star, $id, $t.Desc, $mark)
                }
                Write-Host ''
                Write-Host '  * = tema khas Glowsh. Pakai: glowsh theme <nama>' -ForegroundColor DarkGray
                Write-Host ''
                break
            }
            $id = if ($arg) { Resolve-GlowshThemeId $arg } else { Show-ThemePicker (Get-GlowshCurrentTheme) }
            if ($arg -and -not $id) { Write-Bad "Tema '$arg' tidak ada. Lihat daftar: glowsh theme list"; break }
            if (-not $id) { Write-Note 'Dibatalkan, tema tidak diubah.'; break }
            Write-Step "Menerapkan tema $($GlowshThemes[$id].Title)"
            $fails = Set-GlowshTheme $id
            Write-Host ''
            if ($fails -eq 0) { Write-Host '  Tema diganti! Windows Terminal langsung berubah.' -ForegroundColor Green }
            else { Write-Host "  Tema diganti dengan $fails masalah. Coba: glowsh doctor" -ForegroundColor Yellow }
            Write-Host '  Kalau prompt belum ikut berubah, buka tab baru.' -ForegroundColor DarkGray
            Write-Host ''
        }
        'doctor' { Invoke-GlowshDoctor }
        'uninstall' {
            $u = Join-Path $GlowHome 'uninstall.ps1'
            if (Test-Path $u) { & $u } else { Write-Bad "File $u tidak ditemukan. Jalankan: irm $GlowshRepoRaw/uninstall.ps1 | iex" }
        }
        { $_ -in 'version', '--version', '-v' } { Write-Host "Glowsh $GlowshVersion" }
        default { Show-GlowshHelp }
    }
}
