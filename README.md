# Debian Trixie + LXDE + VSCodium over VNC

A minimal Debian (trixie-slim) desktop container running **LXDE** with **VSCodium**, accessible via **x11vnc**. 
Designed for Apple Silicon (ARM64) hosts but should work on any arm64-capable Docker environment.

> **Note on “59 Hz”**: Virtual displays created with `Xvfb` don’t expose a real refresh rate like physical GPUs. 
> You can set **resolution** and **color depth** (e.g., `1920x1080` and `24-bit`). Your VNC viewer’s perceived 
> frame rate depends on encoding and network conditions—not a fixed “59 Hz”.

## Features
- Debian `trixie-slim` base with **LXDE** lightweight desktop.
- **Papirus** icon theme.
- **VSCodium** installed from the maintained `.deb` repository.
- **x11vnc** + **Xvfb** for headless desktop access.
- Config via `.env` for VNC password, resolution, and depth.
- `docker-compose` for easy run/stop.

## Quick Start

1. **Create your `.env`** by copying the sample:
   ```bash
   cp sample.env .env
   # then edit .env to set a strong VNC password
   ```

2. **Build and run**:
   ```bash
   docker compose up --build
   ```

3. **Connect with a VNC client** (e.g., VNC Viewer, Remmina):
   - Host: `localhost`
   - Port: `5900`
   - Password: the value of `VNC_PASSWORD` from your `.env`

4. **Stop**:
   ```bash
   docker compose down
   ```

## Environment Variables

Defined in `.env`:

- `VNC_PASSWORD` (required): VNC password for **x11vnc**. Choose a strong one.
- `VNC_GEOMETRY` (default: `1920x1080`): Virtual desktop resolution (WIDTHxHEIGHT).
- `VNC_DEPTH` (default: `24`): Color depth (16/24/32 typical).

> Refresh rate (e.g., “59 Hz”) is **not applicable** to `Xvfb`.

## File Layout

```
.
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── xstartup
├── sample.env
├── .gitignore
└── README.md
```

## Security Notes
- This example exposes VNC on `0.0.0.0:5900`. For local testing that’s fine; for remote use, prefer tunneling over SSH or put it behind a VPN/reverse-proxy.
- `x11vnc` password auth is enabled. Use a strong password.
- Do **not** commit your real `.env` to Git—use `sample.env` for sharing.

## Known Limitations
- GPU acceleration is not configured; this is a CPU-rendered headless desktop via `Xvfb`.
- Real display refresh rates do not apply in this setup.
- Audio is not provisioned.

## License
MIT (for this template). Check upstream licenses for included packages.
