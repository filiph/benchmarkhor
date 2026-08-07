// Host-side driver for `flutter drive`.
//
// It carries no profiling logic: the Trial measures itself on the device and
// writes its own Frames to disk (see `integration_test/frame_recorder.dart`),
// so there is no `responseDataCallback` and no timeline to summarise here.
// This script exists only so the local dev loop can use `flutter drive`.

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
