# Dockerfile (key changes only: sshd + lxpanel launchbar + firefox banner fix via host sysctls in compose)
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    USER=user \
    HOME=/home/user \
    DISPLAY=:0

# Build-time passwords (pulled from docker-compose build.args / .env)
ARG USER_PASSWORD
ARG ROOT_PASSWORD

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        lxde-core at-spi2-core lxterminal pcmanfm \
        lxappearance \
        x11vnc xvfb dbus-x11 dbus-user-session \
        xauth x11-utils \
        sudo curl gnupg wget ca-certificates apt-transport-https \
        dumb-init firefox-esr \
        hicolor-icon-theme shared-mime-info desktop-file-utils libgtk-3-bin \
        papirus-icon-theme librsvg2-common libgdk-pixbuf-2.0-0 libgdk-pixbuf2.0-bin \
        # SSH for tunneling VNC securely
        openssh-server \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# Firefox ESR policies (keep yours)
RUN mkdir -p /etc/firefox/policies && \
    printf '%s\n' \
      '{' \
      '  "policies": {' \
      '    "DisableAppUpdate": true,' \
      '    "DisableTelemetry": true,' \
      '    "DisableFirefoxStudies": true,' \
      '    "DontCheckDefaultBrowser": true,' \
      '    "NoDefaultBookmarks": true,' \
      '    "OverrideFirstRunPage": "",' \
      '    "OverridePostUpdatePage": "",' \
      '    "Preferences": {' \
      '      "browser.shell.checkDefaultBrowser": { "Value": false, "Status": "locked" },' \
      '      "browser.startup.homepage": { "Value": "about:blank" },' \
      '      "browser.newtabpage.enabled": { "Value": false },' \
      '      "browser.newtabpage.activity-stream.feeds.topsites": { "Value": false },' \
      '      "browser.newtabpage.activity-stream.feeds.section.topstories": { "Value": false },' \
      '      "browser.newtabpage.activity-stream.feeds.section.highlights": { "Value": false },' \
      '      "browser.newtabpage.activity-stream.feeds.snippets": { "Value": false },' \
      '      "browser.newtabpage.activity-stream.showSponsored": { "Value": false },' \
      '      "browser.newtabpage.activity-stream.showSponsoredTopSites": { "Value": false },' \
      '      "browser.search.defaultenginename": { "Value": "DuckDuckGo" },' \
      '      "browser.search.order.1": { "Value": "DuckDuckGo" },' \
      '      "browser.search.suggest.enabled": { "Value": false },' \
      '      "browser.urlbar.suggest.searches": { "Value": false },' \
      '      "privacy.donottrackheader.enabled": { "Value": true },' \
      '      "privacy.trackingprotection.enabled": { "Value": true },' \
      '      "privacy.trackingprotection.socialtracking.enabled": { "Value": true },' \
      '      "browser.privatebrowsing.autostart": { "Value": true, "Status": "locked" }' \
      '    }' \
      '  }' \
      '}' \
      > /etc/firefox/policies/policies.json

# VSCodium repo + install
RUN curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
      | gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg arch=arm64] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main" \
      > /etc/apt/sources.list.d/vscodium.list && \
    apt-get update && apt-get install -y --no-install-recommends codium && \
    rm -rf /var/lib/apt/lists/*

# Codium sandbox wrapper (keep yours)
RUN printf '%s\n' \
  '#!/bin/sh' \
  'exec /usr/share/codium/codium --no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage "$@"' \
  > /usr/local/bin/codium && \
  chmod 0755 /usr/local/bin/codium && \
  if [ -f /usr/share/applications/codium.desktop ]; then \
    sed -i 's|^Exec=.*|Exec=/usr/local/bin/codium %F|g' /usr/share/applications/codium.desktop; \
  fi

# Create user + passwords (from build args) + passwordless sudo
# - If USER_PASSWORD / ROOT_PASSWORD are not set, fall back to USER/root to keep builds usable.
RUN useradd -m -s /bin/bash "${USER}" && \
    echo "${USER}:${USER_PASSWORD:-${USER}}" | chpasswd && \
    echo "root:${ROOT_PASSWORD:-root}" | chpasswd && \
    adduser "${USER}" sudo && \
    printf '%s\n' "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/010_${USER}_nopasswd && \
    chmod 0440 /etc/sudoers.d/010_${USER}_nopasswd

# VSCodium skip first-run (IMPORTANT: after user exists)
RUN mkdir -p ${HOME}/.config/VSCodium/User && \
    printf '%s\n' \
      '{' \
      '  "workbench.startupEditor": "none",' \
      '  "workbench.welcomePage.walkthroughs.openOnInstall": false,' \
      '  "workbench.tips.enabled": false,' \
      '  "update.mode": "none",' \
      '  "telemetry.telemetryLevel": "off"' \
      '}' \
      > ${HOME}/.config/VSCodium/User/settings.json && \
    chown -R ${USER}:${USER} ${HOME}/.config/VSCodium

# Icon/MIME cache plumbing
RUN gdk-pixbuf-query-loaders --update-cache || true && \
    gtk-update-icon-cache -f /usr/share/icons/Papirus || true && \
    gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark || true && \
    gtk-update-icon-cache -f /usr/share/icons/Papirus-Light || true && \
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true && \
    update-mime-database /usr/share/mime || true

# Force Papirus theme
RUN mkdir -p ${HOME}/.config/gtk-3.0 && \
    printf '%s\n' '[Settings]' 'gtk-icon-theme-name=Papirus' 'gtk-theme-name=Adwaita' \
      > ${HOME}/.config/gtk-3.0/settings.ini && \
    printf '%s\n' 'gtk-icon-theme-name="Papirus"' 'gtk-theme-name="Adwaita"' \
      > ${HOME}/.gtkrc-2.0 && \
    chown -R ${USER}:${USER} ${HOME}

# --- Feature: put Codium in LXPanel Application Launch Bar ---
# LXPanel reads: ~/.config/lxpanel/LXDE/panels/panel
RUN mkdir -p ${HOME}/.config/lxpanel/LXDE/panels && \
    printf '%s\n' \
'Global {' \
'  edge=bottom' \
'  allign=left' \
'  margin=0' \
'  widthtype=percent' \
'  width=100' \
'  height=28' \
'}' \
'Plugin {' \
'  type=launchbar' \
'  Config {' \
'    Button { id=firefox-esr.desktop }' \
'    Button { id=codium.desktop }' \
'    Button { id=pcmanfm.desktop }' \
'    Button { id=lxterminal.desktop }' \
'  }' \
'}' \
'Plugin { type=taskbar }' \
'Plugin { type=tray }' \
'Plugin { type=clock }' \
      > ${HOME}/.config/lxpanel/LXDE/panels/panel && \
    chown -R ${USER}:${USER} ${HOME}/.config/lxpanel

# --- SSH server for VNC tunnel ---
RUN mkdir -p /var/run/sshd && \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    printf '%s\n' \
      'ClientAliveInterval 60' \
      'ClientAliveCountMax 2' \
      >> /etc/ssh/sshd_config

# VNC scripts
RUN mkdir -p ${HOME}/.vnc
COPY xstartup ${HOME}/.vnc/xstartup
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chown -R ${USER}:${USER} ${HOME}/.vnc && \
    chmod +x ${HOME}/.vnc/xstartup /usr/local/bin/entrypoint.sh

USER ${USER}
WORKDIR ${HOME}

# Expose VNC + SSH (compose controls what’s published)
EXPOSE 5900 22

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
