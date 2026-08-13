// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:adb_server/web/components/discover_button.dart'
    as _discover_button;
import 'package:adb_server/web/components/requeue_button.dart'
    as _requeue_button;
import 'package:adb_server/web/components/start_next_button.dart'
    as _start_next_button;
import 'package:adb_server/web/components/stop_button.dart' as _stop_button;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _discover_button.DiscoverButton:
        ClientTarget<_discover_button.DiscoverButton>('discover_button'),
    _requeue_button.RequeueButton: ClientTarget<_requeue_button.RequeueButton>(
      'requeue_button',
      params: __requeue_buttonRequeueButton,
    ),
    _start_next_button.StartNextButton:
        ClientTarget<_start_next_button.StartNextButton>(
          'start_next_button',
          params: __start_next_buttonStartNextButton,
        ),
    _stop_button.StopButton: ClientTarget<_stop_button.StopButton>(
      'stop_button',
      params: __stop_buttonStopButton,
    ),
  },
);

Map<String, Object?> __requeue_buttonRequeueButton(
  _requeue_button.RequeueButton c,
) => {'sessionId': c.sessionId};
Map<String, Object?> __start_next_buttonStartNextButton(
  _start_next_button.StartNextButton c,
) => {'disabled': c.disabled};
Map<String, Object?> __stop_buttonStopButton(_stop_button.StopButton c) => {
  'sessionId': c.sessionId,
};
