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

The NAS (Intel Celeron J4125) is **x86_64/amd64**. If you're building on an
Apple Silicon Mac, cross-build explicitly:

```sh
docker buildx build --platform linux/amd64 -t adb_server:nas adb_server
```

Copy the `adb_server/` directory (or just the files needed to build:
`Dockerfile`, `pubspec.yaml`, `pubspec.lock`, `bin/`, `lib/`,
`docker-compose.yml`, `.dockerignore`) onto the NAS, create a `.env` file
there from `.env.example`, and let Synology's **Container Manager** build
and run it from `docker-compose.yml` (Container Manager reads Compose
files directly -- Project > Create > "Create docker-compose.yml").

Make sure `/data` (sessions/results/logs) and `/root/.android` (adb key) are
backed by persistent NAS volumes/paths, not ephemeral container storage --
see the `docker-compose.yml` volumes for the exact mounts.

### A note on networking

On **macOS (Docker Desktop/OrbStack)**, do NOT use `network_mode: host`. It will
not work as expected and the container will likely fail to connect to your
device. The default bridge mode works fine and handles Tailscale routing.

On the **Synology NAS**, `network_mode: host` IS recommended (and often
required) so the container can see the local network and the ADB device.

### The ADB authorisation trap

The container generates its own `adbkey` the first time it runs `adb`. The
device under test (DUT) will report `unauthorized` and, because this rig
is headless and unattended, **nobody is there to tap "Allow" at 2am**.
Fix this once, before relying on unattended trials:

1. **Persist the key and authorise interactively once.** With a display
   attached to the DUT, run the container (or `adb connect`/`adb shell`
   from inside it) so the "Allow USB debugging?" / "Allow debugging from
   this computer?" prompt appears, tap Allow (and "always allow from this
   computer" if offered). As long as `/root/.android` is a persistent
   volume (it is, by default, in `docker-compose.yml`), this survives
   container and NAS restarts.
2. **Or, if the DUT is rooted**, copy the container's `adbkey.pub`
   (`docker compose exec adb_server cat /root/.android/adbkey.pub`) into
   the device's `/data/misc/adb/adb_keys` (or `/adb_keys` depending on
   Android version) via `adb shell` or `su`.

## Preparing the Device Under Test (DUT)

Before the DUT is ready for unattended benchmarking, several one-time setup steps are required to ensure the environment is stable and doesn't prompt for human intervention.

### 1. Networking and ADB Stability
- **Static DHCP reservation:** Ensure the DUT has a fixed IP address so `DUT_ADDRESS` stays valid across reboots.
- **Persistent ADB over TCP/IP:** `adb tcpip 5555` (or setting `persist.adb.tcp.port` via a build prop / root) must be applied and **survive DUT reboots**. This generally requires root.

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

Per `REQUIREMENTS.md` §10, once the trial lifecycle is implemented, an
`unauthorized` `adb get-state` must surface verbatim in the API response
and `session.log` (not a generic non-zero exit code) and point back to the
authorisation section.
