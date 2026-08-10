# Device Profiles

To ensure stable benchmark results, the `adb_server` can apply a **Device Profile** (shell commands) before each trial and a **Reset Profile** after the session.

## Orange Pi 5B (RK3588S)

The Orange Pi 5B can experience thermal throttling at its peak frequencies (2.3GHz+). We provide a profile that locks the CPU clusters and GPU at stable, fixed frequencies.

### Location
- Performance Profile: `profiles/orange_pi_5b/performance.sh`
- Reset Profile: `profiles/orange_pi_5b/reset.sh`

### Usage
Set the following environment variables when starting the server:

```bash
DEVICE_PROFILE_FILE=profiles/orange_pi_5b/performance.sh
DEVICE_RESET_FILE=profiles/orange_pi_5b/reset.sh
```

### Applied Settings
- **CPUs 0-3 (Little):** Locked at 1.416 GHz (Governor: `performance`)
- **CPUs 4-7 (Big):** Locked at 1.8 GHz (Governor: `performance`)
- **GPU:** Locked at 700 MHz (Governor: `performance`)

### Verification
You can verify these settings are applied by checking `trial.json` metadata in the session directory or by viewing `adb.log` for each trial.
