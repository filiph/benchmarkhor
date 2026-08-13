import 'dart:async';
import 'adb.dart';

/// Represents thermal throttling status parsed from `dumpsys thermalservice`.
class ThermalServiceStatus {
  final bool isThrottling;
  final int? statusLevel;
  final String rawOutput;
  final String? error;

  ThermalServiceStatus({
    required this.isThrottling,
    this.statusLevel,
    required this.rawOutput,
    this.error,
  });

  static ThermalServiceStatus parse(String output) {
    bool isThrottling = false;
    int? statusLevel;

    final throttlingMatch = RegExp(
      r'IsThrottling:\s*(true|false)',
      caseSensitive: false,
    ).firstMatch(output);
    if (throttlingMatch != null) {
      isThrottling = throttlingMatch.group(1)!.toLowerCase() == 'true';
    }

    final statusMatch = RegExp(
      r'(?:Thermal|HAL)\s+Status:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (statusMatch != null) {
      statusLevel = int.tryParse(statusMatch.group(1)!);
      if (statusLevel != null && statusLevel > 0) {
        if (throttlingMatch == null) {
          isThrottling = true;
        }
      }
    }

    return ThermalServiceStatus(
      isThrottling: isThrottling,
      statusLevel: statusLevel,
      rawOutput: output,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_throttling': isThrottling,
        if (statusLevel != null) 'status_level': statusLevel,
        if (rawOutput.isNotEmpty) 'raw': rawOutput,
        if (error != null) 'error': error,
      };
}

/// Collects device metadata as specified in `REQUIREMENTS.md` §7.
class DeviceProbe {
  final Adb adb;

  DeviceProbe(this.adb);

  /// Checks `dumpsys thermalservice` specifically.
  Future<ThermalServiceStatus> checkThermalService() async {
    try {
      final result = await adb.shell('dumpsys thermalservice');
      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        return ThermalServiceStatus.parse(output);
      } else {
        return ThermalServiceStatus(
          isThrottling: false,
          rawOutput: '',
          error:
              'Command failed: dumpsys thermalservice (exit ${result.exitCode})',
        );
      }
    } catch (e) {
      return ThermalServiceStatus(
        isThrottling: false,
        rawOutput: '',
        error: 'Error running dumpsys thermalservice: $e',
      );
    }
  }

  Future<Map<String, dynamic>> probe() async {
    final metadata = <String, dynamic>{};
    final warnings = <String>[];

    Future<void> capture(String key, String command,
        {String? Function(String)? parser}) async {
      try {
        final result = await adb.shell(command);
        if (result.exitCode == 0) {
          final output = (result.stdout as String).trim();
          metadata[key] = parser != null ? parser(output) : output;
        } else {
          metadata[key] = null;
          warnings.add('Command failed: $command (exit ${result.exitCode})');
        }
      } catch (e) {
        metadata[key] = null;
        warnings.add('Error running $command: $e');
      }
    }

    // Per-run metadata
    await capture('uptime', 'cat /proc/uptime');
    await capture('loadavg', 'cat /proc/loadavg');
    await capture('meminfo', 'cat /proc/meminfo');
    await capture('date', 'date +%Y-%m-%dT%H:%M:%S%z');

    // CPU metadata
    await capture('cpu_online', 'cat /sys/devices/system/cpu/online');

    // Attempt to get per-core frequencies
    final frequencies = <String, String>{};
    for (var i = 0; i < 8; i++) {
      final res = await adb
          .shell('cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq');
      if (res.exitCode == 0) {
        frequencies['cpu$i'] = (res.stdout as String).trim();
      }
    }
    if (frequencies.isNotEmpty) metadata['cpu_frequencies'] = frequencies;

    // Thermal metadata
    final temperatures = <Map<String, String>>[];
    for (var i = 0; i < 20; i++) {
      final typeRes =
          await adb.shell('cat /sys/class/thermal/thermal_zone$i/type');
      if (typeRes.exitCode != 0) break;
      final tempRes =
          await adb.shell('cat /sys/class/thermal/thermal_zone$i/temp');
      if (tempRes.exitCode == 0) {
        temperatures.add({
          'type': (typeRes.stdout as String).trim(),
          'temp': (tempRes.stdout as String).trim(),
        });
      }
    }
    if (temperatures.isNotEmpty) metadata['temperatures'] = temperatures;

    // Thermal service metadata
    final thermalStatus = await checkThermalService();
    metadata['thermalservice'] = thermalStatus.toJson();
    if (thermalStatus.error != null) {
      warnings.add(thermalStatus.error!);
    }

    // Build metadata (only once ideally, but probe() serves all cases)
    await capture('fingerprint', 'getprop ro.build.fingerprint');
    await capture('android_version', 'getprop ro.build.version.release');
    await capture('model', 'getprop ro.product.model');
    await capture('abi_list', 'getprop ro.product.cpu.abilist');

    // Display metadata
    await capture('display_size', 'wm size');
    await capture('display_density', 'wm density');
    await capture('display_rotation', 'settings get system user_rotation');
    await capture(
        'display_orientation_prop', 'getprop persist.sys.orientation');

    final refreshRate = await _getRefreshRate();
    if (refreshRate != null) {
      metadata['display_refresh_rate'] = refreshRate;
    }

    if (warnings.isNotEmpty) {
      metadata['warnings'] = warnings;
    }

    return metadata;
  }

  /// Returns the temperature of the first 'soc-thermal' or 'cpu-thermal' zone,
  /// or null if not found or offline.
  Future<double?> getSocTemp() async {
    for (var i = 0; i < 20; i++) {
      final typeRes =
          await adb.shell('cat /sys/class/thermal/thermal_zone$i/type');
      if (typeRes.exitCode != 0) break;
      final type = (typeRes.stdout as String).trim();
      if (type == 'soc-thermal' || type == 'cpu-thermal') {
        final tempRes =
            await adb.shell('cat /sys/class/thermal/thermal_zone$i/temp');
        if (tempRes.exitCode == 0) {
          final val = double.tryParse((tempRes.stdout as String).trim());
          if (val != null) {
            return val > 1000 ? val / 1000.0 : val;
          }
        }
      }
    }
    return null;
  }

  Future<String?> _getRefreshRate() async {
    try {
      final res = await adb.shell('dumpsys display');
      if (res.exitCode == 0) {
        final output = res.stdout as String;
        // Common pattern: "refreshRate 60.0" or "fps=60.0"
        final match =
            RegExp(r'(?:refreshRate|fps)[:=]\s*(\d+\.?\d*)').firstMatch(output);
        return match?.group(1);
      }
    } catch (_) {}
    return null;
  }
}
