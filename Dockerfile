FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    USER=user \
    HOME=/home/user \
    DISPLAY=:0

# Base packages (swap falkon -> firefox-esr) + add theme tool + dbus helpers
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        lxde-core at-spi2-core lxterminal pcmanfm \
        lxappearance \
        x11vnc xvfb dbus-x11 dbus-user-session \
        xauth \
        sudo curl gnupg wget ca-certificates apt-transport-https \
        dumb-init \
        firefox-esr \
        papirus-icon-theme && \
    rm -rf /var/lib/apt/lists/*

# Optional: you can remove this entirely if you want.
# Keeping it does no harm, but doing it at runtime often fails on some engines.
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# VSCodium repo
RUN curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
      | gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg arch=arm64] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main" \
      > /etc/apt/sources.list.d/vscodium.list && \
    apt-get update && apt-get install -y --no-install-recommends codium && \
    rm -rf /var/lib/apt/lists/*

# Create user + set passwords + passwordless sudo
RUN useradd -m -s /bin/bash "${USER}" && \
    echo "${USER}:${USER}" | chpasswd && \
    echo "root:root" | chpasswd && \
    adduser "${USER}" sudo && \
    printf '%s\n' "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/010_${USER}_nopasswd && \
    chmod 0440 /etc/sudoers.d/010_${USER}_nopasswd

# Force Papirus as the GTK icon theme (LXDE reads GTK settings)
RUN mkdir -p ${HOME}/.config/gtk-3.0 && \
    printf '%s\n' \
      '[Settings]' \
      'gtk-icon-theme-name=Papirus' \
      'gtk-theme-name=Adwaita' \
      > ${HOME}/.config/gtk-3.0/settings.ini && \
    printf '%s\n' \
      'gtk-icon-theme-name="Papirus"' \
      'gtk-theme-name="Adwaita"' \
      > ${HOME}/.gtkrc-2.0 && \
    chown -R ${USER}:${USER} ${HOME}

# VNC config and startup scripts
RUN mkdir -p ${HOME}/.vnc
COPY xstartup ${HOME}/.vnc/xstartup
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chown -R ${USER}:${USER} ${HOME}/.vnc && \
    chmod +x ${HOME}/.vnc/xstartup /usr/local/bin/entrypoint.sh

USER ${USER}
WORKDIR ${HOME}

EXPOSE 5900
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]