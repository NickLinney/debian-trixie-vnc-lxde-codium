# Debian Trixie LXDE Desktop (VNC + SSH + VSCodium)

A **minimal, headless Debian (trixie-slim) desktop environment** running **LXDE**, **VSCodium**, and **Firefox ESR**, designed to be accessed remotely over **VNC**, with **SSH tunneling for secure network use**.

This project targets **ARM64 (Apple Silicon)** but should work on any Docker host capable of running `debian:trixie-slim`.

---

## 🚀 Quickstart

This repository provides a **network-ready, containerized Debian Trixie LXDE desktop** with:

* VNC remote desktop (headless, via Xvfb)
* SSH for secure tunneling
* VSCodium (container-safe Electron configuration)
* Firefox ESR (privacy-hardened, no first-run UI)
* Minimal LXDE environment with Papirus icons
* Passwordless sudo for the desktop user

No `git` is required. Docker and Docker Compose are sufficient.

---

### 1️⃣ Download the Repository (No Git Required)

Run the following command on your host system:

```bash
curl -fsSL https://raw.githubusercontent.com/NickLinney/debian-trixie-vnc-lxde-codium/main/install.sh | bash
```

This will:

* Download the repository via HTTPS
* Extract it into a local directory
* Clean up the temporary archive

After completion:

```bash
cd debian-trixie-vnc-lxde-codium
```

---

### 2️⃣ Configuration (Optional)

#### 🔹 No-Config / Quick Test Mode (Defaults)

If you just want to **test the container immediately**, you can skip configuration entirely.

The repository includes a `sample.env` file with safe defaults, and the install script will automatically generate `.env` from it if one does not exist.

Default credentials in this mode:

* **Desktop user:** `user`
* **User password:** `changeme`
* **Root password:** `changeme`
* **VNC password:** `changeme`

You can proceed directly to Step 3.

---

#### 🔹 Custom Configuration (Optional)

If you want custom passwords or display settings:

```bash
cp sample.env .env
```

Edit `.env` as desired, for example:

```env
# Desktop user & root passwords (used for SSH + sudo)
USER_PASSWORD=yourpassword
ROOT_PASSWORD=yourpassword

# VNC settings
VNC_PASSWORD=yourpassword
VNC_GEOMETRY=1920x1080
VNC_DEPTH=24
```

---

### 3️⃣ Build and Launch the Desktop

Start the container:

```bash
docker compose up --build
```

The desktop will start in the background and expose:

* **SSH** on port `2222`
* **VNC** bound internally to `0.0.0.0`, but published only to host loopback

---

### 4️⃣ Connect via SSH + VNC (Recommended)

#### 🔹 No-Config / Default Credentials

From **another machine on the network**, you can immediately create an SSH tunnel using the default password (`changeme`):

```bash
ssh -p 2222 -L 5900:127.0.0.1:5900 user@<HOST_IP>
```

When prompted, enter:

```
changeme
```

Then connect your VNC client to:

```
127.0.0.1:5900
```

---

#### 🔹 Custom Credentials

If you changed the password in your `.env` file, use the same SSH command but authenticate with your custom password instead.

---

### 5️⃣ Local Host Connection (Optional)

If you are running Docker **on the same machine** as your VNC client, you may connect directly to:

```
127.0.0.1:5900
```

(SSH tunneling is not required in this case.)

---

### 🧠 Notes

* **VSCodium** launches without sandbox errors and skips all first-run walkthroughs.
* **Firefox ESR** launches in private mode, with DuckDuckGo as the default search engine, and no onboarding screens.
* **LXDE session** runs without `systemd` or `logind`, avoiding common container session warnings.
* **Passwordless sudo** is enabled for the desktop user.
* SSH tunneling provides encryption for VNC without exposing the VNC port to the network.

---

## Overview

This container provides:

- A lightweight **LXDE desktop** (Openbox + LXPanel + PCManFM)
- **VSCodium** (container-safe Electron configuration)
- **Firefox ESR** (fully preconfigured, no first-run UI)
- **x11vnc + Xvfb** for headless graphical access
- **OpenSSH server** for encrypted VNC tunneling
- Passwordless `sudo` for convenience inside the container
- All configuration managed via `.env` and `docker-compose`

