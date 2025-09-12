import 'dart:typed_data';
import '../models/file_chunk.dart';
import '../models/chunk_boundary.dart';
import 'format_chunk_parser.dart';

/// OGG-specific chunk parser that handles page boundaries and stream identification
class OGGChunkParser extends FormatChunkParser {
  @override
  String get format => 'OGG';

  @override
  List<ChunkBoundary> parseChunkBoundaries(FileChunk fileChunk) {
    final boundaries = <ChunkBoundary>[];
    final data = fileChunk.data;

    // Look for OGG page headers
    for (int i = 0; i < data.length - 26; i++) {
      // OGG page header is at least 27 bytes
      // Check for OGG page sync pattern "OggS"
      if (data[i] == 0x4F && data[i + 1] == 0x67 && data[i + 2] == 0x67 && data[i + 3] == 0x53) {
        // Parse OGG page header
        final pageHeader = _parseOggPageHeader(data, i);
        if (pageHeader != null) {
          boundaries.add(ChunkBoundary(position: fileChunk.startPosition + i, type: BoundaryType.pageStart, isSeekable: true, metadata: pageHeader));

          // Skip past this page header and its segments
          final headerSize = 27 + (pageHeader['segmentCount'] as int);
          i += headerSize - 1; // -1 because loop will increment
        }
      }
    }

    return boundaries;
  }

