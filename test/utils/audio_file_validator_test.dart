import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/utils/audio_file_validator.dart';

void main() {
  group('AudioFileValidator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_validator_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('validate', () {
      test('should throw FileSystemException for non-existent file', () async {
        final nonExistentPath = '${tempDir.path}/does_not_exist.mp3';

        expect(() => AudioFileValidator.validate(nonExistentPath), throwsA(isA<FileSystemException>()));
      });

      test('should throw DecodingException for empty file', () async {
        final emptyFile = File('${tempDir.path}/empty.mp3');
        await emptyFile.writeAsBytes([]);

        expect(() => AudioFileValidator.validate(emptyFile.path), throwsA(isA<DecodingException>().having((e) => e.message, 'message', contains('empty'))));
      });

      test('should throw DecodingException for file smaller than minimum size', () async {
        final tinyFile = File('${tempDir.path}/tiny.mp3');
        await tinyFile.writeAsBytes([1, 2, 3, 4, 5]); // 5 bytes, less than minFileSize (12)

        expect(
          () => AudioFileValidator.validate(tinyFile.path),
          throwsA(isA<DecodingException>().having((e) => e.message, 'message', contains('Invalid file'))),
        );
      });

      test('should pass for file exactly at minimum size', () async {
        final minFile = File('${tempDir.path}/min.mp3');
        await minFile.writeAsBytes(List.filled(AudioFileValidator.minFileSize, 0));

        // Should not throw
        await AudioFileValidator.validate(minFile.path);
      });

      test('should pass for file larger than minimum size', () async {
        final validFile = File('${tempDir.path}/valid.mp3');
        await validFile.writeAsBytes(List.filled(100, 0));

        // Should not throw
        await AudioFileValidator.validate(validFile.path);
      });
    });

    group('validateAndGetSize', () {
      test('should throw FileSystemException for non-existent file', () async {
        final nonExistentPath = '${tempDir.path}/does_not_exist.mp3';

        expect(() => AudioFileValidator.validateAndGetSize(nonExistentPath), throwsA(isA<FileSystemException>()));
      });

      test('should throw DecodingException for empty file', () async {
        final emptyFile = File('${tempDir.path}/empty.mp3');
        await emptyFile.writeAsBytes([]);

        expect(() => AudioFileValidator.validateAndGetSize(emptyFile.path), throwsA(isA<DecodingException>()));
      });

      test('should throw DecodingException for file smaller than minimum size', () async {
        final tinyFile = File('${tempDir.path}/tiny.mp3');
        await tinyFile.writeAsBytes([1, 2, 3]);

        expect(() => AudioFileValidator.validateAndGetSize(tinyFile.path), throwsA(isA<DecodingException>()));
      });

      test('should return correct size for valid file', () async {
        const expectedSize = 256;
        final validFile = File('${tempDir.path}/valid.mp3');
        await validFile.writeAsBytes(List.filled(expectedSize, 0));

        final size = await AudioFileValidator.validateAndGetSize(validFile.path);

        expect(size, equals(expectedSize));
      });

      test('should return exact minimum size for file at minimum', () async {
        final minFile = File('${tempDir.path}/min.mp3');
        await minFile.writeAsBytes(List.filled(AudioFileValidator.minFileSize, 0));

        final size = await AudioFileValidator.validateAndGetSize(minFile.path);

        expect(size, equals(AudioFileValidator.minFileSize));
      });
    });

    group('minFileSize constant', () {
      test('should be a reasonable minimum for audio headers', () {
        // Most audio formats have headers of at least 12 bytes
        // WAV: 44 bytes, MP3: varies but ID3 is 10+, etc.
        expect(AudioFileValidator.minFileSize, greaterThanOrEqualTo(8));
        expect(AudioFileValidator.minFileSize, lessThanOrEqualTo(64));
      });
    });

    group('error messages', () {
      test('empty file error should indicate file is empty', () async {
        final emptyFile = File('${tempDir.path}/empty.mp3');
        await emptyFile.writeAsBytes([]);

        try {
          await AudioFileValidator.validate(emptyFile.path);
          fail('Should have thrown');
        } on DecodingException catch (e) {
          expect(e.message.toLowerCase(), contains('empty'));
        }
      });

      test('too small file error should include file size', () async {
        final tinyFile = File('${tempDir.path}/tiny.mp3');
        await tinyFile.writeAsBytes([1, 2, 3, 4, 5]);

        try {
          await AudioFileValidator.validate(tinyFile.path);
          fail('Should have thrown');
        } on DecodingException catch (e) {
          expect(e.details, contains('5 bytes'));
        }
      });
    });
  });
}
