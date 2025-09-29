import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/opus_decoder.dart';
import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('AudioDecoderFactory Tests', () {
    group('Decoder Creation', () {
      test('should create OpusDecoder for Opus files', () {
        final decoder = AudioDecoderFactory.createDecoder('test.opus');
        expect(decoder, isA<OpusDecoder>());
        decoder.dispose();
      });

      test('should create MP4Decoder for MP4 files', () {
        final decoder1 = AudioDecoderFactory.createDecoder('test.mp4');
        final decoder2 = AudioDecoderFactory.createDecoder('test.m4a');

        expect(decoder1, isA<MP4Decoder>());
        expect(decoder2, isA<MP4Decoder>());

        decoder1.dispose();
        decoder2.dispose();
      });

      test('should throw UnsupportedFormatException for unsupported formats', () {
        expect(() => AudioDecoderFactory.createDecoder('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
        expect(() => AudioDecoderFactory.createDecoder('test.txt'), throwsA(isA<UnsupportedFormatException>()));
      });
    });

    group('Factory Interface Verification', () {
      test('should expose all required factory methods', () {
        // Verify interface methods exist
        expect(AudioDecoderFactory.createDecoder, isA<Function>());
        expect(AudioDecoderFactory.isFormatSupported, isA<Function>());
        expect(AudioDecoderFactory.detectFormat, isA<Function>());
        expect(AudioDecoderFactory.getSupportedFormats, isA<Function>());
        expect(AudioDecoderFactory.getSupportedExtensions, isA<Function>());
        expect(AudioDecoderFactory.getSupportedFormatNames, isA<Function>());
      });

      test('should have consistent format information', () {
        final formats = AudioDecoderFactory.getSupportedFormats();
        final extensions = AudioDecoderFactory.getSupportedExtensions();
        final names = AudioDecoderFactory.getSupportedFormatNames();

        // MP4 format should be present
        expect(formats, contains(AudioFormat.mp4));

        // MP4 extensions should be present
        expect(extensions, contains('mp4'));
        expect(extensions, contains('m4a'));

        // MP4 name should be present
        expect(names, contains('MP4/AAC'));

        // Verify AudioFormat.mp4 properties
        expect(AudioFormat.mp4.extensions, equals(['mp4', 'm4a']));
        expect(AudioFormat.mp4.name, equals('MP4/AAC'));
        expect(AudioFormat.mp4.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.mp4.typicalCompressionRatio, equals(10.0));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle non-existent files gracefully', () {
        expect(AudioDecoderFactory.detectFormat('non_existent_file.mp4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.isFormatSupported('non_existent_file.mp4'), isTrue);

        // Should still create decoder (file existence is checked during decode)
        final decoder = AudioDecoderFactory.createDecoder('non_existent_file.mp4');
        expect(decoder, isA<MP4Decoder>());
        decoder.dispose();
      });

      test('should handle empty file paths', () {
        expect(AudioDecoderFactory.detectFormat(''), equals(AudioFormat.unknown));
        expect(AudioDecoderFactory.isFormatSupported(''), isFalse);
        expect(() => AudioDecoderFactory.createDecoder(''), throwsA(isA<UnsupportedFormatException>()));
      });

      test('should handle files with no extension', () {
        expect(AudioDecoderFactory.detectFormat('filename_without_extension'), equals(AudioFormat.unknown));
        expect(AudioDecoderFactory.isFormatSupported('filename_without_extension'), isFalse);
        expect(() => AudioDecoderFactory.createDecoder('filename_without_extension'), throwsA(isA<UnsupportedFormatException>()));
      });

      test('should handle files with multiple dots in name', () {
        expect(AudioDecoderFactory.detectFormat('my.audio.file.mp4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('my.audio.file.m4a'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.isFormatSupported('my.audio.file.mp4'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('my.audio.file.m4a'), isTrue);
      });

      test('should handle case sensitivity correctly', () {
        final testCases = ['test.mp4', 'test.MP4', 'test.Mp4', 'test.mP4', 'test.m4a', 'test.M4A', 'test.M4a', 'test.m4A'];

        for (final testCase in testCases) {
          expect(AudioDecoderFactory.detectFormat(testCase), equals(AudioFormat.mp4), reason: 'Failed for case: $testCase');
          expect(AudioDecoderFactory.isFormatSupported(testCase), isTrue, reason: 'Failed for case: $testCase');

          final decoder = AudioDecoderFactory.createDecoder(testCase);
          expect(decoder, isA<MP4Decoder>(), reason: 'Failed for case: $testCase');
          decoder.dispose();
        }
      });
    });

    group('Magic Byte Detection Comprehensive Tests', () {
      test('should detect various MP4 container types', () async {
        final testCases = [
          {
            'name': 'isom brand',
            'bytes': [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D],
          },
          {
            'name': 'mp41 brand',
            'bytes': [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x31],
          },
          {
            'name': 'mp42 brand',
            'bytes': [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32],
          },
          {
            'name': 'M4A brand',
            'bytes': [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20],
          },
        ];

        final tempDir = Directory.systemTemp.createTempSync('mp4_magic_test_');

        try {
          for (final testCase in testCases) {
            final bytes = Uint8List.fromList(testCase['bytes'] as List<int>);
            final tempFile = File('${tempDir.path}/${testCase['name']}.unknown');
            await tempFile.writeAsBytes(bytes);

            expect(AudioDecoderFactory.detectFormat(tempFile.path), equals(AudioFormat.mp4), reason: 'Failed to detect MP4 for ${testCase['name']}');
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should not detect non-MP4 formats as MP4', () async {
        final nonMP4Cases = [
          {
            'name': 'MP3 ID3',
            'bytes': [0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00],
          },
          {
            'name': 'WAV RIFF',
            'bytes': [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45],
          },
          {
            'name': 'FLAC',
            'bytes': [0x66, 0x4C, 0x61, 0x43, 0x00, 0x00, 0x00, 0x22],
          },
          {
            'name': 'OGG',
            'bytes': [0x4F, 0x67, 0x67, 0x53, 0x00, 0x02, 0x00, 0x00],
          },
          {
            'name': 'Random data',
            'bytes': [0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00],
          },
        ];

        final tempDir = Directory.systemTemp.createTempSync('non_mp4_test_');

        try {
          for (final testCase in nonMP4Cases) {
            final bytes = Uint8List.fromList(testCase['bytes'] as List<int>);
            final tempFile = File('${tempDir.path}/${testCase['name']}.unknown');
            await tempFile.writeAsBytes(bytes);

            expect(AudioDecoderFactory.detectFormat(tempFile.path), isNot(equals(AudioFormat.mp4)), reason: 'Incorrectly detected ${testCase['name']} as MP4');
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });
  });
}
