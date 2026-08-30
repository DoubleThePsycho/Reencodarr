# syntax=docker/dockerfile:1

FROM node:24-bookworm-slim AS frontend-build
WORKDIR /source

COPY package.json yarn.lock .yarnrc ./
RUN corepack enable \
    && yarn install --frozen-lockfile

COPY frontend/ frontend/
RUN yarn build --env production

FROM mcr.microsoft.com/dotnet/sdk:10.0.400-noble AS backend-build
WORKDIR /source

COPY . .
RUN dotnet msbuild -restore src/Sonarr.sln \
    -p:SelfContained=true \
    -p:Configuration=Release \
    -p:Platform=Posix \
    -p:RuntimeIdentifiers=linux-x64 \
    -p:EnableWindowsTargeting=true \
    -t:PublishAllRids

FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-noble AS runtime

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ffmpeg \
        tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 reencodarr \
    && useradd --uid 10001 --gid reencodarr --no-create-home --shell /usr/sbin/nologin reencodarr \
    && mkdir -p /app /config \
    && chown -R reencodarr:reencodarr /app /config

WORKDIR /app

COPY --from=backend-build --chown=reencodarr:reencodarr /source/_output/net10.0/linux-x64/publish/ ./
COPY --from=backend-build --chown=reencodarr:reencodarr /source/_output/Sonarr.Update/net10.0/linux-x64/publish/ ./Sonarr.Update/
COPY --from=frontend-build --chown=reencodarr:reencodarr /source/_output/UI/ ./UI/
COPY --chown=reencodarr:reencodarr LICENSE.md ./

EXPOSE 8989
VOLUME ["/config"]

USER reencodarr

ENTRYPOINT ["./Sonarr", "-nobrowser", "-data=/config", "-exitimmediately"]
