import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('adb');

/// A thin, typed wrapper over the `adb` command-line tool.
///
/// Every invocation and its results are logged to the [adbLog] file if provided.
class Adb {
  final String adbPath;
  final String deviceAddress;
  final File? adbLog;

  Adb({
    required this.adbPath,
    required this.deviceAddress,
    this.adbLog,
  });

  /// Runs an `adb` command with the given [arguments].
  ///
  /// The command is automatically targeted at [deviceAddress] using `-s`.
  Future<ProcessResult> run(List<String> arguments,
      {bool useDevice = true, Duration? timeout}) async {
    final fullArgs = [
      if (useDevice) ...['-s', deviceAddress],
      ...arguments,
    ];

    final stopwatch = Stopwatch()..start();
    ProcessResult result;
    if (timeout != null) {
      final process = await Process.start(adbPath, fullArgs);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      result = ProcessResult(
        process.pid,
        exitCode,
        exitCode == -1 ? 'Timed out after ${timeout.inSeconds}s' : await stdout,
        exitCode == -1 ? 'Timed out after ${timeout.inSeconds}s' : await stderr,
      );
    } else {
      result = await Process.run(adbPath, fullArgs);
    }
    stopwatch.stop();

    if (adbLog != null) {
      final logEntry = StringBuffer()
        ..writeln('--- ${DateTime.now().toUtc().toIso8601String()} ---')
        ..writeln('Command: $adbPath ${fullArgs.join(' ')}')
        ..writeln('Exit code: ${result.exitCode}')
        ..writeln('Duration: ${stopwatch.elapsed}')
        ..writeln('Stdout:\n${result.stdout}')
        ..writeln('Stderr:\n${result.stderr}')
        ..writeln();
      await adbLog!.writeAsString(logEntry.toString(),
          mode: FileMode.append, flush: true);
    }

    if (result.exitCode != 0) {
      _log.fine(
          'adb command failed (exit ${result.exitCode}): ${fullArgs.join(' ')}');
      _log.fine('Stderr: ${result.stderr}');
    }

    return result;
  }

  Future<bool> connect(
      {int retries = 3, Duration backoff = const Duration(seconds: 30)}) async {
    for (int i = 0; i <= retries; i++) {
      if (i > 0) {
        _log.info(
            'Retrying connection in ${backoff.inSeconds}s... (Attempt ${i + 1}'
            '/${retries + 1})');
        await Future<void>.delayed(backoff);
      }

      final result = await run(['connect', deviceAddress],
          useDevice: false, timeout: const Duration(seconds: 60));
      final stdout = result.stdout as String;

      if (result.exitCode == 0 &&
          (stdout.contains('connected') ||
              stdout.contains('already connected'))) {
        // Double-check with get-state
        final stateResult =
            await run(['get-state'], timeout: const Duration(seconds: 10));
        if (stateResult.exitCode == 0 &&
            (stateResult.stdout as String).trim() == 'device') {
          return true;
        }
        _log.warning(
            'adb connect succeeded but get-state failed: ${stateResult.stderr}');
      } else {
        _log.warning(
            'adb connect failed (exit ${result.exitCode}): ${result.stdout} ${result.stderr}');
      }
    }
    return false;
  }

  Future<String?> getState() async {
    final result = await run(['get-state']);
    if (result.exitCode != 0) return null;
    return (result.stdout as String).trim();
  }

  Future<ProcessResult> shell(String command) => run(['shell', command]);

  Future<ProcessResult> install(String apkPath,
      {bool reinstall = true, bool grantPermissions = true}) async {
    return run([
      'install',
      if (reinstall) '-r',
      if (grantPermissions) '-g',
      apkPath,
    ]);
  }

  Future<ProcessResult> uninstall(String package) =>
      run(['uninstall', package]);

  Future<ProcessResult> pull(String remotePath, String localPath) =>
      run(['pull', remotePath, localPath]);

  Future<ProcessResult> forceStop(String package) =>
      shell('am force-stop $package');

  Future<ProcessResult> clearLogcat() => run(['logcat', '-c']);

  /// Starts capturing logcat to [outputFile].
  ///
  /// Returns a [LogcatProcess] which contains the [Process] and a [Stream] of
  /// logcat lines. The caller is responsible for killing the process.
  Future<LogcatProcess> startLogcat(File outputFile) async {
    final process =
        await Process.start(adbPath, ['-s', deviceAddress, 'logcat']);
    final sink = outputFile.openWrite();

    final controller = StreamController<String>.broadcast();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      sink.writeln(line);
      controller.add(line);
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      sink.writeln(line);
      controller.add(line);
    });

    return LogcatProcess(process, controller.stream, sink);
  }
}

class LogcatProcess {
  final Process process;
  final Stream<String> lines;
  final IOSink _sink;

  LogcatProcess(this.process, this.lines, this._sink);

  Future<void> stop() async {
    process.kill();
    await _sink.flush();
    await _sink.close();
  }
}
