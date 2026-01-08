#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Debian Trixie LXDE Desktop — Bootstrap Installer
#
# Default repository:
#   https://github.com/NickLinney/debian-trixie-vnc-lxde-codium
#
# One-line install (download only):
#   curl -fsSL https://raw.githubusercontent.com/NickLinney/debian-trixie-vnc-lxde-codium/main/install.sh | bash
#
# Download + build:
#   curl -fsSL https://raw.githubusercontent.com/NickLinney/debian-trixie-vnc-lxde-codium/main/install.sh | bash -s -- --build
#
# Download + build + deploy (docker compose up):
#   curl -fsSL https://raw.githubusercontent.com/NickLinney/debian-trixie-vnc-lxde-codium/main/install.sh | bash -s -- --deploy
#
# Fork-friendly overrides (optional env vars):
#   GITHUB_OWNER=YourName GITHUB_REPO=your-repo GITHUB_REF=main INSTALL_DIR=custom-dir ...
# ------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage:
  install.sh [--build] [--deploy] [--help]

Behavior:
  (no flags)   Download + unzip + cleanup only.
  --build      Download + unzip + cleanup, then run: docker compose build
  --deploy     Download + unzip + cleanup, then run: docker compose up --build -d

Notes:
  - --deploy implies build.
  - The repo will be placed into INSTALL_DIR (default: the repo name).
  - This script does not require git; it downloads a GitHub ZIP.
EOF
}

# --- Parse flags ---
DO_BUILD=0
DO_DEPLOY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)
      DO_BUILD=1
      shift
      ;;
    --deploy)
      DO_DEPLOY=1
      DO_BUILD=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
done

# --- Repository defaults (override via environment if forked) ---
GITHUB_OWNER="${GITHUB_OWNER:-NickLinney}"
GITHUB_REPO="${GITHUB_REPO:-debian-trixie-vnc-lxde-codium}"
GITHUB_REF="${GITHUB_REF:-main}"

# Destination directory
INSTALL_DIR="${INSTALL_DIR:-${GITHUB_REPO}}"

ZIP_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/archive/refs/heads/${GITHUB_REF}.zip"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

need_one_of() {
  for c in "$@"; do
    if command -v "$c" >/dev/null 2>&1; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

need_cmd curl

# Create temp working directory
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

ZIP_PATH="${TMP_DIR}/${GITHUB_REPO}.zip"
EXTRACT_DIR="${TMP_DIR}/extract"
mkdir -p "${EXTRACT_DIR}"

echo "Downloading repository:"
echo "  ${ZIP_URL}"
echo

curl -fsSL -o "${ZIP_PATH}" "${ZIP_URL}"

# Extract ZIP (prefer unzip; fallback to bsdtar)
EXTRACTOR="$(need_one_of unzip bsdtar || true)"
if [[ -z "${EXTRACTOR}" ]]; then
  echo "ERROR: need 'unzip' or 'bsdtar' to extract the archive." >&2
  exit 1
fi

if [[ "${EXTRACTOR}" == "unzip" ]]; then
  unzip -q "${ZIP_PATH}" -d "${EXTRACT_DIR}"
else
  bsdtar -xf "${ZIP_PATH}" -C "${EXTRACT_DIR}"
fi

# GitHub zips always contain a single top-level directory
TOP_DIR="$(find "${EXTRACT_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
if [[ -z "${TOP_DIR}" || ! -d "${TOP_DIR}" ]]; then
  echo "ERROR: could not locate extracted repository directory." >&2
  exit 1
fi

if [[ -e "${INSTALL_DIR}" ]]; then
  echo "ERROR: destination already exists: ${INSTALL_DIR}" >&2
  echo "       Remove it or set INSTALL_DIR=... to choose another name." >&2
  exit 1
fi

mv "${TOP_DIR}" "${INSTALL_DIR}"

echo
echo "✔ Repository downloaded successfully"
echo "  Location: ${INSTALL_DIR}"
echo

# --- Optional build/deploy ---
if [[ "${DO_BUILD}" -eq 1 ]]; then
  need_cmd docker

  # Prefer "docker compose" (plugin). Fall back to "docker-compose" if present.
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  else
    echo "ERROR: Docker Compose not found (need 'docker compose' plugin or 'docker-compose')." >&2
    exit 1
  fi

  echo "Building with Compose..."
  ( cd "${INSTALL_DIR}" && "${COMPOSE_CMD[@]}" build )

  if [[ "${DO_DEPLOY}" -eq 1 ]]; then
    echo
    echo "Deploying (docker compose up --build -d)..."
    ( cd "${INSTALL_DIR}" && "${COMPOSE_CMD[@]}" up --build -d )
    echo
    echo "✔ Deployed."
    echo
  else
    echo
    echo "✔ Build complete."
    echo
  fi
fi

echo "Next steps:"
echo "  cd \"${INSTALL_DIR}\""
echo "  cp sample.env .env"
if [[ "${DO_DEPLOY}" -eq 1 ]]; then
  echo "  (already deployed; you can check logs with: docker compose logs -f)"
else
  echo "  docker compose up --build"
fi
echo
echo "For network access:"
echo "  ssh -p 2222 -L 5900:127.0.0.1:5900 user@<HOST_IP>"
echo "  then connect your VNC client to 127.0.0.1:5900"
