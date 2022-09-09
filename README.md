# coder-server
---
This is my opinionated attempt to build a lightweight docker image to run [openvscode-server](https://github.com/gitpod-io/openvscode-server). Think vscode, on the browser.
# Features

1. Based on my [coder-core](https://github.com/raonigabriel/coder-core) instead of Ubuntu. This translates to [musl being used instead of glib](https://wiki.musl-libc.org/functional-differences-from-glibc.html), but compatibility libraries are also preinstalled. 
2. Its is Alpine, but using **bash** instead of **ash**.
3. By using **tini**, we ensure that child processes are correctly reaped.
4. Default user **coder** and group **coder** using UID and GID = 1000, to ease volume-mapping permissions issues.
5. Passwordless, **sudo** support: easily install extra packages with apk (e.g, ```sudo apk add docker-cli  jq```) 
6. Preinstalled [cloudflare tunnel client](https://github.com/cloudflare/cloudflared), like ngrok but free!! This allows you to create reverse tunnels (when your are behind nat). See their docs [here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps) 
7. Preinstalled tooling (node, npm, git, curl, socat, openssh-client, nano, unzip, brotli, zstd, xz) !!!
8. Image is hosted on [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry), hence no Dockerhub caps.

# Guidelines that I follow
 - Whenever possible, install software directly from the Alpine repositories, i.e. use apk instead of downloading / manually installing them.
 - Keep it small: do not cross the 250MB image size boundary.
- Multi arch (amd64 && arm64)
# Security notice
1. By default this image is **not with running with HTTPS** but HTTP instead. Its your responsibility to add a reverse-proxy to do that. If you dont, keep in mind that some issues may arise, regarding service workers on the browser. This is because they [need HTTPS](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers#setting_up_to_play_with_service_workers) to work properly.
2. By default this image has **no security enforced** (user / password). Its your responsibility to add a reverse-proxy to do that. 
# Usage

```
# docker run -d -p 8000:8000 ghcr.io/raonigabriel/coder-server:latest
```
Then, point your browser to [http://localhost:8000](http://localhost:8000) 
# Creating your own derived image (Java example)

```Dockerfile
FROM ghcr.io/raonigabriel/coder-server:latest

# Setup env variables
ENV JAVA_HOME=/usr/lib/jvm/default-jvm \
    MAVEN_HOME=/usr/share/java/maven-3 \
    GRADLE_HOME=/usr/share/java/gradle

# Installing Java and tools
RUN sudo apk --no-cache add maven gradle && \
# Installing Java extensions
    sudo openvscode-server --install-extension vscjava.vscode-java-pack vscjava.vscode-gradle vscjava.vscode-spring-initializr
```
---
## Licenses
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)

---
## Disclaimer
* I am **not** sponsored neither work for cloudflare. I just happen to use their services, because they are cool!
* This code comes with no warranty. Use it at your own risk.
* I don't like Apple. Fuck off, fan-boys.
* I don't like left-winged snowflakes. Fuck off, code-covenant. 
* I will call my branches the old way. Long live **master**, fuck-off renaming.
