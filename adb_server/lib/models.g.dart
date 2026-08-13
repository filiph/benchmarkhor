// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VariantSpec _$VariantSpecFromJson(Map<String, dynamic> json) => _VariantSpec(
  apk: json['apk'] as String? ?? 'app.apk',
  testApk: json['test_apk'] as String? ?? 'app-test.apk',
);

Map<String, dynamic> _$VariantSpecToJson(_VariantSpec instance) =>
    <String, dynamic>{'apk': instance.apk, 'test_apk': instance.testApk};

_SessionSpec _$SessionSpecFromJson(Map<String, dynamic> json) => _SessionSpec(
  schemaVersion:
      (json['schema_version'] as num?)?.toInt() ??
      SessionSpec.currentSchemaVersion,
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  variants: (json['variants'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, VariantSpec.fromJson(e as Map<String, dynamic>)),
  ),
  package: json['package'] as String,
  testPackage: json['test_package'] as String,
  instrumentationRunner:
      json['instrumentation_runner'] as String? ??
      'dev.flutter.plugins.integration_test.FlutterTestRunner',
  rounds: (json['rounds'] as num?)?.toInt() ?? 1,
  trialTimeoutSeconds: (json['trial_timeout_seconds'] as num?)?.toInt(),
  expectedResultFiles:
      (json['expected_result_files'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  deviceResultDir: json['device_result_dir'] as String,
  tags: json['tags'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$SessionSpecToJson(_SessionSpec instance) =>
    <String, dynamic>{
      'schema_version': instance.schemaVersion,
      'name': instance.name,
      'description': instance.description,
      'variants': instance.variants,
      'package': instance.package,
      'test_package': instance.testPackage,
      'instrumentation_runner': instance.instrumentationRunner,
      'rounds': instance.rounds,
      'trial_timeout_seconds': ?instance.trialTimeoutSeconds,
      'expected_result_files': instance.expectedResultFiles,
      'device_result_dir': instance.deviceResultDir,
      'tags': instance.tags,
    };

_SessionHistoryEntry _$SessionHistoryEntryFromJson(Map<String, dynamic> json) =>
    _SessionHistoryEntry(
      at: DateTime.parse(json['at'] as String),
      from: json['from'] as String,
      to: json['to'] as String,
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$SessionHistoryEntryToJson(
  _SessionHistoryEntry instance,
) => <String, dynamic>{
  'at': instance.at.toIso8601String(),
  'from': instance.from,
  'to': instance.to,
  'reason': ?instance.reason,
};

_SessionStatus _$SessionStatusFromJson(Map<String, dynamic> json) =>
    _SessionStatus(
      schemaVersion:
          (json['schema_version'] as num?)?.toInt() ??
          SessionStatus.currentSchemaVersion,
      sessionId: json['session_id'] as String,
      state: $enumDecode(_$SessionStateEnumMap, json['state']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      roundsCompleted: (json['rounds_completed'] as num?)?.toInt() ?? 0,
      roundsPlanned: (json['rounds_planned'] as num).toInt(),
      currentTrial: json['current_trial'] as String?,
      history:
          (json['history'] as List<dynamic>?)
              ?.map(
                (e) => SessionHistoryEntry.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      error: json['error'] as String?,
    );

Map<String, dynamic> _$SessionStatusToJson(_SessionStatus instance) =>
    <String, dynamic>{
      'schema_version': instance.schemaVersion,
      'session_id': instance.sessionId,
      'state': _$SessionStateEnumMap[instance.state]!,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'rounds_completed': instance.roundsCompleted,
      'rounds_planned': instance.roundsPlanned,
      'current_trial': instance.currentTrial,
      'history': instance.history,
      'error': instance.error,
    };

const _$SessionStateEnumMap = {
  SessionState.queued: 'queued',
  SessionState.running: 'running',
  SessionState.done: 'done',
  SessionState.failed: 'failed',
  SessionState.cancelled: 'cancelled',
  SessionState.interrupted: 'interrupted',
  SessionState.invalid: 'invalid',
};

_TrialMetadata _$TrialMetadataFromJson(Map<String, dynamic> json) =>
    _TrialMetadata(
      schemaVersion:
          (json['schema_version'] as num?)?.toInt() ??
          TrialMetadata.currentSchemaVersion,
      sessionId: json['session_id'] as String,
      variantName: json['variant_name'] as String,
      trialId: json['trial_id'] as String,
      round: (json['round'] as num?)?.toInt(),
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: DateTime.parse(json['finished_at'] as String),
      deviceBefore: json['device_before'] as Map<String, dynamic>? ?? const {},
      deviceAfter: json['device_after'] as Map<String, dynamic>? ?? const {},
      warnings:
          (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      config: json['config'] as Map<String, dynamic>? ?? const {},
      deviceProfile: json['device_profile'] as String?,
      deviceProfileSha256: json['device_profile_sha256'] as String?,
      thermalThrottled: json['thermal_throttled'] as bool? ?? false,
      maxThermalStatus: (json['max_thermal_status'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TrialMetadataToJson(_TrialMetadata instance) =>
    <String, dynamic>{
      'schema_version': instance.schemaVersion,
      'session_id': instance.sessionId,
      'variant_name': instance.variantName,
      'trial_id': instance.trialId,
      'round': ?instance.round,
      'started_at': instance.startedAt.toIso8601String(),
      'finished_at': instance.finishedAt.toIso8601String(),
      'device_before': instance.deviceBefore,
      'device_after': instance.deviceAfter,
      'warnings': instance.warnings,
      'config': instance.config,
      'device_profile': ?instance.deviceProfile,
      'device_profile_sha256': ?instance.deviceProfileSha256,
      'thermal_throttled': instance.thermalThrottled,
      'max_thermal_status': ?instance.maxThermalStatus,
    };
