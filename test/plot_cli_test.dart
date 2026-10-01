import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('plot CLI', () {
    test('no subcommand exits with usage error (64)', () async {
      final result = await Process.run('dart', ['run', 'bin/plot.dart']);
      expect(result.exitCode, 64);
      expect(result.stderr, contains('Missing subcommand'));
    });

    test('violin with a missing file exits 1 with expected message', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        '/tmp/nope_a.dat',
      ]);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('File not found'));
    });

    test('line with a missing file exits 1 with expected message', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        '/tmp/nope_b.dat',
      ]);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('File not found'));
    });

    test('line with zero positional args exits with usage error', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
      ]);
      expect(result.exitCode, 64);
    });

    test('line with a valid file exits 0 and produces SVG on stdout', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        'test/fixtures/sample_a.dat',
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout, startsWith('<?xml'));
    });

    test('line removes common prefix by default and supports --no-remove-common-prefix', () async {
      final defaultResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        'test/fixtures/sample_a.dat',
        'test/fixtures/sample_b.dat',
      ]);
      expect(defaultResult.exitCode, 0);
      expect(defaultResult.stdout, contains('>a<'));
      expect(defaultResult.stdout, contains('>b<'));
      expect(defaultResult.stdout, isNot(contains('>sample_a<')));
      expect(defaultResult.stdout, isNot(contains('>sample_b<')));

      final noPrefixResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        '--no-remove-common-prefix',
        'test/fixtures/sample_a.dat',
        'test/fixtures/sample_b.dat',
      ]);
      expect(noPrefixResult.exitCode, 0);
      expect(noPrefixResult.stdout, contains('>sample_a<'));
      expect(noPrefixResult.stdout, contains('>sample_b<'));
    });

    test('violin removes common prefix by default and supports --no-remove-common-prefix', () async {
      final defaultResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        'test/fixtures/sample_a.dat',
        'test/fixtures/sample_b.dat',
      ]);
      expect(defaultResult.exitCode, 0);
      expect(defaultResult.stdout, contains('>a<'));
      expect(defaultResult.stdout, contains('>b<'));
      expect(defaultResult.stdout, isNot(contains('>sample_a<')));
      expect(defaultResult.stdout, isNot(contains('>sample_b<')));

      final noPrefixResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        '--no-remove-common-prefix',
        'test/fixtures/sample_a.dat',
        'test/fixtures/sample_b.dat',
      ]);
      expect(noPrefixResult.exitCode, 0);
      expect(noPrefixResult.stdout, contains('>sample_a<'));
      expect(noPrefixResult.stdout, contains('>sample_b<'));
    });

    test('line supports --theme flag and defaults to dark', () async {
      final defaultResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        'test/fixtures/sample_a.dat',
      ]);
      expect(defaultResult.exitCode, 0);
      expect(defaultResult.stdout, contains('stroke="#ccc"'));
      expect(defaultResult.stdout, contains('fill="#eee"'));

      final lightResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        '--theme',
        'light',
        'test/fixtures/sample_a.dat',
      ]);
      expect(lightResult.exitCode, 0);
      expect(lightResult.stdout, contains('stroke="#333"'));
      expect(lightResult.stdout, contains('fill="#111"'));

      final invalidResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        '--theme',
        'blue',
        'test/fixtures/sample_a.dat',
      ]);
      expect(invalidResult.exitCode, 64);
      expect(invalidResult.stderr, contains('"blue" is not an allowed value'));
    });

    test('violin supports --theme flag and defaults to dark', () async {
      final defaultResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        'test/fixtures/sample_a.dat',
      ]);
      expect(defaultResult.exitCode, 0);
      expect(defaultResult.stdout, contains('stroke="#ccc"'));
      expect(defaultResult.stdout, contains('stroke="white"'));

      final lightResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        '--theme',
        'light',
        'test/fixtures/sample_a.dat',
      ]);
      expect(lightResult.exitCode, 0);
      expect(lightResult.stdout, contains('stroke="#333"'));
      expect(lightResult.stdout, contains('stroke="black"'));

      final invalidResult = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        '--theme',
        'blue',
        'test/fixtures/sample_a.dat',
      ]);
      expect(invalidResult.exitCode, 64);
      expect(invalidResult.stderr, contains('"blue" is not an allowed value'));
    });

    test('line supports --width and --height flags', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        '--width',
        '1200',
        '--height',
        '800',
        'test/fixtures/sample_a.dat',
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('width="1200.0" height="800.0"'));
      expect(result.stdout, contains('viewBox="0 0 1200.0 800.0"'));
    });

    test('violin supports --width and --height flags', () async {
      final result = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        '--width',
        '1400',
        '--height',
        '900',
        'test/fixtures/sample_a.dat',
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('width="1400.0" height="900.0"'));
      expect(result.stdout, contains('viewBox="0 0 1400.0 900.0"'));
    });

    test('line with invalid width or height exits with usage error', () async {
      final nonNumeric = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        '--width',
        'invalid',
        'test/fixtures/sample_a.dat',
      ]);
      expect(nonNumeric.exitCode, 64);
      expect(nonNumeric.stderr, contains('--width must be a positive number'));

      final nonPositive = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'line',
        '--height',
        '-100',
        'test/fixtures/sample_a.dat',
      ]);
      expect(nonPositive.exitCode, 64);
      expect(nonPositive.stderr, contains('--height must be a positive number'));
    });

    test('violin with invalid width or height exits with usage error', () async {
      final nonNumeric = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        '--width',
        '0',
        'test/fixtures/sample_a.dat',
      ]);
      expect(nonNumeric.exitCode, 64);
      expect(nonNumeric.stderr, contains('--width must be a positive number'));

      final nonPositive = await Process.run('dart', [
        'run',
        'bin/plot.dart',
        'violin',
        '--height',
        'bad',
        'test/fixtures/sample_a.dat',
      ]);
      expect(nonPositive.exitCode, 64);
      expect(nonPositive.stderr, contains('--height must be a positive number'));
    });
  });
}
