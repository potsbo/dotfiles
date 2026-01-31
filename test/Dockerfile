FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl xz-utils sudo git && \
    useradd -m testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser
ENV USER=testuser
