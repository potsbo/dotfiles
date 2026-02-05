# ~/.zshenv - 常に読まれる環境変数（非対話シェル、スクリプトでも）

# Locale
# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
export LANG=C # default に寄せる
unset LC_ALL # LC_* が override されるのを防ぐ

# 日本語表示には C 以外が必要, ja_JP.UTF-8 vs en_US.UTF-8 は真剣に考えてない
export LC_CTYPE=en_US.UTF-8
# 英語系で Y->M->D の順に並ぶおそらく唯一の format
export LC_TIME=en_CA.UTF-8

if [ "$OSTYPE" = "linux-gnu" ]; then
  export LC_CTYPE=en_US.utf8
  export LC_TIME=en_CA.utf8
fi

export LC_NUMERIC=C
export LC_COLLATE=C # en_US.UTF-8 だと日本語が文字数以外全て同一視された。default に寄せる
export LC_MONETARY=C
export LC_MESSAGES=C

export EDITOR=nvim
export TERM=xterm-256color
export XDG_CONFIG_HOME="$HOME/.config"

# PATH
export PATH=$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH
export PATH=$HOME/bin:$PATH
## Build
export PATH=$PATH:$HOME/.local/bin # Created by `pipx`
if [ -n "$PIPX_BIN_DIR" ]; then; export PATH=$PATH:$PIPX_BIN_DIR; fi # poetry in codespaces
export PATH=$PATH:$HOME/go/bin
export PATH=$PATH:$HOME/.cargo/bin
## System
export PATH=$PATH:/bin               # cat, cp, ...
export PATH=$PATH:/sbin              # ping, ifconfig, ...
export PATH=$PATH:/usr/bin           # arch, top, ...
export PATH=$PATH:/usr/sbin          # chown, chroot, ...
export PATH=$PATH:/Applications/Docker.app/Contents/Resources/bin/
export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/rc

# M1 Mac で amd64 の docker image を動かすため
export DOCKER_DEFAULT_PLATFORM=linux/amd64

export PATH="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin:$PATH"
export AQUA_GLOBAL_CONFIG=${AQUA_GLOBAL_CONFIG:-}:${XDG_CONFIG_HOME:-$HOME/.config}/aquaproj-aqua/aqua.yaml

export CARGO_NET_GIT_FETCH_WITH_CLI=true

# https://github.com/golang/go/issues/42700
export GODEBUG=asyncpreemptoff=1

# for `go test -race ...`
export CGO_ENABLED=1

export HISTFILE="${HOME}/.zsh_history"
export SAVEHIST=100000
export HISTSIZE=100000

export ANTHROPIC_MODEL=opus
