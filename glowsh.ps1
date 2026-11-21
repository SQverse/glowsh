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
$GlowshVersion = '0.5.2'
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
    logo     = @($true,  'logo ASCII Glowsh di sapaan', 'Glowsh ASCII logo in the greeting')
    sysinfo  = @($true,  'panel sistem di sapaan (RAM, disk, statistik hari ini)', 'system panel in the greeting (RAM, disk, today)')
    calendar = @($true,  'kalender bulan ini + tanggal hijriah di sapaan', 'this month''s calendar + Hijri date in the greeting')
    moon     = @($true,  'gambar fase bulan di kalender', 'moon phase drawing in the calendar')
    sholat   = @($true,  'jadwal sholat di sapaan (atur: glowsh lokasi <kota>)', 'prayer times in the greeting (set: glowsh lokasi <city>)')
    quote    = @($true,  'quote harian di sapaan (lucu, hidup, agama, diri)', 'daily quote in the greeting (fun, life, faith, growth)')
    recent   = @($true,  'folder terakhir dibuka di sapaan (glowsh go)', 'recent folders in the greeting (glowsh go)')
    auto     = @($false, 'tema mengikuti waktu: pagi > senja > neon', 'theme follows the time: pagi > senja > neon')
    seasonal = @($true,  'tema musiman: 17 Agustus, Ramadan, Tahun Baru', 'seasonal themes: Aug 17, Ramadan, New Year')
    notify   = @($true,  'notifikasi saat perintah lama selesai', 'notification when a long command finishes')
    typo     = @($true,  'saran saat salah ketik perintah', 'suggestions for mistyped commands')
    guard    = @($true,  'peringatan sebelum perintah berbahaya', 'warning before dangerous commands')
    stats    = @($true,  'catat statistik untuk glowsh wrapped (nama perintah saja, disimpan lokal)', 'record stats for glowsh wrapped (command names only, stored locally)')
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

# Ambil "nama perintah" saja dari satu baris perintah, untuk statistik glowsh wrapped.
# Argumen sengaja dibuang (bisa berisi token/password); hanya subperintah umum yang disimpan (git push, npm install).
function Get-GlowshCommandHead([string]$Line) {
    $t = ([string]$Line).Trim() -replace '^[&.]\s+', ''
    if (-not $t) { return $null }
    $parts = @($t -split '\s+' | Where-Object { $_ })
    $cmd = $parts[0].Trim('"', "'")
    try { $cmd = [IO.Path]::GetFileName($cmd) } catch {}
    $cmd = ($cmd -replace '\.(exe|cmd|bat|ps1)$', '').ToLower()
    if ($cmd -notmatch '^[a-z0-9][\w.-]{0,39}$') { return $null }
    $withSub = 'git', 'npm', 'pnpm', 'yarn', 'bun', 'winget', 'docker', 'pip', 'dotnet', 'cargo', 'go', 'gh', 'glowsh', 'scoop', 'choco', 'kubectl', 'composer', 'php', 'flutter', 'ng'
    if ($withSub -contains $cmd -and $parts.Count -gt 1 -and $parts[1] -match '^[a-z][a-z0-9-]{0,20}$') { return "$cmd $($parts[1])" }
    return $cmd
}

# ---------- komponen tampilan sapaan (juga dipakai "glowsh quote" dan "glowsh go")
# Quote: @(teks Indonesia, teks Inggris, sumber). Ditulis tanpa apostrof Inggris supaya file tetap aman.
$GlowshQuotes = [ordered]@{
    lucu = @(
        @('Kode yang jalan di laptopku belum tentu jalan di laptopmu.', 'Code that runs on my laptop may not run on yours.', 'pepatah programmer'),
        @('Ada 10 jenis orang di dunia: yang paham biner dan yang tidak.', 'There are 10 kinds of people: those who understand binary and those who do not.', 'anonim'),
        @('Debugging itu seperti jadi detektif di film kriminal, padahal kamu juga pelakunya.', 'Debugging is like being the detective in a crime movie where you are also the murderer.', 'Filipe Fortes'),
        @('99 bug kecil di dalam kode. Perbaiki satu, kompilasi lagi... sekarang ada 127 bug.', '99 little bugs in the code. Fix one, compile again... 127 little bugs in the code.', 'lagu rakyat programmer'),
        @('Deploy hari Jumat sore? Berani juga kamu.', 'Deploying on a Friday afternoon? Bold move.', 'nasihat senior'),
        @('Ctrl+S adalah bentuk kasih sayang paling tulus.', 'Ctrl+S is the purest form of self-care.', 'anonim'),
        @('Ngoding itu 10% menulis kode dan 90% mencari tahu kenapa kodenya tidak jalan.', 'Coding is 10% writing code and 90% figuring out why it does not work.', 'anonim'),
        @('// jangan diubah, entah kenapa ini jalan', '// do not touch, somehow this works', 'komentar paling jujur'),
        @('Dua hal tersulit dalam ilmu komputer: cache invalidation dan memberi nama variabel.', 'There are only two hard things in computer science: cache invalidation and naming things.', 'Phil Karlton'),
        @('Sebelum ngoding: "ah, gampang". Sesudahnya: "kok bisa ya ini jalan?"', 'Before coding: "easy". After: "how does this even work?"', 'anonim')
    )
    hidup = @(
        @('Hidup itu seperti naik sepeda. Agar tetap seimbang, kamu harus terus bergerak.', 'Life is like riding a bicycle. To keep your balance, you must keep moving.', 'Albert Einstein'),
        @('Terbentur, terbentur, terbentuk.', 'Struck, struck again, and shaped.', 'Tan Malaka'),
        @('Hidup bukan tentang menunggu badai berlalu, tapi belajar menari di tengah hujan.', 'Life is not about waiting for the storm to pass, it is about learning to dance in the rain.', 'Vivian Greene'),
        @('Kebahagiaan bukan sesuatu yang sudah jadi. Ia datang dari tindakanmu sendiri.', 'Happiness is not something ready made. It comes from your own actions.', 'Dalai Lama'),
        @('Orang boleh pandai setinggi langit, tapi selama ia tidak menulis, ia akan hilang di dalam masyarakat dan dari sejarah.', 'One may be as clever as the sky is high, but as long as one does not write, one will vanish from society and from history.', 'Pramoedya Ananta Toer'),
        @('Bermimpilah setinggi langit. Jika engkau jatuh, engkau akan jatuh di antara bintang-bintang.', 'Dream as high as the sky. If you fall, you will fall among the stars.', 'Soekarno'),
        @('Hal yang paling sulit adalah memutuskan untuk bertindak. Sisanya hanyalah kegigihan.', 'The most difficult thing is the decision to act. The rest is merely tenacity.', 'Amelia Earhart'),
        @('Tanpa cinta, kecerdasan itu berbahaya. Dan tanpa kecerdasan, cinta itu tidak cukup.', 'Without love, intelligence is dangerous. And without intelligence, love is not enough.', 'B.J. Habibie')
    )
    agama = @(
        @('Sesungguhnya bersama kesulitan ada kemudahan.', 'Indeed, with hardship comes ease.', 'QS. Al-Insyirah: 6'),
        @('Allah tidak membebani seseorang melainkan sesuai dengan kesanggupannya.', 'Allah does not burden a soul beyond what it can bear.', 'QS. Al-Baqarah: 286'),
        @('Ingatlah, hanya dengan mengingat Allah hati menjadi tenteram.', 'Verily, in the remembrance of Allah do hearts find rest.', 'QS. Ar-Ra''d: 28'),
        @('Maka nikmat Tuhanmu yang manakah yang kamu dustakan?', 'So which of the favors of your Lord would you deny?', 'QS. Ar-Rahman: 13'),
        @('Janganlah kamu bersikap lemah, dan janganlah pula kamu bersedih hati.', 'So do not weaken and do not grieve.', 'QS. Ali ''Imran: 139'),
        @('Dan bersabarlah. Sesungguhnya Allah beserta orang-orang yang sabar.', 'And be patient. Indeed, Allah is with the patient.', 'QS. Al-Anfal: 46'),
        @('Sebaik-baik manusia adalah yang paling bermanfaat bagi manusia lainnya.', 'The best of people are those most beneficial to others.', 'HR. Ath-Thabrani'),
        @('Barang siapa menempuh jalan untuk mencari ilmu, Allah mudahkan baginya jalan menuju surga.', 'Whoever takes a path in search of knowledge, Allah makes easy for him a path to Paradise.', 'HR. Muslim'),
        @('Senyummu di hadapan saudaramu adalah sedekah.', 'Your smile to your brother is charity.', 'HR. At-Tirmidzi')
    )
    diri = @(
        @('Kita adalah apa yang kita kerjakan berulang kali. Keunggulan bukanlah tindakan, melainkan kebiasaan.', 'We are what we repeatedly do. Excellence, then, is not an act, but a habit.', 'Will Durant'),
        @('Perjalanan seribu mil dimulai dari satu langkah.', 'A journey of a thousand miles begins with a single step.', 'Lao Tzu'),
        @('Bandingkan dirimu dengan dirimu yang kemarin, bukan dengan orang lain hari ini.', 'Compare yourself to who you were yesterday, not to who someone else is today.', 'Jordan Peterson'),
        @('Kesuksesan adalah jumlah dari usaha kecil yang diulang hari demi hari.', 'Success is the sum of small efforts, repeated day in and day out.', 'Robert Collier'),
        @('Disiplin adalah jembatan antara tujuan dan pencapaian.', 'Discipline is the bridge between goals and accomplishment.', 'Jim Rohn'),
        @('Waktu terbaik untuk menanam pohon adalah 20 tahun lalu. Waktu terbaik kedua adalah sekarang.', 'The best time to plant a tree was 20 years ago. The second best time is now.', 'pepatah Tiongkok'),
        @('Kamu tidak harus hebat untuk memulai, tapi kamu harus memulai untuk menjadi hebat.', 'You do not have to be great to start, but you have to start to be great.', 'Zig Ziglar'),
        @('Bedanya orang sukses dan yang lain bukan kurang kuat atau kurang pintar, tapi kurang kemauan.', 'The difference between a successful person and others is not a lack of strength or knowledge, but a lack of will.', 'Vince Lombardi')
    )
}
$GlowshQuoteAlias = @{ fun = 'lucu'; life = 'hidup'; faith = 'agama'; growth = 'diri' }
$GlowshQuoteLabels = @{ lucu = @('lucu', 'fun'); hidup = @('hidup', 'life'); agama = @('agama', 'faith'); diri = @('diri', 'growth') }

# Kategori yang aktif (dari config "quoteKinds"); kosong = semua
function Get-GlowshQuoteKinds($Configured) {
    $k = @(@($Configured) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $GlowshQuotes.Contains($_) })
    if ($k.Count -eq 0) { $k = @($GlowshQuotes.Keys) }
    return $k
}

# Quote hari ini (sama sepanjang hari) atau acak (-Random)
function Get-GlowshQuote([string[]]$Kinds, [switch]$Random) {
    if (-not $Kinds -or $Kinds.Count -eq 0) { $Kinds = @($GlowshQuotes.Keys) }
    if ($Random) {
        $kind = $Kinds[(Get-Random -Maximum $Kinds.Count)]
        $list = $GlowshQuotes[$kind]
        $item = $list[(Get-Random -Maximum $list.Count)]
    } else {
        $now = Get-Date
        $day = $now.Year * 366 + $now.DayOfYear
        $kind = $Kinds[$day % $Kinds.Count]
        $list = $GlowshQuotes[$kind]
        $item = $list[([int][Math]::Floor($day / $Kinds.Count)) % $list.Count]
    }
    return @{ Kind = $kind; Text = (Get-GlowshText $item[0] $item[1]); Source = $item[2] }
}

function ConvertTo-GlowshPal([string]$A1, [string]$A2, [string]$Muted, [string]$Err = '#FF5F7E', [string]$Bg = '#101018') {
    $rgb = { param($hex) $x = ([string]$hex).TrimStart('#'); @([Convert]::ToInt32($x.Substring(0, 2), 16), [Convert]::ToInt32($x.Substring(2, 2), 16), [Convert]::ToInt32($x.Substring(4, 2), 16)) }
    $p1 = & $rgb $A1; $p2 = & $rgb $A2
    return @{ P1 = $p1; P2 = $p2; c1 = $p1 -join ';'; c2 = $p2 -join ';'; cm = (& $rgb $Muted) -join ';'; err = (& $rgb $Err) -join ';'; bg = (& $rgb $Bg) -join ';' }
}

function Get-GlowshVisibleLength([string]$S) { return ($S -replace "$([char]27)\[[0-9;]*m", '').Length }

function Format-GlowshPad([string]$S, [int]$W) {
    $n = $W - (Get-GlowshVisibleLength $S)
    if ($n -gt 0) { return $S + (' ' * $n) }
    return $S
}

function Split-GlowshWrap([string]$Text, [int]$Width) {
    $out = New-Object System.Collections.Generic.List[string]
    $cur = ''
    foreach ($w in ($Text -split '\s+')) {
        if (-not $w) { continue }
        if (-not $cur) { $cur = $w }
        elseif (($cur.Length + 1 + $w.Length) -le $Width) { $cur += ' ' + $w }
        else { $out.Add($cur); $cur = $w }
    }
    if ($cur) { $out.Add($cur) }
    return $out.ToArray()
}

# Panel berbingkai melengkung: judul berwarna aksen, bingkai warna redup
function New-GlowshBox([string]$Title, [string[]]$Lines, $Pal, [int]$MinWidth = 0) {
    $e = [char]27; $r = "$e[0m"
    $hz = [string][char]0x2500; $vt = [string][char]0x2502
    $tlen = Get-GlowshVisibleLength $Title
    $inner = $MinWidth
    foreach ($l in $Lines) { $inner = [Math]::Max($inner, (Get-GlowshVisibleLength $l)) }
    $inner = [Math]::Max($inner, $tlen + 1)
    $b = "$e[38;2;$($Pal.cm)m"
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add("$b$([char]0x256D)$hz $e[1;38;2;$($Pal.c2)m$Title$r$b " + ($hz * ($inner - 1 - $tlen)) + "$([char]0x256E)$r")
    foreach ($l in $Lines) { $out.Add("$b$vt$r " + (Format-GlowshPad $l $inner) + " $b$vt$r") }
    $out.Add("$b$([char]0x2570)" + ($hz * ($inner + 2)) + "$([char]0x256F)$r")
    return $out.ToArray()
}

# Bar tipis bergradasi; merah kalau persentasenya tinggi
function New-GlowshBar([double]$Pct, [int]$Cells, $Pal) {
    $e = [char]27
    $seg = [string][char]0x2501
    $fill = [int][Math]::Round([Math]::Max(0, [Math]::Min(100, $Pct)) / 100 * $Cells)
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Cells; $i++) {
        if ($i -lt $fill) {
            if ($Pct -ge 85) { $c = $Pal.err }
            else {
                $t = if ($Cells -gt 1) { $i / ($Cells - 1) } else { 0 }
                $c = @(0, 1, 2 | ForEach-Object { [int]($Pal.P1[$_] + ($Pal.P2[$_] - $Pal.P1[$_]) * $t) }) -join ';'
            }
            [void]$sb.Append("$e[38;2;${c}m$seg")
        } else { [void]$sb.Append("$e[2;38;2;$($Pal.cm)m$seg$e[22m") }
    }
    [void]$sb.Append("$e[0m")
    return $sb.ToString()
}

