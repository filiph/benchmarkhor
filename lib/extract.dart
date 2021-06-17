import 'dart:convert';

import 'package:benchmarkhor/benchmark_result.dart';
import 'package:logging/logging.dart';

/// May throw [FormatException] if [fileContents] aren't valid JSON.
Future<BenchmarkResult> extractStatsFromFlutterTimeline(
    String label, DateTime timestamp, String fileContents,
    {required bool shouldSort}) async {
  final map = json.decode(fileContents) as Map<String, dynamic>;

  final events = _parseEvents(map)!;

  var uiThreadId = -1;
  var rasterThreadId = -1;

  for (final event in events.where((e) => e.name == 'thread_name')) {
    final name = event.arguments!['name'] as String;
    if (name.startsWith('1.ui')) {
      uiThreadId = event.threadId!;
    } else if (name.startsWith('1.raster')) {
      rasterThreadId = event.threadId!;
    }
  }
  assert(uiThreadId != -1);
  assert(rasterThreadId != -1);

  final uiTimes = measureTimes(events, uiThreadId, 'MessageLoop::FlushTasks')
      .toList(growable: false);
  final rasterTimes =
      measureTimes(events, rasterThreadId, 'MessageLoop::FlushTasks')
          .toList(growable: false);

  if (shouldSort) {
    uiTimes.sort();
    rasterTimes.sort();
  }

  return BenchmarkResult(
    label: label,
    timestamp: timestamp,
    series: [
      MeasurementSeries('UI thread', uiTimes),
      MeasurementSeries('Raster thread', rasterTimes),
    ],
  );
}

/// Measures events taken by events that are named [eventName]
/// in thread [threadId].
Iterable<int> measureTimes(
    List<_TimelineEvent> events, int threadId, Pattern eventName) sync* {
  final log = Logger('measureTime');

  int? latestStart;

  // See the following document to understand what all these phases
  // and ids mean:
  // https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview
  for (final event in events) {
    if (event.threadId != threadId) continue;
    if (!(event.name ?? '').contains(eventName)) continue;
    if (event.phase == 'B') {
      if (latestStart != null) {
        log.warning('New event beginning but last one (ts=$latestStart) '
            "hasn't ended yet: ${event.json}");
        continue;
      }
      latestStart = event.timestampMicros;
    } else if (event.phase == 'E') {
      if (latestStart == null) {
        log.warning("Event ended but we didn't see it begin: ${event.json}");
        continue;
      }
      if (event.timestampMicros == null) {
        log.warning("Event doesn't have a timestamp: ${event.json}");
        continue;
      }
      yield event.timestampMicros! - latestStart;
      latestStart = null;
    }
  }
}

List<_TimelineEvent>? _parseEvents(Map<String, dynamic> json) {
  final jsonEvents = json['traceEvents'] as List<dynamic>?;

  if (jsonEvents == null) {
    return null;
  }

  final timelineEvents =
      Iterable.castFrom<dynamic, Map<String, dynamic>>(jsonEvents)
          .map<_TimelineEvent>(
              (Map<String, dynamic> eventJson) => _TimelineEvent(eventJson))
          .toList();

  timelineEvents.sort((_TimelineEvent e1, _TimelineEvent e2) {
    final ts1 = e1.timestampMicros;
    final ts2 = e2.timestampMicros;
    if (ts1 == null) {
      if (ts2 == null) {
        return 0;
      } else {
        return -1;
      }
    } else if (ts2 == null) {
      return 1;
    } else {
      return ts1.compareTo(ts2);
    }
  });

  return timelineEvents;
}

/// A single timeline event.
///
/// Copy-pasted from `flutter_driver:driver`.
class _TimelineEvent {
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
  _TimelineEvent(this.json)
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
