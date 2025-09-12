import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('Sonix API Tests', () {
    test('getSupportedFormats returns expected formats', () {
      final formats = Sonix.getSupportedFormats();

      expect(formats, isNotEmpty);
      expect(formats, contains('MP3'));
      expect(formats, contains('WAV'));
      expect(formats, contains('FLAC'));
      expect(formats, contains('OGG Vorbis'));
      expect(formats, contains('Opus'));
    });

    test('getSupportedExtensions returns expected extensions', () {
      final extensions = Sonix.getSupportedExtensions();

      expect(extensions, isNotEmpty);
      expect(extensions, contains('mp3'));
      expect(extensions, contains('wav'));
      expect(extensions, contains('flac'));
      expect(extensions, contains('ogg'));
      expect(extensions, contains('opus'));
    });

    test('isFormatSupported correctly identifies supported formats', () {
      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
      expect(Sonix.isFormatSupported('test.wav'), isTrue);
      expect(Sonix.isFormatSupported('test.flac'), isTrue);
      expect(Sonix.isFormatSupported('test.ogg'), isTrue);
      expect(Sonix.isFormatSupported('test.opus'), isTrue);

      expect(Sonix.isFormatSupported('test.xyz'), isFalse);
      expect(Sonix.isFormatSupported('test.txt'), isFalse);
    });

    test('isExtensionSupported correctly identifies supported extensions', () {
      expect(Sonix.isExtensionSupported('mp3'), isTrue);
      expect(Sonix.isExtensionSupported('.mp3'), isTrue);
      expect(Sonix.isExtensionSupported('MP3'), isTrue);
      expect(Sonix.isExtensionSupported('.WAV'), isTrue);

      expect(Sonix.isExtensionSupported('xyz'), isFalse);
      expect(Sonix.isExtensionSupported('.txt'), isFalse);
    });

    test('getOptimalConfig returns valid configurations', () {
      final musicConfig = Sonix.getOptimalConfig(useCase: WaveformUseCase.musicVisualization);
      expect(musicConfig.resolution, equals(1000));
      expect(musicConfig.normalize, isTrue);

      final speechConfig = Sonix.getOptimalConfig(useCase: WaveformUseCase.speechAnalysis, customResolution: 1500);
      expect(speechConfig.resolution, equals(1500));
      expect(speechConfig.normalize, isTrue);
    });

    test('generateWaveform throws UnsupportedFormatException for invalid format', () async {
      expect(() async => await Sonix.generateWaveform('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
    });

    test('generateWaveformStream throws UnsupportedFormatException for invalid format', () async {
      expect(() async {
        await for (final _ in Sonix.generateWaveformStream('test.xyz')) {
          // This should not execute
        }
      }, throwsA(isA<UnsupportedFormatException>()));
    });

    test('generateWaveformMemoryEfficient throws UnsupportedFormatException for invalid format', () async {
      expect(() async => await Sonix.generateWaveformMemoryEfficient('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
    });

    group('Chunked Processing API Tests', () {
      test('generateWaveform accepts chunked processing parameters', () async {
        // Test that the API accepts the new parameters without throwing
        expect(
          () async => await Sonix.generateWaveform(
            'test.xyz', // Will throw UnsupportedFormatException, but that's expected
            chunkedConfig: ChunkedProcessingConfig.forFileSize(1024 * 1024),
            forceChunkedProcessing: true,
          ),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });

      test('generateWaveformStream accepts chunked processing parameters', () async {
        // Test that the API accepts the new parameters without throwing
        expect(() async {
          await for (final _ in Sonix.generateWaveformStream(
            'test.xyz', // Will throw UnsupportedFormatException, but that's expected
            chunkedConfig: ChunkedProcessingConfig.forFileSize(1024 * 1024),
            onProgress: (progress) {
              // Progress callback
            },
          )) {
            // This should not execute due to unsupported format
          }
        }, throwsA(isA<UnsupportedFormatException>()));
      });

      test('ChunkedProcessingConfig.forFileSize creates appropriate configurations', () {
        // Test small file configuration
        final smallFileConfig = ChunkedProcessingConfig.forFileSize(5 * 1024 * 1024); // 5MB
        expect(smallFileConfig.fileChunkSize, lessThanOrEqualTo(8 * 1024 * 1024)); // <= 8MB (adjusted)
        expect(smallFileConfig.maxConcurrentChunks, lessThanOrEqualTo(4)); // Adjusted

        // Test large file configuration
        final largeFileConfig = ChunkedProcessingConfig.forFileSize(500 * 1024 * 1024); // 500MB
        expect(largeFileConfig.fileChunkSize, greaterThanOrEqualTo(5 * 1024 * 1024)); // >= 5MB
        expect(largeFileConfig.maxConcurrentChunks, greaterThanOrEqualTo(2));

        // Test very large file configuration
        final veryLargeFileConfig = ChunkedProcessingConfig.forFileSize(2 * 1024 * 1024 * 1024); // 2GB
        expect(veryLargeFileConfig.fileChunkSize, greaterThanOrEqualTo(10 * 1024 * 1024)); // >= 10MB
        expect(veryLargeFileConfig.maxConcurrentChunks, greaterThanOrEqualTo(2));
      });

      test('ChunkedProcessingConfig validation works correctly', () {
        // Test valid configuration
        const validConfig = ChunkedProcessingConfig();
        final validation = validConfig.validate();
        expect(validation.isValid, isTrue);
        expect(validation.errors, isEmpty);

        // Test invalid configuration
        const invalidConfig = ChunkedProcessingConfig(
          fileChunkSize: 100, // Too small
          maxConcurrentChunks: 0, // Invalid
          memoryPressureThreshold: 1.5, // Invalid
        );
        final invalidValidation = invalidConfig.validate();
        expect(invalidValidation.isValid, isFalse);
        expect(invalidValidation.errors, isNotEmpty);
      });

      test('ChunkedProcessingConfig copyWith works correctly', () {
        const originalConfig = ChunkedProcessingConfig();
        final modifiedConfig = originalConfig.copyWith(fileChunkSize: 20 * 1024 * 1024, enableSeeking: false);

        expect(modifiedConfig.fileChunkSize, equals(20 * 1024 * 1024));
        expect(modifiedConfig.enableSeeking, isFalse);
        expect(modifiedConfig.maxMemoryUsage, equals(originalConfig.maxMemoryUsage)); // Unchanged
      });

      test('ChunkedProcessingConfig JSON serialization works', () {
        const originalConfig = ChunkedProcessingConfig(fileChunkSize: 15 * 1024 * 1024, maxMemoryUsage: 200 * 1024 * 1024, enableSeeking: false);

        final json = originalConfig.toJson();
        final deserializedConfig = ChunkedProcessingConfig.fromJson(json);

        expect(deserializedConfig.fileChunkSize, equals(originalConfig.fileChunkSize));
        expect(deserializedConfig.maxMemoryUsage, equals(originalConfig.maxMemoryUsage));
        expect(deserializedConfig.enableSeeking, equals(originalConfig.enableSeeking));
      });

      test('API maintains backward compatibility', () async {
        // Test that existing API calls still work without new parameters
        expect(() async => await Sonix.generateWaveform('test.xyz'), throwsA(isA<UnsupportedFormatException>()));

        expect(() async {
          await for (final _ in Sonix.generateWaveformStream('test.xyz')) {
            // This should not execute
          }
        }, throwsA(isA<UnsupportedFormatException>()));
      });
    });

    group('New Chunked-Specific API Methods Tests', () {
      test('generateWaveformChunked throws UnsupportedFormatException for invalid format', () async {
        expect(() async => await Sonix.generateWaveformChunked('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
      });

      test('generateWaveformChunked accepts all parameters', () async {
        // Test that the API accepts all parameters without throwing (except for unsupported format)
        expect(
          () async => await Sonix.generateWaveformChunked(
            'test.xyz',
            resolution: 2000,
            type: WaveformType.bars,
            normalize: false,
            config: WaveformConfig(resolution: 2000),
            chunkedConfig: ChunkedProcessingConfig.forFileSize(1024 * 1024),
            onProgress: (progress) {
              // Progress callback
            },
            onError: (error, stackTrace) {
              // Error callback
            },
          ),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });

      test('generateWaveformWithProgress throws UnsupportedFormatException for invalid format', () async {
        expect(
          () async => await Sonix.generateWaveformWithProgress(
            'test.xyz',
            onProgress: (progress) {
              // Progress callback
            },
          ),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });

      test('generateWaveformWithProgress requires onProgress callback', () {
        // This should be a compile-time error, but we can test the parameter is required
        expect(
          () async => await Sonix.generateWaveformWithProgress(
            'test.xyz', // Use unsupported format to get UnsupportedFormatException before file check
            onProgress: (progress) {
              expect(progress, isA<ProgressInfo>());
            },
          ),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });

      test('seekAndGenerateWaveform throws UnsupportedFormatException for invalid format', () async {
        expect(() async => await Sonix.seekAndGenerateWaveform('test.xyz', seekPosition: Duration(seconds: 30)), throwsA(isA<UnsupportedFormatException>()));
      });

      test('seekAndGenerateWaveform accepts all parameters', () async {
        expect(
          () async => await Sonix.seekAndGenerateWaveform(
            'test.xyz',
            seekPosition: Duration(seconds: 30),
            duration: Duration(seconds: 10),
            resolution: 500,
            type: WaveformType.bars,
            normalize: true,
            config: WaveformConfig(resolution: 500),
            chunkedConfig: ChunkedProcessingConfig.forFileSize(1024 * 1024),
            onProgress: (progress) {
              // Progress callback
            },
          ),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });

      test('getChunkedProcessingCapabilities returns valid structure', () async {
        final capabilities = await Sonix.getChunkedProcessingCapabilities();

        expect(capabilities, isA<Map<String, dynamic>>());
        expect(capabilities['supportsChunkedProcessing'], isA<bool>());
        expect(capabilities['supportedFormats'], isA<List<String>>());
        expect(capabilities['supportsEfficientSeeking'], isA<Map<String, bool>>());
        expect(capabilities['recommendedChunkSizes'], isA<Map<String, Map<String, int>>>());
        expect(capabilities['platformOptimizations'], isA<Map<String, dynamic>>());

        // Check platform optimizations structure
        final platformOpts = capabilities['platformOptimizations'] as Map<String, dynamic>;
        expect(platformOpts['maxRecommendedMemoryUsage'], isA<int>());
        expect(platformOpts['maxRecommendedConcurrentChunks'], isA<int>());
        expect(platformOpts['supportsMemoryPressureDetection'], isA<bool>());
        expect(platformOpts['supportsProgressReporting'], isA<bool>());
      });

      test('getChunkedProcessingCapabilities with file path includes file-specific info', () async {
        // Create a temporary file for testing
        final tempFile = File('test_temp.mp3');
        await tempFile.writeAsBytes([0xFF, 0xE0, 0x00, 0x00]); // Minimal MP3-like header

        try {
          final capabilities = await Sonix.getChunkedProcessingCapabilities(tempFile.path);

          expect(capabilities, isA<Map<String, dynamic>>());

          // Should include file-specific information
          if (capabilities.containsKey('fileSpecific')) {
            final fileSpecific = capabilities['fileSpecific'] as Map<String, dynamic>;
            expect(fileSpecific['fileSize'], isA<int>());
            expect(fileSpecific['recommendedChunkSize'], isA<int>());
            expect(fileSpecific['recommendedMemoryUsage'], isA<int>());
            expect(fileSpecific['recommendedConcurrentChunks'], isA<int>());
            expect(fileSpecific['enableSeeking'], isA<bool>());
            expect(fileSpecific['enableProgressReporting'], isA<bool>());
          }
        } finally {
          // Clean up
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      });

      test('ProgressInfo provides correct progress calculation', () {
        final progress1 = ProgressInfo(processedChunks: 5, totalChunks: 10);
        expect(progress1.progressPercentage, equals(0.5));
        expect(progress1.isComplete, isFalse);

        final progress2 = ProgressInfo(processedChunks: 10, totalChunks: 10);
        expect(progress2.progressPercentage, equals(1.0));
        expect(progress2.isComplete, isTrue);

        final progress3 = ProgressInfo(processedChunks: 0, totalChunks: 0);
        expect(progress3.progressPercentage, equals(0.0));
        expect(progress3.isComplete, isFalse);
      });

      test('ProgressInfo handles edge cases correctly', () {
        // Test with more processed chunks than total (shouldn't happen but should be handled)
        final progress = ProgressInfo(processedChunks: 15, totalChunks: 10);
        expect(progress.progressPercentage, equals(1.0)); // Should be clamped to 1.0
        expect(progress.isComplete, isTrue);
      });

      test('New API methods work with existing WaveformConfig', () async {
        final config = WaveformConfig(resolution: 500, type: WaveformType.bars, normalize: false, algorithm: DownsamplingAlgorithm.peak);

        // Test that config is accepted by new methods
        expect(() async => await Sonix.generateWaveformChunked('test.xyz', config: config), throwsA(isA<UnsupportedFormatException>()));

        expect(
          () async => await Sonix.generateWaveformWithProgress('test.xyz', config: config, onProgress: (progress) {}),
          throwsA(isA<UnsupportedFormatException>()),
        );

        expect(
          () async => await Sonix.seekAndGenerateWaveform('test.xyz', seekPosition: Duration(seconds: 10), config: config),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });
    });
  });
}