# Jumlah perintah hari ini & streak, dari 256 KB terakhir stats.log (cepat walau file-nya besar)
function Get-GlowshTodayStats {
    $f = Join-Path $HOME '.glowsh\stats.log'
    $res = @{ Today = 0; Streak = 0 }
    if (-not (Test-Path $f)) { return $res }
    $fs = [IO.File]::Open($f, 'Open', 'Read', 'ReadWrite')
    try {
        $take = [int][Math]::Min($fs.Length, 262144)
        [void]$fs.Seek(-$take, 'End')
        $buf = New-Object byte[] $take
        [void]$fs.Read($buf, 0, $take)
    } finally { $fs.Dispose() }
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $days = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($l in ([Text.Encoding]::UTF8.GetString($buf) -split "`n")) {
        if ($l.Length -lt 12 -or $l[4] -ne '-' -or $l.Contains("`t__")) { continue }
        $d = $l.Substring(0, 10)
        [void]$days.Add($d)
        if ($d -eq $today) { $res.Today++ }
    }
    $dt = Get-Date
    if (-not $days.Contains($today)) { $dt = $dt.AddDays(-1) }
    while ($days.Contains($dt.ToString('yyyy-MM-dd'))) { $res.Streak++; $dt = $dt.AddDays(-1) }
    return $res
}

function Get-GlowshSysPanel($Pal, [string]$Icon) {
    $e = [char]27; $r = "$e[0m"; $m = "$e[38;2;$($Pal.cm)m"
    $lines = New-Object System.Collections.Generic.List[string]
    $lbl = { param($t) $m + $t.PadRight(9) + $r }
    $os = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -Property Caption, FreePhysicalMemory, TotalVisibleMemorySize, LastBootUpTime -ErrorAction Stop } catch {}
    if ($os) {
        $lines.Add("$e[1m" + ([string]$os.Caption -replace '^Microsoft\s+', '').Trim() + $r)
        $ram = 100 * (1 - [double]$os.FreePhysicalMemory / [double]$os.TotalVisibleMemorySize)
        $lines.Add((& $lbl 'RAM') + (New-GlowshBar $ram 12 $Pal) + ('{0,5}' -f ("$([int]$ram)%")))
    }
    try {
        $dv = New-Object IO.DriveInfo ($env:SystemDrive)
        $used = 100 * (1 - [double]$dv.AvailableFreeSpace / [double]$dv.TotalSize)
        $lines.Add((& $lbl ('Disk ' + $env:SystemDrive.TrimEnd(':'))) + (New-GlowshBar $used 12 $Pal) + ('{0,5}' -f ("$([int]$used)%")))
    } catch {}
    if ($os) {
        $up = (Get-Date) - $os.LastBootUpTime
        $upText = if ($up.Days -gt 0) { Get-GlowshText "$($up.Days) hari $($up.Hours) jam" "$($up.Days)d $($up.Hours)h" } else { Get-GlowshText "$($up.Hours) jam $($up.Minutes) mnt" "$($up.Hours)h $($up.Minutes)m" }
        $lines.Add((& $lbl (Get-GlowshText 'Nyala' 'Uptime')) + $upText)
    }
    try {
        $st = Get-GlowshTodayStats
        $lines.Add((& $lbl (Get-GlowshText 'Hari ini' 'Today')) + "$e[38;2;$($Pal.c1)m$($st.Today)$r " + (Get-GlowshText 'perintah' 'commands') +
            $(if ($st.Streak -gt 0) { "  $m" + (Get-GlowshText "streak $($st.Streak) hari" "$($st.Streak)-day streak") + $r } else { '' }))
    } catch {}
    return New-GlowshBox ($Icon + (Get-GlowshText 'sistem' 'system')) $lines.ToArray() $Pal
}

# Kalender masehi + gambar fase bulan di sampingnya + tanggal hijriah di bawahnya
function Get-GlowshCalendarPanel($Pal, $Culture, [string]$Icon, [datetime]$Now, [bool]$Moon = $true, [int]$HijriOffset = 0, [bool]$AfterMaghrib = $false) {
    $e = [char]27; $r = "$e[0m"
    $grid = @(Get-GlowshMonthGrid $Pal $Now)
    $lines = New-Object System.Collections.Generic.List[string]
    $mi = Get-GlowshMoon $Now
    if ($Moon) {
        $art = @(Get-GlowshMoonArt $mi $Pal 8 18)
        for ($i = 0; $i -lt [Math]::Max($grid.Count, $art.Count); $i++) {
            $left = if ($i -lt $grid.Count) { $grid[$i] } else { '' }
            $right = if ($i -lt $art.Count) { $art[$i] } else { '' }
            $lines.Add((Format-GlowshPad $left 20) + '   ' + $right)
        }
    } else { foreach ($g in $grid) { $lines.Add($g) } }
    # Hari dalam kalender hijriah dimulai saat Maghrib
    $hDate = $Now.Date.AddDays($HijriOffset + $(if ($AfterMaghrib) { 1 } else { 0 }))
    $lines.Add("$e[38;2;$($Pal.c2)m" + (Get-GlowshHijriText $hDate) + $r)
    $lines.Add("$e[38;2;$($Pal.cm)m" + $mi.Name + ' ' + [char]0x00B7 + ' ' + [int][Math]::Round($mi.Illum * 100) + '% ' + [char]0x00B7 + ' ' +
        (Get-GlowshText ('hari ke-' + ([int][Math]::Floor($mi.Age) + 1)) ('day ' + ([int][Math]::Floor($mi.Age) + 1))) + $r)
    $title = $Icon + $Culture.DateTimeFormat.GetMonthName($Now.Month) + ' ' + $Now.Year
    return New-GlowshBox $title $lines.ToArray() $Pal 20
}

