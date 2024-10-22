import 'package:meta/meta.dart';

/// A single timeline event.
///
/// Copy-pasted from `flutter_driver:driver`.
@internal
class TimelineEvent {
  /// The original event JSON.
  final Map<String, dynamic> json;

  /// The name of the event.
  ///
  /// Corresponds to the "name" field in the JSON event.
  final String? name;

  /// Event category. Events with different names may share the same category.
  ///
  /// Corresponds to the "cat" field in the JSON event.
  final String? category;

  /// For a given long lasting event, denotes the phase of the event, such as
  /// "B" for "event began", and "E" for "event ended".
  ///
  /// Corresponds to the "ph" field in the JSON event.
  final String? phase;

  /// ID of process that emitted the event.
  ///
  /// Corresponds to the "pid" field in the JSON event.
  final int? processId;

  /// ID of thread that issues the event.
  ///
  /// Corresponds to the "tid" field in the JSON event.
  final int? threadId;

  /// The duration of the event.
  ///
  /// Note, some events are reported with duration. Others are reported as a
  /// pair of begin/end events.
  ///
  /// Corresponds to the "dur" field in the JSON event.
  final Duration? duration;

  /// The thread duration of the event.
  ///
  /// Note, some events are reported with duration. Others are reported as a
  /// pair of begin/end events.
  ///
  /// Corresponds to the "tdur" field in the JSON event.
  final Duration? threadDuration;

  /// Time passed since tracing was enabled, in microseconds.
  ///
  /// Corresponds to the "ts" field in the JSON event.
  final int? timestampMicros;

  /// Thread clock time, in microseconds.
  ///
  /// Corresponds to the "tts" field in the JSON event.
  final int? threadTimestampMicros;

  /// Arbitrary data attached to the event.
  ///
  /// Corresponds to the "args" field in the JSON event.
  final Map<String, dynamic>? arguments;

  /// Creates a timeline event given JSON-encoded event data.
  TimelineEvent(this.json)
      : name = json['name'] as String?,
        category = json['cat'] as String?,
        phase = json['ph'] as String?,
        processId = json['pid'] as int?,
        threadId = json['tid'] as int?,
        duration = json['dur'] != null
            ? Duration(microseconds: json['dur'] as int)
            : null,
        threadDuration = json['tdur'] != null
            ? Duration(microseconds: json['tdur'] as int)
            : null,
        timestampMicros = json['ts'] as int?,
        threadTimestampMicros = json['tts'] as int?,
        arguments = json['args'] as Map<String, dynamic>?;
}
