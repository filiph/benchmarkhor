/// Possible states for a local session.
enum LocalSessionState {
  queued,
  running,
  completed,
  failed,
  interrupted,
  invalid;

  static LocalSessionState parse(String value) {
    switch (value) {
      case 'queued':
        return LocalSessionState.queued;
      case 'running':
        return LocalSessionState.running;
      case 'completed':
      case 'done':
        return LocalSessionState.completed;
      case 'failed':
        return LocalSessionState.failed;
      case 'interrupted':
        return LocalSessionState.interrupted;
      case 'invalid':
        return LocalSessionState.invalid;
      default:
        throw FormatException('Unknown session state: "$value"');
    }
  }
}

/// Specification for a single executable variant in a local session.
class ExecutableVariantSpec {
  final String name;
  final String executable;
  final List<String> args;
  final String? source;

  const ExecutableVariantSpec({
    required this.name,
    required this.executable,
    this.args = const [],
    this.source,
  });

  factory ExecutableVariantSpec.fromJson(String name, Map<String, dynamic> json) {
    final exec = json['executable'];
    if (exec is! String || exec.trim().isEmpty) {
      throw FormatException(
        'Variant "$name": "executable" must be a non-empty string',
      );
    }

    final rawArgs = json['args'];
    final List<String> args;
    if (rawArgs == null) {
      args = const [];
    } else if (rawArgs is List) {
      args = rawArgs.map((e) => e.toString()).toList();
    } else {
      throw FormatException('Variant "$name": "args" must be a list of strings');
    }

    final source = json['source'] as String?;

    return ExecutableVariantSpec(
      name: name,
      executable: exec.trim(),
      args: args,
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'executable': executable,
      'args': args,
    };
    if (source != null) {
      map['source'] = source;
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExecutableVariantSpec &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          executable == other.executable &&
          _listEquals(args, other.args) &&
          source == other.source;

  @override
  int get hashCode =>
      name.hashCode ^
      executable.hashCode ^
      Object.hashAll(args) ^
      (source?.hashCode ?? 0);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Session definition read from `session.json`.
class LocalSessionSpec {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String name;
  final String? description;
  final int rounds;
  final Map<String, ExecutableVariantSpec> variants;
  final int? trialTimeoutSeconds;

  const LocalSessionSpec({
    this.schemaVersion = currentSchemaVersion,
    required this.name,
    this.description,
    required this.rounds,
    required this.variants,
    this.trialTimeoutSeconds,
  });

  factory LocalSessionSpec.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('session.json: "name" must be a non-empty string');
    }

    final rawRounds = json['rounds'] ?? json['repetitions'];
    if (rawRounds != null && (rawRounds is! int || rawRounds < 1)) {
      throw const FormatException(
        'session.json: "rounds" must be a positive integer',
      );
    }
    final rounds = (rawRounds as int?) ?? 1;

    final variantsJson = json['variants'];
    if (variantsJson is! Map || variantsJson.isEmpty) {
      throw const FormatException(
        'session.json: "variants" must be a non-empty map',
      );
    }

    final variants = <String, ExecutableVariantSpec>{};
    for (final entry in variantsJson.entries) {
      final vName = entry.key.toString();
      final vVal = entry.value;
      if (vVal is! Map<String, dynamic>) {
        if (vVal is Map) {
          variants[vName] = ExecutableVariantSpec.fromJson(
            vName,
            vVal.cast<String, dynamic>(),
          );
        } else {
          throw FormatException(
            'session.json: variant "$vName" definition must be a JSON object',
          );
        }
      } else {
        variants[vName] = ExecutableVariantSpec.fromJson(vName, vVal);
      }
    }

    final schemaVersion = (json['schema_version'] as int?) ?? currentSchemaVersion;
    final description = json['description'] as String?;
    final timeout = (json['trial_timeout_seconds'] ?? json['timeout_seconds']) as int?;

    return LocalSessionSpec(
      schemaVersion: schemaVersion,
      name: name.trim(),
      description: description,
      rounds: rounds,
      variants: variants,
      trialTimeoutSeconds: timeout,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'schema_version': schemaVersion,
      'name': name,
      'rounds': rounds,
      'variants': {
        for (final entry in variants.entries) entry.key: entry.value.toJson(),
      },
    };
    if (description != null) {
      map['description'] = description;
    }
    if (trialTimeoutSeconds != null) {
      map['trial_timeout_seconds'] = trialTimeoutSeconds;
    }
    return map;
  }
}

/// History entry recording status state changes.
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

  factory SessionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SessionHistoryEntry(
      at: DateTime.parse(json['at'] as String),
      from: json['from'] as String,
      to: json['to'] as String,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'at': at.toUtc().toIso8601String(),
      'from': from,
      'to': to,
    };
    if (reason != null) {
      map['reason'] = reason;
    }
    return map;
  }
}

