import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

/// Disk I/O and state-machine logic for sessions.
///
/// All state lives under [dataDir]`/sessions/<session-id>/`.
/// See `REQUIREMENTS.md` §4 for the full on-disk layout and the rules
/// around atomic writes.
class SessionStore {
  final String dataDir;

  SessionStore(this.dataDir);

  Directory get sessionsDir => Directory(p.join(dataDir, 'sessions'));

  Directory sessionDir(String sessionId) =>
      Directory(p.join(sessionsDir.path, sessionId));

  File sessionSpecFile(String sessionId) =>
      File(p.join(sessionDir(sessionId).path, 'session.json'));

  File statusFile(String sessionId) =>
      File(p.join(sessionDir(sessionId).path, 'status.json'));

  File sessionLogFile(String sessionId) =>
      File(p.join(sessionDir(sessionId).path, 'session.log'));

  Directory trialsDir(String sessionId) =>
      Directory(p.join(sessionDir(sessionId).path, 'trials'));

  Directory trialDir(String sessionId, String trialId) =>
      Directory(p.join(trialsDir(sessionId).path, trialId));

  File trialMetadataFile(String sessionId, String trialId) =>
      File(p.join(trialDir(sessionId, trialId).path, 'trial.json'));

  File trialAdbLogFile(String sessionId, String trialId) =>
      File(p.join(trialDir(sessionId, trialId).path, 'adb.log'));

  File trialLogcatFile(String sessionId, String trialId) =>
      File(p.join(trialDir(sessionId, trialId).path, 'logcat.txt'));

  Directory trialResultsDir(String sessionId, String trialId) =>
      Directory(p.join(trialDir(sessionId, trialId).path, 'results'));

  File lockFile() => File(p.join(dataDir, '.runner.lock'));

  Directory get deviceDir => Directory(p.join(dataDir, 'device'));

  File lastSnapshotFile() => File(p.join(deviceDir.path, 'last_snapshot.json'));

  /// Writes [contents] to [file] atomically: write to a sibling `.tmp` file,
  /// flush, then rename over the destination. See `REQUIREMENTS.md` §4.
  Future<void> writeAtomic(File file, String contents) async {
    final tmp = File('${file.path}.tmp');
    final sink = tmp.openWrite();
    sink.write(contents);
    await sink.flush();
    await sink.close();
    await tmp.rename(file.path);
  }

  /// Lists all session IDs currently present on disk, in lexicographic (i.e.
  /// chronological, FIFO) order.
  Future<List<String>> listSessionIds() async {
    if (!await sessionsDir.exists()) return const [];
    final ids = <String>[];
    await for (final entity in sessionsDir.list()) {
      if (entity is Directory) {
        ids.add(p.basename(entity.path));
      }
    }
    ids.sort();
    return ids;
  }

  /// Reads and validates the `session.json` for [sessionId].
  ///
  /// Throws a [FormatException] if the file is missing, not valid JSON, or
  /// fails schema validation. Callers must catch this and transition the
  /// session to [SessionState.invalid] -- never retry in a loop.
  Future<SessionSpec> readSessionSpec(String sessionId) async {
    final file = sessionSpecFile(sessionId);
    if (!await file.exists()) {
      throw FormatException('session.json not found for session "$sessionId"');
    }
    final raw = await file.readAsString();
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FormatException(
          'session.json for "$sessionId" is not valid JSON: $e');
    }
    return SessionSpec.fromJson(json);
  }

  /// Reads `status.json` for [sessionId], or null if it doesn't exist yet (e.g.
  /// a session just dropped onto the filesystem over SMB, not yet discovered).
  Future<SessionStatus?> readStatus(String sessionId) async {
    final file = statusFile(sessionId);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    return SessionStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Writes `status.json` for [sessionId] atomically.
  Future<void> writeStatus(SessionStatus status) async {
    await writeAtomic(
      statusFile(status.sessionId),
      const JsonEncoder.withIndent('  ').convert(status.toJson()),
    );
  }

  /// Ensures every session directory under `sessions/` has a `status.json`.
  ///
  /// This is what makes the "drop a folder onto the NAS over SMB" workflow
  /// converge on the same on-disk state as `POST /api/sessions`: a directory
  /// containing `session.json` but no `status.json` is a newly discovered session
  /// and gets a fresh `queued` status. A `session.json` that fails to parse
  /// immediately produces an `invalid` status recording the parse error,
  /// so it is never retried in a poll loop.
  Future<void> discoverNewSessions() async {
    for (final sessionId in await listSessionIds()) {
      if (await statusFile(sessionId).exists()) continue;

      try {
        final spec = await readSessionSpec(sessionId);
        await writeStatus(
          SessionStatus.initial(
              sessionId: sessionId, roundsPlanned: spec.rounds),
        );
      } on FormatException catch (e) {
        final now = DateTime.now().toUtc();
        await writeStatus(
          SessionStatus(
            sessionId: sessionId,
            state: SessionState.invalid,
            createdAt: now,
            updatedAt: now,
            roundsPlanned: 0,
            error: e.message,
          ),
        );
      }
    }
  }

  /// On startup, any session left in [SessionState.running] is stale by definition
  /// (the process that was driving it is gone) -- transition it to
  /// [SessionState.interrupted]. Partial artifacts are left untouched on disk.
  Future<void> recoverInterruptedSessions() async {
    for (final sessionId in await listSessionIds()) {
      final status = await readStatus(sessionId);
      if (status == null || status.state != SessionState.running) continue;
      await writeStatus(
        status.transitionTo(
          SessionState.interrupted,
          reason: 'Server restarted while this session was running.',
        ),
      );
    }
  }
}
