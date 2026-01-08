#!/usr/bin/env bash
set -e

# Provide an XDG runtime dir (often reduces “no session” type noise)
export XDG_RUNTIME_DIR="/tmp/runtime-${USER}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

# Ensure a user session bus exists for LXDE pieces
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  eval "$(dbus-launch --sh-syntax)"
fi

# (then your existing Xvfb + lxsession + x11vnc startup)

# Defaults
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
VNC_DEPTH="${VNC_DEPTH:-24}"

export DISPLAY=:0

# Xvfb uses WIDTHxHEIGHTxDEPTH (no refresh rate concept)
Xvfb :0 -screen 0 "${VNC_GEOMETRY}x${VNC_DEPTH}" &
sleep 1

# Start a simple LXDE-like session WITHOUT lxsession to avoid logind/systemd session popups in containers.
# (This eliminates the “No session for PID …” dialog.)
#
# We still use dbus-launch so apps expecting a session bus behave normally.
dbus-launch --exit-with-session bash -lc '
  set -e
  # Panel + desktop icons/desktop management + window manager
  lxpanel &
  pcmanfm --desktop --profile LXDE &
  exec openbox-session
' &

# Configure VNC password
mkdir -p "${HOME}/.vnc"
x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd"

# Run x11vnc server
exec x11vnc -forever -shared -rfbauth "${HOME}/.vnc/passwd" -display :0 -listen 0.0.0.0