/// Mutable status stored in `status.json`.
class LocalSessionStatus {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String sessionId;
  final LocalSessionState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int roundsCompleted;
  final int roundsPlanned;
  final String? currentTrial;
  final List<SessionHistoryEntry> history;
  final String? error;

  const LocalSessionStatus({
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

  factory LocalSessionStatus.initial({
    required String sessionId,
    required int roundsPlanned,
  }) {
    final now = DateTime.now().toUtc();
    return LocalSessionStatus(
      sessionId: sessionId,
      state: LocalSessionState.queued,
      createdAt: now,
      updatedAt: now,
      roundsCompleted: 0,
      roundsPlanned: roundsPlanned,
    );
  }

  factory LocalSessionStatus.fromJson(Map<String, dynamic> json) {
    final sessionId = (json['session_id'] ?? json['job_id'] ?? '').toString();
    final rawState = json['state']?.toString() ?? 'queued';
    final state = LocalSessionState.parse(rawState);

    final createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now().toUtc();
    final updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : createdAt;

    final roundsCompleted =
        (json['rounds_completed'] ?? json['runs_completed'] ?? 0) as int;
    final roundsPlanned =
        (json['rounds_planned'] ?? json['runs_planned'] ?? 1) as int;
    final currentTrial = (json['current_trial'] ?? json['current_run']) as String?;
    final error = json['error'] as String?;

    final rawHistory = json['history'] as List?;
    final history = rawHistory != null
        ? rawHistory
            .map((e) => SessionHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList()
        : <SessionHistoryEntry>[];

    final schemaVersion =
        (json['schema_version'] as int?) ?? currentSchemaVersion;

    return LocalSessionStatus(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      state: state,
      createdAt: createdAt,
      updatedAt: updatedAt,
      roundsCompleted: roundsCompleted,
      roundsPlanned: roundsPlanned,
      currentTrial: currentTrial,
      history: history,
      error: error,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'schema_version': schemaVersion,
      'session_id': sessionId,
      'state': state.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'rounds_completed': roundsCompleted,
      'rounds_planned': roundsPlanned,
      'history': history.map((e) => e.toJson()).toList(),
    };
    if (currentTrial != null) {
      map['current_trial'] = currentTrial;
    }
    if (error != null) {
      map['error'] = error;
    }
    return map;
  }

  LocalSessionStatus transitionTo(
    LocalSessionState newState, {
    String? reason,
    String? error,
    String? currentTrial,
    int? roundsCompleted,
  }) {
    final now = DateTime.now().toUtc();
    final newHistory = [
      ...history,
      SessionHistoryEntry(
        at: now,
        from: state.name,
        to: newState.name,
        reason: reason,
      ),
    ];

    return LocalSessionStatus(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      state: newState,
      createdAt: createdAt,
      updatedAt: now,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      roundsPlanned: roundsPlanned,
      currentTrial: currentTrial ?? this.currentTrial,
      history: newHistory,
      error: error ?? this.error,
    );
  }
}

/// Metadata stored in `trial.json` for each trial.
class TrialMetadata {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String sessionId;
  final String trialId;
  final String variantName;
  final int round;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int exitCode;
  final num? durationUs;
  final Map<String, dynamic> deviceBefore;
  final Map<String, dynamic> deviceAfter;
  final List<String> warnings;
  final String? error;

  const TrialMetadata({
    this.schemaVersion = currentSchemaVersion,
    required this.sessionId,
    required this.trialId,
    required this.variantName,
    required this.round,
    required this.startedAt,
    required this.finishedAt,
    required this.exitCode,
    this.durationUs,
    this.deviceBefore = const {},
    this.deviceAfter = const {},
    this.warnings = const [],
    this.error,
  });

  factory TrialMetadata.fromJson(Map<String, dynamic> json) {
    return TrialMetadata(
      schemaVersion: (json['schema_version'] as int?) ?? currentSchemaVersion,
      sessionId: json['session_id'] as String,
      trialId: json['trial_id'] as String,
      variantName: json['variant_name'] as String,
      round: (json['round'] as int?) ?? 1,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: DateTime.parse(json['finished_at'] as String),
      exitCode: (json['exit_code'] as int?) ?? 0,
      durationUs: json['duration_us'] as num?,
      deviceBefore: (json['device_before'] as Map?)?.cast<String, dynamic>() ?? const {},
      deviceAfter: (json['device_after'] as Map?)?.cast<String, dynamic>() ?? const {},
      warnings: (json['warnings'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'schema_version': schemaVersion,
      'session_id': sessionId,
      'trial_id': trialId,
      'variant_name': variantName,
      'round': round,
      'started_at': startedAt.toUtc().toIso8601String(),
      'finished_at': finishedAt.toUtc().toIso8601String(),
      'exit_code': exitCode,
      if (durationUs != null) 'duration_us': durationUs,
      'device_before': deviceBefore,
      'device_after': deviceAfter,
      'warnings': warnings,
    };
    if (error != null) {
      map['error'] = error;
    }
    return map;
  }
}
