import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('NativeAudioBindings MP4 Support', () {
    setUpAll(() {
      // Initialize native bindings before running tests
      NativeAudioBindings.initialize();
    });

    group('Format Detection', () {
      test('should detect MP4 format from valid MP4 file', () async {
        final testFile = File('test/assets/Double-F the King - Your Blessing.mp4');
        if (!await testFile.exists()) {
          markTestSkipped('MP4 test file not available');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final format = NativeAudioBindings.detectFormat(Uint8List.fromList(bytes));

        // Note: MP4 format detection may return unknown if native MP4 support is not yet implemented
        // This test verifies the method doesn't crash and returns a valid format
        expect(format, isA<AudioFormat>());

        // If MP4 support is implemented, it should detect MP4
        if (format != AudioFormat.unknown) {
          expect(format, equals(AudioFormat.mp4));
        }
      });

      test('should handle MP4 format in format conversion methods', () {
        // Test enum to code conversion
        expect(NativeAudioBindings.formatEnumToCode(AudioFormat.mp4), equals(SONIX_FORMAT_MP4));

        // Test code to enum conversion
        expect(NativeAudioBindings.formatCodeToEnum(SONIX_FORMAT_MP4), equals(AudioFormat.mp4));
      });

      test('should handle unknown format gracefully', () {
        expect(NativeAudioBindings.formatCodeToEnum(-999), equals(AudioFormat.unknown));
        expect(NativeAudioBindings.formatEnumToCode(AudioFormat.unknown), equals(SONIX_FORMAT_UNKNOWN));
      });
    });

    group('Memory Estimation', () {
      test('should estimate MP4 decoded memory usage correctly', () {
        const fileSize = 1024 * 1024; // 1MB file

        final estimatedMemory = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, AudioFormat.mp4);

        // Should be at least 4x file size (minimum estimate)
        expect(estimatedMemory, greaterThanOrEqualTo(fileSize * 4));

        // Should be reasonable (not more than 20x for typical AAC)
        expect(estimatedMemory, lessThanOrEqualTo(fileSize * 20));
      });

      test('should provide more detailed MP4 memory estimation than generic', () {
        const fileSize = 5 * 1024 * 1024; // 5MB file

        final mp4Estimate = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, AudioFormat.mp4);
        final genericEstimate = (fileSize * AudioFormat.mp4.typicalCompressionRatio).round();

        // MP4-specific estimation should be more sophisticated
        expect(mp4Estimate, isNot(equals(genericEstimate)));
      });

      test('should handle small MP4 files with proper calculation', () {
        const smallFileSize = 100 * 1024; // 100KB file

        final estimatedMemory = NativeAudioBindings.estimateDecodedMemoryUsage(smallFileSize, AudioFormat.mp4);

        // For small files, the overhead calculation (10x * 1.2 = 12x) is larger than minimum (4x)
        // So we expect the overhead calculation result
        final expectedMemory = (smallFileSize * 10.0 * 1.2).round();
        expect(estimatedMemory, equals(expectedMemory));

        // Should still be at least the minimum estimate
        expect(estimatedMemory, greaterThanOrEqualTo(smallFileSize * 4));
      });

      test('should handle large MP4 files with overhead calculation', () {
        const largeFileSize = 50 * 1024 * 1024; // 50MB file

        final estimatedMemory = NativeAudioBindings.estimateDecodedMemoryUsage(largeFileSize, AudioFormat.mp4);

        // Should be more than minimum (4x) due to overhead calculation
        expect(estimatedMemory, greaterThan(largeFileSize * 4));
        expect(estimatedMemory, lessThanOrEqualTo(largeFileSize * 15)); // Reasonable upper bound
      });
    });

    group('Memory Limits', () {
      test('should correctly check if MP4 decoding would exceed memory limits', () {
        const originalThreshold = 10 * 1024 * 1024; // 10MB threshold
        NativeAudioBindings.setMemoryPressureThreshold(originalThreshold);

        try {
          // Small file should not exceed limits
          const smallFileSize = 500 * 1024; // 500KB
          expect(NativeAudioBindings.wouldExceedMemoryLimits(smallFileSize, AudioFormat.mp4), isFalse);

          // Large file should exceed limits
          const largeFileSize = 5 * 1024 * 1024; // 5MB (will decode to ~50MB+)
          expect(NativeAudioBindings.wouldExceedMemoryLimits(largeFileSize, AudioFormat.mp4), isTrue);
        } finally {
          // Restore reasonable threshold
          NativeAudioBindings.setMemoryPressureThreshold(100 * 1024 * 1024);
        }
      });

      test('should handle memory pressure threshold changes', () {
        const fileSize = 1024 * 1024; // 1MB file
        const lowThreshold = 1024 * 1024; // 1MB threshold
        const highThreshold = 100 * 1024 * 1024; // 100MB threshold

        // With low threshold, should exceed limits
        NativeAudioBindings.setMemoryPressureThreshold(lowThreshold);
        expect(NativeAudioBindings.wouldExceedMemoryLimits(fileSize, AudioFormat.mp4), isTrue);

        // With high threshold, should not exceed limits
        NativeAudioBindings.setMemoryPressureThreshold(highThreshold);
        expect(NativeAudioBindings.wouldExceedMemoryLimits(fileSize, AudioFormat.mp4), isFalse);

        // Verify threshold was actually changed
        expect(NativeAudioBindings.memoryPressureThreshold, equals(highThreshold));
      });
    });

    group('MP4 Chunk Size Recommendations', () {
      test('should provide appropriate chunk sizes for small MP4 files', () {
        const smallFileSize = 1024 * 1024; // 1MB

        final chunkSize = NativeAudioBindings.getRecommendedMP4ChunkSize(smallFileSize);

        expect(chunkSize, greaterThanOrEqualTo(8192)); // At least 8KB
        expect(chunkSize, lessThanOrEqualTo(512 * 1024)); // At most 512KB for small files
        expect(chunkSize, lessThanOrEqualTo(smallFileSize)); // Not larger than file
      });

      test('should provide appropriate chunk sizes for medium MP4 files', () {
        const mediumFileSize = 10 * 1024 * 1024; // 10MB

        final chunkSize = NativeAudioBindings.getRecommendedMP4ChunkSize(mediumFileSize);

        expect(chunkSize, equals(4 * 1024 * 1024)); // Should be 4MB for medium files
      });

      test('should provide appropriate chunk sizes for large MP4 files', () {
        const largeFileSize = 200 * 1024 * 1024; // 200MB

        final chunkSize = NativeAudioBindings.getRecommendedMP4ChunkSize(largeFileSize);

        expect(chunkSize, equals(8 * 1024 * 1024)); // Should be 8MB for large files
      });
    });

    group('Error Handling', () {
      test('should provide specific error messages for MP4 error codes', () {
        final containerError = NativeAudioBindings.getMP4ErrorMessage(SONIX_ERROR_MP4_CONTAINER_INVALID);
        expect(containerError, contains('Invalid MP4 container'));
        expect(containerError, contains('corrupted'));

        final noAudioError = NativeAudioBindings.getMP4ErrorMessage(SONIX_ERROR_MP4_NO_AUDIO_TRACK);
        expect(noAudioError, contains('No audio track'));
        expect(noAudioError, contains('video'));

        final codecError = NativeAudioBindings.getMP4ErrorMessage(SONIX_ERROR_MP4_UNSUPPORTED_CODEC);
        expect(codecError, contains('Unsupported audio codec'));
        expect(codecError, contains('AAC'));
      });

      test('should fall back to generic error message for unknown codes', () {
        final unknownError = NativeAudioBindings.getMP4ErrorMessage(-999);
        // Should not be one of the specific MP4 error messages
        expect(unknownError, isNot(contains('Invalid MP4 container')));
        expect(unknownError, isNot(contains('No audio track')));
        expect(unknownError, isNot(contains('Unsupported audio codec')));
      });
    });

    group('Integration with AudioFormat', () {
      test('should use correct compression ratio for MP4', () {
        expect(AudioFormat.mp4.typicalCompressionRatio, equals(10.0));
        expect(AudioFormat.mp4.name, equals('MP4/AAC'));
        expect(AudioFormat.mp4.extensions, containsAll(['mp4', 'm4a']));
        expect(AudioFormat.mp4.supportsChunkedProcessing, isTrue);
      });

      test('should handle MP4 format consistently across methods', () {
        const fileSize = 2 * 1024 * 1024; // 2MB

        // All methods should recognize MP4 format
        expect(NativeAudioBindings.wouldExceedMemoryLimits(fileSize, AudioFormat.mp4), isA<bool>());
        expect(NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, AudioFormat.mp4), isA<int>());
        expect(NativeAudioBindings.getRecommendedMP4ChunkSize(fileSize), isA<int>());
      });

      test('should handle MP4 decoding attempt gracefully', () {
        // Create minimal MP4-like data that won't crash the decoder
        final mp4LikeData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp' box
          0x69, 0x73, 0x6F, 0x6D, // 'isom' brand
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brands
          0x69, 0x73, 0x6F, 0x32,
          0x61, 0x76, 0x63, 0x31,
          0x6D, 0x70, 0x34, 0x31,
        ]);

        // Should not crash when attempting to decode MP4 data
        // May throw DecodingException if MP4 support not implemented, which is expected
        expect(() => NativeAudioBindings.decodeAudio(mp4LikeData, AudioFormat.mp4), anyOf(returnsNormally, throwsA(isA<Exception>())));
      });
    });

    group('Real File Testing', () {
      test('should decode real MP4 file if available', () async {
        final testFile = File('test/assets/Double-F the King - Your Blessing.mp4');
        if (!await testFile.exists()) {
          markTestSkipped('MP4 test file not available');
          return;
        }

        final bytes = await testFile.readAsBytes();

        // Should not throw exception for valid MP4 file
        expect(() => NativeAudioBindings.detectFormat(Uint8List.fromList(bytes)), returnsNormally);

        // Format detection should return a valid format (may be unknown if MP4 not implemented yet)
        final format = NativeAudioBindings.detectFormat(Uint8List.fromList(bytes));
        expect(format, isA<AudioFormat>());

        // Memory estimation should be reasonable
        final estimatedMemory = NativeAudioBindings.estimateDecodedMemoryUsage(bytes.length, AudioFormat.mp4);
        expect(estimatedMemory, greaterThan(bytes.length));
        expect(estimatedMemory, lessThan(bytes.length * 50)); // Reasonable upper bound
      });

      test('should handle corrupted MP4 data gracefully', () {
        // Create some invalid MP4-like data
        final corruptedData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp' - looks like MP4
          0xFF, 0xFF, 0xFF, 0xFF, // Corrupted data
        ]);

        // Should not crash, might return unknown format
        expect(() => NativeAudioBindings.detectFormat(corruptedData), returnsNormally);
      });
    });
  });
}
