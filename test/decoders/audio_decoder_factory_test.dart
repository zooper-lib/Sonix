import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('AudioDecoderFactory Tests', () {
    group('MP4 Format Detection', () {
      test('should detect MP4 format by file extension', () {
        expect(AudioDecoderFactory.detectFormat('test.mp4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('test.MP4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('TEST.Mp4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('/path/to/audio.mp4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('C:\\Users\\test\\audio.mp4'), equals(AudioFormat.mp4));
      });

      test('should detect M4A format by file extension', () {
        expect(AudioDecoderFactory.detectFormat('test.m4a'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('test.M4A'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('TEST.M4a'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('/path/to/audio.m4a'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('C:\\Users\\test\\audio.m4a'), equals(AudioFormat.mp4));
      });

      test('should detect MP4 format by magic bytes', () async {
        // Create synthetic MP4 with valid ftyp box
        final validMP4Bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // 'ftyp' box type
          0x69, 0x73, 0x6F, 0x6D, // Major brand 'isom'
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand 'isom'
          0x69, 0x73, 0x6F, 0x32, // Compatible brand 'iso2'
          0x61, 0x76, 0x63, 0x31, // Compatible brand 'avc1'
          0x6D, 0x70, 0x34, 0x31, // Compatible brand 'mp41'
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_factory_test_');
        final tempFile = File('${tempDir.path}/test_magic.unknown');
        await tempFile.writeAsBytes(validMP4Bytes);

        try {
          expect(AudioDecoderFactory.detectFormat(tempFile.path), equals(AudioFormat.mp4));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should not detect MP4 format with invalid magic bytes', () async {
        // Create file with invalid ftyp box
        final invalidBytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x69, 0x6E, 0x76, 0x64, // 'invd' - invalid box type
          0x69, 0x73, 0x6F, 0x6D, // Data
          0x00, 0x00, 0x02, 0x00,
          0x69, 0x73, 0x6F, 0x6D,
          0x69, 0x73, 0x6F, 0x32,
          0x61, 0x76, 0x63, 0x31,
          0x6D, 0x70, 0x34, 0x31,
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_factory_test_');
        final tempFile = File('${tempDir.path}/test_invalid.unknown');
        await tempFile.writeAsBytes(invalidBytes);

        try {
          expect(AudioDecoderFactory.detectFormat(tempFile.path), equals(AudioFormat.unknown));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should detect MP4 format with different major brands', () async {
        // Test with mp41 major brand
        final mp41Bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp'
          0x6D, 0x70, 0x34, 0x31, // Major brand 'mp41'
          0x00, 0x00, 0x00, 0x01, // Minor version
          0x6D, 0x70, 0x34, 0x31, // Compatible brands
          0x69, 0x73, 0x6F, 0x6D,
          0x61, 0x76, 0x63, 0x31,
          0x00, 0x00, 0x00, 0x00,
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_factory_test_');
        final tempFile = File('${tempDir.path}/test_mp41.unknown');
        await tempFile.writeAsBytes(mp41Bytes);

        try {
          expect(AudioDecoderFactory.detectFormat(tempFile.path), equals(AudioFormat.mp4));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should handle files too small for magic byte detection', () async {
        final tooSmallBytes = Uint8List.fromList([0x00, 0x00, 0x00]); // Only 3 bytes

        final tempDir = Directory.systemTemp.createTempSync('mp4_factory_test_');
        final tempFile = File('${tempDir.path}/too_small.unknown');
        await tempFile.writeAsBytes(tooSmallBytes);

        try {
          expect(AudioDecoderFactory.detectFormat(tempFile.path), equals(AudioFormat.unknown));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('MP4 Format Support', () {
      test('should report MP4 files as supported', () {
        expect(AudioDecoderFactory.isFormatSupported('test.mp4'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.MP4'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('TEST.Mp4'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.mp4'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('C:\\Users\\test\\audio.mp4'), isTrue);
      });

      test('should report M4A files as supported', () {
        expect(AudioDecoderFactory.isFormatSupported('test.m4a'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.M4A'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('TEST.M4a'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.m4a'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('C:\\Users\\test\\audio.m4a'), isTrue);
      });

      test('should report unsupported formats correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.xyz'), isFalse);
        expect(AudioDecoderFactory.isFormatSupported('test.txt'), isFalse);
        expect(AudioDecoderFactory.isFormatSupported('test.pdf'), isFalse);
        expect(AudioDecoderFactory.isFormatSupported('test'), isFalse);
        expect(AudioDecoderFactory.isFormatSupported(''), isFalse);
      });
    });

    group('MP4 Decoder Creation', () {
      test('should create MP4Decoder for MP4 files', () {
        final decoder1 = AudioDecoderFactory.createDecoder('test.mp4');
        final decoder2 = AudioDecoderFactory.createDecoder('test.MP4');
        final decoder3 = AudioDecoderFactory.createDecoder('/path/to/audio.mp4');

        expect(decoder1, isA<MP4Decoder>());
        expect(decoder2, isA<MP4Decoder>());
        expect(decoder3, isA<MP4Decoder>());

        decoder1.dispose();
        decoder2.dispose();
        decoder3.dispose();
      });

      test('should create MP4Decoder for M4A files', () {
        final decoder1 = AudioDecoderFactory.createDecoder('test.m4a');
        final decoder2 = AudioDecoderFactory.createDecoder('test.M4A');
        final decoder3 = AudioDecoderFactory.createDecoder('/path/to/audio.m4a');

        expect(decoder1, isA<MP4Decoder>());
        expect(decoder2, isA<MP4Decoder>());
        expect(decoder3, isA<MP4Decoder>());

        decoder1.dispose();
        decoder2.dispose();
        decoder3.dispose();
      });

      test('should throw UnsupportedFormatException for unsupported formats', () {
        expect(() => AudioDecoderFactory.createDecoder('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
        expect(() => AudioDecoderFactory.createDecoder('test.txt'), throwsA(isA<UnsupportedFormatException>()));
        expect(() => AudioDecoderFactory.createDecoder('test.pdf'), throwsA(isA<UnsupportedFormatException>()));
        expect(() => AudioDecoderFactory.createDecoder('test'), throwsA(isA<UnsupportedFormatException>()));
      });
    });

    group('Supported Formats and Extensions Lists', () {
      test('should include MP4 in supported formats list', () {
        final supportedFormats = AudioDecoderFactory.getSupportedFormats();
        expect(supportedFormats, contains(AudioFormat.mp4));
        expect(supportedFormats.length, greaterThanOrEqualTo(5)); // mp3, wav, flac, ogg, mp4
      });

      test('should include MP4 extensions in supported extensions list', () {
        final supportedExtensions = AudioDecoderFactory.getSupportedExtensions();
        expect(supportedExtensions, contains('mp4'));
        expect(supportedExtensions, contains('m4a'));
        expect(supportedExtensions.length, greaterThanOrEqualTo(6)); // mp3, wav, flac, ogg, mp4, m4a
      });

      test('should include MP4 name in supported format names list', () {
        final supportedNames = AudioDecoderFactory.getSupportedFormatNames();
        expect(supportedNames, contains('MP4/AAC'));
        expect(supportedNames.length, greaterThanOrEqualTo(5)); // MP3, WAV, FLAC, OGG Vorbis, MP4/AAC
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
