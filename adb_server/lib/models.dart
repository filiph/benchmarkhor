/// Data models for sessions and their mutable status.
///
/// See `REQUIREMENTS.md` §4 for the on-disk schemas these mirror.
library;

/// The states a session can be in. See `REQUIREMENTS.md` §4 for the full state
/// machine diagram.
enum SessionState {
  queued,
  running,
  done,
  failed,
  cancelled,
  interrupted,
  invalid;

  static SessionState parse(String value) => SessionState.values.firstWhere(
        (s) => s.name == value,
        orElse: () => throw FormatException('Unknown session state: "$value"'),
      );
}

/// Specification for a single variant within a session.
class VariantSpec {
  final String apk;
  final String testApk;

  const VariantSpec({
    required this.apk,
    required this.testApk,
  });

  factory VariantSpec.fromJson(Map<String, dynamic> json) {
    return VariantSpec(
      apk: json['apk'] as String? ?? 'app.apk',
      testApk: json['test_apk'] as String? ?? 'app-test.apk',
    );
  }

  Map<String, dynamic> toJson() => {
        'apk': apk,
        'test_apk': testApk,
      };
}

/// The immutable, submitter-authored session specification (`session.json`).
class SessionSpec {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String name;
  final String description;
  final Map<String, VariantSpec> variants;
  final String package;
  final String testPackage;
  final String instrumentationRunner;
  final int rounds;
  final int? trialTimeoutSeconds;
  final List<String> expectedResultFiles;
  final String deviceResultDir;
  final Map<String, dynamic> tags;

  const SessionSpec({
    this.schemaVersion = currentSchemaVersion,
    required this.name,
    this.description = '',
    required this.variants,
    required this.package,
    required this.testPackage,
    required this.instrumentationRunner,
    this.rounds = 1,
    this.trialTimeoutSeconds,
    this.expectedResultFiles = const [],
    required this.deviceResultDir,
    this.tags = const {},
  });

