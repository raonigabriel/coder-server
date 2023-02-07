# This is a hack to setup alternate architecture names
# For this to work, it needs to be built using docker 'buildx'
FROM ghcr.io/raonigabriel/coder-core:1.0.3 AS linux-amd64
ARG ALT_ARCH=x64

FROM ghcr.io/raonigabriel/coder-core:1.0.3 AS linux-arm64
ARG ALT_ARCH=arm64

# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS builder
ARG TARGETARCH
ARG CLOUDFLARE_VERSION=2023.2.1
ARG OPENVSCODE_VERSION=v1.75.0

# Install npm, nodejs and some tools required to build native node modules
USER root
RUN apk --no-cache add npm build-base libsecret-dev python3 wget

COPY package*.json /tmp/

WORKDIR /tmp
# Add dependencies
RUN npm install && \
# Remove any precompiled native modules
    find /tmp/node_modules -name "*.node" -exec rm -rf {} \;

WORKDIR /tmp/node_modules/keytar
# Build keytar native module
RUN npm run build && \
    strip /tmp/node_modules/keytar/build/Release/keytar.node

# Build node-pty native module
WORKDIR /tmp/node_modules/node-pty
RUN npm install && \
    strip /tmp/node_modules/node-pty/build/Release/pty.node

# Build spdlog native module
WORKDIR /tmp/node_modules/spdlog
RUN npm rebuild && \
    strip /tmp/node_modules/spdlog/build/Release/spdlog.node

# Build native-watchdog native module
WORKDIR /tmp/node_modules/native-watchdog
RUN npm rebuild && \
    strip /tmp/node_modules/native-watchdog/build/Release/watchdog.node

# Build @parcel/watcher native module
WORKDIR /tmp/node_modules/@parcel/watcher
RUN npm install && \
    strip /tmp/node_modules/@parcel/watcher/build/Release/watcher.node

# Download 'cloudflared' manually instead of using apk.
# This is currently required because it is only available on the edge/testing Alpine repo.
RUN wget -nv https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARE_VERSION}/cloudflared-linux-${TARGETARCH} && \
    chmod +x cloudflared-linux-${TARGETARCH}  && \
# Remove debug symbols
    strip cloudflared-linux-${TARGETARCH} && \
# Put it into a 'staging' folder
    mkdir -p /tmp/staging/usr/bin && \ 
    mv cloudflared-linux-${TARGETARCH} /tmp/staging/usr/bin/cloudflared && \
    chown root:root  /tmp/staging/usr/bin/cloudflared

# Download 'openvscode-server'
WORKDIR /
RUN wget -nv https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-${OPENVSCODE_VERSION}/openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}.tar.gz && \
# Unpack it
    tar -xf openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}.tar.gz && \
    rm openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}.tar.gz && \
# Remove the 'node binary that comes with it
    rm openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}/node && \
# Replacing it with a symlink
    ln -s /usr/bin/node ./openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}/node && \
# Remove pre-compiled binary node modules
    find openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH} -name "*.node" -exec rm -rf {} \; && \
# Put everything into a 'staging' folder
    mkdir -p /tmp/staging/opt/ && \
    mv openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH} /tmp/staging/opt/openvscode-server && \
    cp /tmp/node_modules/keytar/build/Release/keytar.node /tmp/staging/opt/openvscode-server/node_modules/keytar/build/Release/keytar.node && \
    cp /tmp/node_modules/node-pty/build/Release/pty.node /tmp/staging/opt/openvscode-server/node_modules/node-pty/build/Release/pty.node && \
    cp /tmp/node_modules/spdlog/build/Release/spdlog.node /tmp/staging/opt/openvscode-server/node_modules/spdlog/build/Release/spdlog.node && \
    cp /tmp/node_modules/native-watchdog/build/Release/watchdog.node /tmp/staging/opt/openvscode-server/node_modules/native-watchdog/build/Release/watchdog.node && \
    cp /tmp/node_modules/@parcel/watcher/build/Release/watcher.node /tmp/staging/opt/openvscode-server/node_modules/@parcel/watcher/build/Release/watcher.node && \
    chown -R root:root /tmp/staging/opt/openvscode-server

# Reliquish root powers
USER coder

# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS final
ARG TARGETARCH

# Copy stuff from the staging folder of the 'builder' stage
COPY --from=builder /tmp/staging /

ENV PATH=$PATH:/opt/openvscode-server/bin
EXPOSE 8000
CMD ["openvscode-server", "serve-local", "--host", "0.0.0.0", "--port", "8000", "--accept-server-license-terms", "--disable-telemetry", "--without-connection-token"]
