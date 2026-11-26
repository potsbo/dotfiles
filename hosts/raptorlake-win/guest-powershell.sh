# shellcheck shell=bash
# raptorlake-win の中で PowerShell を SYSTEM として流す。libvirt の guest agent を使うので
# libvirt ホスト (raptorlake) の上でしか使えない。apply と express-scan が source する。
# guest は libvirt の domain 名。呼ぶ側で決めていなければ raptorlake-win。
: "${guest:=raptorlake-win}"

# PowerShell の -EncodedCommand は UTF-16LE の base64
encode() { iconv -f utf-8 -t utf-16le "$1" | base64 -w0; }

# guest-exec は非同期で pid を返す。終了を待って出力を取り出す。JSON の組み立てと分解は jq。
# 出力はゲスト側で終了まで溜められ、終わってからまとめて出る。
guest_powershell() {
  local enc req pid status
  enc=$(encode "$1")
  req=$(jq -cn --arg enc "$enc" '{execute:"guest-exec",arguments:{path:"powershell.exe",arg:["-NoProfile","-NonInteractive","-EncodedCommand",$enc],"capture-output":true}}')
  pid=$(virsh -c qemu:///system qemu-agent-command "$guest" "$req" | jq '.return.pid')
  while :; do
    status=$(virsh -c qemu:///system qemu-agent-command "$guest" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}")
    if [ "$(jq '.return.exited' <<<"$status")" = true ]; then
      jq -r '.return["out-data"] // empty' <<<"$status" | base64 -d
      jq -r '.return["err-data"] // empty' <<<"$status" | base64 -d >&2
      return "$(jq '.return.exitcode' <<<"$status")"
    fi
    sleep 2
  done
}
