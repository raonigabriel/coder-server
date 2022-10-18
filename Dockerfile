# This is a hack to setuo alternate architecture names
# For this to work, it needs to be built using docker 'buildx'
FROM ghcr.io/raonigabriel/coder-core:latest AS linux-amd64
ARG ALT_ARCH=x64

FROM ghcr.io/raonigabriel/coder-core:latest AS linux-arm64
ARG ALT_ARCH=arm64

# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS builder
ARG TARGETARCH
ARG CLOUDFLARE_VERSION=2022.10.1
ARG OPENVSCODE_VERSION=v1.72.2

# Install npm, nodejs and some tools required to build native node modules 
RUN sudo apk --no-cache add npm build-base libsecret-dev python3 wget

# Setup a dummy project
RUN cd /tmp && \
    npm init -y && \
# Then add dependencies
    npm install keytar node-pty spdlog native-watchdog @parcel/watcher && \
# Remove any precompiled native modules
    find /tmp/node_modules -name "*.node" -exec rm -rf {} \;

# Build keytar native modue
RUN cd /tmp/node_modules/keytar && \
    npm run build && \
    strip /tmp/node_modules/keytar/build/Release/keytar.node

# Build node-pty native modue
RUN cd /tmp/node_modules/node-pty && \
    npm install && \
    strip /tmp/node_modules/node-pty/build/Release/pty.node

# Build spdlog native modue
RUN cd /tmp/node_modules/spdlog && \
    npm rebuild && \
    strip /tmp/node_modules/spdlog/build/Release/spdlog.node

# Build native-watchdog native modue
RUN cd /tmp/node_modules/native-watchdog && \
    npm rebuild && \
    strip /tmp/node_modules/native-watchdog/build/Release/watchdog.node

# Build @parcel/watcher native modue
RUN cd /tmp/node_modules/@parcel/watcher && \
    npm install && \
    strip /tmp/node_modules/@parcel/watcher/build/Release/watcher.node

# Download 'cloudflared' manually instead of using apk.
# This is currently required because it is only available on the edge/testing Alpine repo.
RUN wget https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARE_VERSION}/cloudflared-linux-${TARGETARCH} && \
    chmod +x cloudflared-linux-${TARGETARCH}  && \
# Remove debug symbols
    strip cloudflared-linux-${TARGETARCH} && \
# Put it into a 'staging' folder
    mkdir -p /tmp/staging/usr/bin && \ 
    mv cloudflared-linux-${TARGETARCH} /tmp/staging/usr/bin/cloudflared && \
    sudo chown root:root  /tmp/staging/usr/bin/cloudflared

# Download 'openvscode-server'
RUN wget https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-${OPENVSCODE_VERSION}/openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}.tar.gz && \
# Unpack it
    tar -xf openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}.tar.gz && \
    rm openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}.tar.gz && \
# Remove the 'node binary that comes with it
    rm openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}/node && \
# Replacing it with a symlink
    ln -s /usr/bin/node ./openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH}/node && \
# Remove pre-compiled binary node modules
    find . -name "*.node" -exec rm -rf {} \; && \
# Put everything into a 'staging' folder
    sudo mkdir -p /tmp/staging/opt/ && \
    sudo mv openvscode-server-${OPENVSCODE_VERSION}-linux-${ALT_ARCH} /tmp/staging/opt/openvscode-server && \
    sudo cp /tmp/node_modules/keytar/build/Release/keytar.node /tmp/staging/opt/openvscode-server/node_modules/keytar/build/Release/keytar.node && \
    sudo cp /tmp/node_modules/node-pty/build/Release/pty.node /tmp/staging/opt/openvscode-server/node_modules/node-pty/build/Release/pty.node && \
    sudo cp /tmp/node_modules/spdlog/build/Release/spdlog.node /tmp/staging/opt/openvscode-server/node_modules/spdlog/build/Release/spdlog.node && \
    sudo cp /tmp/node_modules/native-watchdog/build/Release/watchdog.node /tmp/staging/opt/openvscode-server/node_modules/native-watchdog/build/Release/watchdog.node && \
    sudo cp /tmp/node_modules/@parcel/watcher/build/Release/watcher.node /tmp/staging/opt/openvscode-server/node_modules/@parcel/watcher/build/Release/watcher.node && \
    sudo chown -R root:root /tmp/staging/opt/openvscode-server

# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS final
ARG TARGETARCH

# Copy stuff from the staging folder of the 'builder' stage
COPY --from=builder /tmp/staging /

ENV PATH=$PATH:/opt/openvscode-server/bin
EXPOSE 8000
CMD ["openvscode-server", "serve-local", "--host", "0.0.0.0", "--port", "8000", "--accept-server-license-terms", "--disable-telemetry", "--without-connection-token"]
