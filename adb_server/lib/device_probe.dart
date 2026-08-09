import 'dart:async';
import 'adb.dart';

/// Collects device metadata as specified in `REQUIREMENTS.md` §7.
class DeviceProbe {
  final Adb adb;

  DeviceProbe(this.adb);

  /// Captures a comprehensive snapshot of the device state.
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

    // Build metadata (only once ideally, but probe() serves all cases)
    await capture('fingerprint', 'getprop ro.build.fingerprint');
    await capture('android_version', 'getprop ro.build.version.release');
    await capture('model', 'getprop ro.product.model');
    await capture('abi_list', 'getprop ro.product.cpu.abilist');

    if (warnings.isNotEmpty) {
      metadata['warnings'] = warnings;
    }

    return metadata;
  }
}