No systemd, no logind, no audio stack, no GPU acceleration — this is a **clean, deterministic remote desktop container**.

---

## Key Features

### Desktop Environment
- LXDE without `lxsession` (avoids systemd/logind session errors in containers)
- Papirus icon theme (SVG support fixed and cached)
- LXPanel launch bar preconfigured with:
  - Firefox ESR
  - VSCodium
  - PCManFM
  - LXTerminal

### VSCodium
- Installed from the official maintained `.deb` repository
- Electron sandbox disabled safely for containers
- Skips welcome screen, walkthroughs, tips, and telemetry on first launch
- Configured via a pre-seeded user settings file

### Firefox ESR
- First-run and post-update pages disabled
- Always starts in **Private Browsing**
- DuckDuckGo set as the default search engine
- New tab content, sponsored items, telemetry, and studies disabled
- No “default browser” or onboarding prompts
- Security warning banner mitigated via host sysctl support

### Remote Access & Security
- **VNC server runs unencrypted inside the container**
- **VNC is only published to `127.0.0.1` on the host**
- **SSH (port 2222)** is used for secure network access via port forwarding
- Password-based SSH authentication enabled
- Root login via SSH disabled
- Passwordless `sudo` for the non-root user

---

## Repository Layout

```
.
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── xstartup
├── sample.env
├── LICENSE.md
└── README.md
```

---

## Quick Start

### 1. Create your `.env`

````
cp sample.env .env
````

Edit `.env` and set **strong passwords**.

### 2. Build and start the container

```bash
docker compose up --build
```

> ⚠️ Changing `USER_PASSWORD` or `ROOT_PASSWORD` requires a rebuild.

---

## Connecting to the Desktop

### Option A: From the Docker host (no SSH)

VNC is published **only to localhost**.

* Host: `127.0.0.1`
* Port: `5900`
* Password: `VNC_PASSWORD`

### Option B: From another machine (recommended)

Use an **SSH tunnel**:

```bash
ssh -p 2222 -L 5900:127.0.0.1:5900 user@<HOST_IP>
```

Then connect your VNC client to:

* Host: `127.0.0.1`
* Port: `5900`

All traffic is encrypted by SSH.

---

## Environment Variables

Defined in `.env`:

### Runtime (container start)

| Variable       | Purpose                                       |
| -------------- | --------------------------------------------- |
| `VNC_PASSWORD` | VNC authentication password                   |
| `VNC_GEOMETRY` | Virtual display resolution (e.g. `1920x1080`) |
| `VNC_DEPTH`    | Color depth (typically `24`)                  |

### Build-time (image creation)

| Variable        | Purpose                        |
| --------------- | ------------------------------ |
| `USER_PASSWORD` | Password for the non-root user |
| `ROOT_PASSWORD` | Root password                  |

---

## User & Privileges

* Default user: `user`
* `sudo` is configured with **NOPASSWD**
* SSH uses password authentication
* Root SSH login is disabled
* VNC authentication is independent of system passwords

---

## Technical Notes

### Why no `lxsession`?

`lxsession` expects systemd/logind integration. In containers, this produces errors like:

```
No session for PID …
```

This setup launches the desktop components directly:

* `lxpanel`
* `pcmanfm`
* `openbox-session`

This is intentional and stable.

### Why Xvfb?

* No GPU dependency
* Deterministic behavior
* Works cleanly on macOS, Linux, CI, and servers

### Refresh Rate

Xvfb does **not** expose a real refresh rate. Any “59 Hz” or similar display values are artifacts of the VNC client.

---

## Limitations

* No audio support
* No GPU acceleration
* No clipboard sync beyond what VNC provides
* Single-user desktop session

These are **deliberate trade-offs** to keep the image small, predictable, and portable.

---

## License

MIT License.
See `LICENSE.md` for details.

Upstream components (Debian, Firefox, VSCodium, LXDE, Papirus) retain their respective licenses.
