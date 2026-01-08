#!/usr/bin/env bash
set -euo pipefail

# Defaults
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
VNC_DEPTH="${VNC_DEPTH:-24}"
export DISPLAY="${DISPLAY:-:0}"

# Provide a user runtime dir (helps avoid “No session for PID …” / logind-ish noise)
export XDG_RUNTIME_DIR="/tmp/runtime-${USER}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

# Desktop/session hints
export XDG_SESSION_TYPE="x11"
export XDG_CURRENT_DESKTOP="LXDE"
export DESKTOP_SESSION="LXDE"

# ---- Start a single DBus session bus (avoid dbus-launch spawning multiple busses) ----
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  DBUS_SOCKET="${XDG_RUNTIME_DIR}/bus"
  rm -f "${DBUS_SOCKET}" || true
  DBUS_SESSION_BUS_ADDRESS="$(dbus-daemon --session --fork --address="unix:path=${DBUS_SOCKET}" --print-address)"
  export DBUS_SESSION_BUS_ADDRESS
fi

# ---- Start SSH daemon (for port-forwarded VNC) ----
# Requires openssh-server in the image and passwordless sudo for ${USER}.
sudo mkdir -p /var/run/sshd
# Ensure host keys exist (some slim-ish images/flows can miss these)
sudo ssh-keygen -A >/dev/null 2>&1 || true
sudo /usr/sbin/sshd

# ---- Start Xvfb ----
Xvfb "${DISPLAY}" -screen 0 "${VNC_GEOMETRY}x${VNC_DEPTH}" -nolisten tcp -ac &
XVFB_PID=$!

# Wait for X to come up
for _ in $(seq 1 50); do
  if command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

# ---- Start a lightweight “LXDE-like” session WITHOUT lxsession ----
(
  set -euo pipefail
  lxpanel &
  pcmanfm --desktop --profile LXDE &
  exec openbox-session
) &
DESKTOP_PID=$!

# ---- Configure VNC password ----
mkdir -p "${HOME}/.vnc"
x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null 2>&1 || true

# ---- Run VNC server (foreground) ----
# Bind to 0.0.0.0 inside the container; compose restricts exposure by only publishing
# 127.0.0.1:5900 on the host. Network users should use SSH port-forwarding via :2222.
exec x11vnc \
  -forever -shared \
  -rfbauth "${HOME}/.vnc/passwd" \
  -display "${DISPLAY}" \
  -listen 0.0.0.0
