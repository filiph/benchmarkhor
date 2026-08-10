import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'adb.dart';
import 'config.dart';
import 'device_probe.dart';
import 'models.dart';
import 'session_store.dart';

final _log = Logger('runner');

class CancelledException implements Exception {
  final String message;
  CancelledException(this.message);
  @override
  String toString() => 'CancelledException: $message';
}

class Runner {
  final Config config;
  final SessionStore sessionStore;

  static String? _runningSessionId;
  static String? statusMessage;
  static bool get isBusy => _runningSessionId != null;

  Runner({required this.config, required this.sessionStore});

  /// Tries to start the next queued session.
  ///
  /// Returns the sessionId if a session was started, null otherwise.
  /// Throws [StateError] if a session is already running.
  Future<String?> startNext() async {
    if (isBusy) {
      throw StateError('A session is already running: $_runningSessionId');
    }

    // Cross-process lock check
    final lockFile = sessionStore.lockFile();
    if (await lockFile.exists()) {
      final content = await lockFile.readAsString();
      _log.warning('Lock file exists: $content');

      final pidMatch = RegExp(r'pid: (\d+)').firstMatch(content);
      final atMatch = RegExp(r'at: (.*)$').firstMatch(content);

      if (pidMatch != null) {
        final lockPid = int.parse(pidMatch.group(1)!);
        final lockTime =
            atMatch != null ? DateTime.tryParse(atMatch.group(1)!) : null;

        if (await _isPidAlive(lockPid, startedAt: lockTime)) {
          throw StateError(
              'Lock file exists and PID $lockPid is alive. Another runner is active.');
        } else {
          _log.warning(
              'Lock file belongs to dead PID $lockPid or is stale. Stealing lock.');
          await lockFile.delete();
        }
      } else {
        // Malformed lock file, safer to fail and require manual deletion?
        // Or steal it? Let's fail for safety if we can't parse it.
        throw StateError(
            'Lock file exists but is malformed. Delete it manually: ${lockFile.path}');
      }
    }

    await sessionStore.discoverNewSessions();
    final queued = <String>[];
    for (final id in await sessionStore.listSessionIds()) {
      final status = await sessionStore.readStatus(id);
      if (status?.state == SessionState.queued) {
        queued.add(id);
      }
    }

    if (queued.isEmpty) return null;

    final sessionId = queued.first;
    _runningSessionId = sessionId;

    // Async execution
    unawaited(_run(sessionId).onError((e, st) {
      _log.severe('Session $sessionId failed with unhandled error', e, st);
    }).whenComplete(() {
      _runningSessionId = null;
      statusMessage = null;
    }));

    return sessionId;
  }

