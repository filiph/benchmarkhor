import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

/// Manages filesystem I/O and state persistence for a local benchmark session.
class LocalSessionStore {
  final String sessionDirPath;

  LocalSessionStore(this.sessionDirPath);

  Directory get sessionDir => Directory(sessionDirPath);

  File get sessionSpecFile => File(p.join(sessionDirPath, 'session.json'));

  File get statusFile => File(p.join(sessionDirPath, 'status.json'));

  File get sessionLogFile => File(p.join(sessionDirPath, 'session.log'));

  Directory get trialsDir => Directory(p.join(sessionDirPath, 'trials'));

  Directory trialDir(String trialId) =>
      Directory(p.join(trialsDir.path, trialId));

  File trialMetadataFile(String trialId) =>
      File(p.join(trialDir(trialId).path, 'trial.json'));

  File trialStdoutFile(String trialId) =>
      File(p.join(trialDir(trialId).path, 'stdout.log'));

  File trialStderrFile(String trialId) =>
      File(p.join(trialDir(trialId).path, 'stderr.log'));

  Directory trialResultsDir(String trialId) =>
      Directory(p.join(trialDir(trialId).path, 'results'));

  File trialIterationsFile(String trialId) =>
      File(p.join(trialResultsDir(trialId).path, 'iterations.jsonl'));

  File trialResultsIndexFile(String trialId) =>
      File(p.join(trialDir(trialId).path, 'results_index.json'));

  /// Formats sequential trial numbers into standard IDs (e.g., `trial-001`).
  static String formatTrialId(int trialNumber) {
    return 'trial-${trialNumber.toString().padLeft(3, '0')}';
  }

  /// Writes [contents] to [file] atomically using a sibling `.tmp` file.
  Future<void> writeAtomic(File file, String contents) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final tmp = File('${file.path}.tmp');
    final sink = tmp.openWrite();
    sink.write(contents);
    await sink.flush();
    await sink.close();
    await tmp.rename(file.path);
  }

  /// Appends a timestamped line to `session.log`.
  Future<void> appendLog(String message) async {
    final parent = sessionLogFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final sink = sessionLogFile.openWrite(mode: FileMode.append);
    sink.writeln('[$now] $message');
    await sink.flush();
    await sink.close();
  }

  /// Reads and parses `session.json`. Throws [FormatException] if missing or invalid.
  Future<LocalSessionSpec> readSessionSpec() async {
    if (!await sessionSpecFile.exists()) {
      throw FormatException('session.json not found in $sessionDirPath');
    }
    final raw = await sessionSpecFile.readAsString();
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FormatException(
        'session.json in "$sessionDirPath" is not valid JSON: $e',
      );
    }
    return LocalSessionSpec.fromJson(json);
  }

  /// Reads `status.json`, or returns null if it does not exist yet.
  Future<LocalSessionStatus?> readStatus() async {
    if (!await statusFile.exists()) return null;
    final raw = await statusFile.readAsString();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LocalSessionStatus.fromJson(json);
    } on FormatException catch (e) {
      throw FormatException('status.json is corrupted or invalid: $e');
    }
  }

  /// Atomically writes formatted `status.json`.
  Future<void> writeStatus(LocalSessionStatus status) async {
    const encoder = JsonEncoder.withIndent('  ');
    await writeAtomic(statusFile, '${encoder.convert(status.toJson())}\n');
  }

  /// Atomically writes `trial.json`.
  Future<void> writeTrialMetadata(TrialMetadata metadata) async {
    const encoder = JsonEncoder.withIndent('  ');
    await writeAtomic(
      trialMetadataFile(metadata.trialId),
      '${encoder.convert(metadata.toJson())}\n',
    );
  }

  /// Atomically writes `results_index.json` for a trial.
  Future<void> writeResultsIndex(
    String trialId,
    List<Map<String, dynamic>> entries,
  ) async {
    const encoder = JsonEncoder.withIndent('  ');
    await writeAtomic(
      trialResultsIndexFile(trialId),
      '${encoder.convert(entries)}\n',
    );
  }

  /// Cleans any existing trials, logs, and status from previous runs.
  Future<void> cleanSession() async {
    if (await trialsDir.exists()) {
      await trialsDir.delete(recursive: true);
    }
    if (await statusFile.exists()) {
      await statusFile.delete();
    }
    if (await sessionLogFile.exists()) {
      await sessionLogFile.delete();
    }
  }

  /// Initializes a fresh status or resumes an existing status.
  Future<LocalSessionStatus> initOrResumeStatus({bool clean = false}) async {
    if (clean) {
      await cleanSession();
    }

    final spec = await readSessionSpec();
    final existingStatus = await readStatus();

    if (existingStatus != null && !clean) {
      await appendLog(
        'Resuming session "${spec.name}" from round ${existingStatus.roundsCompleted + 1} of ${existingStatus.roundsPlanned}',
      );
      return existingStatus;
    }

    final newStatus = LocalSessionStatus.initial(
      sessionId: spec.name,
      roundsPlanned: spec.rounds,
    );
    await writeStatus(newStatus);
    await appendLog(
      'Initialized session "${spec.name}" with ${spec.rounds} planned rounds and ${spec.variants.length} variants',
    );
    return newStatus;
  }

  /// Lists all existing trial directories in alphabetical/chronological order.
  Future<List<String>> listExistingTrialIds() async {
    if (!await trialsDir.exists()) return const [];
    final trialIds = <String>[];
    await for (final entity in trialsDir.list()) {
      if (entity is Directory) {
        trialIds.add(p.basename(entity.path));
      }
    }
    trialIds.sort();
    return trialIds;
  }
}
