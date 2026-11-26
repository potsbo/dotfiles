# 最新の定義でのフルスキャンを、できる限り早く済ませる。express-scan が guest agent
# 経由で SYSTEM として流す。
#
# 1. 定義を更新する
# 2. スキャンする量を減らす: 消しても取り直せるもの ($disposable) を消す。消す前に
#    止める必要があるもの (Drive) は止め、最後に必ず起こし直す
# 3. スキャン自体を速くする: スキャン中の CPU 使用率の上限を外し、終わったら戻す
#
# 出力には定義の版、スキャンの時刻、段階ごとにかかった時間を出す。次にどこを削れば
# 速くなるかを判断するため。

$ErrorActionPreference = 'Stop'
# 出力は UTF-8 にする。既定はコードページ (cp932) で、Linux 側で化ける。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 進捗表示はコンソールが無いと CLIXML の塊として stderr に出る。要らない。
$ProgressPreference = 'SilentlyContinue'

# Drive を動かしているアカウント。プロファイルのフォルダ名はアカウント名と違う
$user = "$env:COMPUTERNAME\potsbo"
$userProfile = 'C:\Users\shimp'
$driveFS = "$userProfile\AppData\Local\Google\DriveFS"

# 消しても取り直せるもの。ここに無いものには触らない。
# - Process: 消す前に止めるプロセス。最後に起こし直す
#
# Windows Update のダウンロード済みファイル (SoftwareDistribution\Download) は入れていない。
# 消すには wuauserv を止める必要があり、更新の適用中に止めると適用が壊れうる。
# 量も 2 GB 程度で、スキャン時間への効きが小さい。
# ブラウザ (Chrome / Edge) のキャッシュも入れていない。プロファイル全体でも 2 GB に届かず
# (2026-11 時点)、Edge は常に動いていて消せない。
$disposable = @(
    @{
        # 共有ドライブはストリーミングなので、ここにあるのは読んだファイルの写し。
        # 次に読んだときに取り直される。100 GB を超えて溜まり、スキャン量の大半を占める。
        # Drive を止めるのは消すためと、マウント先 ($userProfile\gdrive) が C: の中にあり、
        # 動いたままだとスキャンが共有ドライブの中身を読みに行くため。
        Name = 'Drive のキャッシュ'; Process = 'GoogleDriveFS'
        Paths = "$driveFS\*\content_cache", "$driveFS\*\thumbnails_cache"
    }
    @{
        # 使用中のファイルは消せずに残るが、それでよい
        Name = 'Temp'; Process = $null
        Paths = "$userProfile\AppData\Local\Temp\*", 'C:\Windows\Temp\*'
    }
)

$timings = [ordered]@{}
function Log($msg) { Write-Output ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $msg) }
function Step($name, [scriptblock]$body) {
    Log $name
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { & $body } finally { $timings[$name] = $sw.Elapsed }
}

function Get-DriveExe {
    $running = Get-Process GoogleDriveFS -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($running) { return $running.Path }
    # 止まっているときは、版ごとのフォルダのうち最も新しいものを使う
    Get-ChildItem 'C:\Program Files\Google\Drive File Stream\*\GoogleDriveFS.exe' |
        Sort-Object { [version]$_.Directory.Name } | Select-Object -Last 1 -ExpandProperty FullName
}

# SYSTEM から直接起動すると、ログオン中の potsbo ではなく SYSTEM のセッションで動いてしまう。
# Interactive のタスクを作って流し、すぐ消す。
function Start-AsUser($exe, $process) {
    $name = 'express-scan-restart'
    $action = New-ScheduledTaskAction -Execute $exe
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive
    Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Force | Out-Null
    try {
        Start-ScheduledTask -TaskName $name
        for ($i = 0; $i -lt 30 -and -not (Get-Process $process -ErrorAction SilentlyContinue); $i++) { Start-Sleep 2 }
    } finally {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
    }
    if (-not (Get-Process $process -ErrorAction SilentlyContinue)) {
        throw "$process が起動しない。$user がログオンしているか確かめる"
    }
}

$driveExe = Get-DriveExe
$stopped = @()
$cpuFactor = (Get-MpPreference).ScanAvgCPULoadFactor

try {
    Step '定義を更新する' { Update-MpSignature }

    Step 'スキャンする量を減らす' {
        foreach ($d in $disposable) {
            if ($d.Process -and (Get-Process $d.Process -ErrorAction SilentlyContinue)) {
                Get-Process $d.Process | Stop-Process -Force
                for ($i = 0; $i -lt 30 -and (Get-Process $d.Process -ErrorAction SilentlyContinue); $i++) { Start-Sleep 2 }
                if (Get-Process $d.Process -ErrorAction SilentlyContinue) { throw "$($d.Process) が止まらない" }
                $script:stopped += $d.Process
            }
            $items = @(Get-Item $d.Paths -Force -ErrorAction SilentlyContinue)
            $bytes = ($items | ForEach-Object {
                if ($_.PSIsContainer) { Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue } else { $_ }
            } | Measure-Object Length -Sum).Sum
            $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Log ("  {0}: {1:N1} GB を消した" -f $d.Name, ($bytes / 1GB))
        }
    }

    Step 'フルスキャンを流す' {
        # 0 で CPU 使用率の上限を外す
        Set-MpPreference -ScanAvgCPULoadFactor 0
        try { Start-MpScan -ScanType FullScan } finally { Set-MpPreference -ScanAvgCPULoadFactor $cpuFactor }
    }
} finally {
    if ($stopped -contains 'GoogleDriveFS') { Step 'Drive を起こし直す' { Start-AsUser $driveExe 'GoogleDriveFS' } }
}

$s = Get-MpComputerStatus
Log ("定義: {0} ({1:yyyy-MM-dd HH:mm} 更新)" -f $s.AntivirusSignatureVersion, $s.AntivirusSignatureLastUpdated)
Log ("フルスキャン: {0:yyyy-MM-dd HH:mm} - {1:HH:mm}" -f $s.FullScanStartTime, $s.FullScanEndTime)
foreach ($k in $timings.Keys) { Log ("  {0}: {1:hh\:mm\:ss}" -f $k, $timings[$k]) }
$threats = @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object { $_.InitialDetectionTime -ge $s.FullScanStartTime })
if ($threats.Count -gt 0) {
    $threats | Format-List | Out-String -Width 200
    throw "スキャンで $($threats.Count) 件検出した"
}
Log '検出なし'
