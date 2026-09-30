import 'dart:io';

typedef CommandExecutor = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Collects macOS host environment telemetry including thermal pressure.
class MacHostProbe {
  final CommandExecutor _runCommand;
  Map<String, String>? _cachedStaticInfo;

  MacHostProbe({CommandExecutor? commandExecutor})
      : _runCommand = commandExecutor ?? Process.run;

  /// Extracts numeric thermal pressure level from notifyutil output.
  static String parseThermalPressure(String output) {
    final match = RegExp(r'thermalpressurelevel\s+(\d+)').firstMatch(output);
    if (match != null) {
      return match.group(1)!;
    }
    final tokens = output.trim().split(RegExp(r'\s+'));
    if (tokens.isNotEmpty && RegExp(r'^\d+$').hasMatch(tokens.last)) {
      return tokens.last;
    }
    return output.trim().isEmpty ? 'unknown' : output.trim();
  }

  /// Parses `sw_vers` output into a concise OS version string.
  static String parseSwVers(String output) {
    String? name;
    String? version;
    String? build;
    for (final line in output.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join(':').trim();
        if (key == 'ProductName') name = value;
        if (key == 'ProductVersion') version = value;
        if (key == 'BuildVersion') build = value;
      }
    }
    if (name != null || version != null) {
      final ver = [name ?? 'macOS', version].where((s) => s != null && s.isNotEmpty).join(' ');
      if (build != null && build.isNotEmpty) {
        return '$ver ($build)';
      }
      return ver;
    }
    return output.trim().isEmpty ? 'macOS' : output.trim();
  }

  /// Extracts load averages from the `uptime` command string.
  static String parseLoadAvg(String uptimeOutput) {
    final match = RegExp(r'load averages?:\s*(.*)$').firstMatch(uptimeOutput);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return uptimeOutput.trim();
  }

  Future<Map<String, String>> _getStaticInfo() async {
    if (_cachedStaticInfo != null) {
      return _cachedStaticInfo!;
    }

    String model = 'unknown';
    try {
      final res = await _runCommand('sysctl', ['-n', 'hw.model']);
      if (res.exitCode == 0) {
        model = (res.stdout as String).trim();
      }
    } catch (_) {}

    String osVersion = 'macOS';
    try {
      final res = await _runCommand('sw_vers', []);
      if (res.exitCode == 0) {
        osVersion = parseSwVers(res.stdout as String);
      }
    } catch (_) {}

    String cpuBrand = 'unknown';
    try {
      final res = await _runCommand('sysctl', ['-n', 'machdep.cpu.brand_string']);
      if (res.exitCode == 0) {
        cpuBrand = (res.stdout as String).trim();
      }
    } catch (_) {}

    _cachedStaticInfo = {
      'model': model,
      'os_version': osVersion,
      'cpu_brand': cpuBrand,
    };
    return _cachedStaticInfo!;
  }

  /// Collects host telemetry and thermal state.
  Future<Map<String, dynamic>> probe() async {
    final staticInfo = await _getStaticInfo();

    String thermalPressure = 'unknown';
    try {
      final res = await _runCommand('notifyutil', [
        '-g',
        'com.apple.system.thermalpressurelevel',
      ]);
      if (res.exitCode == 0) {
        thermalPressure = parseThermalPressure(res.stdout as String);
      }
    } catch (_) {}

    String uptimeStr = '';
    String loadAvg = '';
    try {
      final res = await _runCommand('uptime', []);
      if (res.exitCode == 0) {
        uptimeStr = (res.stdout as String).trim();
        loadAvg = parseLoadAvg(uptimeStr);
      }
    } catch (_) {}

    return <String, dynamic>{
      'thermal_pressure': thermalPressure,
      'model': staticInfo['model'] ?? 'unknown',
      'os_version': staticInfo['os_version'] ?? 'macOS',
      'cpu_brand': staticInfo['cpu_brand'] ?? 'unknown',
      if (loadAvg.isNotEmpty) 'loadavg': loadAvg,
      if (uptimeStr.isNotEmpty) 'uptime': uptimeStr,
    };
  }
}
