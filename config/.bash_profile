export PATH=$PATH:~/.anyenv/bin

[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

#  Anyenv
#-----------------------------------------------
if [ -d $HOME/.anyenv ]; then
  eval "$(anyenv init -)"
fi

export PATH="$HOME/.cargo/bin:$PATH"
. "/Users/potsbo/arm64/.cargo/env"
