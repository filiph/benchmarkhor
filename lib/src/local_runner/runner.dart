import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'host_probe.dart';
import 'models.dart';
import 'output_parser.dart';
import 'session_store.dart';
import 'trial_runner.dart';

/// Coordinates local benchmark session execution across randomized rounds.
class LocalSessionRunner {
  final LocalSessionStore store;
  final MacHostProbe probe;
  final ProcessTrialRunner trialRunner;
  final Duration? timeoutOverride;
  final Random _random;
  final Logger _log;

  LocalSessionRunner({
    required this.store,
    MacHostProbe? probe,
    ProcessTrialRunner? trialRunner,
    this.timeoutOverride,
    Random? random,
    Logger? logger,
  })  : probe = probe ?? MacHostProbe(),
        trialRunner = trialRunner ??
            ProcessTrialRunner(
              store: store,
              probe: probe,
              parser: BenchmarkOutputParser(logger: logger),
              logger: logger,
            ),
        _random = random ?? Random(),
        _log = logger ?? Logger('LocalSessionRunner');

  /// Cleans leftover partial trial directories beyond [expectedCompletedTrials].
  Future<void> _cleanPartialTrials(int expectedCompletedTrials) async {
    if (!await store.trialsDir.exists()) return;
    await for (final entity in store.trialsDir.list()) {
      if (entity is Directory) {
        final dirName = p.basename(entity.path);
        final match = RegExp(r'trial-(\d+)').firstMatch(dirName);
        if (match != null) {
          final trialNum = int.tryParse(match.group(1)!);
          if (trialNum != null && trialNum > expectedCompletedTrials) {
            await entity.delete(recursive: true);
          }
        }
      }
    }
  }

  /// Runs the session according to `session.json`, resuming if partially complete.
  Future<LocalSessionStatus> run({bool clean = false}) async {
    var status = await store.initOrResumeStatus(clean: clean);
    final spec = await store.readSessionSpec();

    if (status.roundsCompleted >= spec.rounds) {
      _log.info(
        'Session "${spec.name}" already completed (${status.roundsCompleted}/${spec.rounds} rounds).',
      );
      if (status.state != LocalSessionState.completed) {
        status = status.transitionTo(
          LocalSessionState.completed,
          reason: 'All rounds already completed',
        );
        await store.writeStatus(status);
      }
      return status;
    }

    final variantCount = spec.variants.length;
    final expectedCompletedTrials = status.roundsCompleted * variantCount;
    await _cleanPartialTrials(expectedCompletedTrials);

    status = status.transitionTo(
      LocalSessionState.running,
      reason: status.roundsCompleted > 0
          ? 'Resuming from round ${status.roundsCompleted + 1}'
          : 'Starting session',
    );
    await store.writeStatus(status);

    var trialNumber = expectedCompletedTrials + 1;
    final timeout = timeoutOverride ??
        Duration(seconds: spec.trialTimeoutSeconds ?? 300);

    try {
      final variantKeys = spec.variants.keys.toList();

      for (
        var round = status.roundsCompleted + 1;
        round <= spec.rounds;
        round++
      ) {
        final roundMsg = 'Starting round $round of ${spec.rounds}';
        _log.info(roundMsg);
        await store.appendLog(roundMsg);

        // Randomize variant execution order for this round
        final shuffledVariants = List<String>.from(variantKeys)
          ..shuffle(_random);
        final orderMsg =
            'Round $round variant order: ${shuffledVariants.join(', ')}';
        _log.info(orderMsg);
        await store.appendLog(orderMsg);

        for (final variantName in shuffledVariants) {
          final trialId = LocalSessionStore.formatTrialId(trialNumber);
          final variantSpec = spec.variants[variantName]!;

          status = status.transitionTo(
            LocalSessionState.running,
            currentTrial: trialId,
          );
          await store.writeStatus(status);

          _log.info('Running $trialId: variant "$variantName"');

          await trialRunner.runTrial(
            sessionId: spec.name,
            trialId: trialId,
            variant: variantSpec,
            round: round,
            timeout: timeout,
            sessionDirPath: store.sessionDirPath,
          );

          trialNumber++;
        }

        // Round completed
        status = status.transitionTo(
          LocalSessionState.running,
          roundsCompleted: round,
          currentTrial: null,
          reason: 'Completed round $round',
        );
        await store.writeStatus(status);
        final completedRoundMsg = 'Completed round $round of ${spec.rounds}';
        _log.info(completedRoundMsg);
        await store.appendLog(completedRoundMsg);
      }

      // All rounds completed
      status = status.transitionTo(
        LocalSessionState.completed,
        reason: 'All ${spec.rounds} rounds completed successfully',
        currentTrial: null,
      );
      await store.writeStatus(status);
      const doneMsg = 'Session completed successfully';
      _log.info(doneMsg);
      await store.appendLog(doneMsg);
      return status;
    } catch (e, stack) {
      final errorMsg = 'Session failed: $e';
      _log.severe(errorMsg, e, stack);
      status = status.transitionTo(
        LocalSessionState.failed,
        error: e.toString(),
        reason: errorMsg,
      );
      await store.writeStatus(status);
      await store.appendLog(errorMsg);
      rethrow;
    }
  }
}
