// ignore_for_file: avoid_print

/// FFmpeg Performance Benchmarks
///
/// These benchmarks measure the performance impact of FFmpeg init/cleanup
/// to validate the hypothesis that per-job cleanup causes throughput degradation.
///
/// Run with: flutter test test/performance/ffmpeg_benchmark_test.dart
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/isolate/isolate_runner.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  setUpAll(() async {
    await FFMPEGSetupHelper.setupFFMPEGForTesting();
  });

  group('FFmpeg Init/Cleanup Overhead Benchmarks', () {
    /// Benchmark: Measure raw init/cleanup cycle time on main thread
    test('BENCHMARK: FFmpeg init/cleanup cycle overhead', () async {
      const iterations = 20;
      final times = <int>[];

      // Warmup
      NativeAudioBindings.initialize();
      NativeAudioBindings.cleanup();

      for (var i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        NativeAudioBindings.initialize();
        NativeAudioBindings.cleanup();

        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgMicros = times.reduce((a, b) => a + b) / times.length;
      final minMicros = times.reduce((a, b) => a < b ? a : b);
      final maxMicros = times.reduce((a, b) => a > b ? a : b);

      print('');
      print('═══════════════════════════════════════════════════════════');
      print('FFmpeg init/cleanup cycle ($iterations iterations)');
      print('───────────────────────────────────────────────────────────');
      print('  Average: ${avgMicros.toStringAsFixed(1)} µs');
      print('  Min:     $minMicros µs');
      print('  Max:     $maxMicros µs');
      print('═══════════════════════════════════════════════════════════');
      print('');

      // Just ensure it completes - this is a benchmark, not a pass/fail test
      expect(times.length, equals(iterations));
    });

    /// Benchmark: Measure init-only (no cleanup) - the "fixed" scenario
    test('BENCHMARK: FFmpeg init-only (idempotent check) overhead', () async {
      const iterations = 100;
      final times = <int>[];

      // Ensure initialized first
      NativeAudioBindings.initialize();

      for (var i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        // This should be near-instant since already initialized
        NativeAudioBindings.initialize();

        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgMicros = times.reduce((a, b) => a + b) / times.length;
      final minMicros = times.reduce((a, b) => a < b ? a : b);
      final maxMicros = times.reduce((a, b) => a > b ? a : b);

      print('');
      print('═══════════════════════════════════════════════════════════');
      print('FFmpeg init-only (already initialized) ($iterations iterations)');
      print('───────────────────────────────────────────────────────────');
      print('  Average: ${avgMicros.toStringAsFixed(1)} µs');
      print('  Min:     $minMicros µs');
      print('  Max:     $maxMicros µs');
      print('═══════════════════════════════════════════════════════════');
      print('');

      expect(times.length, equals(iterations));
    });
  });

  group('Concurrent Isolate Waveform Generation Benchmarks', () {
    // Use real audio files for realistic benchmarking
    const basePath = '/mnt/data_hdd/Development/Projects/Zooper/Sonix/test/assets/real_audio';

    // Mix of file sizes for realistic benchmarks
    final realAudioFiles = [
      '$basePath/Chris Brown - With You.mp3', // 10MB
      '$basePath/Ciara Feat. Ludacris - Oh.mp3', // 10MB
      '$basePath/Mario - Let Me Love You.mp3', // ~5MB
      '$basePath/Justin Bieber - Yummy.mp3', // ~4MB
      '$basePath/Nelly - Ride Wit Me (Casual Connection Rework) (clean).mp3',
      '$basePath/Sean Kingston - Wait Up (Steve D Redrum) (Clean).mp3',
      '$basePath/Teairra Mari - Make Her Feel Good.mp3',
      '$basePath/Justin Timberlake - Summer Love (Main Version).mp3',
    ];

    /// Benchmark: Sequential waveform generation with REAL files (baseline)
    test('BENCHMARK: Sequential waveform generation - REAL files', () async {
      final times = <int>[];

      for (final audioPath in realAudioFiles.take(5)) {
        final stopwatch = Stopwatch()..start();

        const runner = IsolateRunner();
        await runner.run(audioPath, WaveformConfig(resolution: 500));

        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);
      }

      final avgMs = times.reduce((a, b) => a + b) / times.length;
      final totalMs = times.reduce((a, b) => a + b);

      print('');
      print('═══════════════════════════════════════════════════════════');
      print('Sequential waveform generation (${times.length} real MP3 files)');
      print('───────────────────────────────────────────────────────────');
      print('  Total time:   ${totalMs}ms');
      print('  Average/file: ${avgMs.toStringAsFixed(1)}ms');
      print('  Per-file times: ${times.map((t) => "${t}ms").join(", ")}');
      print('═══════════════════════════════════════════════════════════');
      print('');

      expect(times.isNotEmpty, isTrue);
    });

    /// Benchmark: 2 concurrent isolates
    test('BENCHMARK: 2 concurrent isolates - REAL files', () async {
      await _runConcurrentBenchmarkWithFiles(testAudioFiles: realAudioFiles, concurrency: 2);
    });

    /// Benchmark: 4 concurrent isolates
    test('BENCHMARK: 4 concurrent isolates - REAL files', () async {
      await _runConcurrentBenchmarkWithFiles(testAudioFiles: realAudioFiles, concurrency: 4);
    });

    /// Benchmark: 8 concurrent isolates
    test('BENCHMARK: 8 concurrent isolates - REAL files', () async {
      await _runConcurrentBenchmarkWithFiles(testAudioFiles: realAudioFiles, concurrency: 8);
    });
  });

  group('Isolate Spawn Overhead Benchmarks', () {
    /// Benchmark: Raw isolate spawn/kill overhead (no FFmpeg)
    test('BENCHMARK: Raw isolate spawn overhead (no FFmpeg work)', () async {
      const iterations = 10;
      final times = <int>[];

      for (var i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        final receivePort = ReceivePort();
        final isolate = await Isolate.spawn(_emptyIsolateEntry, receivePort.sendPort);

        // Wait for completion signal
        await receivePort.first;
        isolate.kill();
        receivePort.close();

        stopwatch.stop();
        times.add(stopwatch.elapsedMicroseconds);
      }

      final avgMicros = times.reduce((a, b) => a + b) / times.length;

      print('');
      print('═══════════════════════════════════════════════════════════');
      print('Raw isolate spawn/kill overhead ($iterations iterations)');
      print('───────────────────────────────────────────────────────────');
      print('  Average: ${avgMicros.toStringAsFixed(1)} µs');
      print('  Average: ${(avgMicros / 1000).toStringAsFixed(2)} ms');
      print('═══════════════════════════════════════════════════════════');
      print('');

      expect(times.length, equals(iterations));
    });

    /// Benchmark: Isolate spawn with FFmpeg init only (no cleanup)
    test('BENCHMARK: Isolate spawn + FFmpeg init only', () async {
      const iterations = 10;
      final times = <int>[];

      for (var i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        final receivePort = ReceivePort();
        final isolate = await Isolate.spawn(_initOnlyIsolateEntry, receivePort.sendPort);

        await receivePort.first;
        isolate.kill();
        receivePort.close();

        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);
      }

      final avgMs = times.reduce((a, b) => a + b) / times.length;

      print('');
      print('═══════════════════════════════════════════════════════════');
      print('Isolate spawn + FFmpeg init only ($iterations iterations)');
      print('───────────────────────────────────────────────────────────');
      print('  Average: ${avgMs.toStringAsFixed(1)} ms');
      print('  Times: ${times.map((t) => "${t}ms").join(", ")}');
      print('═══════════════════════════════════════════════════════════');
      print('');

      expect(times.length, equals(iterations));
    });

    /// Benchmark: Isolate spawn with FFmpeg init + cleanup (current behavior)
    test('BENCHMARK: Isolate spawn + FFmpeg init + cleanup (current)', () async {
      const iterations = 10;
      final times = <int>[];

      for (var i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        final receivePort = ReceivePort();
        final isolate = await Isolate.spawn(_initAndCleanupIsolateEntry, receivePort.sendPort);

        await receivePort.first;
        isolate.kill();
        receivePort.close();

        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);
      }

      final avgMs = times.reduce((a, b) => a + b) / times.length;

      print('');
      print('═══════════════════════════════════════════════════════════');
      print('Isolate spawn + FFmpeg init + cleanup ($iterations iterations)');
      print('───────────────────────────────────────────────────────────');
      print('  Average: ${avgMs.toStringAsFixed(1)} ms');
      print('  Times: ${times.map((t) => "${t}ms").join(", ")}');
      print('═══════════════════════════════════════════════════════════');
      print('');

      expect(times.length, equals(iterations));
    });
  });
}

