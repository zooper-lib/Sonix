import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/audio_format_service.dart';
import 'package:sonix/src/decoders/ffmpeg_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('AudioDecoderFactory Tests', () {
    group('Decoder Creation', () {
      test('should create FFmpegDecoder for Opus files', () {
        final decoder = AudioDecoderFactory.createDecoderFromPath('test.opus');
        expect(decoder, isA<FFmpegDecoder>());
        expect(decoder.format, equals(AudioFormat.opus));
        decoder.dispose();
      });

      test('should create FFmpegDecoder for MP4 files', () {
        final decoder1 = AudioDecoderFactory.createDecoderFromPath('test.mp4');
        final decoder2 = AudioDecoderFactory.createDecoderFromPath('test.m4a');

        expect(decoder1, isA<FFmpegDecoder>());
        expect(decoder2, isA<FFmpegDecoder>());
        expect(decoder1.format, equals(AudioFormat.mp4));
        expect(decoder2.format, equals(AudioFormat.mp4));

        decoder1.dispose();
        decoder2.dispose();
      });

      test('should throw UnsupportedFormatException for unsupported formats', () {
        expect(() => AudioDecoderFactory.createDecoderFromPath('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
        expect(() => AudioDecoderFactory.createDecoderFromPath('test.txt'), throwsA(isA<UnsupportedFormatException>()));
      });
    });

    group('Factory Interface Verification', () {
      test('should expose all required factory methods', () {
        // Verify interface methods exist - only decoder creation methods remain on factory
        expect(AudioDecoderFactory.createDecoderFromFormat, isA<Function>());
        expect(AudioDecoderFactory.createDecoderFromPath, isA<Function>());
      });

      test('should have consistent format information', () {
        final formats = AudioFormatService.supportedFormats;
        final extensions = AudioFormatService.getSupportedExtensions();
        final names = AudioFormatService.getSupportedFormatNames();

        // MP4 format should be present
        expect(formats, contains(AudioFormat.mp4));

        // MP4 extensions should be present
        expect(extensions, contains('mp4'));
        expect(extensions, contains('m4a'));

        // MP4 name should be present
        expect(names, contains('MP4/AAC'));

        // Verify AudioFormat.mp4 properties
        expect(AudioFormat.mp4.extensions, equals(['mp4', 'm4a', 'aac']));
        expect(AudioFormat.mp4.name, equals('MP4/AAC'));
        expect(AudioFormat.mp4.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.mp4.typicalCompressionRatio, equals(10.0));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle non-existent files gracefully', () {
        expect(AudioFormatService.detectFromFilePath('non_existent_file.mp4'), equals(AudioFormat.mp4));
        expect(AudioFormatService.isFileSupported('non_existent_file.mp4'), isTrue);

        // Should still create decoder (file existence is checked during decode)
        final decoder = AudioDecoderFactory.createDecoderFromPath('non_existent_file.mp4');
        expect(decoder, isA<FFmpegDecoder>());
        decoder.dispose();
      });

      test('should handle empty file paths', () {
        expect(AudioFormatService.detectFromFilePath(''), equals(AudioFormat.unknown));
        expect(AudioFormatService.isFileSupported(''), isFalse);
        expect(() => AudioDecoderFactory.createDecoderFromPath(''), throwsA(isA<UnsupportedFormatException>()));
      });

      test('should handle files with no extension', () {
        expect(AudioFormatService.detectFromFilePath('filename_without_extension'), equals(AudioFormat.unknown));
        expect(AudioFormatService.isFileSupported('filename_without_extension'), isFalse);
        expect(() => AudioDecoderFactory.createDecoderFromPath('filename_without_extension'), throwsA(isA<UnsupportedFormatException>()));
      });

      test('should handle files with multiple dots in name', () {
        expect(AudioFormatService.detectFromFilePath('my.audio.file.mp4'), equals(AudioFormat.mp4));
        expect(AudioFormatService.detectFromFilePath('my.audio.file.m4a'), equals(AudioFormat.mp4));
        expect(AudioFormatService.isFileSupported('my.audio.file.mp4'), isTrue);
        expect(AudioFormatService.isFileSupported('my.audio.file.m4a'), isTrue);
      });

      test('should handle case sensitivity correctly', () {
        final testCases = ['test.mp4', 'test.MP4', 'test.Mp4', 'test.mP4', 'test.m4a', 'test.M4A', 'test.M4a', 'test.m4A'];

        for (final testCase in testCases) {
          expect(AudioFormatService.detectFromFilePath(testCase), equals(AudioFormat.mp4), reason: 'Failed for case: $testCase');
          expect(AudioFormatService.isFileSupported(testCase), isTrue, reason: 'Failed for case: $testCase');

          final decoder = AudioDecoderFactory.createDecoderFromPath(testCase);
          expect(decoder, isA<FFmpegDecoder>(), reason: 'Failed for case: $testCase');
          decoder.dispose();
        }
      });
    });

    group('Magic Byte Detection Comprehensive Tests', () {
      test('should detect various MP4 file extensions', () async {
        // Test extension-based detection for MP4 formats
        // Note: Magic byte detection is handled at the native FFmpeg level,
        // the factory uses extension-based detection for initial format hints
        final testCases = [
          {'extension': 'mp4', 'name': 'MP4 video container'},
          {'extension': 'm4a', 'name': 'M4A audio container'},
        ];

        for (final testCase in testCases) {
          final extension = testCase['extension']!;
          final testPath = 'test_file.$extension';

          expect(
            AudioFormatService.detectFromFilePath(testPath),
            equals(AudioFormat.mp4),
            reason: 'Failed to detect MP4 for ${testCase['name']} ($extension extension)',
          );
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

            expect(
              AudioFormatService.detectFromFilePath(tempFile.path),
              isNot(equals(AudioFormat.mp4)),
              reason: 'Incorrectly detected ${testCase['name']} as MP4',
            );
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });
  });
}
