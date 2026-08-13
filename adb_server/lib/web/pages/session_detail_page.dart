import 'dart:convert';
import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:path/path.dart' as path;

import '../../models.dart';
import '../app.dart';

class SessionDetailPage extends AsyncStatelessComponent {
  final String id;

  const SessionDetailPage({required this.id, super.key});

  @override
  Future<Component> build(BuildContext context) async {
    final appData = AppDataProvider.of(context);
    if (appData == null) {
      return div([.text('Loading...')]);
    }

    final sessionStore = appData.sessionStore;
    final trialsDir = sessionStore.trialsDir(id);
    final trials = <TrialMetadata>[];

    if (await trialsDir.exists()) {
      final entities = await trialsDir.list().toList();
      entities.sort((e1, e2) => e1.path.compareTo(e2.path));
      for (final entity in entities) {
        if (entity is Directory) {
          final trialId = path.basename(entity.path);
          final metadataFile = sessionStore.trialMetadataFile(id, trialId);
          if (await metadataFile.exists()) {
            try {
              final json =
                  jsonDecode(await metadataFile.readAsString())
                      as Map<String, dynamic>;
              trials.add(TrialMetadata.fromJson(json));
            } catch (_) {
              // Skip malformed trial metadata
            }
          }
        }
      }
    }

    return div([
      h1([.text('Session: $id')]),
      p([
        a(href: '/', [.text('← Back to Dashboard')]),
        .text(' | '),
        a(href: '/api/sessions/$id/log', target: Target.blank, [
          .text('Session Log'),
        ]),
      ]),
      h2([.text('Trials')]),
      table([
        thead([
          tr([
            th([.text('Trial')]),
            th([.text('Variant')]),
            th([.text('Started')]),
            th([.text('Finished')]),
            th([.text('Temp / Throttled')]),
            th([.text('Artifacts')]),
          ]),
        ]),
        tbody([
          for (final trial in trials) ...[
            () {
              final beforeTemp = _getSocThermal(trial.deviceBefore);
              final afterTemp = _getSocThermal(trial.deviceAfter);
              final tempRangeStr = (beforeTemp != null && afterTemp != null)
                  ? '${beforeTemp.toStringAsFixed(1)}°C → ${afterTemp.toStringAsFixed(1)}°C'
                  : 'N/A';
              final statusSuffix = trial.maxThermalStatus != null
                  ? ' (status: ${trial.maxThermalStatus})'
                  : '';

              return tr([
                td([.text(trial.trialId)]),
                td([.text(trial.variantName)]),
                td([
                  .text(trial.startedAt.toLocal().toString().split('.').first),
                ]),
                td([
                  .text(trial.finishedAt.toLocal().toString().split('.').first),
                ]),
                td([
                  .text('$tempRangeStr | '),
                  if (trial.thermalThrottled)
                    span(
                      styles: Styles(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      [.text('Throttled$statusSuffix')],
                    )
                  else
                    .text('Normal'),
                ]),
                td([
                  a(
                    href: '/api/sessions/$id/trials/${trial.trialId}/adb.log',
                    target: Target.blank,
                    [.text('adb.log')],
                  ),
                  .text(' | '),
                  a(
                    href:
                        '/api/sessions/$id/trials/${trial.trialId}/logcat.txt',
                    target: Target.blank,
                    [.text('logcat.txt')],
                  ),
                  .text(' | '),
                  a(
                    href:
                        '/api/sessions/$id/trials/${trial.trialId}/trial.json',
                    target: Target.blank,
                    [.text('trial.json')],
                  ),
                ]),
              ]);
            }(),
          ],
        ]),
      ]),
    ]);
  }

  double? _getSocThermal(Map<String, dynamic> deviceData) {
    final temps = deviceData['temperatures'] as List?;
    if (temps == null) return null;
    for (final t in temps) {
      if (t is Map && t['type'] == 'soc-thermal') {
        final val = double.tryParse(t['temp']?.toString() ?? '');
        if (val != null) return val / 1000.0;
      }
    }
    return null;
  }
}
