# Stage 3/4: Chromium source + this fork's patch stack applied.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG SOURCE_REPO
ENV SOURCE_REPO=$SOURCE_REPO

ARG PATCH_SHA
ENV PATCH_SHA=$PATCH_SHA

ENV WORKSPACE=/workspace

COPY --chown=builder:builder apply-patches.sh /workspace/apply-patches.sh
RUN chmod +x /workspace/apply-patches.sh

# Fetch the fork repo at $PATCH_SHA (full history needed for reproducible builds).
RUN mkdir -p $WORKSPACE/repo && \
    cd $WORKSPACE/repo && \
    git init && \
    git remote add origin "$SOURCE_REPO" && \
    git fetch --depth 1 origin "$PATCH_SHA" && \
    git reset --hard FETCH_HEAD

RUN /workspace/apply-patches.sh && rm /workspace/apply-patches.sh
