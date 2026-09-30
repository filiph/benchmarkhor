import 'dart:io';
import 'package:adb_server/adb.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  late String fakeAdbPath;

  setUpAll(() {
    final adbName = Platform.isWindows ? 'adb.exe' : 'adb';
    fakeAdbPath = p.absolute('test/fixtures/fake_adb/$adbName');
  });

  test('Adb.connect handles success', () async {
    final adb = Adb(adbPath: fakeAdbPath, deviceAddress: '100.120.184.47:5555');
    final success = await adb.connect();
    expect(success, isTrue);
  });

  test('Adb.run handles timeout', () async {
    // We need a way to make the fake adb slow.
    // Since we can't easily modify fake_adb without rebuilding it,
    // let's just use 'sleep' on unix as a fake adb.
    if (Platform.isWindows) return; // Skip on windows for simplicity

    final adb = Adb(adbPath: 'sleep', deviceAddress: '127.0.0.1:5555');
    final stopwatch = Stopwatch()..start();
    final result = await adb.run(
      ['2'],
      useDevice: false,
      timeout: Duration(seconds: 1),
    );
    stopwatch.stop();

    expect(result.exitCode, -1);
    expect(result.stdout, contains('Timed out'));
    expect(stopwatch.elapsed.inSeconds, lessThan(2));
  });

  test('Adb.clearPackage succeeds', () async {
    final adb = Adb(adbPath: fakeAdbPath, deviceAddress: '100.120.184.47:5555');
    await expectLater(adb.clearPackage('com.example.app'), completes);
  });

  test('Adb.reboot and waitForBootCompleted cycle', () async {
    final stateFile = File(
      p.join(
        Directory.systemTemp.path,
        'fake_adb_reboot_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    final env = {'FAKE_ADB_REBOOT_STATE_FILE': stateFile.path};
    final adb = Adb(
      adbPath: fakeAdbPath,
      deviceAddress: '100.120.184.47:5555',
      environment: env,
    );

    try {
      await adb.reboot(disconnectTimeout: const Duration(seconds: 2));
      expect(stateFile.existsSync(), isTrue);

      final bootCompleted = await adb.waitForBootCompleted(
        timeout: const Duration(seconds: 5),
        initialDelay: const Duration(milliseconds: 50),
        maxDelay: const Duration(milliseconds: 200),
      );
      expect(bootCompleted, isTrue);
    } finally {
      if (stateFile.existsSync()) stateFile.deleteSync();
    }
  });
}
