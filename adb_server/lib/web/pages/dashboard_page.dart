import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import '../../adb.dart';
import '../../device_probe.dart';
import '../../models.dart';
import '../app.dart';
import '../components/buttons.dart';

class DashboardPage extends AsyncStatelessComponent {
  const DashboardPage({super.key});

  @override
  Future<Component> build(BuildContext context) async {
    final appData = AppDataProvider.of(context);
    if (appData == null) {
      return div([.text('Loading...')]);
    }

    final config = appData.config;
    final sessionStore = appData.sessionStore;
    final runner = appData.runner;

    final adb = Adb(adbPath: config.adbPath, deviceAddress: config.dutAddress);
    final deviceState = await adb.getState() ?? 'offline';
    final probe = DeviceProbe(adb);
    final temp = deviceState == 'device' ? await probe.getSocTemp() : null;

    final sessionIds = (await sessionStore.listSessionIds()).reversed.take(20);
    final sessions = <SessionStatus>[];
    for (final id in sessionIds) {
      final s = await sessionStore.readStatus(id);
      if (s != null) sessions.add(s);
    }

    final gitCommit = config.gitCommit;

    return div([
      h1([.text('adb_server')]),
      div(styles: Styles(raw: {'margin-bottom': '2rem'}), [
        span(
          classes:
              'device-status ${deviceState == 'device' ? 'status-online' : 'status-offline'}',
          [
            .text('DUT: '),
            strong([.text(config.dutAddress)]),
            .text(' is '),
            strong([.text(deviceState)]),
            if (temp != null) ...[
              .text(' | Temp: '),
              strong([.text('${temp.toStringAsFixed(1)}°C')]),
            ],
          ],
        ),
        .text(' | Busy: '),
        strong([.text('${runner.isBusy}')]),
        .text(' | '),
        a(href: '/api/logs/server.log', [.text('Server Logs')]),
        if (runner.isBusy && runner.runningSessionId != null) ...[
          .text(' | Session: '),
          strong([
            a(href: '/sessions/${runner.runningSessionId}', [
              .text(runner.runningSessionId!),
            ]),
          ]),
        ],
      ]),
      div(styles: Styles(raw: {'margin-bottom': '1rem'}), [
        const DiscoverButton(),
      ]),
      if (runner.isBusy && runner.statusMessage != null)
        p([
          .text('Current state: '),
          em([.text(runner.statusMessage!)]),
        ]),
      h2([.text('Recent Sessions')]),
      table([
        thead([
          tr([
            th([.text('ID')]),
            th([.text('State')]),
            th([.text('Progress')]),
            th([.text('Timestamp')]),
            th([.text('Actions')]),
          ]),
        ]),
        tbody([
          for (final s in sessions)
            tr([
              td([
                a(href: '/sessions/${s.sessionId}', [.text(s.sessionId)]),
              ]),
              td(classes: 'state-${s.state.name}', [.text(s.state.name)]),
              td([.text('${s.roundsCompleted}/${s.roundsPlanned} rounds')]),
              td([
                span(
                  attributes: {'title': s.timestampLabel},
                  [
                    .text(
                      s.timestampValue.toLocal().toString().split('.').first,
                    ),
                  ],
                ),
              ]),
              td([
                if (s.state == SessionState.running)
                  StopButton(sessionId: s.sessionId)
                else if (s.state != SessionState.queued)
                  RequeueButton(sessionId: s.sessionId),
              ]),
            ]),
        ]),
      ]),
      div(styles: Styles(raw: {'margin-top': '2rem'}), [
        StartNextButton(disabled: runner.isBusy),
      ]),
      div(classes: 'footer', [.text('Version: $gitCommit')]),
    ]);
  }
}