  /// Parses and validates a `session.json` map.
  ///
  /// Throws a [FormatException] with a human-readable message if the map
  /// doesn't satisfy the minimal schema. Callers are expected to catch this
  /// and transition the session to [SessionState.invalid] rather than retry.
  factory SessionSpec.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException(
            'session.json: "$key" must be a non-empty string');
      }
      return value;
    }

    final variantsJson = json['variants'];
    if (variantsJson is! Map) {
      throw const FormatException('session.json: "variants" must be a map');
    }
    final variants = variantsJson.cast<String, dynamic>().map(
          (key, value) => MapEntry(
            key,
            VariantSpec.fromJson(value as Map<String, dynamic>),
          ),
        );

    final rounds = json['rounds'] ?? json['repetitions'];
    if (rounds != null && (rounds is! int || rounds < 1)) {
      throw const FormatException(
        'session.json: "rounds" must be a positive integer',
      );
    }

    final expectedResultFiles = json['expected_result_files'];
    if (expectedResultFiles != null && expectedResultFiles is! List) {
      throw const FormatException(
        'session.json: "expected_result_files" must be a list of strings',
      );
    }

    final package = requireString('package');

    return SessionSpec(
      schemaVersion: json['schema_version'] as int? ?? currentSchemaVersion,
      name: requireString('name'),
      description: json['description'] as String? ?? '',
      variants: variants,
      package: package,
      testPackage: json['test_package'] as String? ?? '$package.test',
      instrumentationRunner: json['instrumentation_runner'] as String? ??
          'dev.flutter.plugins.integration_test.FlutterTestRunner',
      rounds: (rounds as int?) ?? 1,
      trialTimeoutSeconds: (json['trial_timeout_seconds'] ??
          json['run_timeout_seconds']) as int?,
      expectedResultFiles:
          (expectedResultFiles as List?)?.map((e) => e as String).toList() ??
              const [],
      deviceResultDir: requireString('device_result_dir'),
      tags: (json['tags'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'name': name,
        'description': description,
        'variants': variants.map((k, v) => MapEntry(k, v.toJson())),
        'package': package,
        'test_package': testPackage,
        'instrumentation_runner': instrumentationRunner,
        'rounds': rounds,
        if (trialTimeoutSeconds != null)
          'trial_timeout_seconds': trialTimeoutSeconds,
        'expected_result_files': expectedResultFiles,
        'device_result_dir': deviceResultDir,
        'tags': tags,
      };
}

/// One entry in a [SessionStatus.history] list.
class SessionHistoryEntry {
  final DateTime at;
  final String from;
  final String to;
  final String? reason;

  const SessionHistoryEntry({
    required this.at,
    required this.from,
    required this.to,
    this.reason,
  });

  factory SessionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SessionHistoryEntry(
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

/// The mutable, server-owned session state (`status.json`).
class SessionStatus {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String sessionId;
  final SessionState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int roundsCompleted;
  final int roundsPlanned;
  final String? currentTrial;
  final List<SessionHistoryEntry> history;
  final String? error;

  const SessionStatus({
    this.schemaVersion = currentSchemaVersion,
    required this.sessionId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.roundsCompleted = 0,
    required this.roundsPlanned,
    this.currentTrial,
    this.history = const [],
    this.error,
  });

  /// A freshly created, `queued` status for a newly discovered session.
  factory SessionStatus.initial({
    required String sessionId,
    required int roundsPlanned,
  }) {
    final now = DateTime.now().toUtc();
    return SessionStatus(
      sessionId: sessionId,
      state: SessionState.queued,
      createdAt: now,
      updatedAt: now,
      roundsPlanned: roundsPlanned,
    );
  }

  factory SessionStatus.fromJson(Map<String, dynamic> json) => SessionStatus(
        schemaVersion: json['schema_version'] as int? ?? currentSchemaVersion,
        sessionId: (json['session_id'] ?? json['job_id']) as String,
        state: SessionState.parse(json['state'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        roundsCompleted:
            (json['rounds_completed'] ?? json['runs_completed']) as int? ?? 0,
        roundsPlanned: (json['rounds_planned'] ?? json['runs_planned']) as int,
        currentTrial: (json['current_trial'] ?? json['current_run']) as String?,
        history: (json['history'] as List?)
                ?.map((e) =>
                    SessionHistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        error: json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'session_id': sessionId,
        'state': state.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'rounds_completed': roundsCompleted,
        'rounds_planned': roundsPlanned,
        'current_trial': currentTrial,
        'history': history.map((e) => e.toJson()).toList(),
        'error': error,
      };

  /// Returns a copy of this status transitioned to [to], appending a
  /// [SessionHistoryEntry] recording the transition.
  SessionStatus transitionTo(
    SessionState to, {
    String? reason,
    String? error,
    int? roundsCompleted,
    String? currentTrial,
  }) {
    final now = DateTime.now().toUtc();
    return SessionStatus(
      sessionId: sessionId,
      state: to,
      createdAt: createdAt,
      updatedAt: now,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      roundsPlanned: roundsPlanned,
      currentTrial: currentTrial ?? this.currentTrial,
      history: [
        ...history,
        SessionHistoryEntry(
            at: now, from: state.name, to: to.name, reason: reason),
      ],
      error: error,
    );
  }
}

/// The metadata captured for a single [Trial] (`trial.json`).
class TrialMetadata {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String sessionId;
  final String variantName;
  final String trialId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final Map<String, dynamic> deviceBefore;
  final Map<String, dynamic> deviceAfter;
  final List<String> warnings;
  final Map<String, dynamic> config;
  final String? deviceProfile;
  final String? deviceProfileSha256;

  const TrialMetadata({
    this.schemaVersion = currentSchemaVersion,
    required this.sessionId,
    required this.variantName,
    required this.trialId,
    required this.startedAt,
    required this.finishedAt,
    this.deviceBefore = const {},
    this.deviceAfter = const {},
    this.warnings = const [],
    this.config = const {},
    this.deviceProfile,
    this.deviceProfileSha256,
  });

  factory TrialMetadata.fromJson(Map<String, dynamic> json) => TrialMetadata(
        schemaVersion: json['schema_version'] as int? ?? currentSchemaVersion,
        sessionId: json['session_id'] as String,
        variantName: json['variant_name'] as String,
        trialId: json['trial_id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        finishedAt: DateTime.parse(json['finished_at'] as String),
        deviceBefore:
            json['device_before'] as Map<String, dynamic>? ?? const {},
        deviceAfter: json['device_after'] as Map<String, dynamic>? ?? const {},
        warnings: (json['warnings'] as List?)?.cast<String>() ?? const [],
        config: json['config'] as Map<String, dynamic>? ?? const {},
        deviceProfile: json['device_profile'] as String?,
        deviceProfileSha256: json['device_profile_sha256'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'session_id': sessionId,
        'variant_name': variantName,
        'trial_id': trialId,
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt.toIso8601String(),
        'device_before': deviceBefore,
        'device_after': deviceAfter,
        'warnings': warnings,
        'config': config,
        if (deviceProfile != null) 'device_profile': deviceProfile,
        if (deviceProfileSha256 != null)
          'device_profile_sha256': deviceProfileSha256,
      };
}
