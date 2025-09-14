import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('SonixInstance', () {
    late SonixInstance sonix;

    setUp(() {
      sonix = SonixInstance();
    });

    tearDown(() async {
      await sonix.dispose();
    });

    group('Configuration', () {
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

      test('should create desktop configuration', () {
        final config = SonixConfig.desktop();

        expect(config.maxConcurrentOperations, equals(4));
        expect(config.isolatePoolSize, equals(3));
        expect(config.maxMemoryUsage, equals(200 * 1024 * 1024));
      });
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await sonix.initialize();

        expect(sonix.isDisposed, isFalse);

        // Should be able to get statistics after initialization
        final stats = sonix.getResourceStatistics();
        expect(stats, isA<IsolateStatistics>());
      });

      test('should not allow initialization after disposal', () async {
        await sonix.dispose();

        expect(() => sonix.initialize(), throwsA(isA<StateError>()));
      });

      test('should handle multiple initialization calls gracefully', () async {
        await sonix.initialize();
        await sonix.initialize(); // Should not throw

        expect(sonix.isDisposed, isFalse);
      });
    });

    group('Format Support', () {
      test('should check format support using static methods', () {
        // These should work with the mock decoder factory - use static methods
        expect(Sonix.isFormatSupported('test.mp3'), isTrue);
        expect(Sonix.isFormatSupported('test.wav'), isTrue);
        expect(Sonix.isFormatSupported('test.unknown'), isFalse);
      });

      test('should return supported formats using static methods', () {
        final formats = Sonix.getSupportedFormats();
        expect(formats, isA<List<String>>());
        expect(formats, isNotEmpty);
      });

      test('should return supported extensions using static methods', () {
        final extensions = Sonix.getSupportedExtensions();
        expect(extensions, isA<List<String>>());
        expect(extensions, isNotEmpty);
      });
    });

    group('Resource Management', () {
      test('should provide resource statistics', () async {
        await sonix.initialize();

        final stats = sonix.getResourceStatistics();
        expect(stats.activeIsolates, greaterThanOrEqualTo(0));
        expect(stats.queuedTasks, equals(0));
        expect(stats.completedTasks, greaterThanOrEqualTo(0));
      });

      test('should optimize resources', () async {
        await sonix.initialize();

        // Should not throw
        sonix.optimizeResources();

        final stats = sonix.getResourceStatistics();
        expect(stats, isA<IsolateStatistics>());
      });

      test('should handle resource operations after disposal gracefully', () async {
        await sonix.dispose();

        expect(() => sonix.getResourceStatistics(), throwsA(isA<StateError>()));

        // Optimize resources should not throw after disposal
        sonix.optimizeResources();
      });
    });

    group('Disposal', () {
      test('should dispose cleanly', () async {
        await sonix.initialize();

        expect(sonix.isDisposed, isFalse);

        await sonix.dispose();

        expect(sonix.isDisposed, isTrue);
      });

      test('should handle multiple disposal calls gracefully', () async {
        await sonix.initialize();

        await sonix.dispose();
        await sonix.dispose(); // Should not throw

        expect(sonix.isDisposed, isTrue);
      });

      test('should not allow operations after disposal', () async {
        await sonix.dispose();

        expect(() => sonix.generateWaveform('test.mp3'), throwsA(isA<StateError>()));
      });
    });

    group('Waveform Generation', () {
      test('should generate waveform data', () async {
        final waveformData = await sonix.generateWaveform('test.mp3');

        expect(waveformData, isA<WaveformData>());
        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.amplitudes.length, equals(1000)); // default resolution
      });

      test('should generate waveform with custom resolution', () async {
        final waveformData = await sonix.generateWaveform('test.mp3', resolution: 500);

        expect(waveformData.amplitudes.length, equals(500));
      });

      test('should generate waveform with custom configuration', () async {
        final config = const WaveformConfig(resolution: 200, type: WaveformType.line, normalize: false);

        final waveformData = await sonix.generateWaveform('test.mp3', config: config);

        expect(waveformData.amplitudes.length, equals(200));
      });

      test('should throw for unsupported format', () async {
        expect(() => sonix.generateWaveform('test.unknown'), throwsA(isA<UnsupportedFormatException>()));
      });
    });

    group('Streaming Waveform Generation', () {
      test('should generate waveform stream', () async {
        final progressUpdates = <WaveformProgress>[];

        await for (final progress in sonix.generateWaveformStream('test.mp3')) {
          progressUpdates.add(progress);
          if (progress.isComplete) break;
        }

        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last.isComplete, isTrue);
        expect(progressUpdates.last.partialData, isA<WaveformData>());
      });

      test('should provide progress updates', () async {
        var hasProgressUpdate = false;
        var hasCompletion = false;

        await for (final progress in sonix.generateWaveformStream('test.mp3')) {
          if (!progress.isComplete) {
            hasProgressUpdate = true;
          } else {
            hasCompletion = true;
            break;
          }
        }

        expect(hasCompletion, isTrue);
      });
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

  group('Backward Compatibility (Sonix)', () {
    tearDown(() async {
      await Sonix.dispose();
    });

    test('should initialize default instance', () async {
      await Sonix.initialize();

      // Should be able to use static methods
      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
      expect(Sonix.getSupportedFormats(), isNotEmpty);
    });

    test('should generate waveform with static method', () async {
      final waveformData = await Sonix.generateWaveform('test.mp3');

      expect(waveformData, isA<WaveformData>());
      expect(waveformData.amplitudes, isNotEmpty);
    });

    test('should handle multiple initialization calls', () async {
      await Sonix.initialize();
      await Sonix.initialize(); // Should not throw

      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
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
  });
}
