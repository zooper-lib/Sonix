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

    test('should check format support using static methods', () {
      // These should work with the mock decoder factory - use static methods
      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
      expect(Sonix.isFormatSupported('test.wav'), isTrue);
      expect(Sonix.isFormatSupported('test.flac'), isTrue);
      expect(Sonix.isFormatSupported('test.ogg'), isTrue);
      expect(Sonix.isFormatSupported('test.opus'), isTrue);
      expect(Sonix.isFormatSupported('test.unknown'), isFalse);
      expect(Sonix.isFormatSupported('test.xyz'), isFalse);
      expect(Sonix.isFormatSupported('test.txt'), isFalse);
    });

    test('should return supported formats and extensions using static methods', () {
      // Use static methods since these are utility functions
      final formats = Sonix.getSupportedFormats();
      expect(formats, isA<List<String>>());
      expect(formats, isNotEmpty);
      expect(formats, contains('MP3'));
      expect(formats, contains('WAV'));
      expect(formats, contains('FLAC'));
      expect(formats, contains('OGG Vorbis'));
      expect(formats, contains('Opus'));

      final extensions = Sonix.getSupportedExtensions();
      expect(extensions, isA<List<String>>());
      expect(extensions, isNotEmpty);
      expect(extensions, contains('mp3'));
      expect(extensions, contains('wav'));
      expect(extensions, contains('flac'));
      expect(extensions, contains('ogg'));
      expect(extensions, contains('opus'));
    });

    test('should check extension support using static methods', () {
      expect(Sonix.isExtensionSupported('mp3'), isTrue);
      expect(Sonix.isExtensionSupported('.mp3'), isTrue);
      expect(Sonix.isExtensionSupported('MP3'), isTrue);
      expect(Sonix.isExtensionSupported('.WAV'), isTrue);
      expect(Sonix.isExtensionSupported('xyz'), isFalse);
      expect(Sonix.isExtensionSupported('.txt'), isFalse);
    });

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

  group('SonixConfig', () {
    test('should create default config', () {
      const config = SonixConfig();

      expect(config.maxConcurrentOperations, equals(3));
      expect(config.isolatePoolSize, equals(2));
      expect(config.maxMemoryUsage, equals(100 * 1024 * 1024));

      expect(config.enableProgressReporting, isTrue);
    });

    test('should create mobile config', () {
      final config = SonixConfig.mobile();

      expect(config.maxConcurrentOperations, equals(2));
      expect(config.isolatePoolSize, equals(1));
      expect(config.maxMemoryUsage, equals(50 * 1024 * 1024));
    });

    test('should create desktop config', () {
      final config = SonixConfig.desktop();

      expect(config.maxConcurrentOperations, equals(4));
      expect(config.isolatePoolSize, equals(3));
      expect(config.maxMemoryUsage, equals(200 * 1024 * 1024));
    });

    test('should have proper string representation', () {
      const config = SonixConfig();
      final str = config.toString();

      expect(str, contains('SonixConfig'));
      expect(str, contains('maxConcurrentOperations: 3'));
      expect(str, contains('isolatePoolSize: 2'));
      expect(str, contains('100.0MB'));
    });
  });
}
