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

  Future<Map<String, dynamic>> probeStatic() async {
    final metadata = <String, dynamic>{};
    final warnings = <String>[];

    Future<void> capture(String key, String command) async {
      try {
        final result = await adb.shell(command);
        if (result.exitCode == 0) {
          metadata[key] = (result.stdout as String).trim();
        } else {
          metadata[key] = null;
          warnings.add('Command failed: $command (exit ${result.exitCode})');
        }
      } catch (e) {
        metadata[key] = null;
        warnings.add('Error running $command: $e');
      }
    }

    await capture('fingerprint', 'getprop ro.build.fingerprint');
    await capture('android_version', 'getprop ro.build.version.release');
    await capture('model', 'getprop ro.product.model');
    await capture('abi_list', 'getprop ro.product.cpu.abilist');
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

  Future<Map<String, dynamic>> probeVolatile({
    String? doneFile,
    String? failedFile,
  }) async {
    final script = StringBuffer();
    script.writeln('echo "UPTIME: \$(cat /proc/uptime)"');
    script.writeln('echo "LOADAVG: \$(cat /proc/loadavg)"');
    script.writeln('echo "MEMINFO: \$(cat /proc/meminfo | head -n 10)"');
    script.writeln('echo "DATE: \$(date +%Y-%m-%dT%H:%M:%S%z)"');
    script.writeln('echo "CPU_ONLINE: \$(cat /sys/devices/system/cpu/online)"');
    script.writeln(
        'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do echo "FREQ \$f: \$(cat \$f)"; done');
    script.writeln(
        'for f in /sys/class/thermal/thermal_zone*/type; do t=\$(echo \$f | sed "s/type/temp/"); echo "THERMAL \$f: \$(cat \$f) | \$(cat \$t)"; done');
    script.writeln('echo "THERMALSERVICE START"');
    script.writeln('dumpsys thermalservice');
    script.writeln('echo "THERMALSERVICE END"');
    if (doneFile != null) {
      script.writeln('if [ -f "$doneFile" ]; then echo "SENTINEL: DONE"; fi');
    }
    if (failedFile != null) {
      script.writeln(
          'if [ -f "$failedFile" ]; then echo "SENTINEL: FAILED"; fi');
    }

    final result = await adb.shell(script.toString());
    if (result.exitCode != 0) {
      return {'error': 'Volatile probe failed (exit ${result.exitCode})'};
    }

    final metadata = <String, dynamic>{};
    final output = result.stdout as String;
    final lines = output.split('\n');

    final frequencies = <String, String>{};
    final temperatures = <Map<String, String>>[];
    final thermalServiceBuffer = StringBuffer();
    bool inThermalService = false;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('UPTIME: ')) {
        metadata['uptime'] = line.substring(8);
      } else if (line.startsWith('LOADAVG: ')) {
        metadata['loadavg'] = line.substring(9);
      } else if (line.startsWith('MEMINFO: ')) {
        metadata['meminfo'] = (metadata['meminfo'] ?? '') + line.substring(9) + '\n';
      } else if (line.startsWith('DATE: ')) {
        metadata['date'] = line.substring(6);
      } else if (line.startsWith('CPU_ONLINE: ')) {
        metadata['cpu_online'] = line.substring(12);
      } else if (line.startsWith('FREQ ')) {
        final match = RegExp(r'FREQ .*/cpu(\d+)/.*: (.*)').firstMatch(line);
        if (match != null) {
          frequencies['cpu${match.group(1)}'] = match.group(2)!;
        }
      } else if (line.startsWith('THERMAL ')) {
        final match = RegExp(r'THERMAL .*: (.*) \| (.*)').firstMatch(line);
        if (match != null) {
          temperatures.add({
            'type': match.group(1)!.trim(),
            'temp': match.group(2)!.trim(),
          });
        }
      } else if (line == 'THERMALSERVICE START') {
        inThermalService = true;
      } else if (line == 'THERMALSERVICE END') {
        inThermalService = false;
        metadata['thermalservice'] =
            ThermalServiceStatus.parse(thermalServiceBuffer.toString())
                .toJson();
      } else if (inThermalService) {
        thermalServiceBuffer.writeln(line);
      } else if (line.startsWith('SENTINEL: ')) {
        metadata['sentinel'] = line.substring(10);
      }
    }

    if (frequencies.isNotEmpty) metadata['cpu_frequencies'] = frequencies;
    if (temperatures.isNotEmpty) metadata['temperatures'] = temperatures;

    return metadata;
  }

  Future<Map<String, dynamic>> probe() async {
    final s = await probeStatic();
    final v = await probeVolatile();
    return {...s, ...v};
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
