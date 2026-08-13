import 'dart:io';

/// A fake ADB executable for testing the runner.
///
/// It responds to common commands with canned output and mimics the
/// side-effects expected by the runner (e.g. creating sentinel files).
void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Android Debug Bridge version 1.0.41');
    return;
  }

  final cmd = arguments.join(' ');

  if (cmd.contains('connect')) {
    print('connected to 100.120.184.47:5555');
    return;
  }

  if (cmd.contains('get-state')) {
    print('device');
    return;
  }

  if (cmd.contains('root')) {
    print('restarting adbd as root');
    return;
  }

  if (cmd.contains('getprop ro.product.model')) {
    print('Pixel 3 XL');
    return;
  }

  if (cmd.contains('getprop ro.build.fingerprint')) {
    print(
      'google/crosshatch/crosshatch:12/SP1A.210812.015/7679544:user/release-keys',
    );
    return;
  }

  if (cmd.contains('UPTIME:') || cmd.contains('cat /proc/uptime')) {
    // This is likely our new volatile probe script or an old individual command
    if (cmd.contains('UPTIME:')) {
      print('UPTIME: 1234.56 789.01');
      print('LOADAVG: 0.1 0.2 0.3 1/100 1234');
      print('MEMINFO: MemTotal: 8000000 kB');
      print('DATE: 2026-08-13T12:00:00+0000');
      print('CPU_ONLINE: 0-7');
      for (var i = 0; i < 8; i++) {
        print(
          'FREQ /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq: 1800000',
        );
      }
      for (var i = 0; i < 2; i++) {
        print(
          'THERMAL /sys/class/thermal/thermal_zone$i/type: cpu-thermal | 35000',
        );
      }
      print('THERMALSERVICE START');
      final throttling =
          Platform.environment['FAKE_ADB_THERMAL_THROTTLING'] == 'true';
      final status =
          Platform.environment['FAKE_ADB_THERMAL_STATUS'] ??
          (throttling ? '2' : '0');
      print('IsThrottling: $throttling');
      print('Thermal Status: $status');
      print('THERMALSERVICE END');

      // Handle sentinels
      final doneMatch = RegExp(
        r'if \[ -f "([^"]+)" \]; then echo "SENTINEL: DONE"; fi',
      ).firstMatch(cmd);
      if (doneMatch != null) {
        final doneFile = doneMatch.group(1)!;
        if (File(doneFile).existsSync()) {
          print('SENTINEL: DONE');
        }
      }
      final failedMatch = RegExp(
        r'if \[ -f "([^"]+)" \]; then echo "SENTINEL: FAILED"; fi',
      ).firstMatch(cmd);
      if (failedMatch != null) {
        final failedFile = failedMatch.group(1)!;
        if (File(failedFile).existsSync()) {
          print('SENTINEL: FAILED');
        }
      }
      return;
    } else {
      print('1234.56 789.01');
      return;
    }
  }

  if (cmd.contains('dumpsys thermalservice')) {
    final throttling =
        Platform.environment['FAKE_ADB_THERMAL_THROTTLING'] == 'true';
    final status =
        Platform.environment['FAKE_ADB_THERMAL_STATUS'] ??
        (throttling ? '2' : '0');
    print('IsThrottling: $throttling');
    print('Thermal Status: $status');
    return;
  }

  if (cmd.contains('cat /sys/class/thermal/thermal_zone')) {
    if (cmd.contains('type')) {
      print('cpu-thermal');
    } else {
      print('35000'); // 35C
    }
    return;
  }

  if (cmd.contains('install')) {
    print('Success');
    return;
  }

  if (cmd.contains('uninstall')) {
    print('Success');
    return;
  }

  if (cmd.contains('logcat -c')) {
    return;
  }

  if (cmd.contains('logcat')) {
    // Check if we should simulate a benchmark completion
    final simulateDone =
        Platform.environment['FAKE_ADB_SIMULATE_DONE'] == 'true';
    if (simulateDone) {
      print('INSTRUMENTATION_STATUS: class=com.example.app.MainActivityTest');
      print('INSTRUMENTATION_STATUS: test=testMethod');
      print('INSTRUMENTATION_STATUS_CODE: 1');
      print('BENCH_DONE 0');
    }
    // Stay alive until killed if it's a streaming logcat
    if (!cmd.contains('-d')) {
      // Keep process alive by waiting for a signal or just sleeping
      // We don't want to drain stdin as it might hang differently.
      // Just sleep for a long time.
      sleep(const Duration(hours: 1));
      return;
    }
    return;
  }

  if (cmd.contains('shell rm -rf')) {
    final path = cmd.split(' ').last;
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    return;
  }

  if (cmd.contains('shell mkdir -p')) {
    final path = cmd.split(' ').last;
    Directory(path).createSync(recursive: true);
    return;
  }

  if (cmd.contains('shell cmd package compile')) {
    print('Success');
    return;
  }

  if (cmd.contains('am instrument')) {
    // Simulate creating the DONE file after a short delay
    final resultDirMatch = RegExp(
      r'device_result_dir=([^\s]+)',
    ).firstMatch(cmd);
    // In our test, the result dir is passed via environment or hardcoded in spec.
    // But the runner cleans it.
    // For simplicity, let's just create it in the hardcoded test path if it's am instrument.
    // Actually, we can just rely on the test to create it, but we need to wait for the runner to finish cleaning.

    print(
      'INSTRUMENTATION_STATUS: class=dev.flutter.plugins.integration_test.FlutterTestRunner',
    );
    print('INSTRUMENTATION_STATUS: test=sample_test');
    print('INSTRUMENTATION_STATUS_CODE: 1');
    print('INSTRUMENTATION_RESULT: stream=');
    print('INSTRUMENTATION_CODE: -1');
    return;
  }

  if (cmd.contains('test -f')) {
    stderr.writeln('DEBUG: test -f command: $cmd');
    // Extract the path from 'test -f <path>'
    final match = RegExp(r'test -f\s+([^\s&]+)').firstMatch(cmd);
    if (match != null) {
      final path = match.group(1)!;
      stderr.writeln('DEBUG: extracted path: $path');
      if (File(path).existsSync()) {
        stderr.writeln('DEBUG: path exists!');
        print('YES');
      } else {
        stderr.writeln('DEBUG: path does NOT exist');
      }
    }
    return;
  }

  if (cmd.contains('pull')) {
    // adb pull <remote> <local>
    final parts = cmd.split(' ');
    final remote = parts[parts.length - 2];
    final local = parts.last;
    final remoteDir = Directory(remote);
    if (remoteDir.existsSync()) {
      final localDir = Directory(local);
      if (!localDir.existsSync()) localDir.createSync(recursive: true);
      for (final file in remoteDir.listSync()) {
        if (file is File) {
          file.copySync('${localDir.path}/${file.uri.pathSegments.last}');
        }
      }
    }
    return;
  }

  if (cmd.contains('pidof')) {
    // Return a fake PID by default so the runner thinks the process is alive.
    // If FAKE_ADB_PROCESS_GONE is true, return nothing.
    if (Platform.environment['FAKE_ADB_PROCESS_GONE'] == 'true') {
      return;
    }
    print('1234');
    return;
  }
}
