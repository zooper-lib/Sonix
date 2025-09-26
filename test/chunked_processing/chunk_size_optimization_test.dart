import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/mp3_decoder.dart';
import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/decoders/wav_decoder.dart';
import 'package:sonix/src/decoders/flac_decoder.dart';
import 'package:sonix/src/decoders/vorbis_decoder.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

/// Centralized chunked processing tests
///
/// This file consolidates ALL chunked processing testing that was previously
/// scattered across individual decoder tests. It covers:
/// - Optimal chunk size calculation for all formats
/// - Chunked processing workflow
/// - Cross-format chunk size comparison
/// - Chunked processing error handling
void main() {
  group('Chunked Processing Tests', () {
    group('Optimal Chunk Size Calculation', () {
      group('MP3 Chunk Sizing', () {
        late MP3Decoder decoder;

        setUp(() {
          decoder = MP3Decoder();
        });

        tearDown(() {
          decoder.dispose();
        });

        test('should recommend appropriate chunk size for small MP3 files', () {
          final recommendation = decoder.getOptimalChunkSize(500 * 1024); // 500KB

          expect(recommendation.recommendedSize, greaterThan(4096));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(500 * 1024));
          expect(recommendation.minSize, equals(4096));
          expect(recommendation.maxSize, equals(500 * 1024));
          expect(recommendation.reason, contains('Small MP3 file'));
          expect(recommendation.metadata?['format'], equals('MP3'));
        });

        test('should recommend appropriate chunk size for medium MP3 files', () {
          final recommendation = decoder.getOptimalChunkSize(10 * 1024 * 1024); // 10MB

          expect(recommendation.recommendedSize, greaterThan(32 * 1024));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(2 * 1024 * 1024));
          expect(recommendation.reason, contains('Medium MP3 file'));
        });

        test('should recommend appropriate chunk size for large MP3 files', () {
          final recommendation = decoder.getOptimalChunkSize(100 * 1024 * 1024); // 100MB

          expect(recommendation.recommendedSize, greaterThan(256 * 1024));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(4 * 1024 * 1024));
          expect(recommendation.reason, contains('Large MP3 file'));
        });
      });

      group('MP4 Chunk Sizing', () {
        late MP4Decoder decoder;

        setUp(() {
          decoder = MP4Decoder();
        });

        tearDown(() {
          decoder.dispose();
        });

        test('should recommend appropriate chunk size for small MP4 files', () {
          final fileSize = 1 * 1024 * 1024; // 1MB
          final recommendation = decoder.getOptimalChunkSize(fileSize);

          expect(recommendation.recommendedSize, greaterThan(8192));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(fileSize));
          expect(recommendation.minSize, equals(8192));
          expect(recommendation.maxSize, equals(fileSize));
          expect(recommendation.reason, contains('Small MP4'));
        });

        test('should recommend appropriate chunk size for medium MP4 files', () {
          final fileSize = 50 * 1024 * 1024; // 50MB
          final recommendation = decoder.getOptimalChunkSize(fileSize);

          expect(recommendation.recommendedSize, greaterThan(64 * 1024));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(8 * 1024 * 1024));
          expect(recommendation.reason, contains('Medium MP4'));
        });

        test('should recommend appropriate chunk size for large MP4 files', () {
          final fileSize = 500 * 1024 * 1024; // 500MB
          final recommendation = decoder.getOptimalChunkSize(fileSize);

          expect(recommendation.recommendedSize, greaterThan(512 * 1024));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(16 * 1024 * 1024));
          expect(recommendation.reason, contains('Large MP4'));
        });

        test('should provide recommendations across different MP4 file sizes', () {
          final smallRecommendation = decoder.getOptimalChunkSize(1024);
          expect(smallRecommendation.recommendedSize, greaterThan(0));

          final boundaryRecommendation = decoder.getOptimalChunkSize(2 * 1024 * 1024);
          expect(boundaryRecommendation.recommendedSize, greaterThan(smallRecommendation.recommendedSize));
        });
      });

      group('WAV Chunk Sizing', () {
        late WAVDecoder decoder;

        setUp(() {
          decoder = WAVDecoder();
        });

        tearDown(() {
          decoder.dispose();
        });

        test('should recommend appropriate chunk size for WAV files', () {
          final recommendation = decoder.getOptimalChunkSize(50 * 1024 * 1024); // 50MB

          expect(recommendation.recommendedSize, greaterThan(16 * 1024));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(8 * 1024 * 1024));
          expect(recommendation.reason, contains('WAV'));
          expect(recommendation.metadata?['format'], equals('WAV'));
        });
      });

      group('FLAC Chunk Sizing', () {
        late FLACDecoder decoder;

        setUp(() {
          decoder = FLACDecoder();
        });

        tearDown(() {
          decoder.dispose();
        });

        test('should recommend appropriate chunk size for FLAC files', () {
          final recommendation = decoder.getOptimalChunkSize(100 * 1024 * 1024); // 100MB

          expect(recommendation.recommendedSize, greaterThan(32 * 1024));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(4 * 1024 * 1024));
          expect(recommendation.reason, contains('FLAC'));
          expect(recommendation.metadata?['format'], equals('FLAC'));
        });
      });

      group('Vorbis Chunk Sizing', () {
        late VorbisDecoder decoder;

        setUp(() {
          decoder = VorbisDecoder();
        });

        tearDown(() {
          decoder.dispose();
        });

        test('should recommend appropriate chunk size for Vorbis files', () {
          final recommendation = decoder.getOptimalChunkSize(80 * 1024 * 1024); // 80MB

          expect(recommendation.recommendedSize, greaterThan(16 * 1024));
          expect(recommendation.recommendedSize, lessThanOrEqualTo(6 * 1024 * 1024));
          expect(recommendation.reason, contains('Vorbis'));
          expect(recommendation.metadata?['format'], equals('Vorbis'));
        });
      });

      group('Cross-Format Chunk Size Comparison', () {
        test('should provide format-appropriate chunk sizes', () {
          final mp3Decoder = MP3Decoder();
          final mp4Decoder = MP4Decoder();
          final wavDecoder = WAVDecoder();
          final flacDecoder = FLACDecoder();

          try {
            final fileSize = 50 * 1024 * 1024; // 50MB test file

            final mp3Chunk = mp3Decoder.getOptimalChunkSize(fileSize);
            final mp4Chunk = mp4Decoder.getOptimalChunkSize(fileSize);
            final wavChunk = wavDecoder.getOptimalChunkSize(fileSize);
            final flacChunk = flacDecoder.getOptimalChunkSize(fileSize);

            // All should provide valid recommendations
            expect(mp3Chunk.recommendedSize, greaterThan(0));
            expect(mp4Chunk.recommendedSize, greaterThan(0));
            expect(wavChunk.recommendedSize, greaterThan(0));
            expect(flacChunk.recommendedSize, greaterThan(0));

            // Each format may have different optimal sizes
            expect(mp3Chunk.metadata?['format'], equals('MP3'));
            expect(mp4Chunk.metadata?['format'], equals('MP4'));
            expect(wavChunk.metadata?['format'], equals('WAV'));
            expect(flacChunk.metadata?['format'], equals('FLAC'));
          } finally {
            mp3Decoder.dispose();
            mp4Decoder.dispose();
            wavDecoder.dispose();
            flacDecoder.dispose();
          }
        });
      });
    });

    group('Native Chunked Processing Interface', () {
      test('should initialize chunked decoder for different formats', () {
        // Test with non-existent file to check error handling
        final filePathPtr = 'non_existent.mp3'.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, filePathPtr.cast<ffi.Char>());
          // Should return null for non-existent file
          expect(decoder.address, equals(0));
        } finally {
          malloc.free(filePathPtr);
        }
      });

      test('should get optimal chunk size from native bindings', () {
        final mp3ChunkSize = SonixNativeBindings.getOptimalChunkSize(
          SONIX_FORMAT_MP3,
          10 * 1024 * 1024, // 10MB file
        );

        final wavChunkSize = SonixNativeBindings.getOptimalChunkSize(
          SONIX_FORMAT_WAV,
          10 * 1024 * 1024, // 10MB file
        );

        final flacChunkSize = SonixNativeBindings.getOptimalChunkSize(
          SONIX_FORMAT_FLAC,
          10 * 1024 * 1024, // 10MB file
        );

        expect(mp3ChunkSize, greaterThan(0));
        expect(wavChunkSize, greaterThan(0));
        expect(flacChunkSize, greaterThan(0));
        expect(mp3ChunkSize, lessThanOrEqualTo(2 * 1024 * 1024)); // Should be reasonable
        expect(wavChunkSize, lessThanOrEqualTo(2 * 1024 * 1024));
        expect(flacChunkSize, lessThanOrEqualTo(2 * 1024 * 1024));
      });

      test('should handle different file sizes appropriately', () {
        // Test various file sizes
        final smallFileChunk = SonixNativeBindings.getOptimalChunkSize(SONIX_FORMAT_MP3, 1024 * 1024); // 1MB
        final mediumFileChunk = SonixNativeBindings.getOptimalChunkSize(SONIX_FORMAT_MP3, 50 * 1024 * 1024); // 50MB
        final largeFileChunk = SonixNativeBindings.getOptimalChunkSize(SONIX_FORMAT_MP3, 500 * 1024 * 1024); // 500MB

        expect(smallFileChunk, greaterThan(0));
        expect(mediumFileChunk, greaterThan(0));
        expect(largeFileChunk, greaterThan(0));

        // Larger files should generally have larger chunk sizes, but with reasonable limits
        expect(smallFileChunk, lessThanOrEqualTo(mediumFileChunk));
      });
    });

    group('Chunked Processing Error Handling', () {
      test('should handle initialization errors gracefully', () {
        final mp3Decoder = MP3Decoder();

        try {
          expect(() => mp3Decoder.initializeChunkedDecoding('non_existent.mp3'), throwsA(isA<FileAccessException>()));
        } finally {
          mp3Decoder.dispose();
        }
      });

      test('should throw exception when using disposed decoder', () {
        final mp3Decoder = MP3Decoder();
        mp3Decoder.dispose();

        expect(() => mp3Decoder.initializeChunkedDecoding('test.mp3'), throwsA(isA<StateError>()));
      });

      test('should handle cleanup properly', () async {
        final mp4Decoder = MP4Decoder();

        try {
          await mp4Decoder.cleanupChunkedProcessing();
          expect(() => mp4Decoder.cleanupChunkedProcessing(), returnsNormally);

          mp4Decoder.dispose();
          await mp4Decoder.cleanupChunkedProcessing();
        } finally {
          // Ensure decoder is disposed
          mp4Decoder.dispose();
        }
      });
    });

    group('Chunked Processing Interface Verification', () {
      test('should expose all required chunked processing methods', () {
        final decoders = [MP3Decoder(), MP4Decoder(), WAVDecoder(), FLACDecoder(), VorbisDecoder()];

        try {
          for (final decoder in decoders) {
            // Verify interface methods exist
            expect(decoder.getOptimalChunkSize, isA<Function>());
            expect(decoder.initializeChunkedDecoding, isA<Function>());
            expect(decoder.cleanupChunkedProcessing, isA<Function>());
            expect(decoder.supportsEfficientSeeking, isA<bool>());
          }
        } finally {
          for (final decoder in decoders) {
            decoder.dispose();
          }
        }
      });
    });
  });
}
