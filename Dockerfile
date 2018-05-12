FROM alpine:3.7

RUN apk add --no-cache bash git openssh curl ruby

ENV MACHINE docker-machine
ENV USERNAME potsbo

RUN adduser -D -s /bin/bash $USERNAME
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
USER $USERNAME

COPY script/bootstrap /tmp/bootstrap
RUN /tmp/bootstrap
CMD ['zsh']
