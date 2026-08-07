/// Data models for jobs and their mutable status.
///
/// See `REQUIREMENTS.md` §4 for the on-disk schemas these mirror.
library;

/// The states a job can be in. See `REQUIREMENTS.md` §4 for the full state
/// machine diagram.
enum JobState {
  queued,
  running,
  done,
  failed,
  cancelled,
  interrupted,
  invalid;

  static JobState parse(String value) => JobState.values.firstWhere(
        (s) => s.name == value,
        orElse: () =>
            throw FormatException('Unknown job state: "$value"'),
      );
}

/// The immutable, submitter-authored job specification (`job.json`).
class JobSpec {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String name;
  final String description;
  final String apk;
  final String package;
  final String activity;
  final int repetitions;
  final int? runTimeoutSeconds;
  final List<String> expectedResultFiles;
  final String deviceResultDir;
  final Map<String, dynamic> tags;

  const JobSpec({
    this.schemaVersion = currentSchemaVersion,
    required this.name,
    this.description = '',
    this.apk = 'app.apk',
    required this.package,
    required this.activity,
    this.repetitions = 1,
    this.runTimeoutSeconds,
    this.expectedResultFiles = const [],
    required this.deviceResultDir,
    this.tags = const {},
  });

  /// Parses and validates a `job.json` map.
  ///
  /// Throws a [FormatException] with a human-readable message if the map
  /// doesn't satisfy the minimal schema. Callers are expected to catch this
  /// and transition the job to [JobState.invalid] rather than retry.
  factory JobSpec.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('job.json: "$key" must be a non-empty string');
      }
      return value;
    }

    final repetitions = json['repetitions'];
    if (repetitions != null &&
        (repetitions is! int || repetitions < 1)) {
      throw const FormatException(
        'job.json: "repetitions" must be a positive integer',
      );
    }

    final expectedResultFiles = json['expected_result_files'];
    if (expectedResultFiles != null && expectedResultFiles is! List) {
      throw const FormatException(
        'job.json: "expected_result_files" must be a list of strings',
      );
    }

    return JobSpec(
      schemaVersion: json['schema_version'] as int? ?? currentSchemaVersion,
      name: requireString('name'),
      description: json['description'] as String? ?? '',
      apk: json['apk'] as String? ?? 'app.apk',
      package: requireString('package'),
      activity: requireString('activity'),
      repetitions: (json['repetitions'] as int?) ?? 1,
      runTimeoutSeconds: json['run_timeout_seconds'] as int?,
      expectedResultFiles: (expectedResultFiles as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      deviceResultDir: requireString('device_result_dir'),
      tags: (json['tags'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'name': name,
        'description': description,
        'apk': apk,
        'package': package,
        'activity': activity,
        'repetitions': repetitions,
        if (runTimeoutSeconds != null)
          'run_timeout_seconds': runTimeoutSeconds,
        'expected_result_files': expectedResultFiles,
        'device_result_dir': deviceResultDir,
        'tags': tags,
      };
}

/// One entry in a [JobStatus.history] list.
class JobHistoryEntry {
  final DateTime at;
  final String from;
  final String to;
  final String? reason;

  const JobHistoryEntry({
    required this.at,
    required this.from,
    required this.to,
    this.reason,
  });

  factory JobHistoryEntry.fromJson(Map<String, dynamic> json) =>
      JobHistoryEntry(
        at: DateTime.parse(json['at'] as String),
        from: json['from'] as String,
        to: json['to'] as String,
        reason: json['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'from': from,
        'to': to,
        if (reason != null) 'reason': reason,
      };
}

/// The mutable, server-owned job state (`status.json`).
class JobStatus {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String jobId;
  final JobState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int runsCompleted;
  final int runsPlanned;
  final String? currentRun;
  final List<JobHistoryEntry> history;
  final String? error;

  const JobStatus({
    this.schemaVersion = currentSchemaVersion,
    required this.jobId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.runsCompleted = 0,
    required this.runsPlanned,
    this.currentRun,
    this.history = const [],
    this.error,
  });

  /// A freshly created, `queued` status for a newly discovered job.
  factory JobStatus.initial({
    required String jobId,
    required int runsPlanned,
  }) {
    final now = DateTime.now().toUtc();
    return JobStatus(
      jobId: jobId,
      state: JobState.queued,
      createdAt: now,
      updatedAt: now,
      runsPlanned: runsPlanned,
    );
  }

  factory JobStatus.fromJson(Map<String, dynamic> json) => JobStatus(
        schemaVersion:
            json['schema_version'] as int? ?? currentSchemaVersion,
        jobId: json['job_id'] as String,
        state: JobState.parse(json['state'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        runsCompleted: json['runs_completed'] as int? ?? 0,
        runsPlanned: json['runs_planned'] as int,
        currentRun: json['current_run'] as String?,
        history: (json['history'] as List?)
                ?.map((e) =>
                    JobHistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        error: json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'job_id': jobId,
        'state': state.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'runs_completed': runsCompleted,
        'runs_planned': runsPlanned,
        'current_run': currentRun,
        'history': history.map((e) => e.toJson()).toList(),
        'error': error,
      };

  /// Returns a copy of this status transitioned to [to], appending a
  /// [JobHistoryEntry] recording the transition.
  JobStatus transitionTo(
    JobState to, {
    String? reason,
    String? error,
    int? runsCompleted,
    String? currentRun,
  }) {
    final now = DateTime.now().toUtc();
    return JobStatus(
      jobId: jobId,
      state: to,
      createdAt: createdAt,
      updatedAt: now,
      runsCompleted: runsCompleted ?? this.runsCompleted,
      runsPlanned: runsPlanned,
      currentRun: currentRun ?? this.currentRun,
      history: [
        ...history,
        JobHistoryEntry(at: now, from: state.name, to: to.name, reason: reason),
      ],
      error: error ?? this.error,
    );
  }
}
