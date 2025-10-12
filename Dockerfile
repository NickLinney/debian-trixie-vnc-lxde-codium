# Debian Trixie Slim base (ARM64-friendly)
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    USER=user \
    HOME=/home/user \
    DISPLAY=:0

# Base packages and LXDE desktop components
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        lxde-core lxterminal pcmanfm \
        x11vnc xvfb dbus-x11 \
        sudo curl gnupg wget ca-certificates \
        apt-transport-https software-properties-common \
        dumb-init && \
    rm -rf /var/lib/apt/lists/*

# Papirus icon theme (via Ubuntu Jammy PPA repo is acceptable for theme assets)
RUN echo 'deb http://ppa.launchpad.net/papirus/papirus/ubuntu jammy main' > /etc/apt/sources.list.d/papirus-ppa.list && \
    wget -qO /etc/apt/trusted.gpg.d/papirus-ppa.asc 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x9461999446FAF0DF770BFC9AE58A9D36647CAE7F' && \
    apt-get update && apt-get install -y --no-install-recommends papirus-icon-theme && \
    rm -rf /var/lib/apt/lists/*

# VSCodium (arm64) from maintained repo (paulcarroty)
RUN curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg arch=arm64] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main" \
    > /etc/apt/sources.list.d/vscodium.list && \
    apt-get update && apt-get install -y --no-install-recommends codium && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash "${USER}" && echo "${USER}:${USER}" | chpasswd && adduser "${USER}" sudo

# VNC config and startup scripts
RUN mkdir -p ${HOME}/.vnc
COPY xstartup ${HOME}/.vnc/xstartup
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chown -R ${USER}:${USER} ${HOME}/.vnc && \
    chmod +x ${HOME}/.vnc/xstartup /usr/local/bin/entrypoint.sh

USER ${USER}
WORKDIR ${HOME}

EXPOSE 5900

# Use dumb-init for proper signal handling, then our entrypoint
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
