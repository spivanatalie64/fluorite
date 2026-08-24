# Stage 2/4: clean Chromium source checkout at $VERSION.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG VERSION
ENV VERSION=$VERSION
ENV WORKSPACE=/workspace

COPY --chown=builder:builder prepare-build.sh /workspace/prepare-build.sh
RUN chmod +x /workspace/prepare-build.sh

# TARGET_OS_LIST: space-separated list, e.g. "android" or "android win"
ARG TARGET_OS_LIST=android

RUN /workspace/prepare-build.sh && rm /workspace/prepare-build.sh
