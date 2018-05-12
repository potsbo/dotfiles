FROM linuxbrew/alpine

ENV MACHINE docker-machine
ENV USERNAME potsbo

RUN adduser -D -s /bin/bash $USERNAME
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
USER $USERNAME

COPY script/bootstrap /tmp/bootstrap
RUN /tmp/bootstrap
CMD ['zsh']
