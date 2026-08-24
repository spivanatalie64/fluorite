# Stage 1/4: base image with all Chromium build dependencies installed.
#
# Primary base: Arch Linux (podman-built official image) — rolling release,
# always fresh enough for the newest Chromium's install-build-deps expectations
# (which stale Ubuntu LTS releases are not). Debian/Ubuntu bases still supported
# via the apt fallback path below. Override BASE_IMAGE in CI to swap distros
# (e.g. a future AcreetionOS-published image) without touching this file.
ARG BASE_IMAGE=docker.io/library/archlinux:base-devel
FROM ${BASE_IMAGE}

ARG VERSION
ENV WORKSPACE=/workspace

# ---- Arch path -------------------------------------------------------------
RUN if command -v pacman >/dev/null 2>&1; then \
      pacman-key --init 2>/dev/null || true; \
      pacman -Syu --noconfirm --needed \
        base-devel git curl wget rsync unzip zip tar xz jq which file \
        dos2unix wiggle python python-setuptools jdk-openjdk sudo; \
    fi

# ---- Debian/Ubuntu fallback path -------------------------------------------
# Chromium ships install-build-deps for dpkg systems only; run it when present.
RUN if command -v apt-get >/dev/null 2>&1; then \
      export DEBIAN_FRONTEND=noninteractive; \
      dpkg --add-architecture i386; \
      apt-get update && \
      apt-get -f -y install sudo lsb-release bash wget curl apt-utils python3 sed tzdata \
        build-essential lib32gcc-s1 g++-multilib dos2unix wiggle git jq xz-utils unzip && \
      wget -q https://raw.githubusercontent.com/chromium/chromium/$VERSION/build/install-build-deps.sh && \
      wget -q https://raw.githubusercontent.com/chromium/chromium/$VERSION/build/install-build-deps.py && \
      sed -i 's/snapcraft/wget/' install-build-deps.sh && \
      chmod +x ./install-build-deps.sh ./install-build-deps.py && \
      ./install-build-deps.sh --no-prompt --lib32 --no-chromeos-fonts && \
      ./install-build-deps.sh --android --no-prompt --no-chromeos-fonts && \
      rm -f install-build-deps.sh install-build-deps.py; \
    fi

# ---- Generic user setup -----------------------------------------------------
RUN groupadd -f wheel && \
    useradd -m -d /home/builder -u 1000 -s /bin/bash builder && \
    usermod -aG wheel builder && \
    printf 'builder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/builder && \
    chmod 440 /etc/sudoers.d/builder && \
    mkdir -p /workspace /github/home/.config/depot_tools && \
    chown -R builder:builder /workspace /github/home/.config/depot_tools

USER builder
WORKDIR /workspace
