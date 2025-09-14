import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('SonixInstance API Structure', () {
    test('should create with default configuration', () {
      final sonix = SonixInstance();

      expect(sonix.config, isA<SonixConfig>());
      expect(sonix.config.maxConcurrentOperations, equals(3));
      expect(sonix.config.isolatePoolSize, equals(2));
      expect(sonix.config.maxMemoryUsage, equals(100 * 1024 * 1024));
      expect(sonix.isDisposed, isFalse);
    });

    test('should create with custom configuration', () {
      final config = SonixConfig.mobile();
      final sonix = SonixInstance(config);

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
      expect(Sonix.isFormatSupported('test.unknown'), isFalse);
    });

    test('should return supported formats and extensions using static methods', () {
      // Use static methods since these are utility functions
      final formats = Sonix.getSupportedFormats();
      expect(formats, isA<List<String>>());
      expect(formats, isNotEmpty);

      final extensions = Sonix.getSupportedExtensions();
      expect(extensions, isA<List<String>>());
      expect(extensions, isNotEmpty);
    });

    test('should handle disposal correctly', () async {
      final sonix = SonixInstance();

      expect(sonix.isDisposed, isFalse);

      await sonix.dispose();

      expect(sonix.isDisposed, isTrue);

      // Should handle multiple disposal calls
      await sonix.dispose();
      expect(sonix.isDisposed, isTrue);
    });

    test('should not allow operations after disposal', () async {
      final sonix = SonixInstance();
      await sonix.dispose();

      expect(() => sonix.generateWaveform('test.mp3'), throwsA(isA<StateError>()));

      expect(() => sonix.getResourceStatistics(), throwsA(isA<StateError>()));
    });

    test('should throw for unsupported format', () async {
      final sonix = SonixInstance();

      expect(() => sonix.generateWaveform('test.unknown'), throwsA(isA<UnsupportedFormatException>()));

      await sonix.dispose();
    });
  });

  group('SonixConfig', () {
    test('should create default config', () {
      const config = SonixConfig();

      expect(config.maxConcurrentOperations, equals(3));
      expect(config.isolatePoolSize, equals(2));
      expect(config.maxMemoryUsage, equals(100 * 1024 * 1024));
      expect(config.enableCaching, isTrue);
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

  group('WaveformProgress', () {
    test('should create progress with required fields', () {
      const progress = WaveformProgress(progress: 0.5);

      expect(progress.progress, equals(0.5));
      expect(progress.statusMessage, isNull);
      expect(progress.partialData, isNull);
      expect(progress.isComplete, isFalse);
      expect(progress.error, isNull);
    });

    test('should create complete progress with data', () {
      final waveformData = WaveformData(
        amplitudes: [0.1, 0.2, 0.3],
        sampleRate: 44100,
        duration: const Duration(seconds: 1),
        metadata: WaveformMetadata(resolution: 3, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
      );

      final progress = WaveformProgress(progress: 1.0, partialData: waveformData, isComplete: true);

      expect(progress.progress, equals(1.0));
      expect(progress.partialData, equals(waveformData));
      expect(progress.isComplete, isTrue);
    });

    test('should create error progress', () {
      const progress = WaveformProgress(progress: 0.8, error: 'Processing failed', isComplete: true);

      expect(progress.progress, equals(0.8));
      expect(progress.error, equals('Processing failed'));
      expect(progress.isComplete, isTrue);
    });
  });

  group('Backward Compatibility (Sonix)', () {
    tearDown(() async {
      await Sonix.dispose();
    });

    test('should provide static format checking methods', () {
      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
      expect(Sonix.getSupportedFormats(), isNotEmpty);
      expect(Sonix.getSupportedExtensions(), isNotEmpty);
    });

    test('should handle initialization', () async {
      await Sonix.initialize();

      // Should be able to use static methods
      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
      expect(Sonix.getSupportedFormats(), isNotEmpty);
    });

    test('should handle multiple initialization calls', () async {
      await Sonix.initialize();
      await Sonix.initialize(); // Should not throw

      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
    });

    test('should initialize with custom config', () async {
      final config = SonixConfig.mobile();
      await Sonix.initialize(config);

      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
    });
  });
}
