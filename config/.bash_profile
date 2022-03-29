if [ -d $HOME/.rbenv ]; then
	eval "$(rbenv init - zsh)"
fi
if [ -d $HOME/.nodenv ]; then
	eval "$(nodenv init -)"
fi
