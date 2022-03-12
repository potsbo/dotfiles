export PATH=$PATH:~/.anyenv/bin

[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

#  Anyenv
#-----------------------------------------------
if [ -d $HOME/.anyenv ]; then
  eval "$(anyenv init -)"
fi

. "$HOME/.cargo/env"
