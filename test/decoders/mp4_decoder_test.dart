import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('MP4 Decoder Unit Tests', () {
    late MP4Decoder decoder;

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Factory Integration', () {
      test('should be created by AudioDecoderFactory for MP4 files', () {
        // Test that the factory creates MP4 decoders for supported extensions
        final decoder1 = AudioDecoderFactory.createDecoder('test.mp4');
        final decoder2 = AudioDecoderFactory.createDecoder('test.m4a');

        expect(decoder1, isA<MP4Decoder>());
        expect(decoder2, isA<MP4Decoder>());

        decoder1.dispose();
        decoder2.dispose();
      });

      test('should detect MP4 format correctly', () {
        // Test format detection
        final format1 = AudioDecoderFactory.detectFormat('test.mp4');
        final format2 = AudioDecoderFactory.detectFormat('test.m4a');

        expect(format1, equals(AudioFormat.mp4));
        expect(format2, equals(AudioFormat.mp4));
      });
    });

    group('Basic Interface and Properties', () {
      test('should create decoder instance with correct initial state', () {
        expect(decoder, isA<MP4Decoder>());
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should implement required interfaces', () {
        expect(decoder, isA<MP4Decoder>());
        // Test that it properly implements the expected interfaces
        expect(decoder.isInitialized, isA<bool>());
        expect(decoder.currentPosition, isA<Duration>());
      });
    });

    group('Input Validation', () {
      test('should reject invalid file paths', () async {
        expect(() => decoder.decode(''), throwsA(isA<FileAccessException>()));

        expect(() => decoder.decode('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
      });

      test('should reject invalid chunked processing parameters', () async {
        expect(() => decoder.initializeChunkedDecoding(''), throwsA(isA<FileAccessException>()));

        expect(() => decoder.initializeChunkedDecoding('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
      });
    });

    group('State Management', () {
      test('should handle operations before initialization', () async {
        // Operations that should fail when not initialized
        final chunk = FileChunk(data: Uint8List.fromList([1, 2, 3, 4]), startPosition: 0, endPosition: 4, isLast: true);

        expect(() => decoder.processFileChunk(chunk), throwsA(isA<StateError>()));

        expect(() => decoder.seekToTime(Duration(seconds: 1)), throwsA(isA<StateError>()));

        // estimateDuration returns null when not initialized, doesn't throw
        final duration = await decoder.estimateDuration();
        expect(duration, isNull);
      });

      test('should provide metadata even when not initialized', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata, isA<Map<String, dynamic>>());
        expect(metadata['format'], equals('MP4/AAC'));
        expect(metadata['supportsSeekTable'], isTrue);
        expect(metadata['seekingAccuracy'], equals('high'));

        // These should have default values when not initialized
        expect(metadata['sampleRate'], anyOf(isNull, equals(0)));
        expect(metadata['channels'], anyOf(isNull, equals(0)));
        expect(metadata['bitrate'], anyOf(isNull, equals(0)));
      });

      test('should handle cleanup when not initialized', () async {
        // Should not throw when cleaning up uninitialized decoder
        expect(() => decoder.cleanupChunkedProcessing(), returnsNormally);
      });
    });

    group('Resource Management', () {
      test('should handle disposal gracefully', () {
        expect(() => decoder.dispose(), returnsNormally);

        // Disposing again should not cause issues
        expect(() => decoder.dispose(), returnsNormally);
      });

      test('should handle multiple cleanup calls', () async {
        // Multiple cleanups should be safe
        expect(() => decoder.cleanupChunkedProcessing(), returnsNormally);
        expect(() => decoder.cleanupChunkedProcessing(), returnsNormally);
      });
    });

    group('Chunked Processing Interface', () {
      test('should validate chunk data structure', () async {
        // Test with various invalid chunk configurations
        final invalidChunks = [
          FileChunk(
            data: Uint8List(0), // Empty data
            startPosition: 0,
            endPosition: 0,
            isLast: true,
          ),
          FileChunk(
            data: Uint8List.fromList([1, 2, 3]),
            startPosition: 10, // Start > end
            endPosition: 5,
            isLast: false,
          ),
        ];

        for (final chunk in invalidChunks) {
          expect(
            () => decoder.processFileChunk(chunk),
            throwsA(isA<StateError>()), // Should fail because not initialized
          );
        }
      });

      test('should provide correct format metadata structure', () {
        final metadata = decoder.getFormatMetadata();

        // Test required metadata fields
        expect(metadata.containsKey('format'), isTrue);
        expect(metadata.containsKey('supportsSeekTable'), isTrue);
        expect(metadata.containsKey('seekingAccuracy'), isTrue);

        // Test metadata types
        expect(metadata['format'], isA<String>());
        expect(metadata['supportsSeekTable'], isA<bool>());
        expect(metadata['seekingAccuracy'], isA<String>());
      });
    });
  });
}
