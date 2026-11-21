<#
    Glowsh uninstaller - kembalikan tampilan terminal ke kondisi sebelum Glowsh.
    Glowsh uninstaller - restores your terminal to how it was before Glowsh.

    PowerShell:
        irm https://raw.githubusercontent.com/SQverse/glowsh/main/uninstall.ps1 | iex

    CMD:
        powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/SQverse/glowsh/main/uninstall.ps1 | iex"

    Berdiri sendiri (tidak butuh glowsh.ps1) supaya tetap bisa jalan walau instalasi rusak.
#>

& {
$ErrorActionPreference = 'Stop'

# ============================================================ konfigurasi (harus sama dengan glowsh.ps1)
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

# Bahasa: ikuti pilihan saat install, kalau tidak ada tebak dari Windows
$lang = $null
try { $lang = [string]([IO.File]::ReadAllText((Join-Path $GlowHome 'config.json')) | ConvertFrom-Json).lang } catch {}
if ($lang -notin 'id', 'en') { $lang = if ((Get-Culture).Name -like 'id*' -or (Get-UICulture).Name -like 'id*') { 'id' } else { 'en' } }
function L([string]$Id, [string]$En) { if ($lang -eq 'en') { $En } else { $Id } }

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
$warnings = 0

Write-Host ''
Write-Host '  Glowsh uninstaller' -ForegroundColor Magenta
Write-Host ('  ' + (L 'Ini akan menghapus Glowsh dari profil, mengembalikan tema Windows Terminal, warna console,' 'This removes Glowsh from your profile and restores the Windows Terminal theme, console colors,'))
Write-Host ('  ' + (L 'Execution Policy & pengaturan git ke kondisi sebelum Glowsh, lalu menghapus ~\.glowsh.' 'Execution Policy & git settings to how they were, then deletes ~\.glowsh.'))
Write-Host ''
if (-not (Read-YesNo (L 'Lanjut?' 'Continue?'))) { Write-Note (L 'Dibatalkan.' 'Cancelled.'); return }

# ============================================================ 1. profil
Write-Step (L 'Hapus blok Glowsh dari profil PowerShell' 'Removing the Glowsh block from your PowerShell profile')
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
Write-Step (L 'Kembalikan pengaturan Windows Terminal' 'Restoring Windows Terminal settings')
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
        Write-Ok $key
    } catch { Write-Bad "$key : $($_.Exception.Message)"; $warnings++ }
}

# ============================================================ 3. console klasik
Write-Step (L 'Kembalikan warna console klasik' 'Restoring classic console colors')
$consoleBackup = Join-Path $BackupDir 'console.json'
if (Test-Path $consoleBackup) {
    try {
        $orig = Get-Content $consoleBackup -Raw | ConvertFrom-Json
        foreach ($prop in $orig.PSObject.Properties) {
            if ($null -eq $prop.Value) { Remove-ItemProperty -Path $ConsoleKey -Name $prop.Name -ErrorAction SilentlyContinue }
            else { Set-ItemProperty -Path $ConsoleKey -Name $prop.Name -Value ([int]$prop.Value) -Type DWord }
        }
        Write-Ok (L 'Selesai' 'Done')
    } catch { Write-Bad $_.Exception.Message; $warnings++ }
} else { Write-Note (L 'Backup tidak ditemukan, dilewati.' 'No backup found, skipped.') }

# ============================================================ 4. execution policy
Write-Step (L 'Kembalikan Execution Policy (CurrentUser)' 'Restoring the Execution Policy (CurrentUser)')
$policyBackup = Join-Path $BackupDir 'executionpolicy.txt'
if (Test-Path $policyBackup) {
    $origPolicy = (Get-Content $policyBackup -Raw).Trim()
    if ((Get-ExecutionPolicy -Scope CurrentUser).ToString() -eq $origPolicy) { Write-Ok $origPolicy }
    else {
        try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $origPolicy -Force } catch {}
        if ((Get-ExecutionPolicy -Scope CurrentUser).ToString() -eq $origPolicy) { Write-Ok $origPolicy }
        else { Write-Bad (L 'Gagal mengembalikan Execution Policy.' 'Could not restore the Execution Policy.'); $warnings++ }
    }
} else { Write-Note (L 'Backup tidak ditemukan, dilewati.' 'No backup found, skipped.') }

# ============================================================ 5. git autocorrect
$gitBackup = Join-Path $BackupDir 'git-autocorrect.txt'
if ((Test-Path $gitBackup) -and (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Step (L 'Kembalikan pengaturan git (help.autocorrect)' 'Restoring git settings (help.autocorrect)')
    try {
        $origGit = ([IO.File]::ReadAllText($gitBackup)).Trim()
        if ($origGit -eq '<unset>') { git config --global --unset help.autocorrect } else { git config --global help.autocorrect $origGit }
        Write-Ok (L 'Selesai' 'Done')
    } catch { Write-Bad $_.Exception.Message; $warnings++ }
}

# ============================================================ 6. terminal-icons (opsional)
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Write-Step 'Terminal-Icons'
    if (Read-YesNo (L 'Hapus juga modul Terminal-Icons?' 'Also remove the Terminal-Icons module?') $false) {
        try { Uninstall-Module -Name Terminal-Icons -AllVersions -Force; Write-Ok (L 'Dihapus' 'Removed') }
        catch { Write-Bad $_.Exception.Message; $warnings++ }
    } else { Write-Ok (L 'Dibiarkan' 'Kept') }
}

# ============================================================ 7. clink (CMD)
$clinkExe = Get-ChildItem (Join-Path $GlowHome 'clink') -Filter 'clink_*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($clinkExe) {
    Write-Step (L 'Lepas Clink dari CMD' 'Detaching Clink from CMD')
    try { & $clinkExe.FullName autorun uninstall | Out-Null; Write-Ok (L 'Selesai' 'Done') }
    catch { Write-Bad $_.Exception.Message; $warnings++ }
}

# ============================================================ 8. perintah glowsh di PATH
Write-Step (L 'Hapus perintah glowsh dari PATH' 'Removing glowsh from PATH')
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
    Write-Ok (L 'Selesai' 'Done')
} catch { Write-Bad $_.Exception.Message; $warnings++ }

# ============================================================ 9. folder glowsh
Write-Step (L 'Hapus folder ~\.glowsh' 'Deleting ~\.glowsh')
if (Test-Path $GlowHome) {
    try { Remove-Item $GlowHome -Recurse -Force; Write-Ok (L 'Dihapus' 'Deleted') }
    catch { Write-Bad (L 'Sebagian file masih dipakai. Tutup semua terminal lalu hapus manual:' 'Some files are still in use. Close all terminals and delete it manually:'); Write-Host "         $GlowHome"; $warnings++ }
} else { Write-Ok (L 'Tidak ada' 'Nothing to delete') }

Write-Host ''
if ($warnings -eq 0) { Write-Host ('  ' + (L 'Glowsh sudah dihapus. Tutup terminal ini dan buka yang baru.' 'Glowsh has been removed. Close this terminal and open a new one.')) -ForegroundColor Green }
else { Write-Host ('  ' + (L "Selesai dengan $warnings peringatan (lihat di atas)." "Finished with $warnings warnings (see above).")) -ForegroundColor Yellow }
Write-Host ('  ' + (L '(Font Meslo Nerd Font, Windows Terminal & PSReadLine baru tetap terpasang karena tidak mengganggu.)' '(Meslo Nerd Font, Windows Terminal & the newer PSReadLine stay installed since they are harmless.)')) -ForegroundColor DarkGray
Write-Host ''
}
