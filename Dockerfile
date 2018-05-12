FROM alpine:3.7

RUN apk add --no-cache bash git
COPY script/bootstrap /tmp/bootstrap
RUN /tmp/bootstrap
CMD ['zsh']