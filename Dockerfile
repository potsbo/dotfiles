FROM alpine:3.6

ENV MACHINE docker-machine
ENV USERNAME potsbo

RUN apk update \
        && apk --no-cache add bash curl file git gcc libc6-compat linux-headers make musl-dev ruby ruby-irb ruby-json ruby-test-unit sudo \
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
RUN $HOME/.dotfiles/script/bootstrap --skip-tags=osx,ruby,rust,python,nodejs
CMD ['zsh']
