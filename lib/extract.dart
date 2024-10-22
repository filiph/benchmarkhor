import 'dart:convert';

import 'package:benchmarkhor/benchmark_result.dart';
import 'package:benchmarkhor/src/timeline_event.dart';
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
    if (name.startsWith('io.flutter.ui')) {
      uiThreadId = event.threadId!;
    } else if (name.startsWith('io.flutter.raster')) {
      rasterThreadId = event.threadId!;
    }
  }
  assert(uiThreadId != -1);
  assert(rasterThreadId != -1);

  final uiTimes = measureTimes(events, uiThreadId, 'Dart_InvokeClosure')
      .toList(growable: false);
  final rasterTimes =
      measureTimes(events, rasterThreadId, 'GPURasterizer::Draw')
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
    List<TimelineEvent> events, int threadId, Pattern eventName) sync* {
  final log = Logger('measureTime');

  /// Started event is null when there hasn't yet been a "B" event, or when
  /// it has already been closed by an "E" event. Otherwise, it's the
  /// latest "B" event.
  TimelineEvent? startedEvent;

  // See the following document to understand what all these phases
  // and ids mean:
  // https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview
  for (final event in events) {
    if (event.threadId != threadId) continue;
    if (!(event.name ?? '').contains(eventName)) continue;
    if (event.timestampMicros == null) {
      log.warning("Event doesn't include a timestamp. Ignoring. "
          'Event: ${event.json}');
      continue;
    }
    if (event.phase == 'B') {
      if (startedEvent != null) {
        log.warning('New event beginning but last one '
            "hasn't ended yet. Ignoring the previous beginning. "
            'Existing: ${startedEvent.json}. New: ${event.json}. ');
      }
      startedEvent = event;
    } else if (event.phase == 'E') {
      if (startedEvent == null) {
        log.warning("Event ended but we didn't see it begin. Ignoring. "
            'End event: ${event.json}');
        continue;
      }
      if (event.timestampMicros == null) {
        log.warning("Event doesn't have a timestamp: ${event.json}. Ignoring.");
        continue;
      }

      // We can assert non-null because we're skipping all events
      // without timestamps.
      final elapsedTime =
          event.timestampMicros! - startedEvent.timestampMicros!;
      if (elapsedTime > 10000000) {
        log.warning('Event seems to be way too long, over 10 seconds. '
            'It will be added as is, but check the timeline. '
            'Start: ${startedEvent.json}. End: ${event.json}');
      }

      yield elapsedTime;
      startedEvent = null;
    }
  }
}

List<TimelineEvent>? _parseEvents(Map<String, dynamic> json) {
  final jsonEvents = json['traceEvents'] as List<dynamic>?;

  if (jsonEvents == null) {
    return null;
  }

  final timelineEvents =
      Iterable.castFrom<dynamic, Map<String, dynamic>>(jsonEvents)
          .map<TimelineEvent>(
              (Map<String, dynamic> eventJson) => TimelineEvent(eventJson))
          .toList();

  timelineEvents.sort((TimelineEvent e1, TimelineEvent e2) {
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
