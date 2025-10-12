#!/usr/bin/env bash
set -euo pipefail

# Defaults
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
VNC_DEPTH="${VNC_DEPTH:-24}"

export DISPLAY=:0

# Start a headless X server with desired geometry & depth
# Note: Xvfb uses WIDTHxHEIGHTxDEPTH format; no refresh rate concept.
Xvfb :0 -screen 0 "${VNC_GEOMETRY}x${VNC_DEPTH}" &
XVFB_PID=$!

# Give Xvfb a moment
sleep 1

# Start LXDE session
# dbus-launch ensures a session bus is available for desktop components
if command -v dbus-launch >/dev/null 2>&1; then
  dbus-launch --exit-with-session lxsession &
else
  lxsession &
fi

# Configure VNC password
mkdir -p "${HOME}/.vnc"
x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd"

# Run x11vnc server
# -rfbauth uses the saved password file
# -forever does not exit on client disconnects
# -shared allows multiple clients
# -display :0 binds to the Xvfb display
exec x11vnc -forever -shared -rfbauth "${HOME}/.vnc/passwd" -display :0 -listen 0.0.0.0
