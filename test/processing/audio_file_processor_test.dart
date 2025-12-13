import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/audio_file_processor.dart';
import 'package:sonix/src/decoders/audio_file_decoder.dart';

void main() {
  group('AudioFileProcessor', () {
    late AudioFileProcessor processor;

    setUp(() {
      processor = AudioFileProcessor();
    });

    test('should create processor with default thresholds', () {
      expect(processor.chunkThreshold, equals(50 * 1024 * 1024)); // 50MB
    });

    test('should create processor with custom thresholds', () {
      final customProcessor = AudioFileProcessor(chunkThreshold: 100 * 1024 * 1024);

      expect(customProcessor.chunkThreshold, equals(100 * 1024 * 1024));
    });

    test('should throw FileSystemException for non-existent file', () async {
      expect(() async => await processor.process('/non/existent/file.mp3'), throwsA(isA<FileSystemException>()));
    });

    test('should throw UnsupportedError for unknown format', () async {
      // Create a temp file with unknown extension
      final tempDir = await Directory.systemTemp.createTemp('audio_processor_test');
      final testFile = File('${tempDir.path}/test.unknown');
      await testFile.writeAsBytes([0x00, 0x01, 0x02]); // Write some bytes

      try {
        await expectLater(processor.process(testFile.path), throwsA(isA<UnsupportedError>()));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Note: Testing actual audio decoding requires real audio files and is covered
    // by integration tests. These unit tests focus on the processor's logic.
  });

  group('AudioFileProcessor streaming', () {
    late AudioFileProcessor processor;

    setUp(() {
      processor = AudioFileProcessor();
    });

    test('should throw FileSystemException for non-existent file in streaming', () async {
      expect(() async => await processor.processStreaming('/non/existent/file.mp3').toList(), throwsA(isA<FileSystemException>()));
    });

    test('should throw UnsupportedError for unknown format in streaming', () async {
      final tempDir = await Directory.systemTemp.createTemp('audio_processor_test');
      final testFile = File('${tempDir.path}/test.unknown');
      await testFile.writeAsBytes([0x00, 0x01, 0x02]); // Write some bytes

      try {
        await expectLater(processor.processStreaming(testFile.path).toList(), throwsA(isA<UnsupportedError>()));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('StreamingAudioFileDecoder', () {
    late StreamingAudioFileDecoder decoder;

    setUp(() {
      decoder = StreamingAudioFileDecoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    test('should throw FileSystemException for non-existent file', () async {
      expect(() async => await decoder.decode('/non/existent/file.mp3'), throwsA(isA<FileSystemException>()));
    });
  });
}
