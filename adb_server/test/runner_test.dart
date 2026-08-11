import 'dart:convert';
import 'dart:io';

import 'package:adb_server/config.dart';
import 'package:adb_server/models.dart';
import 'package:adb_server/runner.dart';
import 'package:adb_server/session_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late SessionStore store;
  late Config config;
  late String fakeAdbPath;

  setUpAll(() {
    fakeAdbPath = p.absolute('test/fixtures/fake_adb/adb');
    if (!File(fakeAdbPath).existsSync()) {
      throw StateError(
          'Fake ADB not found at $fakeAdbPath. Run make to build it.');
    }
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('adb_runner_test_');
    store = SessionStore(tempDir.path);
    config = Config(
      dutAddress: '100.120.184.47:5555',
      dataDir: tempDir.path,
      port: 8080,
      adbPath: fakeAdbPath,
      pollIntervalSeconds: 1,
      defaultTrialTimeoutSeconds: 30,
      thermalGateCelsius: 40,
      thermalGateTimeoutSeconds: 5,
      deviceProfileFile: null,
      deviceResetFile: null,
      profilesDir: p.join(tempDir.path, 'profiles'),
      precompilePackage: false,
      logLevel: 'info',
      gitCommit: 'abdabdabd',
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> setupValidSession(String sessionId) async {
    final dir = Directory(p.join(store.sessionsDir.path, sessionId));
    await dir.create(recursive: true);
    final spec = {
      'name': 'Test Session',
      'variants': {
        'v1': {'apk': 'app.apk', 'test_apk': 'test.apk'}
      },
      'package': 'com.example.app',
      'device_result_dir': p.join(tempDir.path, 'device_sdcard'),
      'rounds': 1,
    };
    await File(p.join(dir.path, 'session.json'))
        .writeAsString(jsonEncode(spec));
    await File(p.join(dir.path, 'app.apk')).create();
    await File(p.join(dir.path, 'test.apk')).create();
  }

  test('Runner executes a session and produces results', () async {
    final sessionId = '20260809__test';
    await setupValidSession(sessionId);
    await store.discoverNewSessions();

    final runner = Runner(config: config, sessionStore: store);

    // Create the device result dir and the DONE file so fake_adb "sees" it
    final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
    await deviceSdcard.create(recursive: true);

    // Start the runner
    final startedId = await runner.startNext();
    expect(startedId, sessionId);
    expect(Runner.isBusy, isTrue);

    // In a background loop, we wait for the runner to start the trial,
    // then we create the DONE file.
    // Since we are using fake_adb, it will respond to `test -f` based on this.

    // We wait a bit for the runner to start _run().
    await Future<void>.delayed(const Duration(seconds: 2));

    // Simulate app finishing
    await File(p.join(deviceSdcard.path, 'result.txt'))
        .writeAsString('bench results');
    await File(p.join(deviceSdcard.path, 'DONE')).create();

    // Wait for the runner to finish
    int attempts = 0;
    while (Runner.isBusy && attempts < 10) {
      await Future<void>.delayed(const Duration(seconds: 2));
      attempts++;
    }

    expect(Runner.isBusy, isFalse);
    final status = await store.readStatus(sessionId);
    expect(status!.state, SessionState.done);

    // Verify artifacts
    final trialDir = store.trialDir(sessionId, 'trial-001');
    expect(await trialDir.exists(), isTrue);
    expect(await File(p.join(trialDir.path, 'trial.json')).exists(), isTrue);
    expect(await File(p.join(trialDir.path, 'results_index.json')).exists(),
        isTrue);
    expect(await File(p.join(trialDir.path, 'results/result.txt')).exists(),
        isTrue);

    final indexRaw =
        await File(p.join(trialDir.path, 'results_index.json')).readAsString();
    final index = jsonDecode(indexRaw) as List<dynamic>;
    expect(index, hasLength(2));
    expect(index.any((e) => e['filename'] == 'result.txt'), isTrue);
    expect(index.any((e) => e['filename'] == 'DONE'), isTrue);
  });

  test('Runner handles thermal gate timeout', () async {
    // Modify config to have a tight thermal gate that won't be met
    // (Our fake_adb returns 35C, so let's set gate to 30C)
    final tightConfig = Config(
      dutAddress: '100.120.184.47:5555',
      dataDir: tempDir.path,
      port: 8080,
      adbPath: fakeAdbPath,
      pollIntervalSeconds: 1,
      defaultTrialTimeoutSeconds: 30,
      thermalGateCelsius: 30, // 35C > 30C, so it will wait
      thermalGateTimeoutSeconds: 2,
      deviceProfileFile: null,
      deviceResetFile: null,
      profilesDir: p.join(tempDir.path, 'profiles'),
      precompilePackage: false,
      logLevel: 'info',
      gitCommit: 'abdabdabd',
    );

    final sessionId = '20260809__thermal';
    await setupValidSession(sessionId);
    await store.discoverNewSessions();

    final runner = Runner(config: tightConfig, sessionStore: store);

    final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
    await deviceSdcard.create(recursive: true);
    await File(p.join(deviceSdcard.path, 'DONE')).create();

    await runner.startNext();

    int attempts = 0;
    while (Runner.isBusy && attempts < 10) {
      await Future<void>.delayed(const Duration(seconds: 2));
      attempts++;
    }

    final metadata = TrialMetadata.fromJson(jsonDecode(await store
        .trialMetadataFile(sessionId, 'trial-001')
        .readAsString()) as Map<String, dynamic>);

    expect(metadata.warnings, contains(contains('Thermal gate timeout')));
  });

  test('Runner applies device profile and reset profile', () async {
    final profileFile = File(p.join(tempDir.path, 'profile.sh'));
    await profileFile.writeAsString(
        'echo performance > /sys/cpu/governor\n# comment\necho 1200000 > /sys/cpu/speed');

    final resetFile = File(p.join(tempDir.path, 'reset.sh'));
    await resetFile.writeAsString('echo schedutil > /sys/cpu/governor');

    final profileConfig = Config(
      dutAddress: '100.120.184.47:5555',
      dataDir: tempDir.path,
      port: 8080,
      adbPath: fakeAdbPath,
      pollIntervalSeconds: 1,
      defaultTrialTimeoutSeconds: 30,
      thermalGateCelsius: null,
      thermalGateTimeoutSeconds: 0,
      deviceProfileFile: profileFile.path,
      deviceResetFile: resetFile.path,
      profilesDir: p.join(tempDir.path, 'profiles'),
      precompilePackage: false,
      logLevel: 'info',
      gitCommit: 'abdabdabd',
    );

    final sessionId = '20260809__profile';
    await setupValidSession(sessionId);
    await store.discoverNewSessions();

    final runner = Runner(config: profileConfig, sessionStore: store);

    final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
    await deviceSdcard.create(recursive: true);
    await File(p.join(deviceSdcard.path, 'DONE')).create();

    await runner.startNext();

    int attempts = 0;
    while (Runner.isBusy && attempts < 10) {
      await Future<void>.delayed(const Duration(seconds: 1));
      attempts++;
    }

    // 1. Verify TrialMetadata records the profile
    final metadataFile = store.trialMetadataFile(sessionId, 'trial-001');
    final metadata = TrialMetadata.fromJson(
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>);

    expect(metadata.deviceProfile, contains('performance'));
    expect(metadata.deviceProfileSha256, isNotNull);

    // 2. Verify adb.log contains the commands
    final adbLog =
        await store.trialAdbLogFile(sessionId, 'trial-001').readAsString();
    expect(adbLog, contains('echo performance > /sys/cpu/governor'));
    expect(adbLog, contains('echo 1200000 > /sys/cpu/speed'));
    expect(adbLog, isNot(contains('# comment')));

    // 3. Verify session log contains reset application and root elevation
    final sessionLog = await store.sessionLogFile(sessionId).readAsString();
    expect(sessionLog, contains('Elevating to root...'));
    expect(sessionLog, contains('Applying device reset profile'));
  });

  test('Runner auto-detects device profile from model', () async {
    // Create a profile in the temp dir under a directory matching "Pixel 3 XL"
    // "Pixel 3 XL" cleaned -> "pixel3xl"
    // So we can use "pixel_3_xl" or "pixel3xl"
    final profileDir =
        Directory(p.join(tempDir.path, 'profiles', 'pixel_3_xl'));
    await profileDir.create(recursive: true);
    final profileFile = File(p.join(profileDir.path, 'performance.sh'));
    await profileFile.writeAsString('echo auto-detected > /sys/cpu/mode');

    final autoConfig = Config(
      dutAddress: '100.120.184.47:5555',
      dataDir: tempDir.path,
      port: 8080,
      adbPath: fakeAdbPath,
      pollIntervalSeconds: 1,
      defaultTrialTimeoutSeconds: 30,
      thermalGateCelsius: null,
      thermalGateTimeoutSeconds: 0,
      deviceProfileFile: null, // No explicit profile
      deviceResetFile: null,
      profilesDir: p.join(tempDir.path, 'profiles'),
      precompilePackage: false,
      logLevel: 'info',
      gitCommit: 'abdabdabd',
    );

    final sessionId = '20260809__auto';
    await setupValidSession(sessionId);
    await store.discoverNewSessions();

    final runner = Runner(config: autoConfig, sessionStore: store);

    final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
    await deviceSdcard.create(recursive: true);
    await File(p.join(deviceSdcard.path, 'DONE')).create();

    await runner.startNext();

    int attempts = 0;
    while (Runner.isBusy && attempts < 10) {
      await Future<void>.delayed(const Duration(seconds: 1));
      attempts++;
    }

    final metadata = TrialMetadata.fromJson(jsonDecode(await store
        .trialMetadataFile(sessionId, 'trial-001')
        .readAsString()) as Map<String, dynamic>);

    expect(metadata.deviceProfile, contains('auto-detected'));

    final adbLog =
        await store.trialAdbLogFile(sessionId, 'trial-001').readAsString();
    expect(adbLog, contains('echo auto-detected > /sys/cpu/mode'));
  });
}
