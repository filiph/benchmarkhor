// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:adb_server/web/components/discover_button.dart'
    deferred as _discover_button;
import 'package:adb_server/web/components/requeue_button.dart'
    deferred as _requeue_button;
import 'package:adb_server/web/components/start_next_button.dart'
    deferred as _start_next_button;
import 'package:adb_server/web/components/stop_button.dart'
    deferred as _stop_button;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'discover_button': ClientLoader(
      (p) => _discover_button.DiscoverButton(),
      loader: _discover_button.loadLibrary,
    ),
    'requeue_button': ClientLoader(
      (p) => _requeue_button.RequeueButton(sessionId: p['sessionId'] as String),
      loader: _requeue_button.loadLibrary,
    ),
    'start_next_button': ClientLoader(
      (p) =>
          _start_next_button.StartNextButton(disabled: p['disabled'] as bool),
      loader: _start_next_button.loadLibrary,
    ),
    'stop_button': ClientLoader(
      (p) => _stop_button.StopButton(sessionId: p['sessionId'] as String),
      loader: _stop_button.loadLibrary,
    ),
  },
);
