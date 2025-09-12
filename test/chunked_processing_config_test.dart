import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/chunked_processing_config.dart';

void main() {
  group('ChunkedProcessingConfig', () {
    group('Default Configuration', () {
      test('should have sensible defaults', () {
        const config = ChunkedProcessingConfig();

        expect(config.fileChunkSize, equals(10 * 1024 * 1024)); // 10MB
        expect(config.maxMemoryUsage, equals(100 * 1024 * 1024)); // 100MB
        expect(config.maxConcurrentChunks, equals(3));
        expect(config.enableSeeking, isTrue);
        expect(config.enableProgressReporting, isTrue);
        expect(config.progressUpdateInterval, equals(const Duration(milliseconds: 100)));
        expect(config.enableMemoryPressureDetection, isTrue);
        expect(config.memoryPressureThreshold, equals(0.8));
        expect(config.enableAdaptiveChunkSize, isTrue);
        expect(config.minChunkSize, equals(1 * 1024 * 1024)); // 1MB
        expect(config.maxChunkSize, equals(50 * 1024 * 1024)); // 50MB
        expect(config.enablePlatformOptimizations, isTrue);
      });

      test('should validate successfully with defaults', () {
        const config = ChunkedProcessingConfig();
        final validation = config.validate();

        expect(validation.isValid, isTrue);
        expect(validation.errors, isEmpty);
      });
    });

    group('forFileSize Factory', () {
      test('should throw for invalid file size', () {
        expect(() => ChunkedProcessingConfig.forFileSize(0), throwsArgumentError);
        expect(() => ChunkedProcessingConfig.forFileSize(-1), throwsArgumentError);
      });

      test('should optimize for small files (< 5MB)', () {
        final config = ChunkedProcessingConfig.forFileSize(2 * 1024 * 1024); // 2MB

        expect(config.fileChunkSize, lessThanOrEqualTo(2 * 1024 * 1024)); // <= 2MB
        expect(config.fileChunkSize, greaterThanOrEqualTo(512 * 1024)); // >= 512KB
        expect(config.maxConcurrentChunks, lessThanOrEqualTo(2));
        expect(config.enableSeeking, isFalse); // Disabled for small files
        expect(config.enableProgressReporting, isFalse); // Disabled for small files
      });

      test('should optimize for medium files (5MB - 50MB)', () {
        final config = ChunkedProcessingConfig.forFileSize(25 * 1024 * 1024); // 25MB

        expect(config.fileChunkSize, greaterThanOrEqualTo(2 * 1024 * 1024)); // >= 2MB
        expect(config.fileChunkSize, lessThanOrEqualTo(8 * 1024 * 1024)); // <= 8MB
        expect(config.maxConcurrentChunks, greaterThanOrEqualTo(2));
        expect(config.enableSeeking, isTrue); // Enabled for medium files
        expect(config.enableProgressReporting, isTrue); // Enabled for medium files
      });

      test('should optimize for large files (50MB - 500MB)', () {
        final config = ChunkedProcessingConfig.forFileSize(200 * 1024 * 1024); // 200MB

        expect(config.fileChunkSize, greaterThanOrEqualTo(5 * 1024 * 1024)); // >= 5MB
        expect(config.fileChunkSize, lessThanOrEqualTo(15 * 1024 * 1024)); // <= 15MB
        expect(config.maxConcurrentChunks, greaterThanOrEqualTo(2));
        expect(config.enableSeeking, isTrue);
        expect(config.enableProgressReporting, isTrue);
        expect(config.enableAdaptiveChunkSize, isTrue); // Enabled for large files
      });

      test('should optimize for very large files (> 500MB)', () {
        final config = ChunkedProcessingConfig.forFileSize(2 * 1024 * 1024 * 1024); // 2GB

        expect(config.fileChunkSize, greaterThanOrEqualTo(10 * 1024 * 1024)); // >= 10MB
        expect(config.fileChunkSize, lessThanOrEqualTo(25 * 1024 * 1024)); // <= 25MB
        expect(config.maxConcurrentChunks, greaterThanOrEqualTo(2));
        expect(config.enableSeeking, isTrue);
        expect(config.enableProgressReporting, isTrue);
        expect(config.progressUpdateInterval, equals(const Duration(milliseconds: 50))); // More frequent updates
      });

      test('should ensure chunk size respects memory constraints', () {
        final config = ChunkedProcessingConfig.forFileSize(100 * 1024 * 1024); // 100MB

        // Chunk size * concurrent chunks should not exceed memory budget
        final totalChunkMemory = config.fileChunkSize * config.maxConcurrentChunks;
        expect(totalChunkMemory, lessThan(config.maxMemoryUsage));
      });
    });

    group('Specialized Factory Methods', () {
      test('forLowMemoryDevice should create conservative configuration', () {
        final config = ChunkedProcessingConfig.forLowMemoryDevice();

        expect(config.maxMemoryUsage, equals(30 * 1024 * 1024)); // 30MB
        expect(config.maxConcurrentChunks, equals(1));
        expect(config.memoryPressureThreshold, equals(0.6)); // Very conservative
        expect(config.progressUpdateInterval, equals(const Duration(milliseconds: 200)));
        expect(config.minChunkSize, equals(512 * 1024)); // 512KB
        expect(config.maxChunkSize, equals(5 * 1024 * 1024)); // 5MB
      });

      test('forLowMemoryDevice with file size should optimize chunk size', () {
        final config = ChunkedProcessingConfig.forLowMemoryDevice(
          fileSize: 40 * 1024 * 1024, // 40MB
        );

        expect(config.fileChunkSize, lessThanOrEqualTo(2 * 1024 * 1024)); // <= 2MB
        expect(config.fileChunkSize, greaterThanOrEqualTo(512 * 1024)); // >= 512KB
      });

      test('forHighPerformanceDevice should create aggressive configuration', () {
        final config = ChunkedProcessingConfig.forHighPerformanceDevice();

        expect(config.maxMemoryUsage, equals(300 * 1024 * 1024)); // 300MB
        expect(config.maxConcurrentChunks, equals(6));
        expect(config.memoryPressureThreshold, equals(0.9)); // Aggressive
        expect(config.progressUpdateInterval, equals(const Duration(milliseconds: 50)));
        expect(config.minChunkSize, equals(2 * 1024 * 1024)); // 2MB
        expect(config.maxChunkSize, equals(100 * 1024 * 1024)); // 100MB
      });
    });

    group('Validation', () {
      test('should detect chunk size too small', () {
        final config = const ChunkedProcessingConfig().copyWith(fileChunkSize: 512);
        final validation = config.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('File chunk size too small')));
      });

      test('should detect chunk size too large', () {
        final config = const ChunkedProcessingConfig().copyWith(
          fileChunkSize: 2 * 1024 * 1024 * 1024, // 2GB
        );
        final validation = config.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('File chunk size too large')));
      });

      test('should detect chunk size smaller than minimum', () {
        final config = const ChunkedProcessingConfig().copyWith(
          fileChunkSize: 512 * 1024, // 512KB
          minChunkSize: 1024 * 1024, // 1MB
        );
        final validation = config.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('smaller than minimum')));
      });

      test('should detect chunk size larger than maximum', () {
        final config = const ChunkedProcessingConfig().copyWith(
          fileChunkSize: 60 * 1024 * 1024, // 60MB
          maxChunkSize: 50 * 1024 * 1024, // 50MB
        );
        final validation = config.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('larger than maximum')));
      });

      test('should detect insufficient memory for concurrent chunks', () {
        final config = const ChunkedProcessingConfig().copyWith(
          fileChunkSize: 50 * 1024 * 1024, // 50MB
          maxMemoryUsage: 100 * 1024 * 1024, // 100MB
          maxConcurrentChunks: 3, // 3 * 50MB = 150MB > 100MB
        );
        final validation = config.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('insufficient for concurrent chunks')));
      });

      test('should detect invalid concurrent chunks count', () {
        final config = const ChunkedProcessingConfig().copyWith(maxConcurrentChunks: 0);
        final validation = config.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('must be at least 1')));
      });

      test('should detect invalid memory pressure threshold', () {
        final config = const ChunkedProcessingConfig().copyWith(memoryPressureThreshold: 1.5);
        final validation = config.validate();

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('between 0.1 and 1.0')));
      });

      test('should warn about very low memory usage', () {
        final config = const ChunkedProcessingConfig().copyWith(
          maxMemoryUsage: 5 * 1024 * 1024, // 5MB
          fileChunkSize: 1 * 1024 * 1024, // 1MB
          maxConcurrentChunks: 1,
        );
        final validation = config.validate();

        expect(validation.isValid, isTrue);
        expect(validation.warnings, contains(contains('very low')));
      });

      test('should warn about high concurrent chunk count', () {
        final config = const ChunkedProcessingConfig().copyWith(
          maxConcurrentChunks: 15,
          maxMemoryUsage: 500 * 1024 * 1024, // 500MB to avoid memory error
        );
        final validation = config.validate();

        expect(validation.isValid, isTrue);
        expect(validation.warnings, contains(contains('resource contention')));
      });

      test('should warn about very frequent progress updates', () {
        final config = const ChunkedProcessingConfig().copyWith(progressUpdateInterval: const Duration(milliseconds: 5));
        final validation = config.validate();

        expect(validation.isValid, isTrue);
        expect(validation.warnings, contains(contains('frequent progress updates')));
      });
    });

    group('Optimization', () {
      test('should optimize for target file size', () {
        const originalConfig = ChunkedProcessingConfig(
          fileChunkSize: 5 * 1024 * 1024, // 5MB
          maxMemoryUsage: 50 * 1024 * 1024, // 50MB
        );

        final optimized = originalConfig.optimize(
          targetFileSize: 500 * 1024 * 1024, // 500MB - large file
        );

        expect(optimized.fileChunkSize, greaterThan(originalConfig.fileChunkSize));
        expect(optimized.maxMemoryUsage, greaterThanOrEqualTo(originalConfig.maxMemoryUsage));
      });

      test('should adjust for available memory', () {
        const originalConfig = ChunkedProcessingConfig();

        final optimized = originalConfig.optimize(
          targetFileSize: 100 * 1024 * 1024, // 100MB
          availableMemory: 200 * 1024 * 1024, // 200MB available
        );

        // The optimize method creates a new config based on file size first,
        // then adjusts memory within the clamp range. For 100MB file, it creates
        // a config with ~100MB memory, then clamps to 30% of available (60MB)
        final expectedMaxMemory = (200 * 1024 * 1024 * 0.3).round(); // 60MB
        expect(optimized.maxMemoryUsage, lessThanOrEqualTo(expectedMaxMemory));
      });

      test('should adjust for low memory device', () {
        const originalConfig = ChunkedProcessingConfig(maxConcurrentChunks: 4);

        final optimized = originalConfig.optimize(
          targetFileSize: 100 * 1024 * 1024, // 100MB
          isLowMemoryDevice: true,
        );

        expect(optimized.maxConcurrentChunks, lessThan(originalConfig.maxConcurrentChunks));
        expect(optimized.memoryPressureThreshold, lessThan(originalConfig.memoryPressureThreshold));
        expect(optimized.enableMemoryPressureDetection, isTrue);
      });

      test('should return same config when no optimization needed', () {
        const originalConfig = ChunkedProcessingConfig();
        final optimized = originalConfig.optimize();

        expect(optimized, equals(originalConfig));
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        const config = ChunkedProcessingConfig(
          fileChunkSize: 15 * 1024 * 1024,
          maxMemoryUsage: 120 * 1024 * 1024,
          maxConcurrentChunks: 4,
          enableSeeking: false,
          progressUpdateInterval: Duration(milliseconds: 150),
        );

        final json = config.toJson();

        expect(json['fileChunkSize'], equals(15 * 1024 * 1024));
        expect(json['maxMemoryUsage'], equals(120 * 1024 * 1024));
        expect(json['maxConcurrentChunks'], equals(4));
        expect(json['enableSeeking'], isFalse);
        expect(json['progressUpdateIntervalMs'], equals(150));
        expect(json['version'], equals(1));
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'fileChunkSize': 15 * 1024 * 1024,
          'maxMemoryUsage': 120 * 1024 * 1024,
          'maxConcurrentChunks': 4,
          'enableSeeking': false,
          'progressUpdateIntervalMs': 150,
          'memoryPressureThreshold': 0.75,
        };

        final config = ChunkedProcessingConfig.fromJson(json);

        expect(config.fileChunkSize, equals(15 * 1024 * 1024));
        expect(config.maxMemoryUsage, equals(120 * 1024 * 1024));
        expect(config.maxConcurrentChunks, equals(4));
        expect(config.enableSeeking, isFalse);
        expect(config.progressUpdateInterval, equals(const Duration(milliseconds: 150)));
        expect(config.memoryPressureThreshold, equals(0.75));
      });

      test('should use defaults for missing JSON fields', () {
        final json = {
          'fileChunkSize': 20 * 1024 * 1024,
          // Other fields missing
        };

        final config = ChunkedProcessingConfig.fromJson(json);

        expect(config.fileChunkSize, equals(20 * 1024 * 1024));
        expect(config.maxMemoryUsage, equals(100 * 1024 * 1024)); // Default
        expect(config.enableSeeking, isTrue); // Default
      });

      test('should round-trip through JSON correctly', () {
        const originalConfig = ChunkedProcessingConfig(fileChunkSize: 12 * 1024 * 1024, maxConcurrentChunks: 5, memoryPressureThreshold: 0.85);

        final json = originalConfig.toJson();
        final deserializedConfig = ChunkedProcessingConfig.fromJson(json);

        expect(deserializedConfig, equals(originalConfig));
      });
    });

    group('copyWith', () {
      test('should create copy with modified parameters', () {
        const originalConfig = ChunkedProcessingConfig();

        final modifiedConfig = originalConfig.copyWith(fileChunkSize: 20 * 1024 * 1024, enableSeeking: false);

        expect(modifiedConfig.fileChunkSize, equals(20 * 1024 * 1024));
        expect(modifiedConfig.enableSeeking, isFalse);
        expect(modifiedConfig.maxMemoryUsage, equals(originalConfig.maxMemoryUsage)); // Unchanged
        expect(modifiedConfig.maxConcurrentChunks, equals(originalConfig.maxConcurrentChunks)); // Unchanged
      });

      test('should return identical copy when no parameters changed', () {
        const originalConfig = ChunkedProcessingConfig();
        final copiedConfig = originalConfig.copyWith();

        expect(copiedConfig, equals(originalConfig));
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when all properties match', () {
        const config1 = ChunkedProcessingConfig(fileChunkSize: 15 * 1024 * 1024);
        const config2 = ChunkedProcessingConfig(fileChunkSize: 15 * 1024 * 1024);

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('should not be equal when properties differ', () {
        const config1 = ChunkedProcessingConfig(fileChunkSize: 15 * 1024 * 1024);
        const config2 = ChunkedProcessingConfig(fileChunkSize: 20 * 1024 * 1024);

        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('should provide readable string representation', () {
        const config = ChunkedProcessingConfig(fileChunkSize: 15 * 1024 * 1024, maxConcurrentChunks: 4);

        final str = config.toString();

        expect(str, contains('ChunkedProcessingConfig'));
        expect(str, contains('fileChunkSize: ${15 * 1024 * 1024}B'));
        expect(str, contains('maxConcurrentChunks: 4'));
      });
    });
  });

  group('ChunkedProcessingConfigValidation', () {
    test('should report valid configuration correctly', () {
      const validation = ChunkedProcessingConfigValidation(isValid: true, errors: [], warnings: ['Some warning']);

      expect(validation.isValid, isTrue);
      expect(validation.hasErrors, isFalse);
      expect(validation.hasWarnings, isTrue);
    });

    test('should report invalid configuration correctly', () {
      const validation = ChunkedProcessingConfigValidation(isValid: false, errors: ['Error 1', 'Error 2'], warnings: []);

      expect(validation.isValid, isFalse);
      expect(validation.hasErrors, isTrue);
      expect(validation.hasWarnings, isFalse);
    });

    test('toString should format errors and warnings', () {
      const validation = ChunkedProcessingConfigValidation(isValid: false, errors: ['Critical error'], warnings: ['Minor warning']);

      final str = validation.toString();

      expect(str, contains('INVALID'));
      expect(str, contains('Errors:'));
      expect(str, contains('Critical error'));
      expect(str, contains('Warnings:'));
      expect(str, contains('Minor warning'));
    });
  });
}
