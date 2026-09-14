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
# Microsoft.PowerShell (7 系) は #Requires -Version 7 のスクリプトを手元で流すため。
foreach ($id in 'Git.Git', 'Microsoft.PowerShell') {
    winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -notin 0, -1978335189) {  # -1978335189 = 既に入っている
        throw "winget install $id failed: $LASTEXITCODE"
    }
}

# --- runner 用のアカウント -------------------------------------------------------
# runner はワークフローを書けるメンバー全員のコードを実行する。この VM は共有ドライブの
# 橋渡し (potsbo のセッションで Drive が動いている) も兼ねているので、そこから
# 切り離した非管理者のアカウントで動かす。Drive も Tailscale の認証も持たない。
#
# パスワードは apply のたびに作り直し、サービスの資格情報にだけ渡す。どこにも保存
# しないので、次の apply で知る必要が無いようにここで毎回更新する。
$runnerUser = 'runner'
$bytes = New-Object byte[] 24
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$runnerPassword = [Convert]::ToBase64String($bytes)
$securePassword = ConvertTo-SecureString $runnerPassword -AsPlainText -Force

if (-not (Get-LocalUser -Name $runnerUser -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $runnerUser -Password $securePassword -PasswordNeverExpires -AccountNeverExpires -Description 'GitHub Actions runner' | Out-Null
} else {
    Set-LocalUser -Name $runnerUser -Password $securePassword -PasswordNeverExpires $true
}
if (Get-LocalGroupMember -Group Administrators -Member $runnerUser -ErrorAction SilentlyContinue) {
    Remove-LocalGroupMember -Group Administrators -Member $runnerUser
}
# New-LocalUser はどのグループにも入れない。普通のユーザーと同じ扱いにする
if (-not (Get-LocalGroupMember -Group Users -Member $runnerUser -ErrorAction SilentlyContinue)) {
    Add-LocalGroupMember -Group Users -Member $runnerUser
}

# ログオン権限。既定では管理者などにしか無く、無いとタスク (バッチ) もサービスも
# "The user has not been granted the requested logon type" で起動できない。
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lsa {
    [StructLayout(LayoutKind.Sequential)] struct LSA_UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
    [StructLayout(LayoutKind.Sequential)] struct LSA_OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }
    [DllImport("advapi32.dll", SetLastError = true)] static extern uint LsaOpenPolicy(IntPtr systemName, ref LSA_OBJECT_ATTRIBUTES attributes, uint access, out IntPtr policy);
    [DllImport("advapi32.dll", SetLastError = true)] static extern uint LsaAddAccountRights(IntPtr policy, byte[] sid, LSA_UNICODE_STRING[] rights, uint count);
    [DllImport("advapi32.dll")] static extern uint LsaClose(IntPtr policy);
    [DllImport("advapi32.dll")] static extern int LsaNtStatusToWinError(uint status);
    public static void AddRight(System.Security.Principal.SecurityIdentifier sid, string right) {
        var attrs = new LSA_OBJECT_ATTRIBUTES();
        IntPtr policy;
        uint status = LsaOpenPolicy(IntPtr.Zero, ref attrs, 0x00000800 /* POLICY_CREATE_ACCOUNT */ | 0x00000010 /* POLICY_LOOKUP_NAMES */, out policy);
        if (status != 0) throw new System.ComponentModel.Win32Exception(LsaNtStatusToWinError(status));
        try {
            var bytes = new byte[sid.BinaryLength]; sid.GetBinaryForm(bytes, 0);
            var s = new LSA_UNICODE_STRING { Buffer = Marshal.StringToHGlobalUni(right), Length = (ushort)(right.Length * 2), MaximumLength = (ushort)((right.Length + 1) * 2) };
            try {
                status = LsaAddAccountRights(policy, bytes, new[] { s }, 1);
                if (status != 0) throw new System.ComponentModel.Win32Exception(LsaNtStatusToWinError(status));
            } finally { Marshal.FreeHGlobal(s.Buffer); }
        } finally { LsaClose(policy); }
    }
}
'@
function Grant-LogonRight([string]$sid, [string]$right) {
    [Lsa]::AddRight((New-Object System.Security.Principal.SecurityIdentifier $sid), $right)
}
$runnerSid = (Get-LocalUser -Name $runnerUser).SID.Value
Grant-LogonRight $runnerSid 'SeBatchLogonRight'
Grant-LogonRight $runnerSid 'SeServiceLogonRight'

