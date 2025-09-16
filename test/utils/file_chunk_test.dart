import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/file_chunk.dart';

void main() {
  group('FileChunk', () {
    test('should create FileChunk with required properties', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final chunk = FileChunk(data: data, startPosition: 0, endPosition: 5, isLast: false);

      expect(chunk.data, equals(data));
      expect(chunk.startPosition, equals(0));
      expect(chunk.endPosition, equals(5));
      expect(chunk.isLast, equals(false));
      expect(chunk.isSeekPoint, equals(false));
      expect(chunk.size, equals(5));
    });

    test('should create FileChunk with optional properties', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final metadata = {'format': 'mp3', 'bitrate': 320};
      final chunk = FileChunk(data: data, startPosition: 100, endPosition: 103, isLast: true, isSeekPoint: true, metadata: metadata);

      expect(chunk.isSeekPoint, equals(true));
      expect(chunk.metadata, equals(metadata));
    });

    test('should calculate size correctly', () {
      final data = Uint8List(1000);
      final chunk = FileChunk(data: data, startPosition: 0, endPosition: 1000, isLast: false);

      expect(chunk.size, equals(1000));
    });

    test('should create copy with modified properties', () {
      final originalData = Uint8List.fromList([1, 2, 3]);
      final newData = Uint8List.fromList([4, 5, 6]);
      final original = FileChunk(data: originalData, startPosition: 0, endPosition: 3, isLast: false);

      final copy = original.copyWith(data: newData, isLast: true, isSeekPoint: true);

      expect(copy.data, equals(newData));
      expect(copy.startPosition, equals(0)); // unchanged
      expect(copy.endPosition, equals(3)); // unchanged
      expect(copy.isLast, equals(true)); // changed
      expect(copy.isSeekPoint, equals(true)); // changed
    });

    test('should implement equality correctly', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([4, 5, 6]);

      final chunk1 = FileChunk(data: data1, startPosition: 0, endPosition: 3, isLast: false);

      final chunk2 = FileChunk(
        data: data2, // Different data
        startPosition: 0,
        endPosition: 3,
        isLast: false,
      );

      final chunk3 = FileChunk(data: data1, startPosition: 0, endPosition: 3, isLast: false);

      expect(chunk1, equals(chunk3)); // Same properties
      expect(chunk1, equals(chunk2)); // Equality doesn't check data content
    });

    test('should have consistent hashCode', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final chunk1 = FileChunk(data: data, startPosition: 0, endPosition: 3, isLast: false);

      final chunk2 = FileChunk(data: data, startPosition: 0, endPosition: 3, isLast: false);

      expect(chunk1.hashCode, equals(chunk2.hashCode));
    });
  });
}

