# syntax=docker/dockerfile:1

# ---- Stage 1: build the AOT-compiled Dart binary with Jaspr --------------
FROM dart:stable AS build

WORKDIR /app

# Resolve dependencies first so this layer is cached across source changes.
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the source and compile.
COPY . .
RUN dart pub get --offline
RUN dart pub global activate jaspr_cli
RUN dart pub global run jaspr_cli:jaspr build

# ---- Stage 2: slim runtime with a pinned adb -----------------------------
FROM debian:bookworm-slim AS runtime

# Pinned platform-tools -- deliberately not "latest". Bump this version
# string (and re-verify against `adb version` at runtime) when upgrading.
# Recorded in /health and in every run.json (see lib/config.dart).
ARG ADB_VERSION=1:29.0.6-28
ARG GIT_COMMIT=unknown

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adb=${ADB_VERSION} \
        curl \
        ca-certificates \
        procps \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Europe/Prague
ENV GIT_COMMIT=${GIT_COMMIT}

WORKDIR /app
COPY --from=build /app/build/jaspr/ /app/
COPY --from=build /app/profiles /app/profiles

# Runs as root deliberately: the adb key persisted under /root/.android
# must survive restarts, and the DUT-authorisation trap in the README
# assumes this exact path. See README.md "ADB authorisation".
ENV HOME=/root

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT:-8080}/health" || exit 1

ENTRYPOINT ["/app/app"]
