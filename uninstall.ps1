<#
    Glowsh uninstaller - kembalikan tampilan terminal ke kondisi sebelum Glowsh.

    Dari PowerShell:
        irm https://raw.githubusercontent.com/USERNAME/glowsh/main/uninstall.ps1 | iex

    Dari CMD:
        powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/USERNAME/glowsh/main/uninstall.ps1 | iex"
#>

& {
$ErrorActionPreference = 'Stop'

# ============================================================ konfigurasi (harus sama dengan install.ps1)
$GlowHome   = Join-Path $HOME '.glowsh'
$BackupDir  = Join-Path $GlowHome 'backup-original'
$MarkStart  = '# >>> glowsh >>>'
$MarkEnd    = '# <<< glowsh <<<'
$ConsoleKey = 'HKCU:\Console'
$WtTargets = [ordered]@{
    stable     = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    preview    = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'
    unpackaged = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
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
function Set-JsonProp($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}
function Read-JsonLoose([string]$Path) {
    $raw = [IO.File]::ReadAllText($Path)
    try { return ($raw | ConvertFrom-Json) }
    catch {
        $clean = ($raw -split "`r?`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
        return ($clean | ConvertFrom-Json)
    }
}

Write-Host ''
Write-Host '  Glowsh uninstaller' -ForegroundColor Magenta
Write-Host '  Ini akan menghapus blok Glowsh dari profil, mengembalikan tema Windows Terminal,'
Write-Host '  warna console, dan Execution Policy ke kondisi sebelum Glowsh, lalu menghapus ~\.glowsh.'
Write-Host ''
if (-not (Read-YesNo 'Lanjut?')) { Write-Note 'Dibatalkan.'; return }
$warnings = 0

# ============================================================ 1. profil
Write-Step 'Hapus blok Glowsh dari profil PowerShell'
$docs = [Environment]::GetFolderPath('MyDocuments')
$pattern = '(?s)\s*' + [regex]::Escape($MarkStart) + '.*?' + [regex]::Escape($MarkEnd)
foreach ($p in (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
               (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1')) {
    if (-not (Test-Path $p)) { continue }
    try {
        $content = [IO.File]::ReadAllText($p)
        if ($content -notmatch [regex]::Escape($MarkStart)) { continue }
        $content = [regex]::Replace($content, $pattern, '').Trim()
        if ($content) { [IO.File]::WriteAllText($p, $content + "`r`n", (New-Object Text.UTF8Encoding $true)) }
        else { Remove-Item $p }   # profil hanya berisi Glowsh -> hapus saja
        Write-Ok $p
    } catch { Write-Bad "$p : $($_.Exception.Message)"; $warnings++ }
}

# ============================================================ 2. windows terminal
Write-Step 'Kembalikan pengaturan Windows Terminal'
if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }
foreach ($key in $WtTargets.Keys) {
    $path = $WtTargets[$key]
    if (-not (Test-Path $path)) { continue }
    try {
        $json = Read-JsonLoose $path
        if ($json.PSObject.Properties['schemes'] -and $json.schemes) {
            Set-JsonProp $json 'schemes' @($json.schemes | Where-Object { $_ -and ($_.name -notlike 'Glowsh *') })
        }
        $d = $null
        if ($json.profiles -and -not ($json.profiles -is [array])) { $d = $json.profiles.defaults }
        # Hanya kembalikan kalau user belum mengganti tema sendiri setelah install
        if ($d -and ($d.colorScheme -like 'Glowsh *')) {
            $od = $null
            $bk = Join-Path $BackupDir "wt-$key.json"
            if (Test-Path $bk) {
                $orig = Read-JsonLoose $bk
                if ($orig.profiles -and -not ($orig.profiles -is [array])) { $od = $orig.profiles.defaults }
            }
            foreach ($prop in 'colorScheme', 'opacity', 'useAcrylic', 'font') {
                if ($od -and $od.PSObject.Properties[$prop]) { Set-JsonProp $d $prop $od.$prop }
                else { $d.PSObject.Properties.Remove($prop) }
            }
        }
        [IO.File]::WriteAllText($path, ($json | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
        Write-Ok "Dikembalikan ($key)"
    } catch { Write-Bad "Gagal ($key): $($_.Exception.Message)"; $warnings++ }
}

# ============================================================ 3. console klasik
Write-Step 'Kembalikan warna console klasik'
$consoleBackup = Join-Path $BackupDir 'console.json'
if (Test-Path $consoleBackup) {
    try {
        $orig = Get-Content $consoleBackup -Raw | ConvertFrom-Json
        foreach ($prop in $orig.PSObject.Properties) {
            if ($null -eq $prop.Value) { Remove-ItemProperty -Path $ConsoleKey -Name $prop.Name -ErrorAction SilentlyContinue }
            else { Set-ItemProperty -Path $ConsoleKey -Name $prop.Name -Value ([int]$prop.Value) -Type DWord }
        }
        Write-Ok 'Selesai'
    } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }
} else { Write-Note 'Backup tidak ditemukan, dilewati.' }

# ============================================================ 4. execution policy
Write-Step 'Kembalikan Execution Policy (CurrentUser)'
$policyBackup = Join-Path $BackupDir 'executionpolicy.txt'
if (Test-Path $policyBackup) {
    $origPolicy = (Get-Content $policyBackup -Raw).Trim()
    if ((Get-ExecutionPolicy -Scope CurrentUser).ToString() -eq $origPolicy) { Write-Ok "Sudah $origPolicy" }
    else {
        try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $origPolicy -Force } catch {}
        if ((Get-ExecutionPolicy -Scope CurrentUser).ToString() -eq $origPolicy) { Write-Ok "Dikembalikan ke $origPolicy" }
        else { Write-Bad 'Gagal mengembalikan Execution Policy.'; $warnings++ }
    }
} else { Write-Note 'Backup tidak ditemukan, dilewati.' }

# ============================================================ 5. terminal-icons (opsional)
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Write-Step 'Modul Terminal-Icons'
    if (Read-YesNo 'Hapus juga modul Terminal-Icons?' $false) {
        try { Uninstall-Module -Name Terminal-Icons -AllVersions -Force; Write-Ok 'Dihapus' }
        catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }
    } else { Write-Ok 'Dibiarkan' }
}

# ============================================================ 5b. clink (CMD)
$clinkExe = Get-ChildItem (Join-Path $GlowHome 'clink') -Filter 'clink_*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($clinkExe) {
    Write-Step 'Lepas Clink dari CMD'
    try {
        & $clinkExe.FullName autorun uninstall | Out-Null
        Write-Ok 'Selesai'
    } catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }
}

