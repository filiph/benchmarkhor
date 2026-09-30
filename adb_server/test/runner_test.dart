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
    final adbName = Platform.isWindows ? 'adb.exe' : 'adb';
    fakeAdbPath = p.absolute('test/fixtures/fake_adb/$adbName');
    if (!File(fakeAdbPath).existsSync()) {
      throw StateError(
        'Fake ADB not found at $fakeAdbPath. Run make to build it.',
      );
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
        'v1': {'apk': 'app.apk', 'test_apk': 'test.apk'},
      },
      'package': 'com.example.app',
      'device_result_dir': p.join(tempDir.path, 'device_sdcard'),
      'rounds': 1,
    };
    await File(
      p.join(dir.path, 'session.json'),
    ).writeAsString(jsonEncode(spec));
    await File(p.join(dir.path, 'app.apk')).create();
    await File(p.join(dir.path, 'test.apk')).create();
  }

  Future<void> setupSingleApkSession(
    String sessionId, {
    String? launchActivity,
  }) async {
    final dir = Directory(p.join(store.sessionsDir.path, sessionId));
    await dir.create(recursive: true);
    final spec = {
      'name': 'Single APK Session',
      'variants': {
        'baseline': {'apk': 'bench.apk'},
      },
      'package': 'com.example.bench',
      if (launchActivity != null) 'launch_activity': launchActivity,
      'device_result_dir': p.join(tempDir.path, 'device_sdcard'),
      'rounds': 1,
      'expected_result_files': ['iterations.jsonl'],
    };
    await File(
      p.join(dir.path, 'session.json'),
    ).writeAsString(jsonEncode(spec));
    await File(p.join(dir.path, 'bench.apk')).create();
  }

  Future<void> simulateAppFinishing(
    String sessionId,
    Directory deviceSdcard, {
    String trialId = 'trial-001',
    String resultFileName = 'result.txt',
    String resultContent = 'bench results',
  }) async {
    final logFile = store.sessionLogFile(sessionId);
    int logAttempts = 0;
    while (logAttempts < 30) {
      if (await logFile.exists()) {
        final content = await logFile.readAsString();
        final trialIdx = content.indexOf('Starting Trial $trialId');
        if (trialIdx != -1 &&
            content.indexOf('Waiting for completion...', trialIdx) != -1) {
          break;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      logAttempts++;
    }

    await File(
      p.join(deviceSdcard.path, resultFileName),
    ).writeAsString(resultContent);
    await File(p.join(deviceSdcard.path, 'DONE')).create();
  }

  test('Runner executes a session and produces results', () async {
    final sessionId = '20260809__test';
    await setupValidSession(sessionId);
    await store.discoverNewSessions();

    final runner = Runner(config: config, sessionStore: store);

    // Create the device result dir
    final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
    await deviceSdcard.create(recursive: true);

    // Start the runner
    final startedId = await runner.startNext();
    expect(startedId, sessionId);
    expect(runner.isBusy, isTrue);

    await simulateAppFinishing(sessionId, deviceSdcard);

    // Wait for the runner to finish
    int attempts = 0;
    while (runner.isBusy && attempts < 10) {
      await Future<void>.delayed(const Duration(seconds: 2));
      attempts++;
    }

    if (runner.isBusy) {
      final sessionLog = await store.sessionLogFile(sessionId).readAsString();
      print('--- Session Log (Busy) ---');
      print(sessionLog);

      final adbLogFile = store.trialAdbLogFile(sessionId, 'trial-001');
      if (await adbLogFile.exists()) {
        print('--- ADB Log (trial-001, Busy) ---');
        print(await adbLogFile.readAsString());
      }
    }
    expect(runner.isBusy, isFalse);
    final status = await store.readStatus(sessionId);
    if (status!.state != SessionState.done) {
      final sessionLog = await store.sessionLogFile(sessionId).readAsString();
      print('--- Session Log ---');
      print(sessionLog);

      final adbLogFile = store.trialAdbLogFile(sessionId, 'trial-001');
      if (await adbLogFile.exists()) {
        print('--- ADB Log (trial-001) ---');
        print(await adbLogFile.readAsString());
      }
    }

    expect(status.state, SessionState.done);

    // Verify artifacts
    final trialDir = store.trialDir(sessionId, 'trial-001');
    expect(await trialDir.exists(), isTrue);
    expect(await File(p.join(trialDir.path, 'trial.json')).exists(), isTrue);
    expect(
      await File(p.join(trialDir.path, 'results_index.json')).exists(),
      isTrue,
    );
    expect(
      await File(p.join(trialDir.path, 'results/result.txt')).exists(),
      isTrue,
    );

    final indexRaw = await File(
      p.join(trialDir.path, 'results_index.json'),
    ).readAsString();
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

    await runner.startNext();

    await simulateAppFinishing(sessionId, deviceSdcard);

    int attempts = 0;
    while (runner.isBusy && attempts < 10) {
      await Future<void>.delayed(const Duration(seconds: 2));
      attempts++;
    }

    final metadata = TrialMetadata.fromJson(
      jsonDecode(
            await store
                .trialMetadataFile(sessionId, 'trial-001')
                .readAsString(),
          )
          as Map<String, dynamic>,
    );

    expect(metadata.warnings, contains(contains('Thermal gate timeout')));
  });

  test(
    'Runner detects thermal throttling during trial and records warning',
    () async {
      final sessionId = '20260809__throttled';
      await setupValidSession(sessionId);
      await store.discoverNewSessions();

      final runner = Runner(
        config: config,
        sessionStore: store,
        environment: {
          'FAKE_ADB_THERMAL_THROTTLING': 'true',
          'FAKE_ADB_THERMAL_STATUS': '2',
        },
      );

      final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
      await deviceSdcard.create(recursive: true);

      await runner.startNext();

      await simulateAppFinishing(sessionId, deviceSdcard);

      int attempts = 0;
      while (runner.isBusy && attempts < 10) {
        await Future<void>.delayed(const Duration(seconds: 1));
        attempts++;
      }

      final metadata = TrialMetadata.fromJson(
        jsonDecode(
              await store
                  .trialMetadataFile(sessionId, 'trial-001')
                  .readAsString(),
            )
            as Map<String, dynamic>,
      );

      expect(metadata.thermalThrottled, isTrue);
      expect(metadata.maxThermalStatus, equals(2));
      expect(
        metadata.warnings,
        contains(
          contains('Device experienced thermal throttling during trial'),
        ),
      );
    },
  );

  test('Runner applies device profile and reset profile', () async {
    final profileFile = File(p.join(tempDir.path, 'profile.sh'));
    await profileFile.writeAsString(
      'echo performance > /sys/cpu/governor\n# comment\necho 1200000 > /sys/cpu/speed',
    );

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

    await runner.startNext();

    await simulateAppFinishing(sessionId, deviceSdcard);

    int attempts = 0;
    while (runner.isBusy && attempts < 30) {
      await Future<void>.delayed(const Duration(seconds: 1));
      attempts++;
    }

    // 1. Verify TrialMetadata records the profile
    final metadataFile = store.trialMetadataFile(sessionId, 'trial-001');
    final metadata = TrialMetadata.fromJson(
      jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>,
    );

    expect(metadata.deviceProfile, contains('performance'));
    expect(metadata.deviceProfileSha256, isNotNull);

    // 2. Verify adb.log contains the commands
    final adbLog = await store
        .trialAdbLogFile(sessionId, 'trial-001')
        .readAsString();
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
    final profileDir = Directory(
      p.join(tempDir.path, 'profiles', 'pixel_3_xl'),
    );
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

    await runner.startNext();

    await simulateAppFinishing(sessionId, deviceSdcard);

    int attempts = 0;
    while (runner.isBusy && attempts < 30) {
      await Future<void>.delayed(const Duration(seconds: 1));
      attempts++;
    }

    final metadata = TrialMetadata.fromJson(
      jsonDecode(
            await store
                .trialMetadataFile(sessionId, 'trial-001')
                .readAsString(),
          )
          as Map<String, dynamic>,
    );

    expect(metadata.deviceProfile, contains('auto-detected'));

    final adbLog = await store
        .trialAdbLogFile(sessionId, 'trial-001')
        .readAsString();
    expect(adbLog, contains('echo auto-detected > /sys/cpu/mode'));
  });

  test('Runner executes a single-APK session via am start', () async {
    final sessionId = '20260809__single_apk';
    await setupSingleApkSession(
      sessionId,
      launchActivity: 'com.example.bench.CustomActivity',
    );
    await store.discoverNewSessions();

    final runner = Runner(config: config, sessionStore: store);

    final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
    await deviceSdcard.create(recursive: true);

    final startedId = await runner.startNext();
    expect(startedId, sessionId);
    expect(runner.isBusy, isTrue);

    final logFile = store.sessionLogFile(sessionId);
    int logAttempts = 0;
    while (logAttempts < 30) {
      if (await logFile.exists()) {
        final content = await logFile.readAsString();
        if (content.contains('Waiting for completion...')) {
          break;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      logAttempts++;
    }

    await File(
      p.join(deviceSdcard.path, 'iterations.jsonl'),
    ).writeAsString('{"iteration":1,"durationUs":1500}\n');
    await File(p.join(deviceSdcard.path, 'DONE')).create();

    int attempts = 0;
    while (runner.isBusy && attempts < 10) {
      await Future<void>.delayed(const Duration(seconds: 2));
      attempts++;
    }

    expect(runner.isBusy, isFalse);
    final status = await store.readStatus(sessionId);
    expect(status!.state, SessionState.done);

    final sessionLog = await store.sessionLogFile(sessionId).readAsString();
    expect(
      sessionLog,
      contains(
        'Launching activity (com.example.bench/com.example.bench.CustomActivity)...',
      ),
    );
    expect(sessionLog, isNot(contains('Launching instrumentation...')));

    final trialDir = store.trialDir(sessionId, 'trial-001');
    expect(
      await File(p.join(trialDir.path, 'results/iterations.jsonl')).exists(),
      isTrue,
    );

    final adbLog = await store
        .trialAdbLogFile(sessionId, 'trial-001')
        .readAsString();
    expect(
      adbLog,
      contains('am start -n com.example.bench/com.example.bench.CustomActivity'),
    );
    expect(adbLog, isNot(contains('am instrument')));
    expect(adbLog, contains('pm clear com.example.bench'));
    expect(adbLog, isNot(contains('uninstall')));
    expect(sessionLog, contains('Session teardown: uninstalling packages...'));
  });

  test(
    'Runner preserves UID via pm clear and skips redundant install for same variant',
    () async {
      final sessionId = '20260809__multitrial';
      final dir = Directory(p.join(store.sessionsDir.path, sessionId));
      await dir.create(recursive: true);
      final spec = {
        'name': 'Multi-trial Session',
        'variants': {
          'v1': {'apk': 'app.apk'},
        },
        'package': 'com.example.app',
        'device_result_dir': p.join(tempDir.path, 'device_sdcard'),
        'rounds': 2,
        'expected_result_files': ['iterations.jsonl'],
      };
      await File(
        p.join(dir.path, 'session.json'),
      ).writeAsString(jsonEncode(spec));
      await File(p.join(dir.path, 'app.apk')).create();
      await store.discoverNewSessions();

      final runner = Runner(config: config, sessionStore: store);
      final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
      await deviceSdcard.create(recursive: true);

      await runner.startNext();

      // Round 1 / trial-001
      await simulateAppFinishing(
        sessionId,
        deviceSdcard,
        trialId: 'trial-001',
        resultFileName: 'iterations.jsonl',
      );

      // Round 2 / trial-002
      await simulateAppFinishing(
        sessionId,
        deviceSdcard,
        trialId: 'trial-002',
        resultFileName: 'iterations.jsonl',
      );

      int attempts = 0;
      while (runner.isBusy && attempts < 20) {
        await Future<void>.delayed(const Duration(seconds: 1));
        attempts++;
      }

      expect(runner.isBusy, isFalse);
      final status = await store.readStatus(sessionId);
      expect(status!.state, SessionState.done);

      final adbLog1 = await store
          .trialAdbLogFile(sessionId, 'trial-001')
          .readAsString();
      final adbLog2 = await store
          .trialAdbLogFile(sessionId, 'trial-002')
          .readAsString();

      // Both trials should clear package instead of uninstalling
      expect(adbLog1, contains('pm clear com.example.app'));
      expect(adbLog1, isNot(contains('uninstall com.example.app')));

      expect(adbLog2, contains('pm clear com.example.app'));
      expect(adbLog2, isNot(contains('uninstall com.example.app')));

      // Trial 1 installed APK
      expect(adbLog1, contains('install -r -d -g'));

      // Trial 2 was same variant, so it skipped install
      expect(adbLog2, isNot(contains('install -r -d -g')));

      final sessionLog = await store.sessionLogFile(sessionId).readAsString();
      expect(
        sessionLog,
        contains(
          'Variant v1 is already installed; skipping APK installation.',
        ),
      );
      expect(sessionLog, contains('Session teardown: uninstalling packages...'));
    },
  );

  test(
    'Runner recovers autonomously from UID exhaustion during APK install',
    () async {
      final sessionId = '20260809__uid_recovery';
      await setupSingleApkSession(sessionId);
      await store.discoverNewSessions();

      final failCountFile = File(
        p.join(tempDir.path, 'fake_adb_uid_fail_count.txt'),
      );
      final rebootStateFile = File(
        p.join(tempDir.path, 'fake_adb_reboot_state.txt'),
      );

      // Create a mock profile to verify profile re-application post-reboot
      final profilesDir = Directory(
        p.join(tempDir.path, 'profiles', 'pixel3xl'),
      );
      await profilesDir.create(recursive: true);
      final profileFile = File(p.join(profilesDir.path, 'performance.sh'));
      await profileFile.writeAsString('echo performance > /sys/cpu/mode\n');

      final recoveryConfig = Config(
        dutAddress: '100.120.184.47:5555',
        dataDir: tempDir.path,
        port: 8080,
        adbPath: fakeAdbPath,
        pollIntervalSeconds: 1,
        defaultTrialTimeoutSeconds: 30,
        thermalGateCelsius: null,
        thermalGateTimeoutSeconds: 0,
        deviceProfileFile: profileFile.path,
        deviceResetFile: null,
        profilesDir: p.join(tempDir.path, 'profiles'),
        precompilePackage: false,
        logLevel: 'info',
        gitCommit: 'abdabdabd',
      );

      final recoveryEnvironment = {
        'FAKE_ADB_FAIL_INSTALL_UID': 'true',
        'FAKE_ADB_UID_FAIL_COUNT_FILE': failCountFile.path,
        'FAKE_ADB_REBOOT_STATE_FILE': rebootStateFile.path,
      };

      final runner = Runner(
        config: recoveryConfig,
        sessionStore: store,
        environment: recoveryEnvironment,
      );

      final deviceSdcard = Directory(p.join(tempDir.path, 'device_sdcard'));
      await deviceSdcard.create(recursive: true);

      await runner.startNext();
      await simulateAppFinishing(
        sessionId,
        deviceSdcard,
        trialId: 'trial-001',
        resultFileName: 'iterations.jsonl',
        resultContent: '{"iteration":1}\n',
      );

      int attempts = 0;
      while (runner.isBusy && attempts < 25) {
        await Future<void>.delayed(const Duration(seconds: 1));
        attempts++;
      }

      expect(runner.isBusy, isFalse);
      final status = await store.readStatus(sessionId);
      expect(status!.state, SessionState.done);

      final sessionLog = await store.sessionLogFile(sessionId).readAsString();
      expect(
        sessionLog,
        contains(
          'Detected UID exhaustion during APK install. Initiating self-healing device reboot.',
        ),
      );
      expect(
        sessionLog,
        contains(
          'Executing self-healing reboot to flush PackageManagerService UID table...',
        ),
      );
      expect(
        sessionLog,
        contains('Device boot completed. Restoring device operational state...'),
      );
      expect(sessionLog, contains('Re-applying device profile'));
      expect(
        sessionLog,
        contains('Retrying APK installation for baseline post-reboot...'),
      );

      final metadataRaw = await store
          .trialMetadataFile(sessionId, 'trial-001')
          .readAsString();
      final metadata = TrialMetadata.fromJson(
        jsonDecode(metadataRaw) as Map<String, dynamic>,
      );
      expect(
        metadata.warnings.any(
          (w) => w.contains('Detected UID exhaustion during APK install'),
        ),
        isTrue,
      );
    },
  );

  test(
    'Runner aborts immediately on non-UID install failure without rebooting',
    () async {
      final sessionId = '20260809__non_uid_fail';
      await setupSingleApkSession(sessionId);
      await store.discoverNewSessions();

      final rebootStateFile = File(
        p.join(tempDir.path, 'fake_adb_reboot_state_non_uid.txt'),
      );

      final failEnvironment = {
        'FAKE_ADB_FAIL_INSTALL_PARSE': 'true',
        'FAKE_ADB_REBOOT_STATE_FILE': rebootStateFile.path,
      };

      final runner = Runner(
        config: config,
        sessionStore: store,
        environment: failEnvironment,
      );

      await runner.startNext();

      int attempts = 0;
      while (runner.isBusy && attempts < 15) {
        await Future<void>.delayed(const Duration(seconds: 1));
        attempts++;
      }

      expect(runner.isBusy, isFalse);
      final status = await store.readStatus(sessionId);
      expect(status!.state, SessionState.failed);
      expect(rebootStateFile.existsSync(), isFalse);

      final sessionLog = await store.sessionLogFile(sessionId).readAsString();
      expect(sessionLog, isNot(contains('self-healing')));
      expect(sessionLog, contains('INSTALL_PARSE_FAILED_NOT_APK'));
    },
  );
}
