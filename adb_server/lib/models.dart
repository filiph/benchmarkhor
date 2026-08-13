/// Data models for sessions and their mutable status.
///
/// See `REQUIREMENTS.md` §4 for the on-disk schemas these mirror.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

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
@freezed
abstract class VariantSpec with _$VariantSpec {
  const VariantSpec._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory VariantSpec({
    @Default('app.apk') String apk,
    @Default('app-test.apk') String testApk,
  }) = _VariantSpec;

  factory VariantSpec.fromJson(Map<String, dynamic> json) =>
      _$VariantSpecFromJson(json);

  @override
  Map<String, dynamic> toJson();
}

Map<String, dynamic> _validateSessionSpecJson(Map<String, dynamic> json) {
  String requireString(String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('session.json: "$key" must be a non-empty string');
    }
    return value;
  }

  final variantsJson = json['variants'];
  if (variantsJson is! Map) {
    throw const FormatException('session.json: "variants" must be a map');
  }

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
  final normalized = Map<String, dynamic>.from(json);
  normalized['rounds'] = rounds ?? 1;
  normalized['package'] = package;
  normalized['name'] = requireString('name');
  normalized['device_result_dir'] = requireString('device_result_dir');
  if (json['test_package'] == null) {
    normalized['test_package'] = '$package.test';
  }
  if (json['trial_timeout_seconds'] == null &&
      json['run_timeout_seconds'] != null) {
    normalized['trial_timeout_seconds'] = json['run_timeout_seconds'];
  }

  return normalized;
}

/// The immutable, submitter-authored session specification (`session.json`).
@freezed
abstract class SessionSpec with _$SessionSpec {
  static const currentSchemaVersion = 1;

  const SessionSpec._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory SessionSpec({
    @Default(SessionSpec.currentSchemaVersion) int schemaVersion,
    required String name,
    @Default('') String description,
    required Map<String, VariantSpec> variants,
    required String package,
    required String testPackage,
    @Default('dev.flutter.plugins.integration_test.FlutterTestRunner')
    String instrumentationRunner,
    @Default(1) int rounds,
    int? trialTimeoutSeconds,
    @Default([]) List<String> expectedResultFiles,
    required String deviceResultDir,
    @Default({}) Map<String, dynamic> tags,
  }) = _SessionSpec;

  /// Parses and validates a `session.json` map.
  ///
  /// Throws a [FormatException] with a human-readable message if the map
  /// doesn't satisfy the minimal schema. Callers are expected to catch this
  /// and transition the session to [SessionState.invalid] rather than retry.
  factory SessionSpec.fromJson(Map<String, dynamic> json) =>
      _$SessionSpecFromJson(_validateSessionSpecJson(json));

  @override
  Map<String, dynamic> toJson();
}

/// One entry in a [SessionStatus.history] list.
@freezed
abstract class SessionHistoryEntry with _$SessionHistoryEntry {
  const SessionHistoryEntry._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory SessionHistoryEntry({
    required DateTime at,
    required String from,
    required String to,
    String? reason,
  }) = _SessionHistoryEntry;

  factory SessionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$SessionHistoryEntryFromJson(json);

  @override
  Map<String, dynamic> toJson();
}

Map<String, dynamic> _normalizeSessionStatusJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  normalized['session_id'] = json['session_id'] ?? json['job_id'];
  normalized['rounds_completed'] =
      json['rounds_completed'] ?? json['runs_completed'] ?? 0;
  normalized['rounds_planned'] = json['rounds_planned'] ?? json['runs_planned'];
  normalized['current_trial'] = json['current_trial'] ?? json['current_run'];
  return normalized;
}

/// The mutable, server-owned session state (`status.json`).
@freezed
abstract class SessionStatus with _$SessionStatus {
  static const currentSchemaVersion = 1;

  const SessionStatus._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SessionStatus({
    @Default(SessionStatus.currentSchemaVersion) int schemaVersion,
    required String sessionId,
    required SessionState state,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int roundsCompleted,
    required int roundsPlanned,
    String? currentTrial,
    @Default([]) List<SessionHistoryEntry> history,
    String? error,
  }) = _SessionStatus;

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

  factory SessionStatus.fromJson(Map<String, dynamic> json) =>
      _$SessionStatusFromJson(_normalizeSessionStatusJson(json));

  /// Returns the human-readable label for the primary timestamp of this session,
  /// based on its current [state].
  String get timestampLabel {
    switch (state) {
      case SessionState.queued:
        return 'updated';
      case SessionState.running:
        return 'started';
      case SessionState.failed:
        return 'failed at';
      case SessionState.done:
        return 'completed at';
      case SessionState.cancelled:
      case SessionState.interrupted:
      case SessionState.invalid:
        return 'ended at';
    }
  }

  /// Returns the primary timestamp for this session's current state, derived
  /// from its [history] or [updatedAt] fallback.
  DateTime get timestampValue {
    if (state == SessionState.queued) return updatedAt;
    if (state == SessionState.running) {
      for (final entry in history) {
        if (entry.to == 'running') return entry.at;
      }
      return updatedAt;
    }
    if (state == SessionState.done || state == SessionState.failed) {
      for (final entry in history.reversed) {
        if (entry.to == state.name) return entry.at;
      }
      return updatedAt;
    }
    // cancelled, interrupted, invalid
    if (history.isNotEmpty) return history.last.at;
    return updatedAt;
  }

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
          at: now,
          from: state.name,
          to: to.name,
          reason: reason,
        ),
      ],
      error: error,
    );
  }

  @override
  Map<String, dynamic> toJson();
}

/// The metadata captured for a single [Trial] (`trial.json`).
@freezed
abstract class TrialMetadata with _$TrialMetadata {
  static const currentSchemaVersion = 1;

  const TrialMetadata._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory TrialMetadata({
    @Default(TrialMetadata.currentSchemaVersion) int schemaVersion,
    required String sessionId,
    required String variantName,
    required String trialId,
    int? round,
    required DateTime startedAt,
    required DateTime finishedAt,
    @Default({}) Map<String, dynamic> deviceBefore,
    @Default({}) Map<String, dynamic> deviceAfter,
    @Default([]) List<String> warnings,
    @Default({}) Map<String, dynamic> config,
    String? deviceProfile,
    String? deviceProfileSha256,
    @Default(false) bool thermalThrottled,
    int? maxThermalStatus,
  }) = _TrialMetadata;

  factory TrialMetadata.fromJson(Map<String, dynamic> json) =>
      _$TrialMetadataFromJson(json);

  @override
  Map<String, dynamic> toJson();
}
