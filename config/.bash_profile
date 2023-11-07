if [ -d $HOME/.rbenv ]; then
	eval "$(rbenv init - zsh)"
fi
if [ -d $HOME/.nodenv ]; then
	eval "$(nodenv init -)"
fi
. "$HOME/.cargo/env"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
