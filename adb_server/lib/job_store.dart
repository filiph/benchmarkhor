import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

/// Disk I/O and state-machine logic for jobs.
///
/// All state lives under [dataDir]/jobs/&lt;job-id&gt;/. See `REQUIREMENTS.md`
/// §4 for the full on-disk layout and the rules around atomic writes.
class JobStore {
  final String dataDir;

  JobStore(this.dataDir);

  Directory get jobsDir => Directory(p.join(dataDir, 'jobs'));

  Directory jobDir(String jobId) => Directory(p.join(jobsDir.path, jobId));

  File jobSpecFile(String jobId) =>
      File(p.join(jobDir(jobId).path, 'job.json'));

  File statusFile(String jobId) =>
      File(p.join(jobDir(jobId).path, 'status.json'));

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

  /// Lists all job IDs currently present on disk, in lexicographic (i.e.
  /// chronological, FIFO) order.
  Future<List<String>> listJobIds() async {
    if (!await jobsDir.exists()) return const [];
    final ids = <String>[];
    await for (final entity in jobsDir.list()) {
      if (entity is Directory) {
        ids.add(p.basename(entity.path));
      }
    }
    ids.sort();
    return ids;
  }

  /// Reads and validates the `job.json` for [jobId].
  ///
  /// Throws a [FormatException] if the file is missing, not valid JSON, or
  /// fails schema validation. Callers must catch this and transition the
  /// job to [JobState.invalid] -- never retry in a loop.
  Future<JobSpec> readJobSpec(String jobId) async {
    final file = jobSpecFile(jobId);
    if (!await file.exists()) {
      throw FormatException('job.json not found for job "$jobId"');
    }
    final raw = await file.readAsString();
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FormatException('job.json for "$jobId" is not valid JSON: $e');
    }
    return JobSpec.fromJson(json);
  }

  /// Reads `status.json` for [jobId], or null if it doesn't exist yet (e.g.
  /// a job just dropped onto the filesystem over SMB, not yet discovered).
  Future<JobStatus?> readStatus(String jobId) async {
    final file = statusFile(jobId);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    return JobStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Writes `status.json` for [jobId] atomically.
  Future<void> writeStatus(JobStatus status) async {
    await writeAtomic(
      statusFile(status.jobId),
      const JsonEncoder.withIndent('  ').convert(status.toJson()),
    );
  }

  /// Ensures every job directory under `jobs/` has a `status.json`.
  ///
  /// This is what makes the "drop a folder onto the NAS over SMB" workflow
  /// converge on the same on-disk state as `POST /api/jobs`: a directory
  /// containing `job.json` but no `status.json` is a newly discovered job
  /// and gets a fresh `queued` status. A `job.json` that fails to parse
  /// immediately produces an `invalid` status recording the parse error,
  /// so it is never retried in a poll loop.
  Future<void> discoverNewJobs() async {
    for (final jobId in await listJobIds()) {
      if (await statusFile(jobId).exists()) continue;

      try {
        final spec = await readJobSpec(jobId);
        await writeStatus(
          JobStatus.initial(jobId: jobId, runsPlanned: spec.repetitions),
        );
      } on FormatException catch (e) {
        final now = DateTime.now().toUtc();
        await writeStatus(
          JobStatus(
            jobId: jobId,
            state: JobState.invalid,
            createdAt: now,
            updatedAt: now,
            runsPlanned: 0,
            error: e.message,
          ),
        );
      }
    }
  }

  /// On startup, any job left in [JobState.running] is stale by definition
  /// (the process that was driving it is gone) -- transition it to
  /// [JobState.interrupted]. Partial artifacts are left untouched on disk.
  Future<void> recoverInterruptedJobs() async {
    for (final jobId in await listJobIds()) {
      final status = await readStatus(jobId);
      if (status == null || status.state != JobState.running) continue;
      await writeStatus(
        status.transitionTo(
          JobState.interrupted,
          reason: 'Server restarted while this job was running.',
        ),
      );
    }
  }
}
