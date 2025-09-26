import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/config/sonix_config.dart';
import 'package:sonix/src/processing/waveform_use_case.dart';
import 'package:sonix/src/isolate/isolate_config.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('Sonix', () {
    test('should create with default configuration', () {
      final sonix = Sonix();

      expect(sonix.config, isA<SonixConfig>());
      expect(sonix.config.maxConcurrentOperations, equals(3));
      expect(sonix.config.isolatePoolSize, equals(2));
      expect(sonix.config.maxMemoryUsage, equals(100 * 1024 * 1024));
      expect(sonix.isDisposed, isFalse);
    });

    test('should create with custom configuration', () {
      final config = SonixConfig.mobile();
      final sonix = Sonix(config);

      expect(sonix.config, equals(config));
      expect(sonix.config.maxConcurrentOperations, equals(2));
      expect(sonix.config.isolatePoolSize, equals(1));
      expect(sonix.config.maxMemoryUsage, equals(50 * 1024 * 1024));
    });

    test('should implement IsolateConfig interface', () {
      final config = SonixConfig.desktop();

      // Should be usable as IsolateConfig
      expect(config, isA<IsolateConfig>());
      expect(config.maxConcurrentOperations, equals(4));
      expect(config.isolatePoolSize, equals(3));
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

    test('should handle disposal correctly', () async {
      final sonix = Sonix();

      expect(sonix.isDisposed, isFalse);

      await sonix.dispose();

      expect(sonix.isDisposed, isTrue);

      // Should handle multiple disposal calls
      await sonix.dispose();
      expect(sonix.isDisposed, isTrue);
    });

    test('should not allow operations after disposal', () async {
      final sonix = Sonix();
      await sonix.dispose();

      expect(() => sonix.generateWaveform('test.mp3'), throwsA(isA<StateError>()));

      expect(() => sonix.getResourceStatistics(), throwsA(isA<StateError>()));
    });

    test('should throw for unsupported format', () async {
      final sonix = Sonix();

      expect(() => sonix.generateWaveform('test.unknown'), throwsA(isA<UnsupportedFormatException>()));

      await sonix.dispose();
    });

    test('should throw UnsupportedFormatException for generateWaveform with invalid format', () async {
      final sonix = Sonix();

      try {
        await sonix.generateWaveform('test.xyz');
        fail('Expected UnsupportedFormatException to be thrown');
      } catch (e) {
        expect(e, isA<UnsupportedFormatException>());
      } finally {
        await sonix.dispose();
      }
    });
  });
}
