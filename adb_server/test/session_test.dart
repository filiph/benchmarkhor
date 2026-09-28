import 'package:adb_server/models.dart';
import 'package:test/test.dart';

void main() {
  group('SessionSpec single-APK and launchActivity parsing', () {
    test('parses single-APK variant and defaults launch_activity', () {
      final spec = SessionSpec.fromJson({
        'name': 'pure-dart-benchmark',
        'variants': {
          'baseline': {'apk': 'baseline.apk'},
          'optimized': {'apk': 'optimized.apk'},
        },
        'package': 'com.example.bench',
        'device_result_dir': '/sdcard/Android/data/com.example.bench/files',
      });

      expect(spec.variants['baseline']!.apk, 'baseline.apk');
      expect(spec.variants['baseline']!.testApk, isNull);
      expect(spec.variants['optimized']!.apk, 'optimized.apk');
      expect(spec.variants['optimized']!.testApk, isNull);
      expect(spec.launchActivity, 'com.example.bench/.MainActivity');
    });

    test('preserves explicit launch_activity when provided', () {
      final spec = SessionSpec.fromJson({
        'name': 'pure-dart-benchmark',
        'variants': {
          'v1': {'apk': 'custom.apk'},
        },
        'package': 'com.example.bench',
        'launch_activity': 'com.example.bench.CustomActivity',
        'device_result_dir': '/sdcard/Android/data/com.example.bench/files',
      });

      expect(spec.launchActivity, 'com.example.bench.CustomActivity');
    });

    test('rejects empty or whitespace-only launch_activity', () {
      expect(
        () => SessionSpec.fromJson({
          'name': 'invalid',
          'variants': {
            'v1': {'apk': 'app.apk'},
          },
          'package': 'com.example.bench',
          'launch_activity': '   ',
          'device_result_dir': '/sdcard/test',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('preserves traditional APK pair variants with test_apk', () {
      final spec = SessionSpec.fromJson({
        'name': 'flutter-benchmark',
        'variants': {
          'baseline': {'apk': 'app.apk', 'test_apk': 'test.apk'},
        },
        'package': 'com.example.app',
        'device_result_dir': '/sdcard/test',
      });

      expect(spec.variants['baseline']!.apk, 'app.apk');
      expect(spec.variants['baseline']!.testApk, 'test.apk');
      expect(spec.launchActivity, isNull);
    });
  });
}
