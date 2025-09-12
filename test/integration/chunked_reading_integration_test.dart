import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/utils/chunked_file_reader.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/models/file_chunk.dart';

void main() {
  group('Chunked Reading Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('chunked_integration_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should read large file in chunks efficiently', () async {
      // Create a large test file (1MB)
      final testFilePath = '${tempDir.path}/large_test.mp3';
      final largeData = List.generate(1024 * 1024, (i) => i % 256);
      await File(testFilePath).writeAsBytes(largeData);

      // Create reader with small chunks
      final reader = await ChunkedFileReaderFactory.createForFile(
        testFilePath,
        chunkSize: 64 * 1024, // 64KB chunks
      );

      expect(reader.format, equals(AudioFormat.mp3));
      expect(reader.chunkSize, equals(64 * 1024));

      // Read all chunks and verify data integrity
      final allReadData = <int>[];
      int chunkCount = 0;

      await for (final chunk in reader.readChunks()) {
        chunkCount++;
        allReadData.addAll(chunk.data);

        // Verify chunk properties
        expect(chunk.size, lessThanOrEqualTo(64 * 1024));
        expect(chunk.startPosition, equals(allReadData.length - chunk.size));

        if (chunk.isLast) {
          expect(chunkCount, greaterThan(1)); // Should have multiple chunks
        }
      }

      // Verify complete data integrity
      expect(allReadData, equals(largeData));
      expect(chunkCount, equals(16)); // 1MB / 64KB = 16 chunks
    });

    test('should handle seeking in chunked reading', () async {
      // Create test file with known pattern
      final testFilePath = '${tempDir.path}/seek_test.wav';
      final testData = List.generate(10000, (i) => i % 256);
      await File(testFilePath).writeAsBytes(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 1000, format: AudioFormat.wav);

      // Read first chunk
      final firstChunk = await reader.readNextChunk();
      expect(firstChunk, isNotNull);
      expect(firstChunk!.startPosition, equals(0));
      expect(firstChunk.size, equals(1000));

      // Seek to middle
      await reader.seekToPosition(5000);
      expect(reader.currentPosition, equals(5000));

      // Read chunk from new position
      final middleChunk = await reader.readNextChunk();
      expect(middleChunk, isNotNull);
      expect(middleChunk!.startPosition, equals(5000));
      expect(middleChunk.data[0], equals(testData[5000]));

      // Seek to near end
      await reader.seekToPosition(9500);
      final nearEndChunk = await reader.readNextChunk();
      expect(nearEndChunk, isNotNull);
      expect(nearEndChunk!.startPosition, equals(9500));
      expect(nearEndChunk.size, equals(500)); // Partial last chunk
      expect(nearEndChunk.isLast, equals(true));

      await reader.close();
    });

    test('should optimize chunk size based on file size', () async {
      // Test small file
      final smallFilePath = '${tempDir.path}/small.flac';
      await File(smallFilePath).writeAsBytes(List.filled(1024, 0)); // 1KB

      final smallReader = await ChunkedFileReaderFactory.createForFile(smallFilePath);
      expect(smallReader.chunkSize, lessThan(5 * 1024 * 1024)); // Should use smaller chunks

      // Test medium file
      final mediumFilePath = '${tempDir.path}/medium.ogg';
      await File(mediumFilePath).writeAsBytes(List.filled(50 * 1024 * 1024, 0)); // 50MB

      final mediumReader = await ChunkedFileReaderFactory.createForFile(mediumFilePath);
      expect(mediumReader.chunkSize, greaterThan(1 * 1024 * 1024)); // Should use larger chunks

      await smallReader.close();
      await mediumReader.close();
    });

    test('should provide accurate progress information', () async {
      final testFilePath = '${tempDir.path}/progress_test.opus';
      final testData = List.generate(5000, (i) => i % 256);
      await File(testFilePath).writeAsBytes(testData);

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 1000, format: AudioFormat.opus);

      // Initial state
      var info = await reader.getInfo();
      expect(info.progress, equals(0.0));
      expect(info.chunksRead, equals(0));
      expect(info.estimatedTotalChunks, equals(5));

      // After reading first chunk
      await reader.readNextChunk();
      info = await reader.getInfo();
      expect(info.progress, closeTo(0.2, 0.01)); // 1/5 = 0.2
      expect(info.chunksRead, equals(1));
      expect(info.estimatedRemainingChunks, equals(4));

      // After reading all chunks
      while (!reader.isAtEnd) {
        await reader.readNextChunk();
      }

      info = await reader.getInfo();
      expect(info.progress, equals(1.0));
      expect(info.chunksRead, equals(5));
      expect(info.estimatedRemainingChunks, equals(0));

      await reader.close();
    });

    test('should handle chunk validation and utilities', () async {
      final testFilePath = '${tempDir.path}/validation_test.mp3';
      await File(testFilePath).writeAsBytes(List.generate(100, (i) => i));

      final reader = ChunkedFileReader(filePath: testFilePath, chunkSize: 30, format: AudioFormat.mp3);

      final chunk = await reader.readNextChunk();
      expect(chunk, isNotNull);

      // Test validation
      final validationResult = FileChunkUtils.validateChunk(chunk!);
      expect(validationResult.isValid, equals(true));
      expect(validationResult.errors, isEmpty);

      // Test splitting
      final splitChunks = FileChunkUtils.splitChunk(chunk, 10);
      expect(splitChunks.length, equals(3)); // 30 bytes / 10 = 3 chunks
      expect(splitChunks[0].size, equals(10));
      expect(splitChunks[1].size, equals(10));
      expect(splitChunks[2].size, equals(10));

      // Test combining
      final combinedChunk = FileChunkUtils.combineChunks(splitChunks);
      expect(combinedChunk.size, equals(chunk.size));
      expect(combinedChunk.data, equals(chunk.data));

      // Test sub-chunk extraction
      final subChunk = FileChunkUtils.extractSubChunk(chunk, 5, 10);
      expect(subChunk.size, equals(10));
      expect(subChunk.startPosition, equals(chunk.startPosition + 5));

      await reader.close();
    });
  });
}