  Future<void> _run(String sessionId) async {
    _log.info('Starting session $sessionId');

    // Create lock file
    final lockFile = sessionStore.lockFile();
    await lockFile.writeAsString(
        'pid: $pid, session: $sessionId, at: ${DateTime.now().toUtc()}');

    SessionStatus status = (await sessionStore.readStatus(sessionId))!;
    SessionSpec spec = await sessionStore.readSessionSpec(sessionId);

    status = status.transitionTo(SessionState.running);
    await sessionStore.writeStatus(status);

    final sessionLog = sessionStore.sessionLogFile(sessionId);
    final logSink = sessionLog.openWrite(mode: FileMode.append);

    void log(String message) {
      final entry = '${DateTime.now().toUtc().toIso8601String()} $message';
      _log.info('[$sessionId] $message');
      logSink.writeln(entry);
      statusMessage = message;
    }

    try {
      final adb = Adb(
        adbPath: config.adbPath,
        deviceAddress: config.dutAddress,
      );
      final probe = DeviceProbe(adb);

      log('Connecting to device ${config.dutAddress}...');
      if (!await adb.connect()) {
        throw Exception('Failed to connect to device');
      }

      log('Elevating to root...');
      if (await adb.root()) {
        // Wait for adbd to restart and reconnect
        await Future<void>.delayed(const Duration(seconds: 5));
        if (!await adb.connect()) {
          log('Warning: Failed to reconnect after adb root. Proceeding as non-root.');
        }
      } else {
        log('Warning: adb root failed. Profiles may fail if root is required.');
      }

      log('Device state: ${await adb.getState()}');

      for (int round = status.roundsCompleted + 1;
          round <= spec.rounds;
          round++) {
        log('Starting Round $round/${spec.rounds}');

        final variants = spec.variants.keys.toList()..shuffle();
        for (final variantName in variants) {
          final trialId =
              'trial-${(status.roundsCompleted * spec.variants.length + variants.indexOf(variantName) + 1).toString().padLeft(3, '0')}';
          log('Starting Trial $trialId (Variant: $variantName)');

          await _runTrial(
              sessionId, trialId, variantName, spec, adb, probe, log);

          // Check for cancellation between trials
          status = (await sessionStore.readStatus(sessionId))!;
          if (status.state == SessionState.cancelled) {
            throw CancelledException('Session cancelled between trials.');
          }
        }

        status = status.transitionTo(
          SessionState.running,
          roundsCompleted: round,
        );
        await sessionStore.writeStatus(status);
      }

      log('Session completed successfully.');
      await sessionStore.writeStatus(status.transitionTo(SessionState.done));
    } catch (e, st) {
      if (e is CancelledException) {
        log('Session cancelled: ${e.message}');
      } else {
        log('Error during session: $e\n$st');
        await sessionStore.writeStatus(
            status.transitionTo(SessionState.failed, error: e.toString()));
      }
    } finally {
      if (config.deviceResetFile != null) {
        log('Applying device reset profile from ${config.deviceResetFile}...');
        try {
          final adb = Adb(
            adbPath: config.adbPath,
            deviceAddress: config.dutAddress,
          );
          if (await adb.connect()) {
            await adb.root();
            // We don't wait as long here, _applyProfile will retry shell commands anyway
            // but let's give it a moment.
            await Future<void>.delayed(const Duration(seconds: 2));
            await adb.connect();
            await _applyProfile(adb, config.deviceResetFile, log);
          }
        } catch (e) {
          log('Warning: Failed to apply reset profile: $e');
        }
      }
      await logSink.flush();
      await logSink.close();
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
    }
  }

