# adb_server

Control-plane server for a Flutter/Dart performance-benchmarking rig. It
drives an Android device under test ("DUT") over ADB (TCP/IP) and stores raw
benchmark results as plain files on disk -- no database, no aggregation.

See `REQUIREMENTS.md` for the full design brief and `CONTRACT.md` for the
contract benchmark APKs must honour so the server can detect trial completion.

## Status

This is an early skeleton ("the beginnings"). Implemented so far:

- Configuration from environment variables (`lib/config.dart`).
- Session/status data models with validation (`lib/models.dart`).
- Disk-backed session store: atomic writes, session discovery (including sessions
  dropped directly onto `sessions/` over SMB), and crash recovery of stale
  `running` sessions on startup (`lib/session_store.dart`).
- A minimal HTTP API: `GET /health`, `GET /api/sessions`,
  `GET /api/sessions/<id>`, `GET /api/device` (probe), `POST /api/sessions` (submission),
  `POST /api/sessions/<id>/cancel` (`lib/api.dart`, `bin/server.dart`).
- The ADB wrapper (`lib/adb.dart`), the trial lifecycle/runner (`lib/runner.dart`),
  and device metadata probing (`lib/device_probe.dart`).

Not implemented yet (see `REQUIREMENTS.md` for the full spec of each):

- The HTML status page.
- The fake-adb test fixture.

## Running locally

```sh
cd adb_server
dart pub get
DUT_ADDRESS=192.168.1.42:5555 DATA_DIR=/tmp/adb_server_data dart run bin/server.dart
```

Then:

```sh
curl http://localhost:8080/health
curl http://localhost:8080/api/sessions
```

## Configuration

All configuration is via environment variables. See `REQUIREMENTS.md` §9 for
the full list; the only required variable is `DUT_ADDRESS`.

## Device Profiles

For stable benchmarks, it is recommended to lock CPU/GPU frequencies to avoid
thermal throttling and ensure reproducibility. See [PROFILES.md](PROFILES.md)
for pre-configured profiles for supported hardware (e.g., Orange Pi 5B).

## Testing

```sh
dart test
```

## Running in Docker (local dev, on your Mac with OrbStack)

The root of the repository has a `Makefile` with a local dev loop for this
container. It builds for your Mac's native architecture and is meant for
iterating -- it does **not** produce the `linux/amd64` image intended for
the NAS (see "Deploying to the Synology NAS" below).

From the repository root:

```sh
make up      # builds (if needed) and starts adb_server, detached
make logs    # follow logs
make down    # stop and remove the container
make test    # run `dart test` locally (uses the fake-adb fixture, no container needed)
```

`make up`/`make build` will create `adb_server/.env` from
`adb_server/.env.example` on first run if it doesn't exist yet -- edit it
and set at least `DUT_ADDRESS` to your device's `ip:port`. `.env` is
gitignored; it's machine-specific.

Data (`sessions/`, `archive/`, `device/`, `server.log`) is bind-mounted to
`adb_server/data/` on your Mac so you can inspect it directly. The adb key
(`~/.android` inside the container) is persisted in a named Docker volume
(`adb_key`) so re-running `make up` doesn't lose device authorisation.

## Deploying to the Synology NAS

The recommended workflow for Synology deployment uses **GitHub Container Registry (GHCR)** for image distribution, but you can also **manually upload** the image if GHCR authentication is problematic on your NAS.

### 1. Build and Push to GHCR

From your local development machine (e.g., Mac), run the following from the repository root:

```sh
make push
```

This builds a multi-arch image (`linux/amd64` for Intel NAS and `linux/arm64` for ARM NAS) and pushes it to `ghcr.io/filiph/adb_server:latest`. 

