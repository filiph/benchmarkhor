// One Trial of the Expensive Route Optimized: ten taps on the Counter, then ten screens
// of flinging down the list. See `doc/CONTEXT-SHARED.md` for the vocabulary.

import 'package:example_apk/expensive_route_optimized.dart';
import 'package:example_apk/main_optimized.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'frame_recorder.dart';

/// How many screens' worth of list the Trial flings past.
const int screensToScroll = 10;

/// Roughly the speed of a brisk flick, in logical pixels per second.
const double flingSpeed = 3000;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Expensive Route Trial Optimized: ten taps, then ten screens of scrolling',
    (tester) async {
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final recorder = FrameRecorder();

      // Anything thrown in here — a finder that times out, a fling that misses,
      // a route that never opens — must still be reported, or the server waits
      // out `trial_timeout_seconds` and calls it a crash. See
      // `adb_server/CONTRACT.md`.
      try {
        await tester.pumpWidget(const MyApp());
        await _settleForReal(tester);

        for (var i = 0; i < 9; i++) {
          await tester.tap(find.byIcon(Icons.add));
          await _settleForReal(tester);
        }
        expect(
          find.byType(ExpensiveRouteOptimized),
          findsNothing,
          reason: 'nine taps must not reach the Threshold',
        );

        await _settleForReal(tester, const Duration(seconds: 2));

        // Discards Frames belonging to app start-up and up to the final tap,
        // which are not part of the Trial.
        await recorder.start();
        recorder.phase = 'route_build';
        await tester.tap(find.byIcon(Icons.add));
        await _settleForReal(tester, const Duration(seconds: 1));
        await _waitFor(tester, find.byType(ExpensiveRouteOptimized));

        await _settleForReal(tester, const Duration(seconds: 2));

        recorder.phase = 'scroll';
        final listFinder = find.byType(ListView);
        final screenHeight = tester.getSize(listFinder).height;
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;

        for (var i = 0; i < screensToScroll; i++) {
          await tester.fling(listFinder, Offset(0, -screenHeight), flingSpeed);
          await _settleForReal(tester, const Duration(milliseconds: 900));
        }

        await _settleForReal(tester, const Duration(seconds: 2));

        recorder.phase = 'rest';
        await _settleForReal(tester, const Duration(milliseconds: 500));
        await recorder.stop();

        expect(
          position.pixels,
          greaterThan(screenHeight * screensToScroll / 2),
          reason: 'the flings must have moved the list a long way down',
        );
        expect(
          recorder.frameCount,
          greaterThan(0),
          reason: 'a Trial that records no Frames is not a measurement',
        );

        final directory = await recorder.writeResults();
        debugPrint('Wrote ${recorder.frameCount} Frames to ${directory.path}');
      } catch (error, stackTrace) {
        await recorder.writeFailure(error, stackTrace);
        rethrow;
      }
    },
  );
}

/// Lets real time pass, so the engine renders Frames at its own cadence.
///
/// The live binding's `pump` waits for genuine wall-clock time, unlike the
/// synthetic clock a widget test runs on.
Future<void> _settleForReal(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 150),
]) async {
  await tester.pump(duration);
}

/// Polls until [finder] matches, without pumping frames faster than vsync.
Future<void> _waitFor(
  WidgetTester tester,
  FinderBase<Element> finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration period = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for $finder.');
    }
    await tester.pump(period);
  }
}