  @override
  Future<int> findNextSeekPoint(int fromPosition) async {
    // For OGG, seek points are at page boundaries
    // This would involve reading the file to find the next page header
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

    // OGG-specific validation
    if (chunk.data.isEmpty) {
      errors.add('OGG chunk cannot be empty');
      return ChunkValidationResult(isValid: false, errors: errors, warnings: warnings);
    }

    // Check if chunk contains valid OGG content
    bool hasValidContent = false;
    final boundaries = parseChunkBoundaries(chunk);

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.pageStart) {
        hasValidContent = true;
        break;
      }
    }

    if (!hasValidContent && !chunk.isLast) {
      warnings.add('OGG chunk contains no recognizable page headers');
    }

    // Check for proper OGG page structure
    final pages = boundaries.where((b) => b.type == BoundaryType.pageStart).toList();

    // Check for sequence number continuity (if we have multiple pages)
    if (pages.length > 1) {
      for (int i = 1; i < pages.length; i++) {
        final prevSeq = pages[i - 1].metadata?['sequenceNumber'] as int?;
        final currSeq = pages[i].metadata?['sequenceNumber'] as int?;

        if (prevSeq != null && currSeq != null) {
          final prevStream = pages[i - 1].metadata?['streamSerial'] as int?;
          final currStream = pages[i].metadata?['streamSerial'] as int?;

          // Check sequence continuity for same stream
          if (prevStream == currStream && currSeq != prevSeq + 1) {
            warnings.add('OGG page sequence numbers are not continuous');
          }
        }
      }
    }

    return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings);
  }

  @override
  FormatMetadata? extractMetadata(FileChunk chunk) {
    final metadata = <String, dynamic>{};
    final boundaries = parseChunkBoundaries(chunk);

    int pageCount = 0;
    final streamSerials = <int>{};
    int totalGranulePosition = 0;
    bool hasFirstPage = false;
    bool hasLastPage = false;
    final codecTypes = <String>{};

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.pageStart) {
        pageCount++;

        final streamSerial = boundary.metadata?['streamSerial'] as int?;
        final granulePosition = boundary.metadata?['granulePosition'] as int?;
        final headerType = boundary.metadata?['headerType'] as int?;
        final codecType = boundary.metadata?['codecType'] as String?;

        if (streamSerial != null) {
          streamSerials.add(streamSerial);
        }

        if (granulePosition != null && granulePosition > 0) {
          totalGranulePosition += granulePosition;
        }

        if (headerType != null) {
          if ((headerType & 0x02) != 0) hasFirstPage = true;
          if ((headerType & 0x04) != 0) hasLastPage = true;
        }

        if (codecType != null) {
          codecTypes.add(codecType);
        }
      }
    }

    metadata['pageCount'] = pageCount;
    metadata['streamCount'] = streamSerials.length;
    metadata['streamSerials'] = streamSerials.toList();
    metadata['totalGranulePosition'] = totalGranulePosition;
    metadata['hasFirstPage'] = hasFirstPage;
    metadata['hasLastPage'] = hasLastPage;
    metadata['codecTypes'] = codecTypes.toList();
    metadata['chunkSize'] = chunk.size;

    return FormatMetadata(format: format, data: metadata);
  }

  @override
  int getRecommendedChunkSize(int fileSize) {
    // OGG pages are typically small (few KB), but can vary
    // Use moderate chunk sizes for good balance
    if (fileSize < 10 * 1024 * 1024) {
      // < 10MB
      return 1 * 1024 * 1024; // 1MB
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      return 4 * 1024 * 1024; // 4MB
    } else {
      return 10 * 1024 * 1024; // 10MB
    }
  }

  @override
  int get minimumChunkSize => 64 * 1024; // 64KB - enough for multiple OGG pages

  @override
  int get maximumChunkSize => 30 * 1024 * 1024; // 30MB

  /// Parse OGG page header and extract metadata
  Map<String, dynamic>? _parseOggPageHeader(Uint8List data, int position) {
    if (position + 26 >= data.length) return null;

    // Verify OGG sync pattern
    if (data[position] != 0x4F || data[position + 1] != 0x67 || data[position + 2] != 0x67 || data[position + 3] != 0x53) {
      return null;
    }

    final metadata = <String, dynamic>{};

    // Version (should be 0)
    final version = data[position + 4];
    if (version != 0) return null; // Invalid version
    metadata['version'] = version;

    // Header type flags
    final headerType = data[position + 5];
    metadata['headerType'] = headerType;
    metadata['isContinuation'] = (headerType & 0x01) != 0;
    metadata['isFirstPage'] = (headerType & 0x02) != 0;
    metadata['isLastPage'] = (headerType & 0x04) != 0;

    // Granule position (8 bytes, little-endian)
    final granulePosition = _readLittleEndian64(data, position + 6);
    metadata['granulePosition'] = granulePosition;

    // Stream serial number (4 bytes, little-endian)
    final streamSerial = _readLittleEndian32(data, position + 14);
    metadata['streamSerial'] = streamSerial;

    // Page sequence number (4 bytes, little-endian)
    final sequenceNumber = _readLittleEndian32(data, position + 18);
    metadata['sequenceNumber'] = sequenceNumber;

    // CRC checksum (4 bytes, little-endian)
    final crcChecksum = _readLittleEndian32(data, position + 22);
    metadata['crcChecksum'] = crcChecksum;

    // Number of page segments
    final segmentCount = data[position + 26];
    metadata['segmentCount'] = segmentCount;

    // Calculate total page size
    if (position + 27 + segmentCount <= data.length) {
      int totalPageSize = 27 + segmentCount; // Header + segment table
      for (int i = 0; i < segmentCount; i++) {
        totalPageSize += data[position + 27 + i];
      }
      metadata['pageSize'] = totalPageSize;

      // Try to identify codec type from first page data
      if (metadata['isFirstPage'] == true && position + 27 + segmentCount < data.length) {
        final codecType = _identifyCodecType(data, position + 27 + segmentCount);
        if (codecType != null) {
          metadata['codecType'] = codecType;
        }
      }
    }

    return metadata;
  }

  /// Read a 32-bit little-endian integer from the data
  int _readLittleEndian32(Uint8List data, int offset) {
    if (offset + 3 >= data.length) return 0;

    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);
  }

  /// Read a 64-bit little-endian integer from the data
  int _readLittleEndian64(Uint8List data, int offset) {
    if (offset + 7 >= data.length) return 0;

    // Read as two 32-bit values and combine
    final low = _readLittleEndian32(data, offset);
    final high = _readLittleEndian32(data, offset + 4);

    // Combine into 64-bit value (note: Dart int is 64-bit)
    return low | (high << 32);
  }

  /// Identify codec type from OGG page data
  String? _identifyCodecType(Uint8List data, int offset) {
    if (offset + 7 >= data.length) return null;

    // Check for Vorbis identification header
    if (offset + 6 < data.length &&
        data[offset] == 0x01 && // Packet type
        data[offset + 1] == 0x76 &&
        data[offset + 2] == 0x6F && // "vo"
        data[offset + 3] == 0x72 &&
        data[offset + 4] == 0x62 && // "rb"
        data[offset + 5] == 0x69 &&
        data[offset + 6] == 0x73) {
      // "is"
      return 'vorbis';
    }

    // Check for Opus identification header
    if (offset + 7 < data.length &&
        data[offset] == 0x4F &&
        data[offset + 1] == 0x70 && // "Op"
        data[offset + 2] == 0x75 &&
        data[offset + 3] == 0x73 && // "us"
        data[offset + 4] == 0x48 &&
        data[offset + 5] == 0x65 && // "He"
        data[offset + 6] == 0x61 &&
        data[offset + 7] == 0x64) {
      // "ad"
      return 'opus';
    }

    // Check for FLAC in OGG
    if (offset + 3 < data.length &&
        data[offset] == 0x7F && // Packet type for FLAC
        data[offset + 1] == 0x46 &&
        data[offset + 2] == 0x4C && // "FL"
        data[offset + 3] == 0x41 &&
        data[offset + 4] == 0x43) {
      // "AC"
      return 'flac';
    }

    // Check for Theora (video codec, but can be in OGG)
    if (offset + 6 < data.length &&
        data[offset] == 0x80 && // Packet type
        data[offset + 1] == 0x74 &&
        data[offset + 2] == 0x68 && // "th"
        data[offset + 3] == 0x65 &&
        data[offset + 4] == 0x6F && // "eo"
        data[offset + 5] == 0x72 &&
        data[offset + 6] == 0x61) {
      // "ra"
      return 'theora';
    }

    return null; // Unknown codec
  }

  /// Calculate granule position for seeking
  int calculateGranulePosition(Duration timePosition, int sampleRate) {
    return (timePosition.inMicroseconds * sampleRate / 1000000).round();
  }

  /// Calculate time position from granule position
  Duration calculateTimePosition(int granulePosition, int sampleRate) {
    if (sampleRate <= 0) return Duration.zero;
    final microseconds = (granulePosition * 1000000 / sampleRate).round();
    return Duration(microseconds: microseconds);
  }
}