**Note on Permissions:**
GitHub Packages are **private by default**. If your NAS gives an `unauthorized` error during pull, you have three options:
- **Option A (Recommended):** Make the package public. Go to your GitHub profile > Packages > `adb_server` > Package Settings > Danger Zone > Change visibility to **Public**.
- **Option B:** Authenticate your NAS via SSH (see the troubleshooting guide).
- **Option C (GUI Only):** Use the manual export/upload workflow (see [Manual Image Upload](#manual-image-upload-no-registry) below).

### 2. Configure on Synology

1. Open **Container Manager** on your Synology NAS.
2. Go to **Project** > **Create**.
3. Set a Project Name (e.g., `adb-server`).
4. Set the path to a folder on your NAS.
5. Choose **Upload docker-compose.yml** and upload the `adb_server/docker-compose.nas.yml` file.
6. Edit the environment variables in the wizard (or via the UI later):
    - `DUT_ADDRESS`: The IP and port of your phone (e.g., `192.168.1.50:5555`).
    - `PORT`: The port the server should listen on (e.g., `60106`). See "Networking" below for why this doubles as the *external* port.
7. **Important volumes:** Ensure the bind mounts in `docker-compose.nas.yml` point to actual folders on your NAS (e.g., `/volume1/docker/adb_server/data`).

### 3. Networking

The Synology deployment uses `network_mode: host`. This is required for the container to easily discover and connect to your Android device on the local network.

Because of `network_mode: host`, the container shares the NAS's own network interface directly -- there's no `ports:` mapping (like `"60102:3001"`) to configure, unlike bridge-networked services (e.g. Uptime Kuma). Instead, whatever value you set for the `PORT` environment variable *is* the port exposed on the NAS, so pick one that isn't already used by another service (e.g. `60106`) and access the server at `http://<nas-ip>:<PORT>`.

### 4. ADB Authorization

When the container first connects to your phone, you will see an "Allow USB debugging?" prompt on the phone's screen. 
1. Tap **Allow** (and check "Always allow from this computer").
2. The RSA keys will be persisted in the `/root/.android` volume (mapped to `/volume1/docker/adb_server/adb_keys` on your NAS), so you won't need to do this again after a restart.

### Manual Image Upload (No Registry)

If you prefer not to use GHCR or encounter authentication issues, you can export the image from your development machine and upload it directly to the NAS:

1. **Export the image locally:**
   Run the following from the repository root on your Mac:
   ```sh
   make export
   ```
   This creates a file named `adb_server.tar` in the root directory. It defaults to `linux/amd64` (Intel NAS). If you have an ARM-based NAS, use `PLATFORM=linux/arm64 make export`.

2. **Upload to Synology:**
   - Open **Container Manager** > **Image**.
   - Click **Add** > **From file**.
   - Select the `adb_server.tar` file you just created.

3. **Deploy the Project:**
   Use the `docker-compose.nas.yml` as described in step 2 above. When you start the project, Container Manager will see the image is already present locally and won't try to pull it from GHCR.

### GHCR Authentication on Synology (via SSH)

If you keep your container image private, you must tell Synology how to log in to GHCR:

1. **Create a GitHub PAT:** Go to GitHub > Settings > Developer settings > Personal access tokens > Tokens (classic). Generate a new token with the `read:packages` scope. Copy it.
2. **Add Registry to Synology:**
    - Open **Container Manager** > **Registry**.
    - Click **Settings** (or **Add** > **Add Registry** depending on DSM version).
    - Choose **Custom** / **Docker Hub** (some versions use a generic list).
    - Click **Add**.
    - Registry URL: `https://ghcr.io`
    - Username: Your GitHub username.
    - Password: The **Personal Access Token** you just created.
3. **Re-run Project:** Go to your Project in Container Manager and click **Build** or **Action** > **Clean up & Start**.

## Preparing the Device Under Test (DUT)

Before the DUT is ready for unattended benchmarking, several one-time setup steps are required to ensure the environment is stable and doesn't prompt for human intervention.

### 1. Networking and ADB Stability
- **Static DHCP reservation:** Ensure the DUT has a fixed IP address so `DUT_ADDRESS` stays valid across reboots.
- **Persistent ADB over TCP/IP:** `adb tcpip 5555` (or setting `persist.adb.tcp.port` via a build prop / root) must be applied and **survive DUT reboots**. This generally requires root.
- IF using Tailscale, install the Tailscale app, connect. Then go to Settings > Networking > VPN, click on the Gear icon next to Tailscale, and enable **Always-on VPN**.

### 2. The ADB Authorisation Trap
See the [The ADB authorisation trap](#the-adb-authorisation-trap) section above for details on how to handle the initial "Allow USB debugging?" prompt.

### 3. Disabling Play Protect Prompts
Google Play Protect will often block unknown APKs (like your benchmark trials) and show a "Send app for a security check?" prompt. This will hang the automated trial indefinitely.

To permanently disable this, run the following command once from your workstation while the device is connected via ADB:

```sh
adb shell settings put global package_verifier_user_consent -1
```

### 4. Developer Options
You may have to enable Developer Mode by going to Settings > About and clicking the Build number several times.
In the device's **Developer Options**, ensure the following are set:
- **Verify apps over USB:** OFF (This is the GUI equivalent of the command above, but verify it's off).
- **Stay awake:** ON (Screen will never sleep while charging).
- **Disable adb authorization timeout:** ON


### 5. Disable System Updates and Notifications
To minimize background interference during trials:
- Disable automatic system updates in Developer Options or System settings.
- Enable "Do Not Disturb" mode.
- (Optional) Uninstall or disable unnecessary background apps.

### 6. Display Orientation (Portrait Mode)
For certain benchmarks, it is desirable to have the display in portrait mode (e.g., to match a typical mobile phone usage). For the Orange Pi 5B, this can be set once via ADB and will persist across reboots.

Run these commands once from your workstation:

```sh
# Disable auto-rotation (accelerometer)
adb shell settings put system accelerometer_rotation 0

# Set rotation to portrait (90 degrees clockwise)
# 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
adb shell settings put system user_rotation 1
```

Orange Pi 5B does _not_ follow these instructions because it has
a `setprop` override. For Orange Pi 5B (and similar devices), you'll need to:

```
adb shell setprop persist.sys.app.rotation original
adb reboot
```

**Note:** These settings are persistent. You can verify the current rotation state by observing the display attached to the HDMI port.

Per `REQUIREMENTS.md` §10, once the trial lifecycle is implemented, an
`unauthorized` `adb get-state` must surface verbatim in the API response
and `session.log` (not a generic non-zero exit code) and point back to the
authorisation section.
