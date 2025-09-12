import 'dart:typed_data';
import '../models/file_chunk.dart';
import '../models/chunk_boundary.dart';
import 'format_chunk_parser.dart';

/// WAV-specific chunk parser that handles RIFF chunks and sample alignment
class WAVChunkParser extends FormatChunkParser {
  @override
  String get format => 'WAV';

  @override
  List<ChunkBoundary> parseChunkBoundaries(FileChunk fileChunk) {
    final boundaries = <ChunkBoundary>[];
    final data = fileChunk.data;

    // Look for RIFF header and WAV chunks
    for (int i = 0; i < data.length - 7; i++) {
      // Check for RIFF header "RIFF"
      if (data[i] == 0x52 && data[i + 1] == 0x49 && data[i + 2] == 0x46 && data[i + 3] == 0x46) {
        // Check if followed by "WAVE" format
        if (i + 11 < data.length && data[i + 8] == 0x57 && data[i + 9] == 0x41 && data[i + 10] == 0x56 && data[i + 11] == 0x45) {
          final fileSize = _readLittleEndian32(data, i + 4);
          boundaries.add(
            ChunkBoundary(
              position: fileChunk.startPosition + i,
              type: BoundaryType.chunkStart,
              isSeekable: false,
              metadata: {'type': 'RIFF_HEADER', 'format': 'WAVE', 'fileSize': fileSize},
            ),
          );
          i += 11; // Skip past RIFF header
          continue;
        }
      }

      // Check for WAV chunk headers (4-byte ID + 4-byte size)
      if (i + 7 < data.length) {
        final chunkId = String.fromCharCodes(data.sublist(i, i + 4));
        final chunkSize = _readLittleEndian32(data, i + 4);

        // Validate chunk ID (should be printable ASCII)
        if (_isValidChunkId(chunkId) && chunkSize > 0 && chunkSize < 0x7FFFFFFF) {
          final isDataChunk = chunkId == 'data';
          boundaries.add(
            ChunkBoundary(
              position: fileChunk.startPosition + i,
              type: BoundaryType.chunkStart,
              isSeekable: isDataChunk, // Data chunks are seekable
              metadata: {'chunkId': chunkId, 'chunkSize': chunkSize, 'isDataChunk': isDataChunk},
            ),
          );

          // Skip past this chunk header
          i += 7;
        }
      }
    }

    return boundaries;
  }

  @override
  Future<int> findNextSeekPoint(int fromPosition) async {
    // For WAV, any sample boundary is a seek point
    // This would typically involve calculating sample positions
    return fromPosition;
  }

  @override
  ChunkValidationResult validateChunk(FileChunk chunk) {
    final errors = <String>[];
    final warnings = <String>[];

    // Basic chunk validation
    final basicValidation = FileChunkUtils.validateChunk(chunk);
    errors.addAll(basicValidation.errors);
    warnings.addAll(basicValidation.warnings);

    // WAV-specific validation
    if (chunk.data.isEmpty) {
      errors.add('WAV chunk cannot be empty');
      return ChunkValidationResult(isValid: false, errors: errors, warnings: warnings);
    }

    // Check if chunk contains valid WAV content
    bool hasValidContent = false;
    final boundaries = parseChunkBoundaries(chunk);

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.chunkStart) {
        hasValidContent = true;
        break;
      }
    }

    if (!hasValidContent && !chunk.isLast) {
      warnings.add('WAV chunk contains no recognizable RIFF chunks');
    }

    // Check for proper WAV structure
    final riffHeaders = boundaries.where((b) => b.metadata?['type'] == 'RIFF_HEADER').toList();
    if (riffHeaders.length > 1) {
      warnings.add('Multiple RIFF headers found in chunk');
    }

    // Check for data chunks without format chunks
    final dataChunks = boundaries.where((b) => b.metadata?['chunkId'] == 'data').toList();
    final formatChunks = boundaries.where((b) => b.metadata?['chunkId'] == 'fmt ').toList();

    if (dataChunks.isNotEmpty && formatChunks.isEmpty && !chunk.isLast) {
      warnings.add('Data chunk found without corresponding format chunk');
    }

    return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings);
  }

  @override
  FormatMetadata? extractMetadata(FileChunk chunk) {
    final metadata = <String, dynamic>{};
    final boundaries = parseChunkBoundaries(chunk);

    int chunkCount = 0;
    int dataChunks = 0;
    int formatChunks = 0;
    bool hasRiffHeader = false;
    int totalDataSize = 0;

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.chunkStart) {
        chunkCount++;

        final chunkId = boundary.metadata?['chunkId'] as String?;
        final chunkSize = boundary.metadata?['chunkSize'] as int? ?? 0;

        if (boundary.metadata?['type'] == 'RIFF_HEADER') {
          hasRiffHeader = true;
          metadata['fileSize'] = boundary.metadata?['fileSize'];
        } else if (chunkId == 'data') {
          dataChunks++;
          totalDataSize += chunkSize;
        } else if (chunkId == 'fmt ') {
          formatChunks++;
        }

        // Store chunk information
        metadata['chunks'] ??= <Map<String, dynamic>>[];
        (metadata['chunks'] as List).add({'id': chunkId ?? 'unknown', 'size': chunkSize, 'position': boundary.position});
      }
    }

    metadata['chunkCount'] = chunkCount;
    metadata['dataChunks'] = dataChunks;
    metadata['formatChunks'] = formatChunks;
    metadata['hasRiffHeader'] = hasRiffHeader;
    metadata['totalDataSize'] = totalDataSize;
    metadata['chunkSize'] = chunk.size;

    return FormatMetadata(format: format, data: metadata);
  }

  @override
  int getRecommendedChunkSize(int fileSize) {
    // WAV files have simple structure, can use larger chunks
    if (fileSize < 10 * 1024 * 1024) {
      // < 10MB
      return 2 * 1024 * 1024; // 2MB
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      return 8 * 1024 * 1024; // 8MB
    } else {
      return 16 * 1024 * 1024; // 16MB
    }
  }

  @override
  int get minimumChunkSize => 128 * 1024; // 128KB - enough for WAV headers and some data

  @override
  int get maximumChunkSize => 50 * 1024 * 1024; // 50MB

  /// Read a 32-bit little-endian integer from the data
  int _readLittleEndian32(Uint8List data, int offset) {
    if (offset + 3 >= data.length) return 0;

    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);
  }

  /// Check if a chunk ID is valid (printable ASCII characters)
  bool _isValidChunkId(String chunkId) {
    if (chunkId.length != 4) return false;

    for (int i = 0; i < chunkId.length; i++) {
      final code = chunkId.codeUnitAt(i);
      // Allow printable ASCII characters and space
      if (code < 0x20 || code > 0x7E) {
        return false;
      }
    }

    return true;
  }

  /// Calculate sample position for seeking (requires format information)
  int calculateSamplePosition(int bytePosition, int bytesPerSample, int channels) {
    final bytesPerFrame = bytesPerSample * channels;
    return (bytePosition / bytesPerFrame).floor();
  }

  /// Calculate byte position from sample position
  int calculateBytePosition(int samplePosition, int bytesPerSample, int channels) {
    final bytesPerFrame = bytesPerSample * channels;
    return samplePosition * bytesPerFrame;
  }

  /// Align position to sample boundary
  int alignToSampleBoundary(int position, int bytesPerSample, int channels) {
    final bytesPerFrame = bytesPerSample * channels;
    return (position ~/ bytesPerFrame) * bytesPerFrame;
  }
}
