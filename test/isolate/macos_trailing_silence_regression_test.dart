// ignore_for_file: avoid_print

import 'dart:io' show Platform, File;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/downsampling_algorithm.dart';

import '../ffmpeg/ffmpeg_setup_helper.dart';
import '../../tool/test_data_generator.dart';
import '../test_helpers/test_sonix_instance.dart';

/// Regression test for macOS trailing silence at the end of waveform when using
/// the selective decoding path for large files. This ensures we don't produce
/// long runs of zero amplitudes at the end due to EOF seek overshoot.
void main() {
  // Only relevant for macOS
  if (!Platform.isMacOS) {
    test('skipped on non-macOS', () {
      expect(true, isTrue);
    });
    return;
  }

  group('macOS trailing silence regression', () {
    late Sonix sonix;
    late String largeWavPath;

    setUpAll(() async {
      // Ensure FFMPEG binaries available for tests
      await FFMPEGSetupHelper.setupFFMPEGForTesting();

      // Use a large real WAV file so the processing isolate chooses the
      // chunked selective decoding path (> 5MB threshold)
      final candidate = 'Double-F the King - Your Blessing.wav';
      final path = TestDataLoader.getAssetPath(candidate);
      final exists = await File(path).exists();
      expect(exists, isTrue, reason: 'Real WAV asset not found: $path');
      largeWavPath = path;
    });

    setUp(() async {
      sonix = TestSonixInstance(const TestSonixConfig(isolatePoolSize: 2, maxConcurrentOperations: 2));
      await sonix.initialize();
    });

    tearDown(() async {
      await sonix.dispose();
    });

    test('no long run of trailing zeros at end of waveform', () async {
      // Act: generate a relatively high-resolution waveform to sample the end
      final config = const WaveformConfig(resolution: 1000, algorithm: DownsamplingAlgorithm.rms, normalize: true);

      final WaveformData waveform = await sonix.generateWaveform(largeWavPath, config: config);

      // Assert basic sanity
      expect(waveform.amplitudes, hasLength(1000));

      // Check the last N bins for consecutive zeros; a long run suggests EOF overshoot
      const tailWindow = 60; // last ~6% of waveform
      const maxAllowedConsecutiveZeros = 10; // allow small silent runs but not long ones
      int consecutiveZeros = 0;
      int maxRunObserved = 0;
      for (int i = waveform.amplitudes.length - tailWindow; i < waveform.amplitudes.length; i++) {
        final a = waveform.amplitudes[i];
        // Treat very tiny values as zero after normalization
        final isZeroish = a.abs() < 1e-6;
        if (isZeroish) {
          consecutiveZeros++;
          if (consecutiveZeros > maxRunObserved) maxRunObserved = consecutiveZeros;
        } else {
          consecutiveZeros = 0;
        }
      }

      expect(
        maxRunObserved,
        lessThanOrEqualTo(maxAllowedConsecutiveZeros),
        reason:
            'Detected a long run ($maxRunObserved) of trailing zeros in the waveform tail, '
            'which indicates EOF seek overshoot on macOS.',
      );
    });
  });
}