# ============================================================ 5c. perintah glowsh di PATH
Write-Step 'Hapus perintah glowsh dari PATH'
try {
    $binDir = Join-Path $GlowHome 'bin'
    $envKey = Get-Item 'HKCU:\Environment'
    $cur = [string]$envKey.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $parts = @($cur -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $binDir.TrimEnd('\') })
    if (($parts -join ';') -ne $cur.Trim(';')) {
        Set-ItemProperty -Path 'HKCU:\Environment' -Name 'Path' -Value ($parts -join ';') -Type ExpandString
        [Environment]::SetEnvironmentVariable('GLOWSH_REFRESH', '1', 'User')
        [Environment]::SetEnvironmentVariable('GLOWSH_REFRESH', $null, 'User')
    }
    Write-Ok 'Selesai'
} catch { Write-Bad "Gagal: $($_.Exception.Message)"; $warnings++ }

# ============================================================ 6. folder glowsh
Write-Step 'Hapus folder ~\.glowsh'
if (Test-Path $GlowHome) {
    try { Remove-Item $GlowHome -Recurse -Force; Write-Ok 'Dihapus' }
    catch { Write-Bad 'Sebagian file masih dipakai. Tutup semua terminal lalu hapus manual:'; Write-Host "         $GlowHome"; $warnings++ }
} else { Write-Ok 'Tidak ada' }

Write-Host ''
if ($warnings -eq 0) { Write-Host '  Glowsh sudah dihapus. Tutup terminal ini dan buka yang baru.' -ForegroundColor Green }
else { Write-Host "  Selesai dengan $warnings peringatan (lihat di atas)." -ForegroundColor Yellow }
Write-Host '  (Font Meslo Nerd Font tetap terpasang karena tidak mengganggu; hapus lewat Settings > Fonts kalau mau.)' -ForegroundColor DarkGray
Write-Host ''
}