/// Run concurrent waveform generation benchmark with a list of real files
Future<void> _runConcurrentBenchmarkWithFiles({required List<String> testAudioFiles, required int concurrency}) async {
  final stopwatch = Stopwatch()..start();
  final individualTimes = <int>[];

  // Create a queue of work using all available files
  final pending = List<String>.from(testAudioFiles);
  final totalFiles = pending.length;
  var activeCount = 0;

  final completer = Completer<void>();

  void startNext() {
    while (pending.isNotEmpty && activeCount < concurrency) {
      final audioPath = pending.removeAt(0);
      activeCount++;

      final taskStopwatch = Stopwatch()..start();

      final future = () async {
        const runner = IsolateRunner();
        await runner.run(audioPath, WaveformConfig(resolution: 500));
        taskStopwatch.stop();
        individualTimes.add(taskStopwatch.elapsedMilliseconds);
      }();

      future.then((_) {
        activeCount--;
        if (pending.isEmpty && activeCount == 0) {
          completer.complete();
        } else {
          startNext();
        }
      });
    }
  }

  startNext();
  await completer.future;

  stopwatch.stop();

  final avgMs = individualTimes.reduce((a, b) => a + b) / individualTimes.length;
  final minMs = individualTimes.reduce((a, b) => a < b ? a : b);
  final maxMs = individualTimes.reduce((a, b) => a > b ? a : b);

  print('');
  print('═══════════════════════════════════════════════════════════');
  print('Concurrent waveform generation (REAL MP3 files)');
  print('  Concurrency: $concurrency isolates');
  print('  Total files: $totalFiles');
  print('───────────────────────────────────────────────────────────');
  print('  Total wall time: ${stopwatch.elapsedMilliseconds}ms');
  print('  Average/file:    ${avgMs.toStringAsFixed(1)}ms');
  print('  Min/file:        ${minMs}ms');
  print('  Max/file:        ${maxMs}ms');
  print('  Throughput:      ${(totalFiles / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(2)} files/sec');
  print('═══════════════════════════════════════════════════════════');
  print('');

  expect(individualTimes.length, equals(totalFiles));
}

/// Empty isolate entry point (just signals completion)
void _emptyIsolateEntry(SendPort sendPort) {
  sendPort.send('done');
}

/// Isolate entry that only does FFmpeg init (proposed fix behavior)
void _initOnlyIsolateEntry(SendPort sendPort) {
  NativeAudioBindings.initialize();
  // No cleanup!
  sendPort.send('done');
}

/// Isolate entry that does FFmpeg init + cleanup (current behavior)
void _initAndCleanupIsolateEntry(SendPort sendPort) {
  NativeAudioBindings.initialize();
  NativeAudioBindings.cleanup();
  sendPort.send('done');
}
