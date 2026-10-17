//! 送る側・受け取る側で走る sh script。どれも先頭に [`PRELUDE`] を付けて走らせる。

/// $CASCP_STDERR_TTY は手元の stderr が端末のときだけ付く (machine.rs)。desync は自分の
/// stderr (リモートでは ssh のパイプ) しか見ないので、進捗バーを出すかはここで伝える。
pub const PRELUDE: &str = r#"store=${XDG_CACHE_HOME:-$HOME/.cache}/desync
mkdir -p "$store" || exit 1
[ -n "${CASCP_STDERR_TTY-}" ] && export DESYNC_PROGRESSBAR_ENABLED=1
"#;

/// 送る側: $1 の種類などを 1 行ずつ返す。
pub const INSPECT: &str = r#"
if [ -d "$1" ]; then
  kind=dir size=$(($(du -sk "$1" | cut -f1) * 1024)) n=$(find "$1" -type f | wc -l)
elif [ -f "$1" ]; then
  kind=file size=$(wc -c <"$1") n=1
else
  echo "cascp: $1: No such file or directory" >&2
  exit 1
fi
mode=$(stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1")
printf '%s\n' "$store" $kind $mode $size $n
"#;

/// 受け取る側: scp と同じく、既存ディレクトリが指定されたらその中に $2 の名前で置く。
pub const PREPARE: &str = r#"
if [ -d "$1" ]; then dst="${1%/}/$2"; else dst=$1; fi
printf '%s\n' "$store" "$dst"
"#;

/// 送る側: chunk に切って store に入れ、index を stdout に出す。
pub const CHUNK: &str = r#"
case $1 in
  dir) exec desync tar -i -s "$store" - "$2" ;;
  *) exec desync make -s "$store" - "$2" ;;
esac
"#;

/// 受け取る側: stdin の chunk path のうち store に無いものを返す。
pub const MISSING: &str = r#"
while IFS= read -r f; do [ -e "$store/$f" ] || printf '%s\n' "$f"; done
"#;

/// 送る側: stdin の chunk path の (圧縮後の) 大きさを同じ順で返す。
pub const SIZES: &str = r#"
cd "$store" || exit 1
if stat -c %s . >/dev/null 2>&1; then set -- -c %s; else set -- -f %z; fi
tr '\n' '\0' | xargs -0 stat "$@"
"#;

/// 受け取る側: stdin の index を store から組み立てる。
pub const ASSEMBLE: &str = r#"
case $1 in
  dir) exec desync untar -i -s "$store" --no-same-owner --no-same-xattrs - "$2" ;;
  *) desync extract -s "$store" - "$2" && chmod "$3" "$2" ;;
esac
"#;

/// 両側: 今回使った chunk (stdin) の mtime を「最後に使った時刻」にする。reap が古い順に消す
/// ときの基準。atime は使わない: raptorlake の btrfs は noatime で、読んでも更新されない。
/// chunk の中身は変えないので、mtime を書き換えてもハッシュが名前という性質は崩れない。
pub const TOUCH: &str = r#"
cd "$store" || exit 1
tr '\n' '\0' | xargs -0 touch -c
"#;
