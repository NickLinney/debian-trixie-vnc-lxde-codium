FROM debian:trixie-slim

ARG USER_PASSWORD=changeme
ARG ROOT_PASSWORD=changeme

ENV DEBIAN_FRONTEND=noninteractive \
    USER=user \
    HOME=/home/user \
    DISPLAY=:0

# Base packages + LXDE + VNC + dbus helpers
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        lxde-core at-spi2-core lxterminal pcmanfm \
        lxappearance \
        x11vnc xvfb dbus-x11 dbus-user-session \
        xauth x11-utils \
        sudo curl gnupg wget ca-certificates apt-transport-https \
        dumb-init firefox-esr \
        openssh-server \
        hicolor-icon-theme \
        shared-mime-info \
        desktop-file-utils \
        libgtk-3-bin \
        papirus-icon-theme \
        # --- Critical for Papirus: SVG icon rendering support ---
        librsvg2-common \
        libgdk-pixbuf-2.0-0 \
        libgdk-pixbuf2.0-bin \
    && rm -rf /var/lib/apt/lists/*

# Ensure X11 socket dir exists with correct permissions (prevents _XSERVTransmkdir errors)
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# --- Feature: Firefox ESR hardened defaults (no first-run, minimal UI, DDG, always private) ---
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

# --- Codium sandbox fix (container-friendly) ---
# 1) Create a wrapper and put it FIRST in PATH
# 2) Patch codium.desktop to use the wrapper (so panel/menu clicks work)
# 3) Do NOT overwrite /usr/bin/codium (keeps dpkg-managed files intact)
RUN printf '%s\n' \
  '#!/bin/sh' \
  '# Electron/Chromium sandbox often fails inside Docker due to restricted namespaces/seccomp.' \
  '# --disable-dev-shm-usage helps if /dev/shm is small (common in containers).' \
  'exec /usr/share/codium/codium --no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage "$@"' \
  > /usr/local/bin/codium && \
  chmod 0755 /usr/local/bin/codium && \
  if [ -f /usr/share/applications/codium.desktop ]; then \
    sed -i 's|^Exec=.*|Exec=/usr/local/bin/codium %F|g' /usr/share/applications/codium.desktop; \
  fi

# Create user + set passwords + passwordless sudo
RUN useradd -m -s /bin/bash "${USER}" && \
    echo "${USER}:${USER_PASSWORD}" | chpasswd && \
    echo "root:${ROOT_PASSWORD}" | chpasswd && \
    adduser "${USER}" sudo && \
    printf '%s\n' "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/010_${USER}_nopasswd && \
    chmod 0440 /etc/sudoers.d/010_${USER}_nopasswd

# --- Icon + MIME plumbing (force caches that slim images sometimes miss) ---
# 1) Ensure SVG loader is registered (Papirus is mostly SVG)
# 2) Rebuild icon caches for Papirus + hicolor
# 3) Update MIME database for file-type icons
RUN gdk-pixbuf-query-loaders --update-cache || true && \
    gtk-update-icon-cache -f /usr/share/icons/Papirus || true && \
    gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark || true && \
    gtk-update-icon-cache -f /usr/share/icons/Papirus-Light || true && \
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true && \
    update-mime-database /usr/share/mime || true

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
EXPOSE 22

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