# runner として実行する。Start-Process -Credential は ssh のセッション (対話的な
# ウィンドウステーションが無い) からだと "The parameter is incorrect" で使えないので、
# 1 回きりのタスクを runner の資格情報で登録して即実行する。プロファイルはここで
# 読み込まれる (初回は作られる)。
function Invoke-AsRunner([string]$script) {
    $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
    $taskName = 'setup-as-runner'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -EncodedCommand $enc"
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $taskName -Action $action -Settings $settings `
        -User $runnerUser -Password $runnerPassword -RunLevel Limited -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep 2
    while ((Get-ScheduledTask -TaskName $taskName).State -eq 'Running') { Start-Sleep 1 }
    $result = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    if ($result -ne 0) { throw "as $runnerUser failed: $result" }
}

# Excel を runner から COM で動かすための、そのユーザーの設定。
#   AccessVBOM: VBA プロジェクトへのアクセスを許可。ワークブックへ VBA を注入するのに要る
#   VBAWarnings=1: マクロを全部有効に。CI 用のアカウントなので絞らない
#   残りは初回起動のダイアログ (使用許諾、初回設定) を出さない。デスクトップが無いので
#   出たら誰も閉じられず、COM の呼び出しが固まる
Invoke-AsRunner @'
$ErrorActionPreference = 'Stop'
foreach ($e in @(
    @{ Path = 'HKCU:\Software\Microsoft\Office\16.0\Excel\Security'; Name = 'AccessVBOM'; Value = 1 },
    @{ Path = 'HKCU:\Software\Microsoft\Office\16.0\Excel\Security'; Name = 'VBAWarnings'; Value = 1 },
    @{ Path = 'HKCU:\Software\Microsoft\Office\16.0\Common\General'; Name = 'ShownFirstRunOptin'; Value = 1 },
    @{ Path = 'HKCU:\Software\Microsoft\Office\16.0\Registration'; Name = 'AcceptAllEulas'; Value = 1 }
)) {
    New-Item -Path $e.Path -Force | Out-Null
    Set-ItemProperty -Path $e.Path -Name $e.Name -Value $e.Value -Type DWord
}
'@

# --- GitHub Actions self-hosted runner ------------------------------------------
# 登録先とトークンは環境変数で受け取る。登録先はリポジトリの識別子なのでここには
# 書かない (公開リポジトリ)。トークンは 1 時間で失効する使い捨てで、GitHub の
# Settings → Actions → Runners → New self-hosted runner に出る。
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
# サービスは runner として動くので、作業ディレクトリごと書けるようにする
icacls $runnerDir /grant "${runnerUser}:(OI)(CI)M" /T /Q | Out-Null

# 以前はログオン セッションのタスクで起動していた。残っていれば消す
if (Get-ScheduledTask -TaskName 'actions-runner' -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName 'actions-runner' -Confirm:$false
}

if (-not (Test-Path "$runnerDir\.runner")) {
    if (-not $env:RUNNER_URL -or -not $env:RUNNER_TOKEN) {
        Write-Warning 'runner は未登録。RUNNER_URL と RUNNER_TOKEN を渡すと登録する'
    } else {
        # --runasservice が、サービスの作成と "サービスとしてログオン" 権限の付与までやる。
        # 資格情報の暗号化がこのアカウントに紐づくので、登録もサービスと同じアカウントで行う。
        # --replace: 同名の登録が残っていても上書きする (snapshot から戻したとき用)
        & "$runnerDir\config.cmd" --unattended --url $env:RUNNER_URL --token $env:RUNNER_TOKEN `
            --name raptorlake-win --labels excel --replace `
            --runasservice --windowslogonaccount ".\$runnerUser" --windowslogonpassword $runnerPassword
        if ($LASTEXITCODE -ne 0) { throw "runner config failed: $LASTEXITCODE" }
    }
}

# パスワードを更新したので、サービスにも新しいものを渡して起動し直す
$service = Get-Service -Name 'actions.runner.*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($service) {
    sc.exe config $service.Name obj= ".\$runnerUser" password= $runnerPassword | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "sc config failed: $LASTEXITCODE" }
    Restart-Service -Name $service.Name
    "runner service: " + (Get-Service -Name $service.Name).Status
}

'setup: ok'
