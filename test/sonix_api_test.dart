import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/config/sonix_config.dart';
import 'package:sonix/src/processing/waveform_use_case.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  setUpAll(() async {
    // Setup FFMPEG binaries for testing
    await FFMPEGSetupHelper.setupFFMPEGForTesting();
  });

  group('Sonix', () {
    test('should create with default configuration', () {
      final sonix = Sonix();

      expect(sonix.config, isA<SonixConfig>());
      expect(sonix.config.maxMemoryUsage, equals(100 * 1024 * 1024));
      expect(sonix.isDisposed, isFalse);
    });

    test('should create with custom configuration', () {
      final config = SonixConfig.mobile();
      final sonix = Sonix(config);

      expect(sonix.config, equals(config));
      expect(sonix.config.maxMemoryUsage, equals(50 * 1024 * 1024));
    });

    test('desktop config should have larger memory limit', () {
      final config = SonixConfig.desktop();

      expect(config.maxMemoryUsage, equals(200 * 1024 * 1024));
    });

    // Configuration testing moved to test/config/sonix_config_test.dart

    test('should provide optimal configuration for different use cases', () {
      final musicConfig = Sonix.getOptimalConfig(useCase: WaveformUseCase.musicVisualization);
      expect(musicConfig.resolution, equals(1000));
      expect(musicConfig.normalize, isTrue);

      final speechConfig = Sonix.getOptimalConfig(useCase: WaveformUseCase.speechAnalysis, customResolution: 1500);
      expect(speechConfig.resolution, equals(1500));
      expect(speechConfig.normalize, isTrue);
    });

    test('should handle disposal correctly', () {
      final sonix = Sonix();

      expect(sonix.isDisposed, isFalse);

      sonix.dispose();

      expect(sonix.isDisposed, isTrue);

      // Should handle multiple disposal calls
      sonix.dispose();
      expect(sonix.isDisposed, isTrue);
    });

    test('should not allow operations after disposal', () {
      final sonix = Sonix();
      sonix.dispose();

      expect(() => sonix.generateWaveform('test.mp3'), throwsA(isA<StateError>()));
    });

    test('should throw for unsupported format', () {
      final sonix = Sonix();

      expect(() => sonix.generateWaveform('test.unknown'), throwsA(isA<UnsupportedFormatException>()));

      sonix.dispose();
    });

    test('should throw UnsupportedFormatException for generateWaveform with invalid format', () async {
      final sonix = Sonix();

      try {
        await sonix.generateWaveform('test.xyz');
        fail('Expected UnsupportedFormatException to be thrown');
      } catch (e) {
        expect(e, isA<UnsupportedFormatException>());
      } finally {
        sonix.dispose();
      }
    });

    test('should throw UnsupportedFormatException for generateWaveformInIsolate with invalid format', () async {
      final sonix = Sonix();

      try {
        await sonix.generateWaveformInIsolate('test.xyz');
        fail('Expected UnsupportedFormatException to be thrown');
      } catch (e) {
        expect(e, isA<UnsupportedFormatException>());
      } finally {
        sonix.dispose();
      }
    });

    test('should not allow generateWaveformInIsolate after disposal', () {
      final sonix = Sonix();
      sonix.dispose();

      expect(() => sonix.generateWaveformInIsolate('test.mp3'), throwsA(isA<StateError>()));
    });
  });

  group('Sonix waveform generation', () {
    late Sonix sonix;
    // Use a known working MP3 file that other tests use successfully
    const testFilePath = 'test/assets/Double-F the King - Your Blessing.mp3';

    setUpAll(() async {
      // Ensure FFMPEG is available and initialized for these tests
      await FFMPEGSetupHelper.setupFFMPEGForTesting();
      NativeAudioBindings.initialize();
    });

    setUp(() {
      sonix = Sonix();
    });

    tearDown(() {
      sonix.dispose();
    });

    test('generateWaveform should process audio on main thread', () async {
      final waveformData = await sonix.generateWaveform(testFilePath);

      expect(waveformData, isNotNull);
      expect(waveformData.amplitudes, isNotEmpty);
      expect(waveformData.amplitudes.length, equals(1000)); // default resolution
      expect(waveformData.duration, greaterThan(Duration.zero));
    });

    test('generateWaveform should respect custom resolution', () async {
      final waveformData = await sonix.generateWaveform(testFilePath, resolution: 500);

      expect(waveformData.amplitudes.length, equals(500));
    });

    test('generateWaveformInIsolate should process audio in background', () async {
      final waveformData = await sonix.generateWaveformInIsolate(testFilePath);

      expect(waveformData, isNotNull);
      expect(waveformData.amplitudes, isNotEmpty);
      expect(waveformData.amplitudes.length, equals(1000)); // default resolution
      expect(waveformData.duration, greaterThan(Duration.zero));
    });

    test('generateWaveformInIsolate should respect custom resolution', () async {
      final waveformData = await sonix.generateWaveformInIsolate(testFilePath, resolution: 500);

      expect(waveformData.amplitudes.length, equals(500));
    });

    test('both methods should produce valid comparable results', () async {
      final mainThreadResult = await sonix.generateWaveform(testFilePath, resolution: 200);

      final isolateResult = await sonix.generateWaveformInIsolate(testFilePath, resolution: 200);

      // Both should have the same length
      expect(mainThreadResult.amplitudes.length, equals(isolateResult.amplitudes.length));

      // Both should have very similar duration (allow small differences due to floating point)
      final durationDiffMs = (mainThreadResult.duration.inMilliseconds - isolateResult.duration.inMilliseconds).abs();
      expect(durationDiffMs, lessThan(100), reason: 'Duration difference should be minimal');

      // Both should have valid amplitude ranges
      for (final amp in mainThreadResult.amplitudes) {
        expect(amp, greaterThanOrEqualTo(0.0));
        expect(amp, lessThanOrEqualTo(1.0));
      }
      for (final amp in isolateResult.amplitudes) {
        expect(amp, greaterThanOrEqualTo(0.0));
        expect(amp, lessThanOrEqualTo(1.0));
      }

      // Both should have similar overall characteristics (not all zeros, has variation)
      final mainThreadMax = mainThreadResult.amplitudes.reduce((a, b) => a > b ? a : b);
      final isolateMax = isolateResult.amplitudes.reduce((a, b) => a > b ? a : b);
      expect(mainThreadMax, greaterThan(0.0), reason: 'Main thread should have non-zero amplitudes');
      expect(isolateMax, greaterThan(0.0), reason: 'Isolate should have non-zero amplitudes');
    });
  });
}