function Get-GlowshMonthGrid($Pal, [datetime]$Now) {
    $e = [char]27; $r = "$e[0m"
    $first = New-Object DateTime ($Now.Year, $Now.Month, 1)
    $offset = ([int]$first.DayOfWeek + 6) % 7          # minggu dimulai hari Senin
    $daysIn = [DateTime]::DaysInMonth($Now.Year, $Now.Month)
    $names = if ($GlowshLang -eq 'en') { @('Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su') } else { @('Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg') }
    $holidays = @('1-1', '5-1', '6-1', '8-17', '12-25')   # libur nasional bertanggal tetap
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$e[38;2;$($Pal.cm)m" + ($names[0..5] -join ' ') + " $e[38;2;$($Pal.err)m" + $names[6] + $r)
    $row = '   ' * $offset
    for ($d = 1; $d -le $daysIn; $d++) {
        $wd = ($offset + $d - 1) % 7
        $txt = '{0,2}' -f $d
        if ($d -eq $Now.Day) { $cell = "$e[1;38;2;$($Pal.bg);48;2;$($Pal.c1)m$txt$r" }
        elseif ($wd -eq 6 -or $holidays -contains "$($Now.Month)-$d") { $cell = "$e[38;2;$($Pal.err)m$txt$r" }
        else { $cell = $txt }
        $row += $cell
        if ($wd -eq 6 -or $d -eq $daysIn) { $lines.Add($row); $row = '' } else { $row += ' ' }
    }
    return $lines.ToArray()
}

function Get-GlowshQuotePanel($Pal, $Quote, [string]$Icon, [int]$Width = 40) {
    $e = [char]27; $r = "$e[0m"
    $lines = New-Object System.Collections.Generic.List[string]
    $wrapped = @(Split-GlowshWrap ('"' + $Quote.Text + '"') $Width)
    foreach ($w in $wrapped) { $lines.Add("$e[3m$w$r") }
    $src = '- ' + $Quote.Source
    $lines.Add((' ' * [Math]::Max(0, $Width - $src.Length)) + "$e[38;2;$($Pal.c1)m$src$r")
    $label = Get-GlowshText $GlowshQuoteLabels[$Quote.Kind][0] $GlowshQuoteLabels[$Quote.Kind][1]
    return New-GlowshBox ($Icon + 'quote ' + [char]0x00B7 + ' ' + $label) $lines.ToArray() $Pal $Width
}

# ---------- waktu sholat (parameter Kemenag RI), kalender hijriah, fase bulan
# Rumus astronomi dari PrayTimes.org (Hamid Zarrabi-Zadeh). Semua dihitung lokal, tanpa internet.
function Get-GlowshPrayerTimes([double]$Lat, [double]$Lon, [datetime]$Date) {
    $rad = [Math]::PI / 180.0
    $fixA = { param($v) $v - 360.0 * [Math]::Floor($v / 360.0) }
    $fixH = { param($v) $v - 24.0 * [Math]::Floor($v / 24.0) }
    $yy = $Date.Year; $mm = $Date.Month; $dd = $Date.Day
    if ($mm -le 2) { $yy -= 1; $mm += 12 }
    $ca = [Math]::Floor($yy / 100.0); $cb = 2 - $ca + [Math]::Floor($ca / 4.0)
    $jd = [Math]::Floor(365.25 * ($yy + 4716)) + [Math]::Floor(30.6001 * ($mm + 1)) + $dd + $cb - 1524.5 - $Lon / (15.0 * 24.0)
    $sun = { param($j)
        $n = $j - 2451545.0
        $g = & $fixA (357.529 + 0.98560028 * $n)
        $q = & $fixA (280.459 + 0.98564736 * $n)
        $lam = & $fixA ($q + 1.915 * [Math]::Sin($g * $rad) + 0.020 * [Math]::Sin(2 * $g * $rad))
        $obl = 23.439 - 0.00000036 * $n
        $ra = ([Math]::Atan2([Math]::Cos($obl * $rad) * [Math]::Sin($lam * $rad), [Math]::Cos($lam * $rad)) / $rad) / 15.0
        @{ Eqt = $q / 15.0 - (& $fixH $ra); Decl = [Math]::Asin([Math]::Sin($obl * $rad) * [Math]::Sin($lam * $rad)) / $rad }
    }
    $mid = { param($frac) & $fixH (12.0 - (& $sun ($jd + $frac)).Eqt) }
    $angleTime = { param($angle, $frac, $ccw)
        $s = & $sun ($jd + $frac)
        $noon = & $mid $frac
        $cosv = (-[Math]::Sin($angle * $rad) - [Math]::Sin($s.Decl * $rad) * [Math]::Sin($Lat * $rad)) / ([Math]::Cos($s.Decl * $rad) * [Math]::Cos($Lat * $rad))
        $span = ([Math]::Acos([Math]::Max(-1.0, [Math]::Min(1.0, $cosv))) / $rad) / 15.0
        if ($ccw) { $noon - $span } else { $noon + $span }
    }
    $asr = { param($factor, $frac)
        $s = & $sun ($jd + $frac)
        $angle = -([Math]::Atan(1.0 / ($factor + [Math]::Tan([Math]::Abs($Lat - $s.Decl) * $rad))) / $rad)
        & $angleTime $angle $frac $false
    }
    $adj = ([TimeZoneInfo]::Local.GetUtcOffset($Date.Date.AddHours(12))).TotalHours - $Lon / 15.0
    # Jam desimal -> waktu lokal, + ihtiyath, dibulatkan ke atas ke menit penuh (seperti jadwal Kemenag)
    $at = { param($hrs, $extra)
        $x = $Date.Date.AddHours($hrs + $adj).AddMinutes($extra)
        if ($x.Second -gt 0 -or $x.Millisecond -gt 0) { $x = $x.AddMilliseconds(-$x.Millisecond).AddSeconds(60 - $x.Second) }
        $x
    }
    $subuh = & $at (& $angleTime 20.0 (5 / 24.0) $true) 2
    return @(
        @{ Key = 'imsak';   Id = 'Imsak';   En = 'Imsak';   Main = $false; Time = $subuh.AddMinutes(-10) },
        @{ Key = 'subuh';   Id = 'Subuh';   En = 'Fajr';    Main = $true;  Time = $subuh },
        @{ Key = 'terbit';  Id = 'Terbit';  En = 'Sunrise'; Main = $false; Time = (& $at (& $angleTime 0.833 (6 / 24.0) $true) 0) },
        @{ Key = 'dzuhur';  Id = 'Dzuhur';  En = 'Dhuhr';   Main = $true;  Time = (& $at (& $mid (12 / 24.0)) 2) },
        @{ Key = 'ashar';   Id = 'Ashar';   En = 'Asr';     Main = $true;  Time = (& $at (& $asr 1.0 (13 / 24.0)) 2) },
        @{ Key = 'maghrib'; Id = 'Maghrib'; En = 'Maghrib'; Main = $true;  Time = (& $at (& $angleTime 0.833 (18 / 24.0) $false) 2) },
        @{ Key = 'isya';    Id = 'Isya';    En = 'Isha';    Main = $true;  Time = (& $at (& $angleTime 18.0 (18 / 24.0) $false) 2) }
    )
}

function Format-GlowshCountdown([TimeSpan]$T) {
    if ($T.TotalHours -ge 1) { return Get-GlowshText ("{0}j {1}m" -f [int][Math]::Floor($T.TotalHours), $T.Minutes) ("{0}h {1}m" -f [int][Math]::Floor($T.TotalHours), $T.Minutes) }
    return Get-GlowshText ("{0} mnt" -f [int][Math]::Ceiling($T.TotalMinutes)) ("{0} min" -f [int][Math]::Ceiling($T.TotalMinutes))
}

function Get-GlowshPrayerPanel($Pal, $Loc, [string]$Icon, [datetime]$Now) {
    $e = [char]27; $r = "$e[0m"; $m = "$e[38;2;$($Pal.cm)m"
    $lines = New-Object System.Collections.Generic.List[string]
    if (-not $Loc -or $null -eq $Loc.lat) {
        $lines.Add((Get-GlowshText 'Atur lokasi dulu:' 'Set your location first:'))
        $lines.Add("$e[38;2;$($Pal.c1)mglowsh lokasi Jakarta$r")
        return New-GlowshBox ($Icon + (Get-GlowshText 'sholat' 'prayer')) $lines.ToArray() $Pal
    }
    $times = Get-GlowshPrayerTimes ([double]$Loc.lat) ([double]$Loc.lon) $Now
    $next = $times | Where-Object { $_.Main -and $_.Time -gt $Now } | Select-Object -First 1
    foreach ($t in $times) {
        $name = (Get-GlowshText $t.Id $t.En).PadRight(8) + $t.Time.ToString('HH:mm')
        if ($next -and $t.Key -eq $next.Key) {
            $lines.Add("$e[1;38;2;$($Pal.c1)m$name$r  $e[38;2;$($Pal.c2)m" + (Get-GlowshText 'lagi ' 'in ') + (Format-GlowshCountdown ($t.Time - $Now)) + $r)
        } elseif (-not $t.Main -or $t.Time -le $Now) { $lines.Add("$m$name$r") }
        else { $lines.Add($name) }
    }
    if (-not $next) {
        $tomorrow = (Get-GlowshPrayerTimes ([double]$Loc.lat) ([double]$Loc.lon) $Now.AddDays(1)) | Where-Object { $_.Key -eq 'subuh' }
        $lines.Add("$e[1;38;2;$($Pal.c1)m" + (Get-GlowshText 'Subuh besok ' 'Fajr tomorrow ') + $tomorrow.Time.ToString('HH:mm') + $r)
    }
    return New-GlowshBox ($Icon + (Get-GlowshText 'sholat' 'prayer') + ' ' + [char]0x00B7 + ' ' + [string]$Loc.name) $lines.ToArray() $Pal
}

function Get-GlowshHijriText([datetime]$Date) {
    $names = if ($GlowshLang -eq 'en') {
        @('Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani', 'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhu al-Qadah', 'Dhu al-Hijjah')
    } else {
        @('Muharram', 'Safar', 'Rabiul Awal', 'Rabiul Akhir', 'Jumadil Awal', 'Jumadil Akhir', 'Rajab', 'Sya''ban', 'Ramadan', 'Syawal', 'Dzulqa''dah', 'Dzulhijjah')
    }
    $cal = New-Object Globalization.UmAlQuraCalendar
    return '{0} {1} {2} H' -f $cal.GetDayOfMonth($Date), $names[$cal.GetMonth($Date) - 1], $cal.GetYear($Date)
}

# Umur bulan dihitung dari bulan baru acuan (6 Jan 2000 18:14 UTC), siklus sinodis 29,53 hari
function Get-GlowshMoon([datetime]$Now) {
    $synodic = 29.530588853
    $ref = New-Object DateTime (2000, 1, 6, 18, 14, 0, [DateTimeKind]::Utc)
    $age = (($Now.ToUniversalTime() - $ref).TotalDays) % $synodic
    if ($age -lt 0) { $age += $synodic }
    $theta = 2 * [Math]::PI * $age / $synodic
    $idx = [int][Math]::Floor($age / $synodic * 8 + 0.5) % 8
    $names = @(@('Bulan baru', 'New moon'), @('Sabit awal', 'Waxing crescent'), @('Separuh awal', 'First quarter'), @('Cembung awal', 'Waxing gibbous'),
               @('Purnama', 'Full moon'), @('Cembung akhir', 'Waning gibbous'), @('Separuh akhir', 'Last quarter'), @('Sabit akhir', 'Waning crescent'))
    return @{ Age = $age; Theta = $theta; Illum = (1 - [Math]::Cos($theta)) / 2; Waxing = ($age -lt $synodic / 2); Name = (Get-GlowshText $names[$idx][0] $names[$idx][1]) }
}

# Gambar bulan dengan setengah-blok: tiap karakter = 2 piksel (atas & bawah), jadi lingkarannya halus
# $Rows baris teks (= 2x piksel tinggi), $Cols kolom. Karakter terminal lebih ramping dari 1:2
# (Meslo di Windows Terminal kira-kira 0,42), jadi 8 baris butuh ~18 kolom supaya bulannya bulat.
function Get-GlowshMoonArt($Moon, $Pal, [int]$Rows = 8, [int]$Cols = 18) {
    $e = [char]27
    $halfX = $Cols / 2.0; $halfY = $Rows    # tinggi dalam piksel = 2 x baris
    $k = [Math]::Cos($Moon.Theta)
    $bg = @($Pal.bg -split ';' | ForEach-Object { [int]$_ }); $mu = @($Pal.cm -split ';' | ForEach-Object { [int]$_ })
    $dark = @(0, 1, 2 | ForEach-Object { [int]($bg[$_] + ($mu[$_] - $bg[$_]) * 0.35) }) -join ';'
    $light = @(255, 246, 214); $shade = @(206, 192, 150)
    $pixel = { param($px, $py)
        $nx = ($px + 0.5 - $halfX) / $halfX; $ny = ($py + 0.5 - $halfY) / $halfY
        $d2 = $nx * $nx + $ny * $ny
        if ($d2 -gt 1.0) { return $null }
        $w = [Math]::Sqrt([Math]::Max(0.0, 1.0 - $ny * $ny))
        $lit = if ($Moon.Waxing) { $nx -ge $k * $w } else { $nx -le -$k * $w }
        if (-not $lit) { return $dark }
        $t = [Math]::Sqrt($d2)    # makin ke tepi makin redup: efek bola 3D
        return (@(0, 1, 2 | ForEach-Object { [int]($light[$_] + ($shade[$_] - $light[$_]) * $t) }) -join ';')
    }
    $artRows = New-Object System.Collections.Generic.List[string]
    for ($ry = 0; $ry -lt $Rows; $ry++) {
        $sb = New-Object System.Text.StringBuilder
        for ($cx = 0; $cx -lt $Cols; $cx++) {
            $top = & $pixel $cx (2 * $ry); $bot = & $pixel $cx (2 * $ry + 1)
            if ($top -and $bot) { [void]$sb.Append("$e[38;2;${top};48;2;${bot}m" + [char]0x2580 + "$e[0m") }
            elseif ($top) { [void]$sb.Append("$e[38;2;${top}m" + [char]0x2580 + "$e[0m") }
            elseif ($bot) { [void]$sb.Append("$e[38;2;${bot}m" + [char]0x2584 + "$e[0m") }
            else { [void]$sb.Append(' ') }
        }
        $artRows.Add($sb.ToString())
    }
    return $artRows.ToArray()
}

# ---------- folder terakhir (untuk panel & glowsh go)
function Get-GlowshRecentDirs([int]$Max = 5) {
    $f = Join-Path $HOME '.glowsh\recent.txt'
    if (-not (Test-Path $f)) { return @() }
    return @([IO.File]::ReadAllLines($f) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First $Max)
}

function Add-GlowshRecentDir([string]$Dir) {
    if (-not $Dir -or $Dir.TrimEnd('\') -eq $HOME.TrimEnd('\')) { return }
    $f = Join-Path $HOME '.glowsh\recent.txt'
    $old = if (Test-Path $f) { @([IO.File]::ReadAllLines($f)) } else { @() }
    $new = @($Dir) + @($old | Where-Object { $_ -and $_ -ne $Dir }) | Select-Object -First 15
    try { [IO.File]::WriteAllLines($f, [string[]]$new) } catch {}
}

function Get-GlowshShortPath([string]$P, [int]$Max = 24) {
    $s = $P
    if ($s.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $s = '~' + $s.Substring($HOME.Length) }
    if ($s.Length -gt $Max) { $s = '..' + $s.Substring($s.Length - ($Max - 2)) }
    return $s
}

function Get-GlowshGitBranch([string]$Dir) {
    $h = Join-Path $Dir '.git\HEAD'
    if (-not (Test-Path -LiteralPath $h -PathType Leaf)) { return $null }
    $c = ([IO.File]::ReadAllText($h)).Trim()
    if ($c -match '^ref: refs/heads/(.+)$') { return $Matches[1] }
    if ($c.Length -ge 7) { return $c.Substring(0, 7) }
    return $null
}

function Get-GlowshRecentPanel($Pal, [string]$Icon) {
    $e = [char]27; $r = "$e[0m"
    $dirs = @(Get-GlowshRecentDirs 4)
    if ($dirs.Count -eq 0) { return $null }
    $lines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $dirs.Count; $i++) {
        $br = Get-GlowshGitBranch $dirs[$i]
        $lines.Add("$e[38;2;$($Pal.c1)m$($i + 1)$r  " + (Get-GlowshShortPath $dirs[$i] 22).PadRight(22) + $(if ($br) { "  $e[38;2;$($Pal.c2)m$br$r" } else { '' }))
    }
    $lines.Add("$e[38;2;$($Pal.cm)m" + (Get-GlowshText 'lompat: glowsh go 1' 'jump: glowsh go 1') + $r)
    return New-GlowshBox ($Icon + (Get-GlowshText 'terakhir dibuka' 'recent')) $lines.ToArray() $Pal
}

# Susun blok-blok (logo, info, panel) mengalir ke kanan; pindah baris kalau tidak muat
function Write-GlowshLayout($Blocks, [int]$Width, [int]$Margin = 2, [int]$Gap = 4) {
    $rows = New-Object System.Collections.ArrayList
    $cur = New-Object System.Collections.ArrayList
    $x = $Margin
    foreach ($blk in $Blocks) {
        $need = if ($cur.Count) { $Gap + $blk.W } else { $blk.W }
        if ($cur.Count -and ($x + $need) -gt $Width) { [void]$rows.Add($cur.ToArray()); $cur.Clear(); $x = $Margin; $need = $blk.W }
        [void]$cur.Add($blk); $x += $need
    }
    if ($cur.Count) { [void]$rows.Add($cur.ToArray()) }
    for ($ri = 0; $ri -lt $rows.Count; $ri++) {
        $row = $rows[$ri]
        if ($ri -gt 0) { Write-Host '' }
        $hgt = 0
        foreach ($blk in $row) { $hgt = [Math]::Max($hgt, @($blk.Lines).Count) }
        for ($i = 0; $i -lt $hgt; $i++) {
            $line = ' ' * $Margin
            for ($j = 0; $j -lt $row.Count; $j++) {
                $blk = $row[$j]
                $cnt = @($blk.Lines).Count
                $off = if ($blk.Center) { [int][Math]::Floor(($hgt - $cnt) / 2) } else { 0 }
                $k = $i - $off
                $cell = if ($k -ge 0 -and $k -lt $cnt) { @($blk.Lines)[$k] } else { '' }
                if ($j -lt $row.Count - 1) { $line += (Format-GlowshPad $cell $blk.W) + (' ' * $Gap) } else { $line += $cell }
            }
            Write-Host $line.TrimEnd()
        }
    }
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
        try { Invoke-GlowshPromptHook $ok $code } catch {}
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
$global:__glowshErrTop = $null
if ($global:Error.Count -gt 0) { $global:__glowshErrTop = $global:Error[0] }

# Catatan lokal untuk glowsh wrapped: waktu, sukses/gagal, durasi, NAMA perintah saja (tanpa argumen)
function Add-GlowshStat([string]$Head, [bool]$Ok = $true, [long]$Ms = 0, $Time = $null) {
    if (-not $Head -or -not (Get-GlowshSetting 'stats' $true)) { return }
    if (-not $Time) { $Time = Get-Date }
    $row = @($Time.ToString('yyyy-MM-ddTHH:mm:ss'), [int]$Ok, $Ms, $Head) -join "`t"
    try { [IO.File]::AppendAllText((Join-Path $GlowshHome 'stats.log'), $row + "`n") } catch {}
}

function Invoke-GlowshPromptHook([bool]$Ok = $true, $ExitCode = $null) {
    $h = Get-History -Count 1
    # Error PowerShell terbaru (dibandingkan dengan yang terakhir kita lihat; $Error dibatasi 256 item)
    $newErr = $null
    if ($global:Error.Count -gt 0 -and -not [object]::ReferenceEquals($global:Error[0], $global:__glowshErrTop)) { $newErr = $global:Error[0] }
    if ($global:Error.Count -gt 0) { $global:__glowshErrTop = $global:Error[0] }
    if ($h -and $h.Id -ne $global:__glowshLastId) {
        $global:__glowshLastId = $h.Id
        $dur = $h.EndExecutionTime - $h.StartExecutionTime
        Add-GlowshStat (Get-GlowshCommandHead ([string]$h.CommandLine)) $Ok ([long]$dur.TotalMilliseconds) $h.StartExecutionTime
        # Simpan kegagalan terakhir untuk "glowsh why"
        if (-not $Ok) {
            $global:GlowshLastFailure = [pscustomobject]@{ Line = [string]$h.CommandLine; ExitCode = $ExitCode; Error = $newErr; Time = Get-Date }
        }
        if (Get-GlowshSetting 'notify' $true) {
            if ($dur.TotalSeconds -ge [double](Get-GlowshSetting 'notifySeconds' 30)) {
                $cmd = [string]$h.CommandLine
                if ($cmd.Length -gt 60) { $cmd = $cmd.Substring(0, 57) + '...' }
                $title = if ($Ok) { Get-GlowshText 'Perintah selesai' 'Command finished' } else { Get-GlowshText 'Perintah gagal' 'Command failed' }
                Send-GlowshToast $title "$cmd  ($(Format-GlowshDuration $dur))"
            }
        }
    }
    # Catat folder yang dikunjungi untuk panel "terakhir dibuka" & glowsh go
    if (Get-GlowshSetting 'recent' $true) {
        try {
            $loc = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
            if ($loc -and $loc -ne $global:__glowshLastDir) { $global:__glowshLastDir = $loc; Add-GlowshRecentDir $loc }
        } catch {}
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
    if ($args.Count -gt 0 -and $args[0] -in 'theme', 'wallpaper', 'import', 'browse', 'name', 'sync', 'auto', 'seasonal') { Initialize-GlowshPrompt }
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
            return @{ Kind = 'linux'; Message = (Get-GlowshText "'$Name' adalah perintah Linux. Padanannya di PowerShell:" "'$Name' is a Linux command. The PowerShell equivalent is:"); Display = $e.Show; Run = $e.Run }
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
        Kind = 'typo'
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
                    # Untuk wrapped: "berapa kali Glowsh menyelamatkan salah ketik kamu"
                    if ($s.Kind -eq 'typo') { Add-GlowshStat ('__typo:' + $Name.ToLower() + '>' + $s.Display.ToLower()) }
                    else { Add-GlowshStat ('__linux:' + $Name.ToLower()) }
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
    # Semua variabel sementara diawali "__gr" supaya mudah dibersihkan di akhir
    try {
        $__grNow = Get-Date
        $__grH = $__grNow.Hour
        $__grGreet = if ($__grH -ge 4 -and $__grH -lt 11) { Get-GlowshText 'Selamat pagi' 'Good morning' }
                     elseif ($__grH -ge 11 -and $__grH -lt 15) { Get-GlowshText 'Selamat siang' 'Good afternoon' }
                     elseif ($__grH -ge 15 -and $__grH -lt 18) { Get-GlowshText 'Selamat sore' 'Good afternoon' }
                     else { Get-GlowshText 'Selamat malam' 'Good evening' }
        $__grCulture = [Globalization.CultureInfo]::GetCultureInfo($(if ($GlowshLang -eq 'en') { 'en-US' } else { 'id-ID' }))

        # Warna dari tema aktif (ditulis glowsh saat ganti tema): aksen1;aksen2;redup;nama tema;merah;latar
        $__grAcc = @('#FF2E88', '#00F0FF', '#8A87B8', '', '#FF5F7E', '#101018')
        try {
            $__grF = @(([IO.File]::ReadAllText((Join-Path $GlowshHome 'accent.txt'))).Trim() -split ';')
            for ($__grI = 0; $__grI -lt [Math]::Min($__grF.Count, 6); $__grI++) { if ($__grF[$__grI] -or $__grI -eq 3) { $__grAcc[$__grI] = $__grF[$__grI] } }
        } catch {}
        $__grE = [char]27
        $__grPal = ConvertTo-GlowshPal $__grAcc[0] $__grAcc[1] $__grAcc[2] $__grAcc[4] $__grAcc[5]
        $__grP1 = $__grPal.P1; $__grP2 = $__grPal.P2
        $__grC1 = $__grPal.c1; $__grC2 = $__grPal.c2; $__grCm = $__grPal.cm
        # Ikon Nerd Font hanya di terminal modern (di jendela klasik jadi kotak)
        $__grIc = { param($code) if ($env:WT_SESSION -or $env:TERM_PROGRAM) { [string][char]$code + ' ' } else { '' } }

        $__grIcon = ''
        if ($env:WT_SESSION) { $__grIcon = [string][char]$(if ($__grH -ge 6 -and $__grH -lt 18) { 0xF185 } else { 0xF186 }) + ' ' }
        $__grName = [string](Get-GlowshSetting 'name' $env:USERNAME)
        if (-not $__grName.Trim()) { $__grName = $env:USERNAME }
        $__grLines = @("$__grE[1;38;2;${__grC1}m$__grIcon$__grGreet, $__grName!$__grE[0m")
        $__grLines += "$__grE[38;2;${__grCm}m$($__grNow.ToString('dddd, d MMMM yyyy', $__grCulture))$__grE[0m"
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $__grPs = [System.Windows.Forms.SystemInformation]::PowerStatus
            if ($__grPs.BatteryChargeStatus.ToString() -notmatch 'NoSystemBattery|Unknown') {
                $__grBat = (Get-GlowshText 'baterai ' 'battery ') + [int]($__grPs.BatteryLifePercent * 100) + '%'
                if ($__grPs.PowerLineStatus.ToString() -eq 'Online') { $__grBat += (Get-GlowshText ' (dicas)' ' (charging)') }
                $__grLines += "$__grE[38;2;${__grCm}m$__grBat$__grE[0m"
            }
        } catch {}
        if ($__grAcc[3]) { $__grLines += "$__grE[38;2;${__grCm}m" + (Get-GlowshText 'tema ' 'theme ') + "$__grE[38;2;${__grC2}m$($__grAcc[3])$__grE[0m" }
        $__grSeason = Get-GlowshSeason $__grNow
        $__grSeasonText = @{
            merdeka   = @('Dirgahayu Republik Indonesia! Merdeka!', 'Happy Indonesian Independence Day! Merdeka!')
            ramadan   = @('Selamat menunaikan ibadah puasa Ramadan.', 'Ramadan Kareem!')
            tahunbaru = @('Selamat Tahun Baru!', 'Happy New Year!')
        }
        if ($__grSeason -and (Get-GlowshSetting 'seasonal' $true)) {
            $__grLines += "$__grE[1;38;2;${__grC2}m" + (Get-GlowshText $__grSeasonText[$__grSeason][0] $__grSeasonText[$__grSeason][1]) + "$__grE[0m"
        }

        $__grWidth = 80
        try { $__grWidth = $Host.UI.RawUI.WindowSize.Width } catch {}
        Write-Host ''
        $__grLogo = $null
        if ((Get-GlowshSetting 'logo' $true) -and $__grWidth -ge 58) {
            # Logo GLOWSH dari huruf blok. Disimpan sebagai kode ASCII (file ini harus ASCII-only),
            # diubah ke karakter aslinya di sini: # = blok penuh, q w e z = sudut, v = garis tegak, = = garis datar
            $__grArt = @(
                ' ######q ##q      ######q ##q    ##q#######q##q  ##q',
                '##w====e ##v     ##w===##q##v    ##v##w====e##v  ##v',
                '##v  ###q##v     ##v   ##v##v #q ##v#######q#######v',
                '##v   ##v##v     ##v   ##v##v###q##vz====##v##w==##v',
                'z######we#######qz######wez###w###we#######v##v  ##v',
                ' z=====e z======e z=====e  z==ez==e z======ez=e  z=e'
            )
            $__grMap = @{ '#' = 0x2588; 'q' = 0x2557; 'w' = 0x2554; 'e' = 0x255D; 'z' = 0x255A; 'v' = 0x2551; '=' = 0x2550 }
            $__grLogo = foreach ($__grRow in $__grArt) {
                $__grSb = New-Object System.Text.StringBuilder
                for ($__grJ = 0; $__grJ -lt $__grRow.Length; $__grJ++) {
                    $__grCh = [string]$__grRow[$__grJ]
                    if ($__grCh -eq ' ') { [void]$__grSb.Append(' '); continue }
                    # gradasi warna dari kiri (aksen 1) ke kanan (aksen 2)
                    $__grT = $__grJ / ($__grRow.Length - 1)
                    $__grRgbNow = @(0, 1, 2 | ForEach-Object { [int]($__grP1[$_] + ($__grP2[$_] - $__grP1[$_]) * $__grT) }) -join ';'
                    [void]$__grSb.Append("$__grE[38;2;${__grRgbNow}m" + [string][char]$__grMap[$__grCh])
                }
                [void]$__grSb.Append("$__grE[0m")
                $__grSb.ToString()
            }
        }
        if ($__grWidth -ge 58) {
            # Blok-blok sapaan, disusun otomatis sesuai lebar jendela
            $__grBlocks = New-Object System.Collections.ArrayList
            if ($__grLogo) { [void]$__grBlocks.Add(@{ Lines = @($__grLogo); W = 52; Center = $false }) }
            $__grInfoW = 0; foreach ($__grL in $__grLines) { $__grInfoW = [Math]::Max($__grInfoW, (Get-GlowshVisibleLength $__grL)) }
            [void]$__grBlocks.Add(@{ Lines = @($__grLines); W = $__grInfoW; Center = $true })
            $__grPanels = @()
            if (Get-GlowshSetting 'sysinfo' $true) { try { $__grPanels += ,@(Get-GlowshSysPanel $__grPal (& $__grIc 0xF2DB)) } catch {} }
            $__grLoc = Get-GlowshSetting 'location' $null
            $__grAfterMaghrib = $false
            if ($__grLoc -and $null -ne $__grLoc.lat) {
                try {
                    $__grMg = (Get-GlowshPrayerTimes ([double]$__grLoc.lat) ([double]$__grLoc.lon) $__grNow | Where-Object { $_.Key -eq 'maghrib' }).Time
                    $__grAfterMaghrib = ($__grNow -ge $__grMg)
                } catch {}
            }
            if (Get-GlowshSetting 'sholat' $true) { try { $__grPanels += ,@(Get-GlowshPrayerPanel $__grPal $__grLoc (& $__grIc 0xF017) $__grNow) } catch {} }
            if (Get-GlowshSetting 'calendar' $true) {
                try {
                    $__grPanels += ,@(Get-GlowshCalendarPanel $__grPal $__grCulture (& $__grIc 0xF073) $__grNow ([bool](Get-GlowshSetting 'moon' $true)) ([int](Get-GlowshSetting 'hijriOffset' 0)) $__grAfterMaghrib)
                } catch {}
            }
            if (Get-GlowshSetting 'quote' $true) {
                try {
                    # mode "harian": quote sama sepanjang hari; mode "acak": ganti setiap kali terminal dibuka
                    $__grQ = Get-GlowshQuote (Get-GlowshQuoteKinds (Get-GlowshSetting 'quoteKinds' $null)) -Random:([string](Get-GlowshSetting 'quoteMode' 'harian') -eq 'acak')
                    $__grPanels += ,@(Get-GlowshQuotePanel $__grPal $__grQ (& $__grIc 0xF10D) 40)
                } catch {}
            }
            if (Get-GlowshSetting 'recent' $true) { try { $__grRp = Get-GlowshRecentPanel $__grPal (& $__grIc 0xF07C); if ($__grRp) { $__grPanels += ,@($__grRp) } } catch {} }
            foreach ($__grPn in $__grPanels) { [void]$__grBlocks.Add(@{ Lines = $__grPn; W = (Get-GlowshVisibleLength $__grPn[0]); Center = $false }) }
            Write-GlowshLayout $__grBlocks $__grWidth
        } else {
            # Versi ringkas (logo dimatikan atau jendela terlalu sempit)
            Write-Host ('  ' + $__grLines[0] + "$__grE[38;2;${__grCm}m   " + ((@($__grLines | Select-Object -Skip 1) | ForEach-Object { $_ -replace "$([char]27)\[[0-9;]*m", '' }) -join '  |  ') + "$__grE[0m")
        }
        $__grTips = @(
            @('ketik "glowsh theme" untuk ganti tema dengan preview', 'type "glowsh theme" to switch themes with a preview'),
            @('"glowsh wallpaper" membuat tema dari wallpaper kamu', '"glowsh wallpaper" builds a theme from your wallpaper'),
            @('"glowsh explain <perintah>" menjelaskan arti sebuah perintah', '"glowsh explain <command>" explains what a command does'),
            @('"glowsh auto on" membuat tema berganti mengikuti waktu', '"glowsh auto on" makes the theme follow the time of day'),
            @('"glowsh share" menghasilkan kode untuk berbagi tema', '"glowsh share" gives you a code to share your theme'),
            @('ada yang aneh? jalankan "glowsh doctor"', 'something looks off? run "glowsh doctor"'),
            @('tekan panah kanan untuk menerima saran perintah', 'press the right arrow to accept a command suggestion'),
            @('matikan sapaan ini dengan "glowsh greet off"', 'turn this greeting off with "glowsh greet off"'),
            @('"glowsh wrapped" menampilkan rekap tahunan terminal kamu', '"glowsh wrapped" shows your year in the terminal'),
            @('error? ketik "glowsh why" untuk penjelasan & solusinya', 'got an error? type "glowsh why" for an explanation & fix'),
            @('logo ini bisa dimatikan dengan "glowsh logo off"', 'turn this logo off with "glowsh logo off"'),
            @('"glowsh go 1" lompat ke folder yang terakhir kamu buka', '"glowsh go 1" jumps to the folder you opened last'),
            @('"glowsh quote agama" menampilkan quote dari kategori tertentu', '"glowsh quote faith" shows a quote from one category'),
            @('panel bisa dimatikan satu-satu: glowsh calendar off', 'turn panels off one by one: glowsh calendar off')
        )
        $__grTip = $__grTips[(Get-Random -Maximum $__grTips.Count)]
        Write-Host ''
        Write-Host ("  $__grE[38;2;${__grCm}mTip: " + (Get-GlowshText $__grTip[0] $__grTip[1]) + "$__grE[0m")
        Write-Host ''
    } catch {}
    Get-Variable -Name '__gr*' -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
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
    # GLOWSH_FROM_CMD memberi tahu glowsh.ps1 bahwa ia dipanggil dari CMD (misalnya "glowsh go" tidak bisa pindah folder CMD)
    $cmd = "@echo off`r`nsetlocal`r`nset GLOWSH_FROM_CMD=1`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\.glowsh\glowsh.ps1`" %*`r`nendlocal`r`n"
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
    $json = $GlowshPromptTemplate.Replace('__BG__', $Theme.Scheme.background).Replace('__A1__', $a.a1).Replace('__A2__', $a.a2).
        Replace('__A3__', $a.a3).Replace('__A4__', $a.a4).Replace('__OK__', $a.ok).Replace('__ERR__', $a.err).Replace('__MUTED__', $a.muted)
    return (Set-GlowshPromptName $json)
}

# Nama tampilan pilihan user (glowsh name); $null = pakai nama user Windows
function Get-GlowshDisplayName {
    $n = [string](Get-GlowshConfig).name
    if ([string]::IsNullOrWhiteSpace($n)) { return $null }
    return $n
}

# Ganti {{ .UserName }} di config prompt dengan nama pilihan user (kalau ada)
function Set-GlowshPromptName([string]$Json) {
    $name = Get-GlowshDisplayName
    if (-not $name) { return $Json }
    return $Json.Replace('{{ .UserName }}', $name).Replace('{{.UserName}}', $name)
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
            Write-Utf8NoBom $ThemeFile (Set-GlowshPromptName ([IO.File]::ReadAllText($cached)))
        } else { Write-Utf8NoBom $ThemeFile (New-SignaturePrompt $t) }
        Write-Utf8NoBom (Join-Path $GlowHome 'theme-lite.omp.json') (New-LitePrompt $t)
        Write-Ok "Prompt: $($t.Title)"
    } catch { Write-Bad "Prompt: $($_.Exception.Message)"; $fails++ }
    $fails += Update-WTSettings $t
    try { Set-ConsoleColors $t; Write-Ok (L 'Warna console klasik' 'Classic console colors') }
    catch { Write-Bad "Console: $($_.Exception.Message)"; $fails++ }
    Write-Utf8NoBom $StateFile $Id
    # Warna aksen untuk logo & sapaan di shell.ps1 (dibaca saat terminal dibuka, supaya startup tetap cepat)
    try {
        $acc = Get-ThemeAccents $t
        Write-Utf8NoBom (Join-Path $GlowHome 'accent.txt') (@($acc.a1, $acc.a2, $acc.muted, $t.Title, $acc.err, $t.Scheme.background) -join ';')
    } catch {}

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

# -Themes/-Heading/-Legend dipakai ulang oleh galeri komunitas (glowsh browse)
function Show-ThemePicker([string]$CurrentId = 'senja', $Themes = $null, [string]$Heading = '', [string]$Legend = '') {
    if (-not $Themes) { $Themes = $GlowshThemes }
    if (-not $Heading) { $Heading = L 'pilih tema' 'pick a theme' }
    if (-not $Legend) { $Legend = L '* khas Glowsh   ~ musiman   + buatanmu' '* Glowsh signature   ~ seasonal   + your own' }
    $ids = @($Themes.Keys)
    if ($ids.Count -eq 0) { return $null }
    $idx = [Math]::Max(0, [Array]::IndexOf($ids, $CurrentId))
    $interactive = $true
    try { if ([Console]::IsInputRedirected -or $Host.Name -ne 'ConsoleHost') { $interactive = $false } } catch { $interactive = $false }

    if (-not $interactive) {
        # Cadangan untuk host yang tidak mendukung tombol panah: menu bernomor
        for ($i = 0; $i -lt $ids.Count; $i++) {
            $t = $Themes[$ids[$i]]
            Write-Host ("    [{0}] {1} - {2}" -f ($i + 1), $t.Title, (Get-ThemeDesc $t))
        }
        $n = 0
        if ([int]::TryParse((Read-Host ('    ' + (L 'Nomor tema' 'Theme number'))), [ref]$n) -and $n -ge 1 -and $n -le $ids.Count) { return $ids[$n - 1] }
        return $null
    }

    Enable-VirtualTerminal
    $e = [char]27
    [Console]::Write("$e[?1049h$e[?25l")   # layar alternatif + sembunyikan kursor
    try {
        while ($true) {
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append("$e[H$e[2J")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("  $e[1;35mGlowsh$e[0m - " + $Heading)
            [void]$sb.AppendLine("  $e[90m" + (L '[atas/bawah] pilih   [Enter] pakai   [Esc] batal' '[up/down] move   [Enter] apply   [Esc] cancel') + "$e[0m")
            [void]$sb.AppendLine('')
            for ($i = 0; $i -lt $ids.Count; $i++) {
                $t = $Themes[$ids[$i]]
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
            [void]$sb.AppendLine("  $e[90m" + $Legend + "$e[0m")
            [void]$sb.AppendLine('')
            foreach ($l in (Get-ThemePreview $Themes[$ids[$idx]])) { [void]$sb.AppendLine($l) }
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

# ============================================================ glowsh wrapped (rekap tahunan)
function Get-GlowshPSReadLineHistoryPath {
    try { $p = (Get-PSReadLineOption -ErrorAction Stop).HistorySavePath; if ($p) { return $p } } catch {}
    return Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
}

function Get-GlowshPersona([int]$Hour) {
    if ($Hour -lt 5)  { return @('Kalong Begadang', 'Night Owl') }
    if ($Hour -lt 11) { return @('Si Paling Pagi', 'Early Bird') }
    if ($Hour -lt 15) { return @('Anak Siang', 'Midday Hacker') }
    if ($Hour -lt 19) { return @('Pejuang Sore', 'Golden Hour Coder') }
    return @('Anak Malam', 'Night Coder')
}

function Get-GlowshWrappedData([int]$Year) {
    $cmds = New-Object System.Collections.Generic.List[object]
    $typos = New-Object System.Collections.Generic.List[string]
    $linux = 0
    $file = Join-Path $GlowHome 'stats.log'
    if (Test-Path $file) {
        $inv = [Globalization.CultureInfo]::InvariantCulture
        foreach ($l in [IO.File]::ReadLines($file)) {
            $p = $l.Split("`t")
            if ($p.Count -lt 4) { continue }
            $ts = [datetime]::MinValue
            if (-not [datetime]::TryParseExact($p[0], 'yyyy-MM-ddTHH:mm:ss', $inv, [Globalization.DateTimeStyles]::None, [ref]$ts)) { continue }
            if ($ts.Year -ne $Year) { continue }
            if ($p[3].StartsWith('__typo:')) { $typos.Add($p[3].Substring(7)); continue }
            if ($p[3].StartsWith('__linux:')) { $linux++; continue }
            $ms = 0L; [void][long]::TryParse($p[2], [ref]$ms)
            $cmds.Add([pscustomobject]@{ T = $ts; Ok = ($p[1] -eq '1'); Ms = $ms; Head = $p[3] })
        }
    }
    $d = [ordered]@{ Year = $Year; Source = 'glowsh'; Total = $cmds.Count; Timed = $false }

    # Data Glowsh masih sedikit -> pakai riwayat PowerShell (tanpa waktu) untuk perintah favorit
    $heads = @($cmds | ForEach-Object { $_.Head })
    if ($cmds.Count -lt 30) {
        $hist = Get-GlowshPSReadLineHistoryPath
        if (Test-Path $hist) {
            $fromHist = @([IO.File]::ReadAllLines($hist) | ForEach-Object { Get-GlowshCommandHead $_ } | Where-Object { $_ })
            if ($fromHist.Count -gt $cmds.Count) { $heads = $fromHist; $d.Source = 'history'; $d.Total = $fromHist.Count }
        }
    }
    $firstWords = @($heads | ForEach-Object { ($_ -split ' ')[0] })
    $d.Unique = @($firstWords | Sort-Object -Unique).Count
    $d.Top = @($firstWords | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 |
        ForEach-Object { [pscustomobject]@{ Name = $_.Name; Count = $_.Count } })
    $sub = $heads | Where-Object { $_ -match ' ' } | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
    $d.TopSub = if ($sub) { [pscustomobject]@{ Name = $sub.Name; Count = $sub.Count } } else { $null }

    if ($d.Source -eq 'glowsh' -and $cmds.Count -gt 0) {
        $d.Timed = $true
        $d.Since = ($cmds | Sort-Object T | Select-Object -First 1).T
        $days = @($cmds | ForEach-Object { $_.T.Date } | Sort-Object -Unique)
        $d.ActiveDays = $days.Count
        $best = 1; $run = 1
        for ($i = 1; $i -lt $days.Count; $i++) {
            if (($days[$i] - $days[$i - 1]).TotalDays -eq 1) { $run++; if ($run -gt $best) { $best = $run } } else { $run = 1 }
        }
        $d.Streak = $best
        $d.Hour = [int](($cmds | Group-Object { $_.T.Hour } | Sort-Object Count -Descending | Select-Object -First 1).Name)
        $d.Weekday = [int](($cmds | Group-Object { [int]$_.T.DayOfWeek } | Sort-Object Count -Descending | Select-Object -First 1).Name)
        $d.Longest = $cmds | Sort-Object Ms -Descending | Select-Object -First 1
        $d.OkRate = [int][Math]::Round(100.0 * @($cmds | Where-Object { $_.Ok }).Count / $cmds.Count)
        $d.Persona = Get-GlowshPersona $d.Hour
    } else {
        $top1 = if ($d.Top.Count) { $d.Top[0].Name } else { '' }
        $d.Persona = switch -Regex ($top1) {
            '^git$'                          { @('Raja Commit', 'Commit Royalty') }
            '^(npm|npx|node|pnpm|yarn|bun)$' { @('Anak JavaScript', 'JS Wizard') }
            '^(python|py|pip)$'              { @('Pawang Python', 'Python Tamer') }
            '^(cd|ls|dir|gci)$'              { @('Penjelajah Folder', 'Folder Explorer') }
            default                          { @('Penjelajah Terminal', 'Terminal Explorer') }
        }
    }
    $d.TypoSaves = $typos.Count + $linux
    $tp = $typos | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
    $d.TopTypo = if ($tp) { $tp.Name -replace '>', ' -> ' } else { $null }
    return $d
}

function Show-GlowshWrapped($D, $Theme) {
    Enable-VirtualTerminal
    $e = [char]27
    $a = Get-ThemeAccents $Theme
    $fg = $Theme.Scheme.foreground
    $c = { param($hex) "$e[38;2;$(Get-Rgb $hex)m" }
    $r = "$e[0m"
    $block = [string][char]0x2588
    $culture = [Globalization.CultureInfo]::GetCultureInfo($(if ($GlowshLang -eq 'en') { 'en-US' } else { 'id-ID' }))
    $num = { param($n) ([int]$n).ToString('N0', $culture) }
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('')
    $out.Add("  $(& $c $a.a2)G L O W S H   W R A P P E D$r")
    $out.Add("  $e[1m$(& $c $a.a1)$($D.Year)$r")
    $out.Add('')
    $label = if ($D.Source -eq 'history') { L 'perintah di riwayat PowerShell kamu' 'commands in your PowerShell history' } else { L "perintah kamu jalankan tahun ini" "commands you ran this year" }
    $out.Add("  $e[1m$(& $c $fg)$(& $num $D.Total)$r $(& $c $a.muted)$label$r")
    $out.Add('')
    if ($D.Top.Count) {
        $out.Add("  $(& $c $a.a2)$(L 'Perintah favorit' 'Top commands')$r")
        $max = [double]$D.Top[0].Count
        $cols = @($a.a1, $a.a2, $a.a3, $a.a4, $a.ok)
        for ($i = 0; $i -lt $D.Top.Count; $i++) {
            $t = $D.Top[$i]
            $w = [Math]::Max(1, [int][Math]::Round(24 * $t.Count / $max))
            $out.Add(("  {0}. {1,-12} " -f ($i + 1), $t.Name) + "$(& $c $cols[$i])$($block * $w)$r $(& $c $a.muted)$(& $num $t.Count)x$r")
        }
        $out.Add('')
    }
    if ($D.TopSub) { $out.Add("  $(L 'Subperintah andalan' 'Go-to subcommand'): $(& $c $a.a1)$($D.TopSub.Name)$r $(& $c $a.muted)($(& $num $D.TopSub.Count)x)$r") }
    if ($D.Timed) {
        $day = $culture.DateTimeFormat.GetDayName([DayOfWeek]$D.Weekday)
        $out.Add("  $(L 'Streak terpanjang' 'Longest streak'): $(& $c $a.a1)$($D.Streak) $(L 'hari' 'days')$r   $(& $c $a.muted)($($D.ActiveDays) $(L 'hari aktif' 'active days'))$r")
        $out.Add("  $(L 'Jam paling produktif' 'Most productive hour'): $(& $c $a.a1)$('{0:D2}:00' -f $D.Hour)$r   $(& $c $a.muted)$(L 'hari favorit' 'favorite day'): $day$r")
        $out.Add("  $(L 'Perintah paling lama' 'Longest command'): $(& $c $a.a1)$($D.Longest.Head)$r $(& $c $a.muted)($(Format-GlowshDuration ([TimeSpan]::FromMilliseconds($D.Longest.Ms))))$r")
        $out.Add("  $(L 'Tingkat sukses' 'Success rate'): $(& $c $a.ok)$($D.OkRate)%$r")
    }
    $out.Add("  $(L 'Salah ketik diselamatkan Glowsh' 'Typos rescued by Glowsh'): $(& $c $a.a1)$($D.TypoSaves)x$r" + $(if ($D.TopTypo) { "   $(& $c $a.muted)$(L 'favorit' 'favorite'): $($D.TopTypo)$r" } else { '' }))
    $out.Add('')
    $out.Add("  $(L 'Kamu adalah' 'You are'): $e[1m$(& $c $a.a2)$(L $D.Persona[0] $D.Persona[1])$r")
    $out.Add('')
    if (-not $D.Timed) {
        $out.Add("  $(& $c $a.muted)$(L 'Statistik waktu (streak, jam favorit) mulai dicatat sekarang. Cek lagi akhir tahun!' 'Time stats (streak, favorite hour) start recording now. Check back at year end!')$r")
        $out.Add('')
    }
    foreach ($l in $out) { [Console]::WriteLine($l) }
}

function Save-GlowshWrappedImage($D, $Theme, [string]$Path) {
    Add-Type -AssemblyName System.Drawing
    $a = Get-ThemeAccents $Theme
    $col = { param($hex, $alpha = 255) [System.Drawing.Color]::FromArgb($alpha, [System.Drawing.ColorTranslator]::FromHtml($hex)) }
    $culture = [Globalization.CultureInfo]::GetCultureInfo($(if ($GlowshLang -eq 'en') { 'en-US' } else { 'id-ID' }))
    $W = 1080; $H = 1920
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear((& $col $Theme.Scheme.background))
    # cahaya lembut di latar
    foreach ($blob in @(@(-200, 80, 900, $a.a1), @(480, 1100, 900, $a.a2))) {
        # (nama variabel sengaja bukan $path: PowerShell tidak case-sensitive, jadi akan bentrok dengan parameter $Path)
        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gp.AddEllipse([single]$blob[0], [single]$blob[1], [single]$blob[2], [single]$blob[2])
        $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $gp
        $pg.CenterColor = & $col $blob[3] 90
        $pg.SurroundColors = [System.Drawing.Color[]]@((& $col $blob[3] 0))
        $g.FillPath($pg, $gp); $pg.Dispose(); $gp.Dispose()
    }
    $font = { param($size, $family = 'Segoe UI', $style = 'Bold') New-Object System.Drawing.Font($family, [single]$size, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel) }
    $text = { param($s, $f, $hex, $x, $y, $alpha = 255) $b = New-Object System.Drawing.SolidBrush((& $col $hex $alpha)); $g.DrawString([string]$s, $f, $b, [single]$x, [single]$y); $b.Dispose() }
    $rounded = { param($x, $y, $w, $h, $rad)
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddArc([single]$x, [single]$y, [single]($rad * 2), [single]($rad * 2), 180, 90)
        $p.AddArc([single]($x + $w - $rad * 2), [single]$y, [single]($rad * 2), [single]($rad * 2), 270, 90)
        $p.AddArc([single]($x + $w - $rad * 2), [single]($y + $h - $rad * 2), [single]($rad * 2), [single]($rad * 2), 0, 90)
        $p.AddArc([single]$x, [single]($y + $h - $rad * 2), [single]($rad * 2), [single]($rad * 2), 90, 90)
        $p.CloseFigure(); return $p }
    $fg = $Theme.Scheme.foreground

    & $text 'G L O W S H   W R A P P E D' (& $font 40 'Segoe UI' 'Bold') $a.a2 110 130
    & $text $D.Year (& $font 230 'Segoe UI Black' 'Regular') $a.a1 90 170
    & $text (([int]$D.Total).ToString('N0', $culture)) (& $font 150 'Segoe UI Black' 'Regular') $fg 100 470
    $label = if ($D.Source -eq 'history') { L 'perintah di riwayat PowerShell kamu' 'commands in your PowerShell history' } else { L 'perintah kamu jalankan tahun ini' 'commands you ran this year' }
    & $text $label (& $font 42 'Segoe UI' 'Regular') $fg 110 660 190

    & $text (L 'Perintah favorit' 'Top commands') (& $font 44 'Segoe UI' 'Bold') $a.a2 110 790
    $cols = @($a.a1, $a.a2, $a.a3, $a.a4, $a.ok)
    $max = if ($D.Top.Count) { [double]$D.Top[0].Count } else { 1 }
    $right = New-Object System.Drawing.StringFormat; $right.Alignment = [System.Drawing.StringAlignment]::Far
    for ($i = 0; $i -lt $D.Top.Count; $i++) {
        $y = 870 + $i * 96
        & $text ("{0}  {1}" -f ($i + 1), $D.Top[$i].Name) (& $font 44 'Consolas' 'Bold') $fg 110 $y
        $cb = New-Object System.Drawing.SolidBrush((& $col $fg 160))
        $g.DrawString((([int]$D.Top[$i].Count).ToString('N0', $culture) + 'x'), (& $font 40 'Segoe UI' 'Regular'), $cb, [single]970, [single]($y + 2), $right); $cb.Dispose()
        $bw = [Math]::Max(24, 860 * $D.Top[$i].Count / $max)
        $bp = & $rounded 110 ($y + 60) $bw 16 8
        $bb = New-Object System.Drawing.SolidBrush((& $col $cols[$i])); $g.FillPath($bb, $bp); $bb.Dispose(); $bp.Dispose()
    }

    $tiles = if ($D.Timed) {
        @(@((L 'Streak terpanjang' 'Longest streak'), "$($D.Streak) $(L 'hari' 'days')"),
          @((L 'Jam paling produktif' 'Peak hour'), ('{0:D2}:00' -f $D.Hour)),
          @((L 'Salah ketik diselamatkan' 'Typos rescued'), "$($D.TypoSaves)x"),
          @((L 'Tingkat sukses' 'Success rate'), "$($D.OkRate)%"))
    } else {
        @(@((L 'Perintah berbeda' 'Unique commands'), "$($D.Unique)"),
          @((L 'Subperintah andalan' 'Go-to subcommand'), $(if ($D.TopSub) { $D.TopSub.Name } else { '-' })),
          @((L 'Salah ketik diselamatkan' 'Typos rescued'), "$($D.TypoSaves)x"),
          @((L 'Tema' 'Theme'), $Theme.Title))
    }
    for ($i = 0; $i -lt 4; $i++) {
        $x = 110 + ($i % 2) * 440; $y = 1450 + [Math]::Floor($i / 2) * 195
        $tp = & $rounded $x $y 420 180 28
        $tb = New-Object System.Drawing.SolidBrush((& $col $fg 22)); $g.FillPath($tb, $tp); $tb.Dispose(); $tp.Dispose()
        & $text $tiles[$i][0] (& $font 30 'Segoe UI' 'Regular') $fg ($x + 30) ($y + 26) 190
        $vb = New-Object System.Drawing.SolidBrush((& $col $cols[$i]))
        $g.DrawString([string]$tiles[$i][1], (& $font 54 'Segoe UI' 'Bold'), $vb, (New-Object System.Drawing.RectangleF([single]($x + 30), [single]($y + 70), [single]370, [single]100))); $vb.Dispose()
    }

    $center = New-Object System.Drawing.StringFormat; $center.Alignment = [System.Drawing.StringAlignment]::Center
    $pb = New-Object System.Drawing.SolidBrush((& $col $a.a2))
    $g.DrawString(((L 'Kamu adalah ' 'You are ') + (L $D.Persona[0] $D.Persona[1])), (& $font 52 'Segoe UI' 'Bold'), $pb, (New-Object System.Drawing.RectangleF([single]0, [single]1352, [single]$W, [single]70)), $center); $pb.Dispose()
    $fb = New-Object System.Drawing.SolidBrush((& $col $fg 150))
    $g.DrawString('glowsh  |  github.com/SQverse/glowsh', (& $font 30 'Segoe UI' 'Regular'), $fb, (New-Object System.Drawing.RectangleF([single]0, [single]1846, [single]$W, [single]50)), $center); $fb.Dispose()

    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

# ============================================================ glowsh why (penjelasan error)
# P = pola error, X = pola untuk mengambil detail ({x}), T/E = judul & penjelasan, F = langkah perbaikan
$GlowshWhyRules = @(
    @{ P = 'Python was not found; run without arguments to install'
       T = @('Python belum terpasang', 'Python is not installed')
       E = @('Yang terpanggil adalah pintasan Microsoft Store, bukan Python sungguhan.', 'Windows ran the Microsoft Store shortcut, not a real Python.')
       F = @(@('Install Python: winget install Python.Python.3.12', 'Install Python: winget install Python.Python.3.12'),
             @('Lalu matikan pintasan Store: Settings > Apps > App execution aliases > python.exe', 'Then turn off the Store alias: Settings > Apps > App execution aliases > python.exe')) }
    @{ P = 'running scripts is disabled|cannot be loaded because running scripts|PSSecurityException'
       T = @('Script PowerShell diblokir', 'PowerShell scripts are blocked')
       E = @('Execution Policy di komputer ini melarang file .ps1 dijalankan.', 'This computer''s Execution Policy blocks .ps1 files.')
       F = @(@('Set-ExecutionPolicy -Scope CurrentUser RemoteSigned', 'Set-ExecutionPolicy -Scope CurrentUser RemoteSigned')) }
    @{ P = "is not recognized as (the name of a cmdlet|an internal or external command)|CommandNotFoundException"; X = "'([^']+)' is not recognized"
       T = @('Perintah tidak ditemukan', 'Command not found')
       E = @("Perintah '{x}' tidak dikenal: salah ketik, belum terpasang, atau belum masuk PATH.", "'{x}' is unknown: a typo, not installed, or not on PATH.")
       F = @(@('Cek ejaannya (Glowsh juga memberi saran saat salah ketik)', 'Check the spelling (Glowsh suggests fixes for typos)'),
             @('Cari & install: winget search {x}', 'Find & install it: winget search {x}'),
             @('Baru saja install? Buka tab terminal baru supaya PATH diperbarui', 'Just installed it? Open a new terminal tab so PATH refreshes')) }
    @{ P = 'EADDRINUSE|address already in use|Only one usage of each socket address|port \d+ is (already )?in use'; X = '(?::|port\s+)(\d{2,5})'
       T = @('Port sedang dipakai', 'Port already in use')
       E = @('Port {x} sudah dipakai program lain, biasanya server yang masih jalan di tab lain.', 'Port {x} is taken by another program, usually a server still running in another tab.')
       F = @(@('Cari pemakainya: Get-NetTCPConnection -LocalPort {x} | Select-Object OwningProcess', 'Find it: Get-NetTCPConnection -LocalPort {x} | Select-Object OwningProcess'),
             @('Hentikan: Stop-Process -Id <OwningProcess>', 'Stop it: Stop-Process -Id <OwningProcess>'),
             @('Atau jalankan di port lain', 'Or run on a different port')) }
    @{ P = 'being used by another process|EBUSY|resource busy'
       T = @('File sedang dipakai', 'File is in use')
       E = @('Ada program lain yang sedang membuka file/folder ini.', 'Another program has this file or folder open.')
       F = @(@('Tutup program yang memakainya (editor, explorer, server), lalu coba lagi', 'Close whatever is using it (editor, Explorer, a server), then retry')) }
    @{ P = 'Access (to the path .+ )?is denied|Permission denied(?! \(publickey)|UnauthorizedAccessException|EPERM|EACCES'
       T = @('Akses ditolak', 'Access denied')
       E = @('Kamu tidak punya izin untuk file/folder ini, atau butuh hak admin.', 'You lack permission for this file/folder, or it needs admin rights.')
       F = @(@('Pastikan kamu bekerja di folder milikmu (misalnya di Documents)', 'Make sure you work in your own folders (e.g. Documents)'),
             @('Kalau memang butuh admin: klik kanan Windows Terminal > Run as administrator', 'If it really needs admin: right-click Windows Terminal > Run as administrator')) }
    @{ P = 'Cannot find path|ENOENT|No such file or directory|cannot find the (path|file) specified|PathNotFound|ItemNotFoundException'; X = "Cannot find path '([^']+)'|ENOENT[^']*'([^']+)'"
       T = @('File atau folder tidak ditemukan', 'File or folder not found')
       E = @('Lokasi yang dituju tidak ada. Mungkin salah ketik atau kamu sedang di folder lain. {x}', 'That location does not exist. Maybe a typo, or you are in another folder. {x}')
       F = @(@('Cek posisi sekarang: pwd   lalu lihat isinya: ls', 'Check where you are: pwd   then list it: ls'),
             @('Tekan Tab saat mengetik nama file supaya dilengkapi otomatis', 'Press Tab while typing a name to autocomplete it')) }
    @{ P = "Cannot find module|MODULE_NOT_FOUND"; X = "Cannot find module '([^']+)'"
       T = @('Modul Node.js tidak ditemukan', 'Node.js module not found')
       E = @('Library {x} belum terpasang di proyek ini.', 'The library {x} is not installed in this project.')
       F = @(@('Install semua dependensi: npm install', 'Install all dependencies: npm install'),
             @('Atau install satu: npm install {x}', 'Or just that one: npm install {x}')) }
    @{ P = 'ModuleNotFoundError|No module named'; X = "No module named '?([\w.]+)'?"
       T = @('Modul Python tidak ditemukan', 'Python module not found')
       E = @('Library {x} belum terpasang untuk Python yang kamu pakai.', 'The library {x} is not installed for the Python you are using.')
       F = @(@('python -m pip install {x}', 'python -m pip install {x}'),
             @('Pakai virtual env? Aktifkan dulu: .\.venv\Scripts\Activate.ps1', 'Using a virtual env? Activate it first: .\.venv\Scripts\Activate.ps1')) }
    @{ P = 'ERESOLVE|unable to resolve dependency tree|peer dep'
       T = @('Versi dependensi npm bentrok', 'npm dependency conflict')
       E = @('Dua library butuh versi yang tidak cocok satu sama lain.', 'Two libraries require versions that do not fit together.')
       F = @(@('npm install --legacy-peer-deps', 'npm install --legacy-peer-deps')) }
    @{ P = 'not a git repository'
       T = @('Bukan folder git', 'Not a git repository')
       E = @('Folder ini belum dilacak git.', 'This folder is not tracked by git.')
       F = @(@('Pindah ke folder proyek: cd <folder-proyek>', 'Move to your project: cd <project-folder>'),
             @('Atau mulai git di sini: git init', 'Or start git here: git init')) }
    @{ P = 'Please tell me who you are|empty ident name|unable to auto-detect email'
       T = @('Identitas git belum diatur', 'Git identity not set')
       E = @('Git perlu nama & email untuk mencatat commit.', 'Git needs a name and email to record commits.')
       F = @(@('git config --global user.name "Nama Kamu"', 'git config --global user.name "Your Name"'),
             @('git config --global user.email "email@kamu.com"', 'git config --global user.email "you@example.com"')) }
    @{ P = 'would be overwritten by (merge|checkout)|Please commit your changes or stash them'
       T = @('Perubahan lokal akan tertimpa', 'Local changes would be overwritten')
       E = @('Ada perubahan yang belum di-commit, dan git tidak mau menimpanya.', 'You have uncommitted changes git refuses to overwrite.')
       F = @(@('Simpan sementara: git stash', 'Stash them: git stash'),
             @('Lanjutkan perintahmu, lalu kembalikan: git stash pop', 'Run your command, then restore: git stash pop')) }
    @{ P = 'CONFLICT \(|Automatic merge failed|Merge conflict'
       T = @('Merge conflict', 'Merge conflict')
       E = @('Dua versi mengubah baris yang sama, git butuh kamu memilih.', 'Two versions changed the same lines and git needs you to choose.')
       F = @(@('Buka file yang konflik, cari tanda <<<<<<< dan >>>>>>>, pilih isi yang benar', 'Open the conflicted files, find <<<<<<< and >>>>>>>, keep the right content'),
             @('Lalu: git add .   dan   git commit', 'Then: git add .   and   git commit')) }
    @{ P = '\[rejected\]|failed to push some refs|non-fast-forward|fetch first'
       T = @('Push ditolak', 'Push rejected')
       E = @('Di remote ada commit baru yang belum ada di laptop kamu.', 'The remote has new commits you do not have yet.')
       F = @(@('git pull --rebase', 'git pull --rebase'), @('Lalu: git push', 'Then: git push')) }
    @{ P = 'Authentication failed|Permission denied \(publickey\)|could not read Username|Invalid username or password|returned error: 403'
       T = @('Login git gagal', 'Git authentication failed')
       E = @('GitHub tidak menerima login kamu (password biasa sudah tidak bisa dipakai).', 'GitHub rejected your login (plain passwords no longer work).')
       F = @(@('Paling mudah pakai GitHub CLI: gh auth login', 'Easiest with GitHub CLI: gh auth login'),
             @('Atau pakai Personal Access Token sebagai password', 'Or use a Personal Access Token as the password')) }
    @{ P = 'ECONNREFUSED|Connection refused|actively refused'
       T = @('Koneksi ditolak', 'Connection refused')
       E = @('Tidak ada server yang mendengarkan di alamat/port itu.', 'Nothing is listening at that address/port.')
       F = @(@('Pastikan server/database sudah dijalankan', 'Make sure the server/database is running'),
             @('Cek alamat & port-nya sudah benar', 'Double-check the address and port')) }
    @{ P = 'ENOTFOUND|getaddrinfo|Could not resolve host|ETIMEDOUT|timed out|unable to connect|No such host'
       T = @('Masalah jaringan', 'Network problem')
       E = @('Server tidak bisa dihubungi: internet putus, DNS bermasalah, atau terhalang proxy/VPN.', 'The server is unreachable: no internet, DNS trouble, or a proxy/VPN in the way.')
       F = @(@('Cek internet: Test-Connection github.com -Count 2', 'Check the internet: Test-Connection github.com -Count 2'),
             @('Pakai WiFi kampus/kantor? Mungkin ada proxy', 'On campus/office WiFi? There may be a proxy')) }
    @{ P = 'certificate|SSL|self.signed'
       T = @('Masalah sertifikat SSL', 'SSL certificate problem')
       E = @('Koneksi aman gagal diverifikasi.', 'The secure connection could not be verified.')
       F = @(@('Cek tanggal & jam di laptop sudah benar', 'Check your date and time are correct'),
             @('Jaringan kampus/kantor sering memakai proxy: coba jaringan lain', 'Campus/office networks often use a proxy: try another network')) }
    @{ P = 'heap out of memory|JavaScript heap'
       T = @('Node.js kehabisan memori', 'Node.js ran out of memory')
       E = @('Proses butuh RAM lebih banyak dari batas bawaan Node.js.', 'The process needs more RAM than Node''s default limit.')
       F = @(@('$env:NODE_OPTIONS = "--max-old-space-size=4096"   lalu jalankan lagi', '$env:NODE_OPTIONS = "--max-old-space-size=4096"   then run it again')) }
    @{ P = 'ENOSPC|no space left|not enough space|disk is full'
       T = @('Disk penuh', 'Disk is full')
       E = @('Ruang penyimpanan habis.', 'You ran out of storage space.')
       F = @(@('Kosongkan ruang: hapus node_modules lama, Recycle Bin, atau jalankan Disk Cleanup', 'Free some space: old node_modules, Recycle Bin, or Disk Cleanup')) }
    @{ P = 'SyntaxError|Unexpected token|ParseException|IndentationError|ParserError'
       T = @('Kesalahan penulisan kode (syntax)', 'Syntax error')
       E = @('Ada kode yang penulisannya tidak valid.', 'Some code is not written validly.')
       F = @(@('Lihat nomor baris di pesan error', 'Look at the line number in the message'),
             @('Cek tanda kurung, kutip, koma, atau indentasi yang kurang/lebih', 'Check for missing or extra brackets, quotes, commas or indentation')) }
)

function Find-GlowshWhyRule([string]$Text) {
    foreach ($r in $GlowshWhyRules) { if ($Text -match "(?i)$($r.P)") { return $r } }
    return $null
}

function Show-GlowshWhy([string[]]$Words) {
    $text = $null; $cmdLine = $null; $source = ''
    if ($Words -and $Words.Count) { $text = $Words -join ' '; $source = 'arg' }
    $fail = $global:GlowshLastFailure
    if (-not $text -and $fail) {
        $cmdLine = $fail.Line
        if ($fail.Error) { $text = [string]$fail.Error.Exception.Message + "`n" + [string]$fail.Error.FullyQualifiedErrorId; $source = 'last' }
    }
    if (-not $text) {
        try {
            $clip = [string](Get-Clipboard -Raw)
            if ($clip -and $clip.Length -lt 20000 -and (Find-GlowshWhyRule $clip)) { $text = $clip; $source = 'clipboard' }
        } catch {}
    }
    Write-Host ''
    if (-not $text) {
        if ($fail) {
            Write-Host ('  ' + (L "Perintah '$($fail.Line)' gagal (exit code $($fail.ExitCode)), tapi pesan error-nya tidak tertangkap." "'$($fail.Line)' failed (exit code $($fail.ExitCode)), but its error message was not captured.")) -ForegroundColor Yellow
        } else {
            Write-Host ('  ' + (L 'Belum ada error yang bisa dijelaskan.' 'No error to explain yet.')) -ForegroundColor Yellow
        }
        Write-Host ('  ' + (L 'Seleksi pesan error di layar, tekan Ctrl+C, lalu jalankan: glowsh why' 'Select the error message on screen, press Ctrl+C, then run: glowsh why')) -ForegroundColor DarkGray
        Write-Host ('  ' + (L 'Atau tempel langsung: glowsh why "isi pesan error"' 'Or paste it directly: glowsh why "the error message"')) -ForegroundColor DarkGray
        Write-Host ''
        return
    }
    $rule = Find-GlowshWhyRule $text
    if ($cmdLine) { Write-Host ('  ' + (L 'Perintah: ' 'Command: ') + $cmdLine) -ForegroundColor DarkGray }
    if ($source -eq 'clipboard') { Write-Host ('  ' + (L '(membaca pesan error dari clipboard)' '(reading the error from your clipboard)')) -ForegroundColor DarkGray }
    if (-not $rule) {
        $first = (($text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
        Write-Host ('  ' + (L 'Glowsh belum kenal error ini:' 'Glowsh does not know this error yet:')) -ForegroundColor Yellow
        Write-Host "    $first"
        Write-Host ''
        Write-Host ('  ' + (L 'Coba cari kalimat pertamanya di Google / Stack Overflow, atau kirim ke kami:' 'Try searching its first line on Google / Stack Overflow, or send it to us:')) -ForegroundColor DarkGray
        Write-Host "    https://github.com/SQverse/glowsh/issues" -ForegroundColor DarkGray
        Write-Host ''
        return
    }
    $x = ''
    if ($rule.X -and $text -match "(?i)$($rule.X)") { $x = @($Matches[1], $Matches[2]) | Where-Object { $_ } | Select-Object -First 1 }
    $fill = { param($s) $s.Replace('{x}', [string]$x).Trim() }
    Write-Host ('  ' + (L $rule.T[0] $rule.T[1])) -ForegroundColor Magenta
    Write-Host ('  ' + (& $fill (L $rule.E[0] $rule.E[1])))
    Write-Host ''
    Write-Host ('  ' + (L 'Coba ini:' 'Try this:')) -ForegroundColor White
    $i = 1
    foreach ($f in $rule.F) { Write-Host ("    $i. " + (& $fill (L $f[0] $f[1]))) -ForegroundColor Cyan; $i++ }
    Write-Host ''
}

# ============================================================ galeri tema komunitas
$GlowshRepoWeb = 'https://github.com/SQverse/glowsh'

function Get-GlowshCommunityThemes {
    $data = Invoke-RestMethod -UseBasicParsing -Uri "$GlowshRepoRaw/themes/community.json?t=$([DateTime]::UtcNow.Ticks)"
    $list = [ordered]@{}
    foreach ($e in @($data.themes)) {
        try { $t = ConvertFrom-GlowshShareCode ([string]$e.code) } catch { continue }
        $name = [string]$e.name
        $t.Title = $name
        $t.Scheme.name = "Glowsh $name"
        $t.Desc = @("$([string]$e.desc_id)  - oleh $([string]$e.author)", "$([string]$e.desc_en)  - by $([string]$e.author)")
        $slug = ($name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
        if ($slug -and -not $list.Contains($slug)) { $list[$slug] = $t }
    }
    return $list
}

function Install-GlowshCustomTheme($Theme) {
    $slug = ($Theme.Title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
    if (-not $slug) { $slug = 'shared' }
    $id = $slug; $n = 2
    while ($GlowshThemes.Contains($id) -and -not $GlowshThemes[$id].Custom) { $id = "$slug-$n"; $n++ }
    $Theme.Custom = $true
    Save-GlowshCustomTheme $id $Theme
    $GlowshThemes[$id] = $Theme
    [void](Set-GlowshTheme $id -Explicit)
    return $id
}

function Submit-GlowshTheme([string]$Id) {
    $t = $GlowshThemes[$Id]
    $code = ConvertTo-GlowshShareCode $t
    $title = "Tema komunitas: $($t.Title)"
    $body = "**Nama tema / theme name:** $($t.Title)`n`n**Kode / code:**`n`n``````n$code`n```````n`n**Deskripsi / description:** (ceritakan nuansa temamu / describe its vibe)`n`n_Dikirim lewat / sent with: glowsh submit_"
    $url = "$GlowshRepoWeb/issues/new?title=$([uri]::EscapeDataString($title))&body=$([uri]::EscapeDataString($body))"
    Write-Host ''
    Write-Host ('  ' + (L "Mengirim tema '$($t.Title)' ke galeri komunitas Glowsh" "Submitting '$($t.Title)' to the Glowsh community gallery")) -ForegroundColor Magenta
    Write-Host ('  ' + (L 'Halaman GitHub akan terbuka dengan kode tema yang sudah terisi.' 'A GitHub page will open with your theme code filled in.'))
    Write-Host ('  ' + (L 'Tambahkan deskripsi singkat, lalu klik "Submit new issue". Kalau disetujui, temamu muncul di: glowsh browse' 'Add a short description, then click "Submit new issue". Once approved it shows up in: glowsh browse')) -ForegroundColor DarkGray
    Write-Host ''
    try { Start-Process $url } catch { Write-Host "  $url" }
}

# ============================================================ lokasi & jadwal sholat
# Kota-kota Indonesia (nama, lintang, bujur) supaya "glowsh lokasi <kota>" bekerja tanpa internet
$GlowshCities = [ordered]@{
    'jakarta' = @('Jakarta', -6.2088, 106.8456); 'bogor' = @('Bogor', -6.5971, 106.8060); 'depok' = @('Depok', -6.4025, 106.7942)
    'tangerang' = @('Tangerang', -6.1783, 106.6319); 'bekasi' = @('Bekasi', -6.2383, 106.9756); 'serang' = @('Serang', -6.1200, 106.1503)
    'bandung' = @('Bandung', -6.9175, 107.6191); 'cirebon' = @('Cirebon', -6.7063, 108.5570); 'tasikmalaya' = @('Tasikmalaya', -7.3274, 108.2207)
    'sukabumi' = @('Sukabumi', -6.9277, 106.9300); 'karawang' = @('Karawang', -6.3227, 107.3376); 'purwakarta' = @('Purwakarta', -6.5569, 107.4431)
    'garut' = @('Garut', -7.2279, 107.9087); 'semarang' = @('Semarang', -6.9667, 110.4167); 'yogyakarta' = @('Yogyakarta', -7.7956, 110.3695)
    'jogja' = @('Yogyakarta', -7.7956, 110.3695); 'solo' = @('Surakarta', -7.5755, 110.8243); 'surakarta' = @('Surakarta', -7.5755, 110.8243)
    'magelang' = @('Magelang', -7.4797, 110.2177); 'purwokerto' = @('Purwokerto', -7.4245, 109.2302); 'tegal' = @('Tegal', -6.8694, 109.1402)
    'pekalongan' = @('Pekalongan', -6.8886, 109.6753); 'kudus' = @('Kudus', -6.8048, 110.8405); 'surabaya' = @('Surabaya', -7.2575, 112.7521)
    'sidoarjo' = @('Sidoarjo', -7.4478, 112.7183); 'gresik' = @('Gresik', -7.1566, 112.6555); 'malang' = @('Malang', -7.9666, 112.6326)
    'kediri' = @('Kediri', -7.8480, 112.0178); 'madiun' = @('Madiun', -7.6298, 111.5239); 'jember' = @('Jember', -8.1845, 113.6681)
    'probolinggo' = @('Probolinggo', -7.7543, 113.2159); 'banyuwangi' = @('Banyuwangi', -8.2192, 114.3691); 'denpasar' = @('Denpasar', -8.6705, 115.2126)
    'mataram' = @('Mataram', -8.5833, 116.1167); 'kupang' = @('Kupang', -10.1772, 123.6070); 'banda aceh' = @('Banda Aceh', 5.5483, 95.3238)
    'lhokseumawe' = @('Lhokseumawe', 5.1801, 97.1507); 'medan' = @('Medan', 3.5952, 98.6722); 'pematangsiantar' = @('Pematangsiantar', 2.9595, 99.0687)
    'padang' = @('Padang', -0.9471, 100.4172); 'pekanbaru' = @('Pekanbaru', 0.5071, 101.4478); 'batam' = @('Batam', 1.0456, 104.0305)
    'tanjung pinang' = @('Tanjung Pinang', 0.9186, 104.4553); 'jambi' = @('Jambi', -1.6101, 103.6131); 'palembang' = @('Palembang', -2.9761, 104.7754)
    'bengkulu' = @('Bengkulu', -3.7928, 102.2608); 'bandar lampung' = @('Bandar Lampung', -5.3971, 105.2668); 'pangkal pinang' = @('Pangkal Pinang', -2.1291, 106.1090)
    'pontianak' = @('Pontianak', -0.0263, 109.3425); 'palangka raya' = @('Palangka Raya', -2.2136, 113.9108); 'banjarmasin' = @('Banjarmasin', -3.3186, 114.5944)
    'samarinda' = @('Samarinda', -0.5022, 117.1536); 'balikpapan' = @('Balikpapan', -1.2379, 116.8529); 'tarakan' = @('Tarakan', 3.3000, 117.6333)
    'makassar' = @('Makassar', -5.1477, 119.4327); 'manado' = @('Manado', 1.4748, 124.8421); 'palu' = @('Palu', -0.8999, 119.8707)
    'kendari' = @('Kendari', -3.9985, 122.5129); 'gorontalo' = @('Gorontalo', 0.5435, 123.0568); 'mamuju' = @('Mamuju', -2.6748, 118.8885)
    'ambon' = @('Ambon', -3.6954, 128.1814); 'ternate' = @('Ternate', 0.7893, 127.3778); 'jayapura' = @('Jayapura', -2.5337, 140.7181)
    'manokwari' = @('Manokwari', -0.8615, 134.0620); 'sorong' = @('Sorong', -0.8762, 131.2558); 'merauke' = @('Merauke', -8.4932, 140.4018)
}

function Find-GlowshCity([string]$Query) {
    $q = $Query.Trim().ToLower() -replace '^kota\s+', ''
    if ($GlowshCities.Contains($q)) { $c = $GlowshCities[$q] }
    else {
        $key = @($GlowshCities.Keys | Where-Object { $_ -like "$q*" -or $_.Replace(' ', '') -eq $q.Replace(' ', '') }) | Select-Object -First 1
        $c = if ($key) { $GlowshCities[$key] } else { $null }
    }
    if (-not $c) { return $null }
    return @{ Name = $c[0]; Lat = [double]$c[1]; Lon = [double]$c[2] }
}

function Get-GlowshThemePal {
    $th = $GlowshThemes[(Get-GlowshCurrentTheme)]
    $ac = Get-ThemeAccents $th
    return ConvertTo-GlowshPal $ac.a1 $ac.a2 $ac.muted $ac.err $th.Scheme.background
}

function Show-GlowshPrayerToday {
    $loc = Get-GlowshSettingValue 'location'
    $pal = Get-GlowshThemePal
    $now = Get-Date
    $ic = if ($env:WT_SESSION -or $env:TERM_PROGRAM) { [string][char]0xF017 + ' ' } else { '' }
    Enable-VirtualTerminal
    Write-Host ''
    foreach ($l in (Get-GlowshPrayerPanel $pal $loc $ic $now)) { Write-Host "  $l" }
    $after = $false
    if ($loc -and $null -ne $loc.lat) { $after = $now -ge ((Get-GlowshPrayerTimes ([double]$loc.lat) ([double]$loc.lon) $now) | Where-Object { $_.Key -eq 'maghrib' }).Time }
    $hOff = [int](Get-GlowshSettingValue 'hijriOffset')
    Write-Host ('  ' + (Get-GlowshHijriText ($now.Date.AddDays($hOff + $(if ($after) { 1 } else { 0 }))))) -ForegroundColor Cyan
    Write-Host ('  ' + (L 'Metode Kemenag RI (Subuh 20 derajat, Isya 18 derajat, ihtiyath 2 menit). Selisih 1-2 menit dengan jadwal resmi itu wajar.' 'Indonesian Ministry of Religious Affairs method (Fajr 20 deg, Isha 18 deg, 2-minute safety margin). A 1-2 minute difference from official tables is normal.')) -ForegroundColor DarkGray
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
        @('glowsh why',                'jelaskan error terakhir + solusinya',  'explain the last error + how to fix it'),
        @('glowsh wrapped [tahun]',    'rekap tahunan terminal kamu',          'your year in the terminal'),
        @('glowsh browse',             'galeri tema komunitas',                'community theme gallery'),
        @("glowsh submit [$nm]",       'kirim temamu ke galeri',               'share your theme with the gallery'),
        @('glowsh doctor',             'cek & perbaiki masalah tampilan',      'diagnose & fix display problems'),
        @('glowsh settings',           'lihat & ubah fitur (on/off)',          'view & toggle features'),
        @("glowsh name <$nm>",         'ganti nama di prompt & sapaan',        'set the name in your prompt & greeting'),
        @('glowsh quote [kategori]',   'quote acak: lucu, hidup, agama, diri', 'random quote: fun, life, faith, growth'),
        @('glowsh go [nomor|nama]',    'lompat ke folder yang baru dibuka',    'jump to a recently visited folder'),
        @('glowsh lokasi <kota>',      'atur lokasi untuk jadwal sholat',      'set your location for prayer times'),
        @('glowsh sholat',             'jadwal sholat hari ini',               'today''s prayer times'),
        @('glowsh hijri [+1|-1|0]',    'tanggal hijriah (+ koreksi)',          'Hijri date (+ correction)'),
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
    $qm = [string](Get-GlowshSettingValue 'quoteMode'); if (-not $qm) { $qm = 'harian' }
    Write-Host ('    {0,-10}{1,-7}{2}' -f 'quote mode', $qm, (L '(harian / acak): glowsh quote mode acak' '(daily / random): glowsh quote mode random'))
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
        'quote' {
            if ($arg1 -in 'on', 'off') { }   # biarkan ditangani pengaturan on/off di bawah
            elseif ($arg1 -eq 'mode') {
                $want = if ($Arguments.Count -gt 1) { $Arguments[1].ToLower() } else { '' }
                if ($want -in 'acak', 'random') { $want = 'acak' } elseif ($want -in 'harian', 'daily') { $want = 'harian' }
                else {
                    $cur = [string](Get-GlowshSettingValue 'quoteMode'); if (-not $cur) { $cur = 'harian' }
                    Write-Host ('  ' + (L 'Mode quote sekarang: ' 'Quote mode now: ') + $(if ($cur -eq 'acak') { L 'acak (ganti tiap terminal dibuka)' 'random (changes every new terminal)' } else { L 'harian (sama sepanjang hari)' 'daily (same all day)' }))
                    Write-Host ('  ' + (L 'Ubah: glowsh quote mode acak   atau   glowsh quote mode harian' 'Change: glowsh quote mode random   or   glowsh quote mode daily')) -ForegroundColor DarkGray
                    break
                }
                Set-GlowshConfigValue 'quoteMode' $want
                Write-Ok $(if ($want -eq 'acak') { L 'Quote akan berganti setiap kali terminal dibuka.' 'Quotes now change every time a terminal opens.' } else { L 'Quote akan sama sepanjang hari, berganti besok.' 'Quotes now stay the same all day and change tomorrow.' })
                Write-Host ('  ' + (L 'Berlaku di tab terminal baru.' 'Takes effect in new terminal tabs.')) -ForegroundColor DarkGray
                break
            }
            elseif ($arg1 -in 'kinds', 'kategori') {
                $sel = @((($Arguments | Select-Object -Skip 1) -join ',') -split '[,\s]+' | Where-Object { $_ } |
                    ForEach-Object { $k = $_.ToLower(); if ($GlowshQuoteAlias.ContainsKey($k)) { $GlowshQuoteAlias[$k] } else { $k } })
                if ($sel.Count -eq 0 -or $sel -contains 'all' -or $sel -contains 'semua') {
                    Set-GlowshConfigValue 'quoteKinds' $null
                    Write-Ok (L 'Quote dari semua kategori: lucu, hidup, agama, diri' 'Quotes from every category: fun, life, faith, growth')
                } else {
                    $valid = @($sel | Where-Object { $GlowshQuotes.Contains($_) } | Select-Object -Unique)
                    if ($valid.Count -eq 0) { Write-Bad (L 'Kategori yang ada: lucu, hidup, agama, diri' 'Available categories: fun, life, faith, growth'); break }
                    Set-GlowshConfigValue 'quoteKinds' $valid
                    Write-Ok ((L 'Quote harian hanya dari: ' 'Daily quotes only from: ') + (($valid | ForEach-Object { L $GlowshQuoteLabels[$_][0] $GlowshQuoteLabels[$_][1] }) -join ', '))
                }
                break
            } else {
                $kind = ''
                if ($arg1) {
                    $kind = $arg1.ToLower()
                    if ($GlowshQuoteAlias.ContainsKey($kind)) { $kind = $GlowshQuoteAlias[$kind] }
                    if (-not $GlowshQuotes.Contains($kind)) { Write-Bad (L 'Kategori yang ada: lucu, hidup, agama, diri' 'Available categories: fun, life, faith, growth'); break }
                }
                $kinds = if ($kind) { @($kind) } else { Get-GlowshQuoteKinds (Get-GlowshSettingValue 'quoteKinds') }
                $th = $GlowshThemes[(Get-GlowshCurrentTheme)]
                $ac = Get-ThemeAccents $th
                $pal = ConvertTo-GlowshPal $ac.a1 $ac.a2 $ac.muted $ac.err $th.Scheme.background
                $ic = if ($env:WT_SESSION -or $env:TERM_PROGRAM) { [string][char]0xF10D + ' ' } else { '' }
                Enable-VirtualTerminal
                Write-Host ''
                foreach ($l in (Get-GlowshQuotePanel $pal (Get-GlowshQuote $kinds -Random) $ic 46)) { Write-Host "  $l" }
                Write-Host ''
                Write-Host ('  ' + (L 'Lagi: glowsh quote   Kategori: glowsh quote lucu|hidup|agama|diri   Atur harian: glowsh quote kinds lucu,diri' 'Another: glowsh quote   Category: glowsh quote fun|life|faith|growth   Daily: glowsh quote kinds fun,growth')) -ForegroundColor DarkGray
                Write-Host ('  ' + (L 'Mode di sapaan: glowsh quote mode harian | acak' 'Greeting mode: glowsh quote mode daily | random')) -ForegroundColor DarkGray
                Write-Host ''
                break
            }
        }
        { $_ -in 'lokasi', 'location' } {
            if ($Arguments.Count -eq 0) {
                $loc = Get-GlowshSettingValue 'location'
                Write-Host ''
                if ($loc -and $null -ne $loc.lat) { Write-Host ('  ' + (L 'Lokasi: ' 'Location: ')) -NoNewline; Write-Host "$($loc.name)  ($($loc.lat), $($loc.lon))" -ForegroundColor Cyan }
                else { Write-Note (L 'Lokasi belum diatur.' 'No location set yet.') }
                Write-Host ('  ' + (L 'Atur: glowsh lokasi Bandung   atau koordinat: glowsh lokasi -6.91 107.61 Rumah   Hapus: glowsh lokasi reset' 'Set: glowsh lokasi Bandung   or coordinates: glowsh lokasi -6.91 107.61 Home   Remove: glowsh lokasi reset')) -ForegroundColor DarkGray
                Write-Host ''
                break
            }
            if ($Arguments.Count -eq 1 -and $arg1 -in 'reset', 'hapus') { Set-GlowshConfigValue 'location' $null; Write-Ok (L 'Lokasi dihapus.' 'Location removed.'); break }
            $inv = [Globalization.CultureInfo]::InvariantCulture
            $lat = 0.0; $lon = 0.0; $name = $null
            if ($Arguments.Count -ge 2 -and [double]::TryParse($Arguments[0], [Globalization.NumberStyles]::Float, $inv, [ref]$lat) -and [double]::TryParse($Arguments[1], [Globalization.NumberStyles]::Float, $inv, [ref]$lon)) {
                $name = if ($Arguments.Count -gt 2) { ($Arguments | Select-Object -Skip 2) -join ' ' } else { ('{0}, {1}' -f $lat, $lon) }
            } else {
                $query = $Arguments -join ' '
                $hit = Find-GlowshCity $query
                if ($hit) { $name = $hit.Name; $lat = $hit.Lat; $lon = $hit.Lon }
                else {
                    Write-Note (L "'$query' tidak ada di daftar kota bawaan. Mencari lewat open-meteo.com (hanya nama kotanya yang dikirim)..." "'$query' is not in the built-in city list. Looking it up on open-meteo.com (only the city name is sent)...")
                    $g = $null
                    try { $g = @((Invoke-RestMethod -UseBasicParsing "https://geocoding-api.open-meteo.com/v1/search?name=$([uri]::EscapeDataString($query))&count=1&language=id&format=json").results)[0] } catch {}
                    if (-not $g) { Write-Bad (L "Kota '$query' tidak ditemukan. Coba pakai koordinat: glowsh lokasi <lintang> <bujur> <nama>" "Could not find '$query'. Try coordinates: glowsh lokasi <lat> <lon> <name>"); break }
                    $name = [string]$g.name; $lat = [double]$g.latitude; $lon = [double]$g.longitude
                    if ($g.country) { Write-Host ('  ' + (L 'Ditemukan: ' 'Found: ') + "$name, $($g.admin1), $($g.country)") -ForegroundColor DarkGray }
                }
            }
            if ([Math]::Abs($lat) -gt 66 -or [Math]::Abs($lon) -gt 180) { Write-Bad (L 'Koordinat tidak valid (lintang maks. 66, bujur maks. 180).' 'Invalid coordinates (max latitude 66, max longitude 180).'); break }
            Set-GlowshConfigValue 'location' ([pscustomobject]@{ name = $name; lat = [Math]::Round($lat, 4); lon = [Math]::Round($lon, 4) })
            Write-Ok ((L 'Lokasi diatur: ' 'Location set: ') + $name)
            Show-GlowshPrayerToday
        }
        { $_ -in 'sholat', 'prayer' } {
            if ($arg1 -in 'on', 'off') { }   # biarkan ditangani pengaturan on/off di bawah
            else { Show-GlowshPrayerToday; break }
        }
        'hijri' {
            $tmp = 0
            if ($arg1 -match '^[+-]?\d$' -and [int]::TryParse($arg1.TrimStart('+'), [ref]$tmp) -and [Math]::Abs($tmp) -le 2) {
                Set-GlowshConfigValue 'hijriOffset' $tmp
                Write-Ok ((L 'Koreksi tanggal hijriah: ' 'Hijri date correction: ') + $tmp + (L ' hari' ' days'))
            } elseif ($arg1) { Write-Bad (L 'Pakai: glowsh hijri +1 / -1 / 0' 'Usage: glowsh hijri +1 / -1 / 0'); break }
            $hOff = [int](Get-GlowshSettingValue 'hijriOffset')
            Write-Host ''
            Write-Host ('  ' + (Get-GlowshHijriText ((Get-Date).Date.AddDays($hOff)))) -ForegroundColor Cyan
            Write-Host ('  ' + (L 'Dihitung dengan kalender Umm al-Qura. Kalau beda dengan penetapan di Indonesia, koreksi dengan: glowsh hijri +1 atau -1' 'Uses the Umm al-Qura calendar. If it differs from your local announcement, correct it with: glowsh hijri +1 or -1')) -ForegroundColor DarkGray
            Write-Host ''
        }
        'go' {
            $dirs = @(Get-GlowshRecentDirs 15)
            if ($dirs.Count -eq 0) { Write-Note (L 'Belum ada folder yang tercatat. Buka beberapa folder dulu dengan cd.' 'No folders recorded yet. Visit a few folders with cd first.'); break }
            if (-not $arg1) {
                Write-Host ''
                for ($i = 0; $i -lt $dirs.Count; $i++) {
                    $br = Get-GlowshGitBranch $dirs[$i]
                    Write-Host ('  {0,2}  ' -f ($i + 1)) -NoNewline -ForegroundColor Magenta
                    Write-Host (Get-GlowshShortPath $dirs[$i] 60) -NoNewline
                    if ($br) { Write-Host "  ($br)" -ForegroundColor Cyan } else { Write-Host '' }
                }
                Write-Host ''
                Write-Host ('  ' + (L 'Lompat: glowsh go <nomor>   atau   glowsh go <sebagian nama folder>' 'Jump: glowsh go <number>   or   glowsh go <part of the folder name>')) -ForegroundColor DarkGray
                Write-Host ''
                break
            }
            $target = $null; $n = 0
            if ([int]::TryParse($arg1, [ref]$n) -and $n -ge 1 -and $n -le $dirs.Count) { $target = $dirs[$n - 1] }
            else { $target = $dirs | Where-Object { (Split-Path $_ -Leaf) -like "*$arg1*" } | Select-Object -First 1 }
            if (-not $target) { $target = $dirs | Where-Object { $_ -like "*$arg1*" } | Select-Object -First 1 }
            if (-not $target) { Write-Bad (L "Tidak ada folder terakhir yang cocok dengan '$arg1'." "No recent folder matches '$arg1'."); break }
            if ($env:GLOWSH_FROM_CMD -eq '1') {
                Write-Host (L '  Di CMD, jalankan:' '  In CMD, run:') -ForegroundColor DarkGray
                Write-Host "  cd /d `"$target`"" -ForegroundColor Cyan
            } else {
                Set-Location -LiteralPath $target
                Write-Ok $target
            }
        }
        'name' {
            $current = Get-GlowshDisplayName
            if ($Arguments.Count -eq 0) {
                Write-Host ''
                Write-Host ('  ' + (L 'Nama sekarang: ' 'Current name: ')) -NoNewline
                Write-Host $(if ($current) { $current } else { "$env:USERNAME " + (L '(nama Windows)' '(Windows name)') }) -ForegroundColor Cyan
                Write-Host ('  ' + (L 'Ganti: glowsh name <nama baru>   Kembali ke nama Windows: glowsh name reset' 'Change: glowsh name <new name>   Back to the Windows name: glowsh name reset')) -ForegroundColor DarkGray
                Write-Host ''
                break
            }
            if ($arg1 -eq 'reset' -and $Arguments.Count -eq 1) {
                Set-GlowshConfigValue 'name' $null
                $shown = $env:USERNAME
            } else {
                # Buang karakter yang bisa merusak config prompt ({ } " \ `), batasi 24 karakter
                $new = (($Arguments -join ' ') -replace '[{}"\\`]', '').Trim()
                if ($new.Length -gt 24) { $new = $new.Substring(0, 24).Trim() }
                if (-not $new) { Write-Bad (L 'Nama tidak boleh kosong.' 'The name cannot be empty.'); break }
                Set-GlowshConfigValue 'name' $new
                $shown = $new
            }
            # Terapkan ulang tema yang aktif supaya prompt memakai nama baru
            [void](Set-GlowshTheme (Get-GlowshCurrentTheme) 6>$null)
            Write-Ok ((L 'Nama sekarang: ' 'Name is now: ') + $shown)
            Write-Host ('  ' + (L 'Prompt langsung berubah; sapaan berubah di tab baru.' 'The prompt updates now; the greeting updates in new tabs.')) -ForegroundColor DarkGray
        }
        'why' { Show-GlowshWhy $Arguments }
        'wrapped' {
            $yr = (Get-Date).Year; $tmp = 0
            if ([int]::TryParse($arg1, [ref]$tmp) -and $tmp -gt 2000) { $yr = $tmp }
            $data = Get-GlowshWrappedData $yr
            if ($data.Total -eq 0) {
                Write-Note (L "Belum ada data untuk $yr. Pakai terminal seperti biasa, Glowsh akan mencatatnya." "No data for $yr yet. Just use your terminal, Glowsh records it as you go.")
                break
            }
            $th = $GlowshThemes[(Get-GlowshCurrentTheme)]
            Show-GlowshWrapped $data $th
            if (Read-YesNo (L 'Simpan sebagai gambar untuk story IG?' 'Save it as an image for your IG story?')) {
                $png = Join-Path ([Environment]::GetFolderPath('Desktop')) "glowsh-wrapped-$yr.png"
                try {
                    Save-GlowshWrappedImage $data $th $png
                    Write-Ok ((L 'Tersimpan: ' 'Saved: ') + $png)
                    try { Start-Process $png } catch {}
                } catch { Write-Bad ((L 'Gagal membuat gambar: ' 'Could not create the image: ') + $_.Exception.Message) }
            }
        }
        'browse' {
            Write-Step (L 'Mengambil galeri tema komunitas...' 'Fetching the community theme gallery...')
            try { $community = Get-GlowshCommunityThemes } catch { Write-Bad ((L 'Galeri tidak bisa diambil: ' 'Could not fetch the gallery: ') + $_.Exception.Message); break }
            if ($community.Count -eq 0) { Write-Note (L 'Galeri masih kosong.' 'The gallery is empty.'); break }
            $pick = Show-ThemePicker '' $community (L 'galeri tema komunitas' 'community theme gallery') (L 'Punya tema keren? Kirim lewat: glowsh submit' 'Got a cool theme? Share it with: glowsh submit')
            if (-not $pick) { Write-Note (L 'Dibatalkan, tema tidak diubah.' 'Cancelled, theme unchanged.'); break }
            Write-Step ((L 'Memasang tema ' 'Installing theme ') + $community[$pick].Title)
            $newId = Install-GlowshCustomTheme $community[$pick]
            Write-Host ''
            Write-Host ('  ' + (L "Tema '$newId' terpasang! Ada di daftar: glowsh theme list" "Theme '$newId' installed! It is now in: glowsh theme list")) -ForegroundColor Green
            Write-Host ''
        }
        'submit' {
            $id = if ($arg1) { Resolve-GlowshThemeId $arg1 } else { Get-GlowshCurrentTheme }
            if (-not $id) { Write-Bad (L "Tema '$arg1' tidak ada." "Theme '$arg1' does not exist."); break }
            Submit-GlowshTheme $id
        }
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