  Future<void> _runTrial(
    String sessionId,
    String trialId,
    String variantName,
    SessionSpec spec,
    Adb adb,
    DeviceProbe probe,
    void Function(String) log,
  ) async {
    final trialDir = sessionStore.trialDir(sessionId, trialId);
    await trialDir.create(recursive: true);

    final adbLogFile = sessionStore.trialAdbLogFile(sessionId, trialId);
    final trialAdb = Adb(
      adbPath: config.adbPath,
      deviceAddress: config.dutAddress,
      adbLog: adbLogFile,
    );
    final trialProbe = DeviceProbe(trialAdb);

    final startedAt = DateTime.now().toUtc();

    // 0. Apply Device Profile
    ({String content, String sha256})? profileResult;
    if (config.deviceProfileFile != null) {
      log('Applying device profile from ${config.deviceProfileFile}...');
      profileResult =
          await _applyProfile(trialAdb, config.deviceProfileFile, log);
    }

    // 1. Thermal Gate
    final warnings = <String>[];
    if (config.thermalGateCelsius != null) {
      log('Thermal gating...');
      final timeout = DateTime.now()
          .add(Duration(seconds: config.thermalGateTimeoutSeconds));
      bool gated = false;
      while (DateTime.now().isBefore(timeout)) {
        final p = await trialProbe.probe();
        final temps = p['temperatures'] as List<Map<String, String>>?;
        final maxTemp = temps
                ?.map((t) => double.tryParse(t['temp'] ?? '0') ?? 0)
                .reduce(max) ??
            0;
        // temps are often in millicelsius
        final tempC = maxTemp > 1000 ? maxTemp / 1000 : maxTemp;

        if (tempC < config.thermalGateCelsius!) {
          log('Temperature $tempC C is below threshold ${config.thermalGateCelsius} C.');
          gated = true;
          break;
        }
        log('Temperature $tempC C is too high, waiting...');
        await Future<void>.delayed(const Duration(seconds: 10));
      }

      if (!gated) {
        final msg =
            'Thermal gate timeout after ${config.thermalGateTimeoutSeconds}s. Proceeding anyway.';
        log(msg);
        warnings.add(msg);
      }
    }

    // 2. Pre-run snapshot
    log('Capturing pre-run snapshot...');
    final deviceBefore = await trialProbe.probe();
    await sessionStore.deviceDir.create(recursive: true);
    await sessionStore.writeAtomic(
      sessionStore.lastSnapshotFile(),
      const JsonEncoder.withIndent('  ').convert(deviceBefore),
    );

    // 3. Clean device state
    log('Cleaning device state...');
    await trialAdb.shell('rm -rf ${spec.deviceResultDir}',
        timeout: const Duration(minutes: 1));
    await trialAdb.shell('mkdir -p ${spec.deviceResultDir}',
        timeout: const Duration(minutes: 1));

    // 4. Install
    final variant = spec.variants[variantName]!;
    log('Installing APKs for $variantName...');
    final apkPath =
        p.join(sessionStore.sessionDir(sessionId).path, variant.apk);
    final testApkPath =
        p.join(sessionStore.sessionDir(sessionId).path, variant.testApk);

    await trialAdb.install(apkPath, timeout: const Duration(minutes: 5));
    await trialAdb.install(testApkPath, timeout: const Duration(minutes: 5));

    // 5. Precompile
    if (config.precompilePackage) {
      log('Precompiling package ${spec.package}...');
      await trialAdb.shell('cmd package compile -m speed -f ${spec.package}',
          timeout: const Duration(minutes: 5));
    }

    // 6. Launch
    log('Launching instrumentation...');
    await trialAdb.clearLogcat();
    final logcatFile = sessionStore.trialLogcatFile(sessionId, trialId);
    final logcatProcess = await trialAdb.startLogcat(logcatFile);

    String? benchDoneMarker;
    final logcatSub = logcatProcess.lines.listen((line) {
      if (line.contains('BENCH_DONE') || line.contains('BENCH_FAILED')) {
        benchDoneMarker = line;
      }
    });

    try {
      unawaited(trialAdb.run([
        'shell',
        'am',
        'instrument',
        '-w',
        '-r',
        '${spec.testPackage}/${spec.instrumentationRunner}'
      ], timeout: Duration.zero));

      // 7. Wait for completion (Contract)
      log('Waiting for completion...');
      final timeout =
          spec.trialTimeoutSeconds ?? config.defaultTrialTimeoutSeconds;
      final deadline = DateTime.now().add(Duration(seconds: timeout));

      bool finished = false;
      int consecutivePidMissing = 0;

      while (DateTime.now().isBefore(deadline)) {
        // Immediate cancellation check
        final currentStatus = await sessionStore.readStatus(sessionId);
        if (currentStatus?.state == SessionState.cancelled) {
          throw CancelledException('Session cancelled during trial poll.');
        }

        // Priority 1: Sentinel file
        final sentinel = await trialAdb
            .shell('test -f ${spec.deviceResultDir}/DONE && echo YES');
        if ((sentinel.stdout as String).contains('YES')) {
          log('Sentinel file DONE found.');
          finished = true;
          break;
        }

        final failed = await trialAdb
            .shell('test -f ${spec.deviceResultDir}/FAILED && echo YES');
        if ((failed.stdout as String).contains('YES')) {
          log('Sentinel file FAILED found.');
          break;
        }

        // Priority 2: Logcat marker
        if (benchDoneMarker != null) {
          log('Marker found in logcat: $benchDoneMarker');
          if (benchDoneMarker!.contains('BENCH_DONE')) {
            finished = true;
          }
          break;
        }

        // Priority 3: Process gone
        final pidof = await trialAdb.shell('pidof ${spec.package}',
            timeout: const Duration(seconds: 10));
        if ((pidof.stdout as String).trim().isEmpty) {
          consecutivePidMissing++;
          if (consecutivePidMissing >= 2) {
            log('Process disappeared without sentinel for 2 polls.');
            break;
          }
        } else {
          consecutivePidMissing = 0;
        }

        await Future<void>.delayed(
            Duration(seconds: config.pollIntervalSeconds));
      }

      await logcatSub.cancel();
      await logcatProcess.stop();

      // 8. Pull results
      log('Pulling results...');
      final resultsDir = sessionStore.trialResultsDir(sessionId, trialId);
      await resultsDir.create(recursive: true);
      await trialAdb.pull(spec.deviceResultDir, resultsDir.path,
          timeout: const Duration(minutes: 5));

      // 8b. Generate Results Index
      await _generateResultsIndex(resultsDir, log);

      // 9. Post-run snapshot
      log('Capturing post-run snapshot...');
      final deviceAfter = await trialProbe.probe();

      // 10. Finalize Trial
      final finishedAt = DateTime.now().toUtc();
      final metadata = TrialMetadata(
        sessionId: sessionId,
        variantName: variantName,
        trialId: trialId,
        startedAt: startedAt,
        finishedAt: finishedAt,
        deviceBefore: deviceBefore,
        deviceAfter: deviceAfter,
        warnings: warnings,
        config: config.toJson(),
        deviceProfile: profileResult?.content,
        deviceProfileSha256: profileResult?.sha256,
      );

      await sessionStore.writeAtomic(
        sessionStore.trialMetadataFile(sessionId, trialId),
        const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      );

      if (!finished) {
        throw Exception('Trial failed or timed out.');
      }
    } finally {
      log('Uninstalling APKs...');
      await trialAdb.uninstall(spec.package,
          timeout: const Duration(minutes: 1));
      await trialAdb.uninstall(spec.testPackage,
          timeout: const Duration(minutes: 1));
    }
  }

