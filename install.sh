#!/usr/bin/env bash
set -euo pipefail

# install.sh
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/install.sh | bash
# Options:
#   --build   : run docker compose build after download
#   --deploy  : run docker compose up -d --build after download
#
# Env overrides (optional):
#   REPO_URL=https://github.com/owner/repo
#   BRANCH=main
#   INSTALL_DIR=./repo-dir-name

DEFAULT_REPO_URL="https://github.com/NickLinney/debian-trixie-vnc-lxde-codium"
DEFAULT_BRANCH="main"

REPO_URL="${REPO_URL:-$DEFAULT_REPO_URL}"
BRANCH="${BRANCH:-$DEFAULT_BRANCH}"

DO_BUILD=0
DO_DEPLOY=0

for arg in "$@"; do
  case "${arg}" in
    --build)  DO_BUILD=1 ;;
    --deploy) DO_DEPLOY=1 ;;
    *) ;;
  esac
done

# Derive install dir name from repo URL if not provided
REPO_BASENAME="$(basename "${REPO_URL}")"
INSTALL_DIR="${INSTALL_DIR:-./${REPO_BASENAME}}"

# Normalize github URL to archive URL
# Example:
#   https://github.com/OWNER/REPO -> https://github.com/OWNER/REPO/archive/refs/heads/main.zip
ARCHIVE_URL="${REPO_URL}/archive/refs/heads/${BRANCH}.zip"

TMP_DIR="$(mktemp -d)"
ARCHIVE_ZIP="${TMP_DIR}/repo.zip"

cleanup() {
  rm -rf "${TMP_DIR}" || true
}
trap cleanup EXIT

echo "[info] Repo:   ${REPO_URL}"
echo "[info] Branch: ${BRANCH}"
echo "[info] Dest:   ${INSTALL_DIR}"
echo

# Basic dependency check
need_cmd() { command -v "$1" >/dev/null 2>&1; }
if ! need_cmd curl; then
  echo "ERROR: curl is required" >&2
  exit 1
fi
if ! need_cmd unzip; then
  echo "ERROR: unzip is required" >&2
  exit 1
fi

# Download archive
echo "[info] Downloading ${ARCHIVE_URL}"
curl -fsSL "${ARCHIVE_URL}" -o "${ARCHIVE_ZIP}"

# Extract
echo "[info] Extracting..."
unzip -q "${ARCHIVE_ZIP}" -d "${TMP_DIR}"

# GitHub archives extract as REPO-BRANCH (or REPO-main)
TOP_DIR="$(find "${TMP_DIR}" -maxdepth 1 -type d -name "${REPO_BASENAME}-*" | head -n 1)"
if [[ -z "${TOP_DIR}" || ! -d "${TOP_DIR}" ]]; then
  echo "ERROR: could not locate extracted directory" >&2
  exit 1
fi

if [[ -e "${INSTALL_DIR}" ]]; then
  echo "ERROR: destination already exists: ${INSTALL_DIR}" >&2
  echo "       Remove it or set INSTALL_DIR=... to choose another name." >&2
  exit 1
fi

mv "${TOP_DIR}" "${INSTALL_DIR}"

# If no .env exists, auto-generate it from sample.env (no-config quickstart)
if [ ! -f "${INSTALL_DIR}/.env" ]; then
  if [ -f "${INSTALL_DIR}/sample.env" ]; then
    cp "${INSTALL_DIR}/sample.env" "${INSTALL_DIR}/.env"
    echo "[info] Created ${INSTALL_DIR}/.env from sample.env"
  else
    echo "[warn] sample.env not found; skipping .env generation"
  fi
fi

echo
echo "✔ Repository downloaded successfully"
echo "  Location: ${INSTALL_DIR}"
echo

# --- Optional build/deploy ---
if [[ "${DO_DEPLOY}" -eq 1 ]]; then
  echo "[info] Deploying (docker compose up -d --build)..."
  (cd "${INSTALL_DIR}" && docker compose up -d --build)
  echo
  echo "✔ Deployed"
elif [[ "${DO_BUILD}" -eq 1 ]]; then
  echo "[info] Building (docker compose build)..."
  (cd "${INSTALL_DIR}" && docker compose build)
  echo
  echo "✔ Built"
else
  echo "[info] Next steps:"
  echo "  cd ${INSTALL_DIR}"
  echo "  # .env already created from sample.env (if it was missing)"
  echo "  docker compose up --build"
fi
