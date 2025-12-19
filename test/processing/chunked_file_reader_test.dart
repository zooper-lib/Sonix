import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/chunked_file_reader.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ChunkedFileReader', () {
    late Directory tempDir;

    setUp(() async {
      // Create temp directory for test files
      tempDir = await Directory.systemTemp.createTemp('chunked_file_reader_test');
    });

    tearDown(() async {
      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<String> createTestFile(int sizeInBytes) async {
      final filePath = path.join(tempDir.path, 'test_file.dat');
      final file = File(filePath);
      final data = Uint8List(sizeInBytes);
      // Fill with sequential bytes for verification
      for (var i = 0; i < sizeInBytes; i++) {
        data[i] = i % 256;
      }
      await file.writeAsBytes(data);
      return filePath;
    }

    test('should create ChunkedFileReader with default chunk size', () {
      final reader = ChunkedFileReader('test.dat');
      expect(reader.filePath, equals('test.dat'));
      expect(reader.chunkSize, equals(10 * 1024 * 1024)); // 10MB default
    });

    test('should create ChunkedFileReader with custom chunk size', () {
      final reader = ChunkedFileReader('test.dat', chunkSize: 5 * 1024 * 1024);
      expect(reader.chunkSize, equals(5 * 1024 * 1024));
    });

    test('should throw FileSystemException for non-existent file', () async {
      final reader = ChunkedFileReader('/non/existent/file.dat');
      expect(
        () async => await reader.readChunks().toList(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('should read small file in single chunk', () async {
      final filePath = await createTestFile(1024); // 1KB file
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final chunks = await reader.readChunks().toList();

      expect(chunks.length, equals(1));
      expect(chunks[0].data.length, equals(1024));
      expect(chunks[0].index, equals(0));
      expect(chunks[0].offset, equals(0));
      expect(chunks[0].isLast, isTrue);
      expect(chunks[0].totalChunks, equals(1));
      expect(chunks[0].fileSize, equals(1024));
    });

    test('should read file in multiple chunks', () async {
      final filePath = await createTestFile(25 * 1024); // 25KB file
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024); // 10KB chunks

      final chunks = await reader.readChunks().toList();

      expect(chunks.length, equals(3)); // 10KB + 10KB + 5KB

      // First chunk
      expect(chunks[0].data.length, equals(10 * 1024));
      expect(chunks[0].index, equals(0));
      expect(chunks[0].offset, equals(0));
      expect(chunks[0].isLast, isFalse);

      // Second chunk
      expect(chunks[1].data.length, equals(10 * 1024));
      expect(chunks[1].index, equals(1));
      expect(chunks[1].offset, equals(10 * 1024));
      expect(chunks[1].isLast, isFalse);

      // Third chunk
      expect(chunks[2].data.length, equals(5 * 1024));
      expect(chunks[2].index, equals(2));
      expect(chunks[2].offset, equals(20 * 1024));
      expect(chunks[2].isLast, isTrue);
    });

    test('should preserve data integrity across chunks', () async {
      final filePath = await createTestFile(256); // Small file with sequential bytes
      final reader = ChunkedFileReader(filePath, chunkSize: 100);

      final chunks = await reader.readChunks().toList();
      final reconstructed = <int>[];
      for (final chunk in chunks) {
        reconstructed.addAll(chunk.data);
      }

      // Verify reconstructed data matches original
      expect(reconstructed.length, equals(256));
      for (var i = 0; i < 256; i++) {
        expect(reconstructed[i], equals(i % 256));
      }
    });

    test('should calculate progress correctly', () async {
      final filePath = await createTestFile(30 * 1024);
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final chunks = await reader.readChunks().toList();

      expect(chunks[0].progress, closeTo(0.33, 0.01));
      expect(chunks[1].progress, closeTo(0.67, 0.01));
      expect(chunks[2].progress, equals(1.0));
    });

    test('should format progress string correctly', () async {
      final filePath = await createTestFile(30 * 1024);
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final chunks = await reader.readChunks().toList();

      expect(chunks[0].progressString, equals('33.3%'));
      expect(chunks[1].progressString, equals('66.7%'));
      expect(chunks[2].progressString, equals('100.0%'));
    });

    test('should get correct chunk count', () async {
      final filePath = await createTestFile(25 * 1024);
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final count = await reader.getChunkCount();
      expect(count, equals(3));
    });

    test('should handle empty file', () async {
      final filePath = await createTestFile(0);
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final chunks = await reader.readChunks().toList();
      expect(chunks.length, equals(0));
    });

    test('should handle file size exactly equal to chunk size', () async {
      final filePath = await createTestFile(10 * 1024);
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final chunks = await reader.readChunks().toList();

      expect(chunks.length, equals(1));
      expect(chunks[0].data.length, equals(10 * 1024));
      expect(chunks[0].isLast, isTrue);
    });

    test('should handle file size exactly double chunk size', () async {
      final filePath = await createTestFile(20 * 1024);
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final chunks = await reader.readChunks().toList();

      expect(chunks.length, equals(2));
      expect(chunks[0].data.length, equals(10 * 1024));
      expect(chunks[0].isLast, isFalse);
      expect(chunks[1].data.length, equals(10 * 1024));
      expect(chunks[1].isLast, isTrue);
    });

    test('readAllChunks should return same result as toList on readChunks', () async {
      final filePath = await createTestFile(15 * 1024);
      final reader = ChunkedFileReader(filePath, chunkSize: 10 * 1024);

      final streamChunks = await reader.readChunks().toList();
      final allChunks = await reader.readAllChunks();

      expect(allChunks.length, equals(streamChunks.length));
      for (var i = 0; i < allChunks.length; i++) {
        expect(allChunks[i].index, equals(streamChunks[i].index));
        expect(allChunks[i].data.length, equals(streamChunks[i].data.length));
        expect(allChunks[i].offset, equals(streamChunks[i].offset));
      }
    });
  });

  group('FileChunk', () {
    test('should create FileChunk with all properties', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final chunk = FileChunk(
        data: data,
        index: 0,
        offset: 0,
        isLast: false,
        totalChunks: 3,
        fileSize: 15,
      );

      expect(chunk.data, equals(data));
      expect(chunk.index, equals(0));
      expect(chunk.offset, equals(0));
      expect(chunk.isLast, isFalse);
      expect(chunk.totalChunks, equals(3));
      expect(chunk.fileSize, equals(15));
    });

    test('should calculate progress correctly', () {
      final chunk1 = FileChunk(
        data: Uint8List(5),
        index: 0,
        offset: 0,
        isLast: false,
        totalChunks: 4,
        fileSize: 20,
      );
      final chunk2 = FileChunk(
        data: Uint8List(5),
        index: 1,
        offset: 5,
        isLast: false,
        totalChunks: 4,
        fileSize: 20,
      );
      final chunk3 = FileChunk(
        data: Uint8List(5),
        index: 3,
        offset: 15,
        isLast: true,
        totalChunks: 4,
        fileSize: 20,
      );

      expect(chunk1.progress, equals(0.25));
      expect(chunk2.progress, equals(0.5));
      expect(chunk3.progress, equals(1.0));
    });

    test('should format toString correctly', () {
      final chunk = FileChunk(
        data: Uint8List(5),
        index: 1,
        offset: 10,
        isLast: false,
        totalChunks: 3,
        fileSize: 15,
      );

      final str = chunk.toString();
      expect(str, contains('index: 1/3'));
      expect(str, contains('offset: 10'));
      expect(str, contains('size: 5 bytes'));
      expect(str, contains('progress: 66.7%'));
      expect(str, contains('isLast: false'));
    });
  });
}
