# Stage 4/4: compile-ready image. Patched source + warm tool caches + PGO profiles.
# Build state (out/) is committed back onto this tag between runs so builds resume
# incrementally; the whole image is disposable per Chromium major version.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ENV WORKSPACE=/workspace
ARG TARGET_OS_LIST=android
ENV TARGET_OS_LIST=$TARGET_OS_LIST

COPY --chown=builder:builder pre-start.sh /workspace/pre-start.sh
RUN chmod +x /workspace/pre-start.sh && /workspace/pre-start.sh && rm /workspace/pre-start.sh

WORKDIR $WORKSPACE/chromium/src