  Future<({String content, String sha256})?> _applyProfile(
      Adb adb, String? profilePath, void Function(String) log) async {
    if (profilePath == null) return null;
    final file = File(profilePath);
    if (!await file.exists()) {
      log('Warning: Profile file $profilePath not found.');
      return null;
    }

    final content = await file.readAsString();
    final commands = content.split('\n');
    for (var command in commands) {
      command = command.trim();
      if (command.isEmpty || command.startsWith('#')) continue;
      log('Applying device profile command: $command');
      final res = await adb.shell(command);
      if (res.exitCode != 0) {
        log('Warning: Profile command failed: $command (exit ${res.exitCode})');
      }
    }

    final hash = sha256.convert(utf8.encode(content)).toString();
    return (content: content, sha256: hash);
  }

  Future<void> _generateResultsIndex(
      Directory resultsDir, void Function(String) log) async {
    final index = <Map<String, dynamic>>[];
    await for (final entity in resultsDir.list(recursive: true)) {
      if (entity is File) {
        final bytes = await entity.readAsBytes();
        final sha256Hash = sha256.convert(bytes).toString();
        int lines = 0;
        try {
          lines = utf8.decode(bytes, allowMalformed: true).split('\n').length;
        } catch (e) {
          log('Warning: Failed to decode ${p.basename(entity.path)} as UTF-8 for line count. It may be a binary file.');
          _log.warning(
              'Failed to decode ${entity.path} as UTF-8 for line count: $e');
        }
        index.add({
          'filename': p.relative(entity.path, from: resultsDir.path),
          'bytes': bytes.length,
          'sha256': sha256Hash,
          'line_count': lines,
        });
      }
    }
    final indexFile =
        File(p.join(resultsDir.parent.path, 'results_index.json'));
    await sessionStore.writeAtomic(
      indexFile,
      const JsonEncoder.withIndent('  ').convert(index),
    );
  }

  Future<bool> _isPidAlive(int pid, {DateTime? startedAt}) async {
    if (Platform.isWindows) {
      final res = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
      return res.stdout.toString().contains(pid.toString());
    } else {
      final res = await Process.run('kill', ['-0', pid.toString()]);
      if (res.exitCode != 0) return false;
      if (startedAt == null) return true;

      // Robustness check: is it the SAME process?
      // We check if the process started BEFORE the lock file was written.
      try {
        final psRes =
            await Process.run('ps', ['-p', pid.toString(), '-o', 'etimes=']);
        if (psRes.exitCode == 0) {
          final elapsedSeconds = int.tryParse(psRes.stdout.toString().trim());
          if (elapsedSeconds != null) {
            final processStartedAt =
                DateTime.now().subtract(Duration(seconds: elapsedSeconds));
            // Give it a bit of buffer (2 seconds) to account for clock skew/timing.
            // If the process started AFTER the lock was written, it's a reuse.
            return processStartedAt
                .isBefore(startedAt.add(const Duration(seconds: 2)));
          }
        }
      } catch (e) {
        _log.warning('Failed to check process age: $e');
      }
      return true; // Fallback to true if we can't check age
    }
  }
}
