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
  });
}
