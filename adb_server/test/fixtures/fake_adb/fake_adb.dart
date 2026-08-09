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

  if (cmd.contains('getprop ro.build.fingerprint')) {
    print(
        'google/crosshatch/crosshatch:12/SP1A.210812.015/7679544:user/release-keys');
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

  if (cmd.contains('am instrument')) {
    print(
        'INSTRUMENTATION_STATUS: class=dev.flutter.plugins.integration_test.FlutterTestRunner');
    print('INSTRUMENTATION_STATUS: test=sample_test');
    print('INSTRUMENTATION_STATUS_CODE: 1');
    print('INSTRUMENTATION_RESULT: stream=');
    print('INSTRUMENTATION_CODE: -1');
    return;
  }

  if (cmd.contains('test -f')) {
    // Check if the file was created by the test
    final path = cmd.split(' ').lastWhere((s) => s.contains('/'));
    if (File(path).existsSync()) {
      print('YES');
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
    // By default return nothing (process gone) so the runner proceeds
    return;
  }
}
