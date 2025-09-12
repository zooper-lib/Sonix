import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/utils/chunked_file_reader.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/models/file_chunk.dart';

void main() {
  group('ChunkedFileReader', () {
    late Directory tempDir;
    late String testFilePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('chunked_reader_test');
      testFilePath = '${tempDir.path}/test_audio.mp3';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> createTestFile(List<int> data) async {
      final file = File(testFilePath);
      await file.writeAsBytes(data);
    }

    test('should create ChunkedFileReader with valid parameters', () {
      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 1024, format: AudioFormat.mp3);

      expect(reader.filePath, equals(testFilePath));
      expect(reader.chunkSize, equals(1024));
      expect(reader.format, equals(AudioFormat.mp3));
      expect(reader.enableSeeking, equals(true));
      expect(reader.currentPosition, equals(0));
      expect(reader.isAtEnd, equals(false));
    });

    test('should throw on invalid chunk size', () {
      expect(() => ChunkedFileReader(filePath: testFilePath, chunkSize: 0, format: AudioFormat.mp3), throwsA(isA<ArgumentError>()));

      expect(() => ChunkedFileReader(filePath: testFilePath, chunkSize: -100, format: AudioFormat.mp3), throwsA(isA<ArgumentError>()));
    });

    test('should get file size', () async {
      final testData = List.generate(1000, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      final fileSize = await reader.getFileSize();
      expect(fileSize, equals(1000));

      await reader.close();
    });

    test('should throw on non-existent file', () async {
      final reader = ChunkedFileReader(filePath: '/non/existent/file.mp3', chunkSize: 100, format: AudioFormat.mp3);

      expect(() => reader.getFileSize(), throwsA(isA<SonixFileException>()));
    });

    test('should read chunks sequentially', () async {
      final testData = List.generate(250, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      // Read first chunk
      final chunk1 = await reader.readNextChunk();
      expect(chunk1, isNotNull);
      expect(chunk1!.data.length, equals(100));
      expect(chunk1.startPosition, equals(0));
      expect(chunk1.endPosition, equals(100));
      expect(chunk1.isLast, equals(false));
      expect(reader.currentPosition, equals(100));
      expect(reader.isAtEnd, equals(false));

      // Read second chunk
      final chunk2 = await reader.readNextChunk();
      expect(chunk2, isNotNull);
      expect(chunk2!.data.length, equals(100));
      expect(chunk2.startPosition, equals(100));
      expect(chunk2.endPosition, equals(200));
      expect(chunk2.isLast, equals(false));
      expect(reader.currentPosition, equals(200));

      // Read last chunk (partial)
      final chunk3 = await reader.readNextChunk();
      expect(chunk3, isNotNull);
      expect(chunk3!.data.length, equals(50));
      expect(chunk3.startPosition, equals(200));
      expect(chunk3.endPosition, equals(250));
      expect(chunk3.isLast, equals(true));
      expect(reader.currentPosition, equals(250));
      expect(reader.isAtEnd, equals(true));

      // Try to read beyond end
      final chunk4 = await reader.readNextChunk();
      expect(chunk4, isNull);

      await reader.close();
    });

    test('should read chunks as stream', () async {
      final testData = List.generate(150, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 50, format: AudioFormat.mp3);

      final chunks = <FileChunk>[];
      await for (final chunk in reader.readChunks()) {
        chunks.add(chunk);
      }

      expect(chunks.length, equals(3));
      expect(chunks[0].data.length, equals(50));
      expect(chunks[1].data.length, equals(50));
      expect(chunks[2].data.length, equals(50));
      expect(chunks[2].isLast, equals(true));

      // Verify data integrity
      final allData = <int>[];
      for (final chunk in chunks) {
        allData.addAll(chunk.data);
      }
      expect(allData, equals(testData));
    });

    test('should seek to position', () async {
      final testData = List.generate(1000, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      // Seek to middle of file
      await reader.seekToPosition(500);
      expect(reader.currentPosition, equals(500));
      expect(reader.isAtEnd, equals(false));

      // Read chunk from new position
      final chunk = await reader.readNextChunk();
      expect(chunk, isNotNull);
      expect(chunk!.startPosition, equals(500));
      expect(chunk.data[0], equals(testData[500]));

      // Seek beyond file size
      await reader.seekToPosition(2000);
      expect(reader.currentPosition, equals(1000)); // Clamped to file size
      expect(reader.isAtEnd, equals(true));

      await reader.close();
    });

    test('should seek to time position', () async {
      final testData = List.generate(1000, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      // Seek to approximate middle (this uses basic estimation)
      await reader.seekToTime(const Duration(seconds: 90)); // Half of assumed 180s

      // Position should be approximately in the middle
      expect(reader.currentPosition, greaterThan(400));
      expect(reader.currentPosition, lessThan(600));

      await reader.close();
    });

    test('should reset to beginning', () async {
      final testData = List.generate(500, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      // Read some chunks
      await reader.readNextChunk();
      await reader.readNextChunk();
      expect(reader.currentPosition, equals(200));

      // Reset
      await reader.reset();
      expect(reader.currentPosition, equals(0));
      expect(reader.isAtEnd, equals(false));

      // Should be able to read from beginning again
      final chunk = await reader.readNextChunk();
      expect(chunk, isNotNull);
      expect(chunk!.startPosition, equals(0));

      await reader.close();
    });

    test('should handle seeking disabled', () async {
      final testData = List.generate(100, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 50, format: AudioFormat.mp3, enableSeeking: false);

      expect(reader.enableSeeking, equals(false));

      expect(() => reader.seekToPosition(25), throwsA(isA<SonixUnsupportedOperationException>()));

      expect(() => reader.seekToTime(const Duration(seconds: 10)), throwsA(isA<SonixUnsupportedOperationException>()));

      await reader.close();
    });

    test('should get reader info', () async {
      final testData = List.generate(300, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      final info = await reader.getInfo();

      expect(info.filePath, equals(testFilePath));
      expect(info.fileSize, equals(300));
      expect(info.chunkSize, equals(100));
      expect(info.format, equals(AudioFormat.mp3));
      expect(info.currentPosition, equals(0));
      expect(info.isAtEnd, equals(false));
      expect(info.estimatedTotalChunks, equals(3));
      expect(info.enableSeeking, equals(true));
      expect(info.progress, equals(0.0));
      expect(info.chunksRead, equals(0));
      expect(info.estimatedRemainingChunks, equals(3));

      // Read a chunk and check updated info
      await reader.readNextChunk();
      final updatedInfo = await reader.getInfo();
      expect(updatedInfo.currentPosition, equals(100));
      expect(updatedInfo.progress, closeTo(0.33, 0.01));
      expect(updatedInfo.chunksRead, equals(1));
      expect(updatedInfo.estimatedRemainingChunks, equals(2));

      await reader.close();
    });

    test('should handle empty file', () async {
      await createTestFile([]);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      final fileSize = await reader.getFileSize();
      expect(fileSize, equals(0));

      final chunk = await reader.readNextChunk();
      expect(chunk, isNull);
      expect(reader.isAtEnd, equals(true));

      await reader.close();
    });

    test('should handle single byte file', () async {
      await createTestFile([42]);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 100, format: AudioFormat.mp3);

      final chunk = await reader.readNextChunk();
      expect(chunk, isNotNull);
      expect(chunk!.data.length, equals(1));
      expect(chunk.data[0], equals(42));
      expect(chunk.isLast, equals(true));

      await reader.close();
    });

    test('should close safely multiple times', () async {
      final testData = List.generate(100, (i) => i % 256);
      await createTestFile(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 50, format: AudioFormat.mp3);

      await reader.readNextChunk();

      // Close multiple times should not throw
      await reader.close();
      await reader.close();
      await reader.close();
    });
  });

  group('ChunkedFileReaderInfo', () {
    test('should calculate progress correctly', () {
      final info = ChunkedFileReaderInfo(
        filePath: '/test.mp3',
        fileSize: 1000,
        chunkSize: 100,
        format: AudioFormat.mp3,
        currentPosition: 300,
        isAtEnd: false,
        estimatedTotalChunks: 10,
        enableSeeking: true,
      );

      expect(info.progress, equals(0.3));
      expect(info.chunksRead, equals(3));
      expect(info.estimatedRemainingChunks, equals(7));
    });

    test('should handle zero file size', () {
      final info = ChunkedFileReaderInfo(
        filePath: '/test.mp3',
        fileSize: 0,
        chunkSize: 100,
        format: AudioFormat.mp3,
        currentPosition: 0,
        isAtEnd: true,
        estimatedTotalChunks: 0,
        enableSeeking: true,
      );

      expect(info.progress, equals(0.0));
      expect(info.chunksRead, equals(0));
      expect(info.estimatedRemainingChunks, equals(0));
    });
  });

  group('ChunkedFileReaderFactory', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reader_factory_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create reader for existing file', () async {
      final testFilePath = '${tempDir.path}/test.mp3';
      final testData = List.generate(1000, (i) => i % 256);
      await File(testFilePath).writeAsBytes(testData);

      final reader = await ChunkedFileReaderFactory.createForFile(testFilePath);

      expect(reader.filePath, equals(testFilePath));
      expect(reader.format, equals(AudioFormat.mp3));
      expect(reader.chunkSize, greaterThan(0));

      await reader.close();
    });

    test('should detect format from file extension', () async {
      final formats = {
        'test.mp3': AudioFormat.mp3,
        'test.wav': AudioFormat.wav,
        'test.flac': AudioFormat.flac,
        'test.ogg': AudioFormat.ogg,
        'test.opus': AudioFormat.opus,
        'test.unknown': AudioFormat.unknown,
      };

      for (final entry in formats.entries) {
        final testFilePath = '${tempDir.path}/${entry.key}';
        await File(testFilePath).writeAsBytes([1, 2, 3]);

        final reader = await ChunkedFileReaderFactory.createForFile(testFilePath);
        expect(reader.format, equals(entry.value));
        await reader.close();
      }
    });

    test('should calculate optimal chunk size based on file size', () async {
      // Small file (< 10MB)
      final smallFilePath = '${tempDir.path}/small.mp3';
      await File(smallFilePath).writeAsBytes(List.filled(5 * 1024 * 1024, 0));
      final smallReader = await ChunkedFileReaderFactory.createForFile(smallFilePath);
      expect(smallReader.chunkSize, lessThan(5 * 1024 * 1024));
      await smallReader.close();

      // Medium file (< 100MB) - simulate with smaller file for test
      final mediumFilePath = '${tempDir.path}/medium.mp3';
      await File(mediumFilePath).writeAsBytes(List.filled(50 * 1024 * 1024, 0));
      final mediumReader = await ChunkedFileReaderFactory.createForFile(mediumFilePath);
      expect(mediumReader.chunkSize, greaterThan(1 * 1024 * 1024));
      await mediumReader.close();
    });

    test('should use custom chunk size when provided', () async {
      final testFilePath = '${tempDir.path}/test.mp3';
      await File(testFilePath).writeAsBytes([1, 2, 3]);

      final reader = await ChunkedFileReaderFactory.createForFile(testFilePath, chunkSize: 2048);

      expect(reader.chunkSize, equals(2048));
      await reader.close();
    });

    test('should use custom format when provided', () async {
      final testFilePath = '${tempDir.path}/test.mp3';
      await File(testFilePath).writeAsBytes([1, 2, 3]);

      final reader = await ChunkedFileReaderFactory.createForFile(testFilePath, format: AudioFormat.wav);

      expect(reader.format, equals(AudioFormat.wav));
      await reader.close();
    });

    test('should throw on non-existent file', () async {
      expect(() => ChunkedFileReaderFactory.createForFile('/non/existent/file.mp3'), throwsA(isA<SonixFileException>()));
    });
  });
}
