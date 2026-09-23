# raptorlake-win の、ssh が通ったあとの設定。apply が ssh 越しに potsbo として流す。
# 何度流しても同じ状態に収束する。
#
# 目的は「Excel の入った Windows で、手元の変更を ssh 越しにテストできる」状態を保つこと。
# CI (self-hosted runner) にはしない。runner はリポジトリに書ける人全員のコードをこの
# VM で実行する口になり、この VM は共有ドライブの橋渡しも兼ねているので、常設の口を
# 開けておく理由が無い。テストは本人が ssh で入って回す。

$ErrorActionPreference = 'Stop'
# 出力は UTF-8 にする。既定はコードページ (cp932) で、Linux 側で化ける。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 進捗表示はコンソールが無いと CLIXML の塊として stderr に出る。要らない。
$ProgressPreference = 'SilentlyContinue'

# --- パッケージ ------------------------------------------------------------------
# winget は入っていれば no-op で返るので、そのまま冪等になる。
# --source winget で固定する。ソースを指定しないと Store 版 (MSIX) が選ばれることがある。
#   Git.Git      リポジトリを clone / pull するため
#   astral-sh.uv Python のテスト (pytest + xlwings) を `uv run pytest` で回すため
foreach ($id in 'Git.Git', 'astral-sh.uv') {
    winget install --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -notin 0, -1978335189) {  # -1978335189 = 既に入っている
        throw "winget install $id failed: $LASTEXITCODE"
    }
}

# PowerShell 7。#Requires -Version 7 のスクリプト (ADODB のプローブなど) を手元で流すため。
# winget の Microsoft.PowerShell は MSIX (インストールしたユーザーにしか見えない) を選ぶ
# ことがあるので、MSI を版を固定して直接入れる。Program Files に入り、machine の PATH にも載る
$pwshVersion = '7.6.6'
if (-not (Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe')) {
    $msi = "$env:TEMP\PowerShell-$pwshVersion-win-x64.msi"
    Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v$pwshVersion/PowerShell-$pwshVersion-win-x64.msi" -OutFile $msi
    $p = Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart ADD_PATH=1" -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "PowerShell msi failed: $($p.ExitCode)" }
    Remove-Item $msi
}

# --- Excel を COM から動かすための設定 (このユーザーの HKCU) ------------------------
# AccessVBOM: VBA プロジェクトへのアクセスを許可。テストがワークブックに VBA を注入するのに要る。
# 無いと全件が「プログラミングによる Visual Basic プロジェクトへのアクセスは信頼性に欠けます」で落ちる。
# Excel は終了時にこの設定をレジストリへ書き戻すので、手で開いた Excel が値を戻すことがある。
# そのため apply のたびに書き直す。
$security = 'HKCU:\Software\Microsoft\Office\16.0\Excel\Security'
New-Item -Path $security -Force | Out-Null
Set-ItemProperty -Path $security -Name AccessVBOM -Value 1 -Type DWord

'setup: ok'
