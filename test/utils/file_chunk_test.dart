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

  group('ChunkValidationResult', () {
    test('should create valid result', () {
      final result = ChunkValidationResult.valid();

      expect(result.isValid, equals(true));
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.hasErrors, equals(false));
      expect(result.hasWarnings, equals(false));
    });

    test('should create invalid result with errors', () {
      final errors = ['Error 1', 'Error 2'];
      final warnings = ['Warning 1'];
      final result = ChunkValidationResult.invalid(errors, warnings);

      expect(result.isValid, equals(false));
      expect(result.errors, equals(errors));
      expect(result.warnings, equals(warnings));
      expect(result.hasErrors, equals(true));
      expect(result.hasWarnings, equals(true));
    });

    test('should create invalid result with only errors', () {
      final errors = ['Error 1'];
      final result = ChunkValidationResult.invalid(errors);

      expect(result.isValid, equals(false));
      expect(result.errors, equals(errors));
      expect(result.warnings, isEmpty);
      expect(result.hasErrors, equals(true));
      expect(result.hasWarnings, equals(false));
    });
  });

  group('FileChunkUtils', () {
    group('validateChunk', () {
      test('should validate correct chunk', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final chunk = FileChunk(data: data, startPosition: 0, endPosition: 5, isLast: false);

        final result = FileChunkUtils.validateChunk(chunk);

        expect(result.isValid, equals(true));
        expect(result.errors, isEmpty);
        expect(result.warnings, isEmpty);
      });

      test('should detect negative start position', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final chunk = FileChunk(data: data, startPosition: -1, endPosition: 2, isLast: false);

        final result = FileChunkUtils.validateChunk(chunk);

        expect(result.isValid, equals(false));
        expect(result.errors, contains('Start position cannot be negative'));
      });

      test('should detect end position before start position', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final chunk = FileChunk(data: data, startPosition: 10, endPosition: 5, isLast: false);

        final result = FileChunkUtils.validateChunk(chunk);

        expect(result.isValid, equals(false));
        expect(result.errors, contains('End position cannot be before start position'));
      });

      test('should detect size mismatch', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final chunk = FileChunk(
          data: data,
          startPosition: 0,
          endPosition: 10, // Doesn't match data size
          isLast: false,
        );

        final result = FileChunkUtils.validateChunk(chunk);

        expect(result.isValid, equals(false));
        expect(result.errors, contains('Data size does not match position range'));
      });

      test('should warn about empty non-last chunk', () {
        final data = Uint8List(0);
        final chunk = FileChunk(data: data, startPosition: 0, endPosition: 0, isLast: false);

        final result = FileChunkUtils.validateChunk(chunk);

        expect(result.isValid, equals(true));
        expect(result.warnings, contains('Empty chunk data (not last chunk)'));
      });
    });

    group('splitChunk', () {
      test('should not split chunk smaller than max size', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final chunk = FileChunk(data: data, startPosition: 0, endPosition: 5, isLast: true);

        final result = FileChunkUtils.splitChunk(chunk, 10);

        expect(result.length, equals(1));
        expect(result.first, equals(chunk));
      });

      test('should split large chunk into smaller chunks', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        final chunk = FileChunk(data: data, startPosition: 100, endPosition: 110, isLast: true, isSeekPoint: true);

        final result = FileChunkUtils.splitChunk(chunk, 3);

        expect(result.length, equals(4)); // 3 + 3 + 3 + 1

        // Check first chunk
        expect(result[0].data, equals(Uint8List.fromList([1, 2, 3])));
        expect(result[0].startPosition, equals(100));
        expect(result[0].endPosition, equals(103));
        expect(result[0].isLast, equals(false));
        expect(result[0].isSeekPoint, equals(true)); // Only first chunk keeps seek point

        // Check middle chunk
        expect(result[1].data, equals(Uint8List.fromList([4, 5, 6])));
        expect(result[1].startPosition, equals(103));
        expect(result[1].endPosition, equals(106));
        expect(result[1].isLast, equals(false));
        expect(result[1].isSeekPoint, equals(false));

        // Check last chunk
        expect(result[3].data, equals(Uint8List.fromList([10])));
        expect(result[3].startPosition, equals(109));
        expect(result[3].endPosition, equals(110));
        expect(result[3].isLast, equals(true)); // Only last sub-chunk keeps isLast
        expect(result[3].isSeekPoint, equals(false));
      });
    });

    group('combineChunks', () {
      test('should throw on empty chunk list', () {
        expect(() => FileChunkUtils.combineChunks([]), throwsA(isA<ArgumentError>()));
      });

      test('should return single chunk unchanged', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final chunk = FileChunk(data: data, startPosition: 0, endPosition: 3, isLast: true);

        final result = FileChunkUtils.combineChunks([chunk]);

        expect(result, equals(chunk));
      });

      test('should combine contiguous chunks', () {
        final chunk1 = FileChunk(data: Uint8List.fromList([1, 2, 3]), startPosition: 0, endPosition: 3, isLast: false, isSeekPoint: true);

        final chunk2 = FileChunk(data: Uint8List.fromList([4, 5]), startPosition: 3, endPosition: 5, isLast: true);

        final result = FileChunkUtils.combineChunks([chunk1, chunk2]);

        expect(result.data, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
        expect(result.startPosition, equals(0));
        expect(result.endPosition, equals(5));
        expect(result.isLast, equals(true)); // Takes from last chunk
        expect(result.isSeekPoint, equals(true)); // Takes from first chunk
      });

      test('should sort chunks by position before combining', () {
        final chunk1 = FileChunk(data: Uint8List.fromList([4, 5]), startPosition: 3, endPosition: 5, isLast: true);

        final chunk2 = FileChunk(data: Uint8List.fromList([1, 2, 3]), startPosition: 0, endPosition: 3, isLast: false, isSeekPoint: true);

        final result = FileChunkUtils.combineChunks([chunk1, chunk2]);

        expect(result.data, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
        expect(result.startPosition, equals(0));
        expect(result.endPosition, equals(5));
      });

      test('should throw on non-contiguous chunks', () {
        final chunk1 = FileChunk(data: Uint8List.fromList([1, 2, 3]), startPosition: 0, endPosition: 3, isLast: false);

        final chunk2 = FileChunk(
          data: Uint8List.fromList([4, 5]),
          startPosition: 5, // Gap between chunks
          endPosition: 7,
          isLast: true,
        );

        expect(() => FileChunkUtils.combineChunks([chunk1, chunk2]), throwsA(isA<ArgumentError>()));
      });
    });

    group('extractSubChunk', () {
      test('should extract sub-chunk from beginning', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final chunk = FileChunk(data: data, startPosition: 100, endPosition: 105, isLast: true, isSeekPoint: true);

        final result = FileChunkUtils.extractSubChunk(chunk, 0, 3);

        expect(result.data, equals(Uint8List.fromList([1, 2, 3])));
        expect(result.startPosition, equals(100));
        expect(result.endPosition, equals(103));
        expect(result.isLast, equals(false)); // Sub-chunks are never last
        expect(result.isSeekPoint, equals(true)); // Keeps seek point if at start
      });

      test('should extract sub-chunk from middle', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final chunk = FileChunk(data: data, startPosition: 100, endPosition: 105, isLast: true, isSeekPoint: true);

        final result = FileChunkUtils.extractSubChunk(chunk, 2, 2);

        expect(result.data, equals(Uint8List.fromList([3, 4])));
        expect(result.startPosition, equals(102));
        expect(result.endPosition, equals(104));
        expect(result.isLast, equals(false));
        expect(result.isSeekPoint, equals(false)); // Loses seek point if not at start
      });

      test('should throw on invalid start offset', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final chunk = FileChunk(data: data, startPosition: 0, endPosition: 3, isLast: false);

        expect(() => FileChunkUtils.extractSubChunk(chunk, -1, 2), throwsA(isA<ArgumentError>()));

        expect(() => FileChunkUtils.extractSubChunk(chunk, 5, 2), throwsA(isA<ArgumentError>()));
      });

      test('should throw on invalid length', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final chunk = FileChunk(data: data, startPosition: 0, endPosition: 3, isLast: false);

        expect(() => FileChunkUtils.extractSubChunk(chunk, 0, 0), throwsA(isA<ArgumentError>()));

        expect(() => FileChunkUtils.extractSubChunk(chunk, 1, 5), throwsA(isA<ArgumentError>()));
      });
    });
  });
}
