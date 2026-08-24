# Stage 1/4: base image with all Chromium build dependencies installed.
# Generic: no user-specific paths, no proxy assumptions, no registry assumptions.
ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

ARG VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update && \
    apt-get -f -y install sudo lsb-release bash wget curl apt-utils python3 sed tzdata \
      build-essential lib32gcc-s1 g++-multilib dos2unix wiggle git python3-distutils jq xz-utils unzip

ENV USER_NAME builder
ARG UID=1000
RUN useradd -m -d /home/${USER_NAME} -u ${UID} -s /bin/bash ${USER_NAME} && \
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME} && \
    adduser ${USER_NAME} sudo && \
    chmod 4755 /usr/bin/sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER ${USER_NAME}
WORKDIR /workspace

# Chromium's install-build-deps scripts for the given source version.
RUN wget -q https://raw.githubusercontent.com/chromium/chromium/$VERSION/build/install-build-deps.sh && \
    wget -q https://raw.githubusercontent.com/chromium/chromium/$VERSION/build/install-build-deps.py && \
    sed -i 's/snapcraft/wget/' install-build-deps.sh && \
    chmod +x ./install-build-deps.sh ./install-build-deps.py && \
    sudo DEBIAN_FRONTEND=noninteractive ./install-build-deps.sh --no-prompt --lib32 --no-chromeos-fonts && \
    sudo DEBIAN_FRONTEND=noninteractive ./install-build-deps.sh --android --no-prompt --no-chromeos-fonts && \
    rm -f install-build-deps.sh install-build-deps.py

RUN sudo mkdir -p /workspace /github/home/.config/depot_tools && \
    sudo chown -R ${USER_NAME}:${USER_NAME} /workspace /github/home/.config/depot_tools

ENV WORKSPACE=/workspace
