# raptorlake-win の、ssh が通ったあとの設定。apply が ssh 越しに potsbo として流す。
# 何度流しても同じ状態に収束する。
#
# 入れるのは Excel を使う CI (GitHub Actions の self-hosted runner) に要るものだけ。
# 開発ツールは runner がワークフローの中で入れる (aqua) ので、ここでは持たない。
# 唯一の例外が git で、runner が checkout に使う。

$ErrorActionPreference = 'Stop'
# 出力は UTF-8 にする。既定はコードページ (cp932) で、Linux 側で化ける。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 進捗表示はコンソールが無いと CLIXML の塊として stderr に出る。要らない。
$ProgressPreference = 'SilentlyContinue'

# --- パッケージ (winget) --------------------------------------------------------
# winget は入っていれば no-op で返るので、そのまま冪等になる。
# Microsoft.PowerShell (7 系) は anonymizer/tests/adodb_charset_check.ps1 のような
# #Requires -Version 7 のスクリプトを手元で流すため。5.1 しか無いと動かない。
foreach ($id in 'Git.Git', 'Microsoft.PowerShell') {
    winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -notin 0, -1978335189) {  # -1978335189 = 既に入っている
        throw "winget install $id failed: $LASTEXITCODE"
    }
}

# --- GitHub Actions self-hosted runner ------------------------------------------
# Excel の COM 自動化は対話セッションでしか安定しないので、runner を service ではなく
# ログオン中のユーザーのセッションで動かす。自動ログオンは Sysinternals Autologon で
# 済ませてある (hosts/raptorlake/README.md)。
#
# 登録先とトークンは環境変数で受け取る。登録先はリポジトリの識別子なのでここには
# 書かない (公開リポジトリ)。トークンは 1 時間で失効する使い捨てで、GitHub の
# Settings → Actions → Runners → New self-hosted runner に出るもの。
# 一度登録すれば .runner が残るので、以後は無くてよい。
$runnerVersion = '2.337.0'
$runnerDir = 'C:\actions-runner'

if (-not (Test-Path "$runnerDir\run.cmd")) {
    New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
    $zip = "$env:TEMP\actions-runner-win-x64-$runnerVersion.zip"
    Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $runnerDir -Force
    Remove-Item $zip
}

if (-not (Test-Path "$runnerDir\.runner")) {
    if (-not $env:RUNNER_URL -or -not $env:RUNNER_TOKEN) {
        Write-Warning 'runner は未登録。RUNNER_URL と RUNNER_TOKEN を渡すと登録する'
    } else {
        # --replace: 同名の登録が残っていても上書きする (VM を作り直したとき用)
        & "$runnerDir\config.cmd" --unattended --url $env:RUNNER_URL --token $env:RUNNER_TOKEN --name raptorlake-win --labels excel --replace
        if ($LASTEXITCODE -ne 0) { throw "runner config failed: $LASTEXITCODE" }
    }
}

# ログオン時に、そのユーザーのセッションで run.cmd を起動する。LogonType Interactive が
# 「ユーザーがログオンしているときのみ実行」で、パスワードを持たずに登録できる。
$taskName = 'actions-runner'
$action = New-ScheduledTaskAction -Execute "$runnerDir\run.cmd" -WorkingDirectory $runnerDir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
# ExecutionTimeLimit 0 = 無期限。既定の 3 日で runner が殺される。
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

if ((Test-Path "$runnerDir\.runner") -and (Get-ScheduledTask -TaskName $taskName).State -ne 'Running') {
    Start-ScheduledTask -TaskName $taskName
}

'setup: ok'
