/// Server configuration, read once at startup from environment variables.
///
/// See `REQUIREMENTS.md` §9 for the full list of supported variables and
/// their defaults.
class Config {
  /// Address of the device under test, e.g. `192.168.1.42:5555`.
  final String dutAddress;

  /// NAS-backed root directory holding all session state. See `REQUIREMENTS.md`
  /// §4.
  final String dataDir;

  /// TCP port the HTTP server listens on.
  final int port;

  /// Path to (or name of) the `adb` executable. Overridable so tests can
  /// point at a fake adb fixture.
  final String adbPath;

  /// How often (in seconds) the runner polls the device for trial completion.
  final int pollIntervalSeconds;

  /// Default per-trial timeout, used when a session doesn't specify its own.
  final int defaultTrialTimeoutSeconds;

  /// SoC temperature (Celsius) below which a trial is allowed to start. If
  /// null, the thermal gate is disabled.
  final double? thermalGateCelsius;

  /// How long to wait for the thermal gate before proceeding anyway.
  final int thermalGateTimeoutSeconds;

  /// Path to a newline-separated file of shell commands to run on the DUT
  /// before each trial (e.g. to pin CPU governor/frequency). If null, no
  /// device profile is applied.
  final String? deviceProfileFile;

  /// Path to a newline-separated file of shell commands to run on the DUT
  /// after the entire session finishes, to restore it to defaults. If null,
  /// no reset is performed.
  final String? deviceResetFile;

  /// Whether to force `speed` AOT compilation right after install.
  final bool precompilePackage;

  /// Logging verbosity, e.g. `info`, `fine`, `warning`.
  final String logLevel;

  const Config({
    required this.dutAddress,
    required this.dataDir,
    required this.port,
    required this.adbPath,
    required this.pollIntervalSeconds,
    required this.defaultTrialTimeoutSeconds,
    required this.thermalGateCelsius,
    required this.thermalGateTimeoutSeconds,
    required this.deviceProfileFile,
    required this.deviceResetFile,
    required this.precompilePackage,
    required this.logLevel,
  });

  /// Builds a [Config] from process environment variables.
  ///
  /// Throws a [StateError] if a required variable (currently only
  /// `DUT_ADDRESS`) is missing.
  factory Config.fromEnvironment(Map<String, String> env) {
    final dutAddress = env['DUT_ADDRESS'];
    if (dutAddress == null || dutAddress.isEmpty) {
      throw StateError(
        'DUT_ADDRESS environment variable is required, '
        'e.g. DUT_ADDRESS=192.168.1.42:5555',
      );
    }

    return Config(
      dutAddress: dutAddress,
      dataDir: env['DATA_DIR'] ?? '/data',
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      adbPath: env['ADB_PATH'] ?? 'adb',
      pollIntervalSeconds:
          int.tryParse(env['POLL_INTERVAL_SECONDS'] ?? '') ?? 15,
      defaultTrialTimeoutSeconds:
          int.tryParse(env['DEFAULT_TRIAL_TIMEOUT_SECONDS'] ?? '') ??
              int.tryParse(env['DEFAULT_RUN_TIMEOUT_SECONDS'] ?? '') ??
              1800,
      thermalGateCelsius: double.tryParse(env['THERMAL_GATE_CELSIUS'] ?? ''),
      thermalGateTimeoutSeconds:
          int.tryParse(env['THERMAL_GATE_TIMEOUT_SECONDS'] ?? '') ?? 300,
      deviceProfileFile: env['DEVICE_PROFILE_FILE'],
      deviceResetFile: env['DEVICE_RESET_FILE'],
      precompilePackage:
          (env['PRECOMPILE_PACKAGE'] ?? 'true').toLowerCase() != 'false',
      logLevel: env['LOG_LEVEL'] ?? 'info',
    );
  }

  /// A JSON-serialisable summary, safe to embed in `/health` responses and
  /// in every `trial.json`.
  Map<String, dynamic> toJson() => {
        'dut_address': dutAddress,
        'data_dir': dataDir,
        'port': port,
        'adb_path': adbPath,
        'poll_interval_seconds': pollIntervalSeconds,
        'default_trial_timeout_seconds': defaultTrialTimeoutSeconds,
        'thermal_gate_celsius': thermalGateCelsius,
        'thermal_gate_timeout_seconds': thermalGateTimeoutSeconds,
        'device_profile_file': deviceProfileFile,
        'device_reset_file': deviceResetFile,
        'precompile_package': precompilePackage,
        'log_level': logLevel,
      };
}
