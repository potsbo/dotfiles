# raptorlake-win (Windows 11 ゲスト) に ssh を通すところまで。ここより先は setup.ps1 が
# ssh 越しにやる。ssh が無い状態で流すので、ホストから libvirt の guest agent 経由で
# SYSTEM として実行される (apply がそうする)。何度流しても同じ状態に収束する。
#
# 鍵は GitHub から引き、静的な authorized_keys は置かない。理由は NixOS 側の
# modules/nixos/sshd.nix のコメントと同じ (失効の反映速度を可用性より優先)。
# %u は使わず GitHub のユーザー名を固定し、AllowUsers で Windows 側のアカウントも
# 1 つに絞る。このゲストには RDP / SMB 用のローカルアカウントが他にもあり、%u だと
# それらの名前と同名の GitHub ユーザーの鍵で入れてしまう。

$ErrorActionPreference = 'Stop'
# 出力は UTF-8 にする。既定はコードページ (cp932) で、Linux 側で化ける。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 進捗表示はコンソールが無いと CLIXML の塊として stderr に出る。要らない。
$ProgressPreference = 'SilentlyContinue'

$capability = 'OpenSSH.Server~~~~0.0.1.0'
if ((Get-WindowsCapability -Online -Name $capability).State -ne 'Installed') {
    Add-WindowsCapability -Online -Name $capability | Out-Null
}

# 既定のシェルは cmd。ssh 越しに流すのは PowerShell なので、そちらを既定にする。
$shellKey = 'HKLM:\SOFTWARE\OpenSSH'
New-Item -Path $shellKey -Force | Out-Null
Set-ItemProperty -Path $shellKey -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Type String

$sshDir = 'C:\ProgramData\ssh'
New-Item -ItemType Directory -Path $sshDir -Force | Out-Null

# 鍵を GitHub から引くコマンド。powershell.exe を直接指定すると sshd が
# 「所有者が TrustedInstaller で ACL が too open」として実行を拒むので、
# こちらが所有するラッパーを置き、ACL を SYSTEM と Administrators だけに絞る。
$keysCommand = "$sshDir\gh-authorized-keys.cmd"
$keysScript = @'
@echo off
powershell.exe -NoProfile -NonInteractive -Command "(Invoke-RestMethod -TimeoutSec 10 https://github.com/potsbo.keys)"
'@
if (-not (Test-Path $keysCommand) -or (Get-Content $keysCommand -Raw) -ne $keysScript) {
    Set-Content -Path $keysCommand -Value $keysScript -Encoding ascii -NoNewline
}
$acl = Get-Acl $keysCommand
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
foreach ($who in 'NT AUTHORITY\SYSTEM', 'BUILTIN\Administrators') {
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($who, 'FullControl', 'Allow')))
}
$acl.SetOwner([System.Security.Principal.NTAccount]'BUILTIN\Administrators')
Set-Acl -Path $keysCommand -AclObject $acl

# sshd_config はファイルごとこちらが持つ。差分で編集すると「何が効いているか」が
# ファイルを読んでも分からなくなる。
# AuthorizedKeysCommandUser には Windows のアカウントとして解決できる名前が要る。
# sshd はこのアカウントを基準にコマンドのファイルの所有者と ACL を検査していて、
# 解決できない名前 (慣例の sshd など) だと検査が常に落ちて "too open" になる。
$sshdConfig = @"
AllowUsers potsbo

PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no

AuthorizedKeysCommand $keysCommand
AuthorizedKeysCommandUser potsbo

Subsystem sftp sftp-server.exe
"@
$configPath = "$sshDir\sshd_config"
$current = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { '' }
$changed = $current -ne $sshdConfig
if ($changed) {
    Set-Content -Path $configPath -Value $sshdConfig -Encoding ascii -NoNewline
}

Set-Service -Name sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne 'Running') {
    Start-Service sshd
} elseif ($changed) {
    Restart-Service sshd
}

# 受信規則は Add-WindowsCapability が作る。無ければ作り、あれば有効にするだけ。
# スコープは絞らない。認証は GitHub の鍵だけなので、SMB (パスワード) と違って
# tailnet の他の端末から見えても入れない。
$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $rule) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null
} elseif (-not $rule.Enabled) {
    Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'
}

'bootstrap: ok'
