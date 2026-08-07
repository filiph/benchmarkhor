# adb_server

Control-plane server for a Flutter/Dart performance-benchmarking rig. It
drives an Android device under test ("DUT") over ADB (TCP/IP) and stores raw
benchmark results as plain files on disk -- no database, no aggregation.

See `REQUIREMENTS.md` for the full design brief and `CONTRACT.md` for the
contract benchmark APKs must honour so the server can detect run completion.

## Status

This is an early skeleton ("the beginnings"). Implemented so far:

- Configuration from environment variables (`lib/config.dart`).
- Job/status data models with validation (`lib/models.dart`).
- Disk-backed job store: atomic writes, job discovery (including jobs
  dropped directly onto `jobs/` over SMB), and crash recovery of stale
  `running` jobs on startup (`lib/job_store.dart`).
- A minimal read-only HTTP API: `GET /health`, `GET /api/jobs`,
  `GET /api/jobs/<id>` (`lib/api.dart`, `bin/server.dart`).

Not implemented yet (see `REQUIREMENTS.md` for the full spec of each):

- `POST /api/jobs` (job submission), `POST /api/jobs/<id>/cancel`,
  `POST /api/queue/next` and the runner/mutual-exclusion machinery.
- The ADB wrapper, the run lifecycle, and device metadata probing.
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
curl http://localhost:8080/api/jobs
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

Data (`jobs/`, `archive/`, `device/`, `server.log`) is bind-mounted to
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

Make sure `/data` (jobs/results/logs) and `/root/.android` (adb key) are
backed by persistent NAS volumes/paths, not ephemeral container storage --
see the `docker-compose.yml` volumes for the exact mounts.

### The ADB authorisation trap

The container generates its own `adbkey` the first time it runs `adb`. The
device under test (DUT) will report `unauthorized` and, because this rig
is headless and unattended, **nobody is there to tap "Allow" at 2am**.
Fix this once, before relying on unattended runs:

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

Also make sure:

- `adb tcpip 5555` (or `persist.adb.tcp.port` set via a build prop /
  root) is applied on the DUT and **survives DUT reboots** -- this
  generally requires root.
- The DUT has a **static DHCP reservation** so `DUT_ADDRESS` stays valid
  across reboots.

Per `REQUIREMENTS.md` §10, once the run lifecycle is implemented, an
`unauthorized` `adb get-state` must surface verbatim in the API response
and `job.log` (not a generic non-zero exit code) and point back to this
section.
