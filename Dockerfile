FROM alpine:3.6

ENV MACHINE docker-machine
ENV USERNAME potsbo

RUN apk update \
        && apk --no-cache add bash curl file git libc6-compat make ruby ruby-irb ruby-json ruby-test-unit sudo \
        && adduser -D -s /bin/bash $USERNAME \
        && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
WORKDIR /home/$USERNAME
ENV PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH \
        SHELL=/bin/bash \
        USER=$USERNAME

RUN ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)" \
        && HOMEBREW_NO_ANALYTICS=1 brew install --ignore-dependencies patchelf glibc \
        && HOMEBREW_NO_ANALYTICS=1 brew config

RUN brew install ansible

COPY . /home/potsbo/.dotfiles
RUN $HOME/.dotfiles/script/bootstrap
CMD ['zsh']
