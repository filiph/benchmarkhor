import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

/// Records one [FrameTiming] row per Frame, tagged with the phase of the Trial
/// during which it was rendered.
///
/// The device never averages, sorts or filters: every Frame is written out
/// verbatim, and deciding which ones matter is the host's job. See
/// `doc/CONTEXT-SHARED.md` for Trial/Frame, and `adb_server/CONTRACT.md` for
/// the result-file and completion contract this honours.
class FrameRecorder {
  /// The engine batches [FrameTiming]s and may only deliver them once per
  /// second, so both flushing stale Frames and collecting the last ones need
  /// patience.
  static const Duration flushDelay = Duration(seconds: 2);

  final List<Map<String, Object?>> _frames = <Map<String, Object?>>[];

  String _phase = 'unknown';

  bool _recording = false;

  /// The number of Frames recorded so far.
  int get frameCount => _frames.length;

  /// Labels every Frame recorded from now on, until the next assignment.
  ///
  /// Because the engine reports Frames late, a Frame is tagged with whatever
  /// phase is current when its timing *arrives*, which smears the boundary
  /// between phases by up to one batch. Phases are therefore approximate
  /// markers, not exact partitions.
  set phase(String value) => _phase = value;

  /// Discards stale batched Frames, then starts recording.
  Future<void> start() async {
    await Future<void>.delayed(flushDelay);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _recording = true;
  }

  /// Waits until the engine has stopped delivering Frames, then stops
  /// recording.
  Future<void> stop() async {
    var previousCount = -1;
    while (previousCount != _frames.length) {
      previousCount = _frames.length;
      await Future<void>.delayed(flushDelay);
    }
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _recording = false;
  }

  /// Writes the recorded Frames as newline-delimited JSON objects into
  /// [fileName] in the result directory, then signals completion the way
  /// `adb_server/CONTRACT.md` requires.
  ///
  /// Returns the directory written to.
  Future<Directory> writeResults({String fileName = 'frames.jsonl'}) async {
    if (_recording) {
      throw StateError('Call stop() before writeResults().');
    }
    final directory = await _resultDirectory();
    final file = File('${directory.path}/$fileName');
    final sink = file.openWrite();
    for (final frame in _frames) {
      sink.writeln(jsonEncode(frame));
    }
    await sink.flush();
    await sink.close();

    // Only once every result file is closed and flushed.
    await File('${directory.path}/DONE').writeAsString('');
    stdout.writeln('BENCH_DONE 0 ${file.path} ${_frames.length} frames');
    await stdout.flush();
    return directory;
  }

  /// On Android this is `/sdcard/Android/data/<pkg>/files`, which `adb pull`
  /// can reach without root. Elsewhere it falls back to the app's documents
  /// directory so the Trial can also be run on a desktop host.
  Future<Directory> _resultDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames.add(<String, Object?>{
        'phase': _phase,
        'frameNumber': timing.frameNumber,
        'vsyncStart': timing.timestampInMicroseconds(FramePhase.vsyncStart),
        'buildStart': timing.timestampInMicroseconds(FramePhase.buildStart),
        'buildFinish': timing.timestampInMicroseconds(FramePhase.buildFinish),
        'rasterStart': timing.timestampInMicroseconds(FramePhase.rasterStart),
        'rasterFinish': timing.timestampInMicroseconds(FramePhase.rasterFinish),
        'buildUs': timing.buildDuration.inMicroseconds,
        'rasterUs': timing.rasterDuration.inMicroseconds,
        'vsyncOverheadUs': timing.vsyncOverhead.inMicroseconds,
        'totalSpanUs': timing.totalSpan.inMicroseconds,
        'layerCacheBytes': timing.layerCacheBytes,
        'pictureCacheBytes': timing.pictureCacheBytes,
      });
    }
  }
}
