import 'dart:typed_data';
import '../models/file_chunk.dart';
import '../models/chunk_boundary.dart';
import 'format_chunk_parser.dart';

/// FLAC-specific chunk parser that handles frame boundaries and metadata blocks
class FLACChunkParser extends FormatChunkParser {
  @override
  String get format => 'FLAC';

  @override
  List<ChunkBoundary> parseChunkBoundaries(FileChunk fileChunk) {
    final boundaries = <ChunkBoundary>[];
    final data = fileChunk.data;

    // Look for FLAC stream marker and metadata blocks first
    for (int i = 0; i < data.length - 3; i++) {
      // Check for FLAC stream marker "fLaC"
      if (i <= data.length - 4 && data[i] == 0x66 && data[i + 1] == 0x4C && data[i + 2] == 0x61 && data[i + 3] == 0x43) {
        boundaries.add(
          ChunkBoundary(position: fileChunk.startPosition + i, type: BoundaryType.metadata, isSeekable: false, metadata: {'type': 'FLAC_STREAM_MARKER'}),
        );
        i += 3; // Skip past the marker
        continue;
      }

      // Check for metadata blocks (after stream marker position)
      if (i >= 4 && i < data.length - 3) {
        final blockType = data[i] & 0x7F; // Remove last metadata block flag
        if (blockType <= 6) {
          // Valid FLAC metadata block types (0-6)
          final blockLength = (data[i + 1] << 16) | (data[i + 2] << 8) | data[i + 3];

          // Additional validation: block length should be reasonable
          if (blockLength > 0 && blockLength < 16 * 1024 * 1024) {
            // Max 16MB per block
            final isLastBlock = (data[i] & 0x80) != 0;
            boundaries.add(
              ChunkBoundary(
                position: fileChunk.startPosition + i,
                type: BoundaryType.blockStart,
                isSeekable: blockType == 3, // SEEKTABLE blocks are seekable
                metadata: {'blockType': _getBlockTypeName(blockType), 'isLastBlock': isLastBlock, 'blockLength': blockLength},
              ),
            );
            // Skip past this block header
            i += 3;
          }
        }
      }
    }

    // Look for FLAC frame sync codes
    for (int i = 0; i < data.length - 3; i++) {
      final syncWord = (data[i] << 8) | data[i + 1];
      if ((syncWord & 0xFFFE) == 0x3FFE) {
        // Validate this is actually a FLAC frame header
        if (_isValidFLACFrameHeader(data, i)) {
          boundaries.add(
            ChunkBoundary(position: fileChunk.startPosition + i, type: BoundaryType.frameStart, isSeekable: true, metadata: _parseFLACFrameHeader(data, i)),
          );
        }
      }
    }

    return boundaries;
  }

  @override
  Future<int> findNextSeekPoint(int fromPosition) async {
    // For FLAC, seek points are typically at frame boundaries or in seek tables
    // This would involve reading the file to find the next frame sync
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

    // FLAC-specific validation
    if (chunk.data.isEmpty) {
      errors.add('FLAC chunk cannot be empty');
      return ChunkValidationResult(isValid: false, errors: errors, warnings: warnings);
    }

    // Check if chunk contains valid FLAC content
    bool hasValidContent = false;
    final boundaries = parseChunkBoundaries(chunk);

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.frameStart || boundary.type == BoundaryType.blockStart || boundary.type == BoundaryType.metadata) {
        hasValidContent = true;
        break;
      }
    }

    if (!hasValidContent && !chunk.isLast) {
      warnings.add('FLAC chunk contains no recognizable frame headers or metadata blocks');
    }

    // Check for proper FLAC stream structure
    final streamMarkers = boundaries.where((b) => b.metadata?['type'] == 'FLAC_STREAM_MARKER').toList();
    if (streamMarkers.length > 1) {
      warnings.add('Multiple FLAC stream markers found in chunk');
    }

    return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings);
  }

  @override
  FormatMetadata? extractMetadata(FileChunk chunk) {
    final metadata = <String, dynamic>{};
    final boundaries = parseChunkBoundaries(chunk);

    int frameCount = 0;
    int metadataBlockCount = 0;
    int seekTableBlocks = 0;
    bool hasStreamMarker = false;

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.frameStart) {
        frameCount++;
        // Add frame-specific metadata if available
        if (boundary.metadata != null) {
          metadata.addAll(boundary.metadata!);
        }
      } else if (boundary.type == BoundaryType.blockStart) {
        metadataBlockCount++;
        if (boundary.metadata?['blockType'] == 'SEEKTABLE') {
          seekTableBlocks++;
        }
      } else if (boundary.type == BoundaryType.metadata) {
        if (boundary.metadata?['type'] == 'FLAC_STREAM_MARKER') {
          hasStreamMarker = true;
        }
      }
    }

    metadata['frameCount'] = frameCount;
    metadata['metadataBlockCount'] = metadataBlockCount;
    metadata['seekTableBlocks'] = seekTableBlocks;
    metadata['hasStreamMarker'] = hasStreamMarker;
    metadata['chunkSize'] = chunk.size;

    return FormatMetadata(format: format, data: metadata);
  }

  @override
  int getRecommendedChunkSize(int fileSize) {
    // FLAC frames can vary significantly in size (typically 1KB-16KB)
    // Use larger chunks for better efficiency with metadata blocks
    if (fileSize < 10 * 1024 * 1024) {
      // < 10MB
      return 1 * 1024 * 1024; // 1MB
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      return 4 * 1024 * 1024; // 4MB
    } else {
      return 12 * 1024 * 1024; // 12MB
    }
  }

  @override
  int get minimumChunkSize => 64 * 1024; // 64KB - enough for multiple FLAC frames

  @override
  int get maximumChunkSize => 25 * 1024 * 1024; // 25MB

  /// Validate if the bytes at the given position form a valid FLAC frame header
  bool _isValidFLACFrameHeader(Uint8List data, int position) {
    if (position + 3 >= data.length) return false;

    // Check sync code (14 bits: 0x3FFE)
    final syncWord = (data[position] << 8) | data[position + 1];
    if ((syncWord & 0xFFFE) != 0x3FFE) return false;

    // Check reserved bit (should be 0)
    if ((data[position + 1] & 0x01) != 0) return false;

    // Check blocking strategy (bit 0 of third byte)
    final blockingStrategy = (data[position + 2] >> 7) & 0x01;

    // Check block size (bits 4-7 of third byte)
    final blockSizeCode = (data[position + 2] >> 4) & 0x0F;
    if (blockSizeCode == 0x00) return false; // Reserved

    // Check sample rate (bits 0-3 of third byte)
    final sampleRateCode = data[position + 2] & 0x0F;
    // All sample rate codes are valid (0x00-0x0F)

    // Check channel assignment (bits 4-7 of fourth byte)
    final channelAssignment = (data[position + 3] >> 4) & 0x0F;
    if (channelAssignment >= 0x0B && channelAssignment <= 0x0F) {
      return false; // Reserved values
    }

    // Check sample size (bits 1-3 of fourth byte)
    final sampleSizeCode = (data[position + 3] >> 1) & 0x07;
    if (sampleSizeCode == 0x03 || sampleSizeCode == 0x07) {
      return false; // Reserved values
    }

    // Check reserved bit (bit 0 of fourth byte, should be 0)
    if ((data[position + 3] & 0x01) != 0) return false;

    return true;
  }

  /// Parse FLAC frame header and extract metadata
  Map<String, dynamic>? _parseFLACFrameHeader(Uint8List data, int position) {
    if (!_isValidFLACFrameHeader(data, position)) return null;

    final metadata = <String, dynamic>{};

    // Blocking strategy
    final blockingStrategy = (data[position + 2] >> 7) & 0x01;
    metadata['blockingStrategy'] = blockingStrategy == 0 ? 'fixed' : 'variable';

    // Block size
    final blockSizeCode = (data[position + 2] >> 4) & 0x0F;
    metadata['blockSizeCode'] = blockSizeCode;

    // Sample rate
    final sampleRateCode = data[position + 2] & 0x0F;
    metadata['sampleRateCode'] = sampleRateCode;

    // Channel assignment
    final channelAssignment = (data[position + 3] >> 4) & 0x0F;
    if (channelAssignment < 8) {
      metadata['channels'] = channelAssignment + 1;
      metadata['channelMode'] = 'independent';
    } else if (channelAssignment == 8) {
      metadata['channels'] = 2;
      metadata['channelMode'] = 'left_side';
    } else if (channelAssignment == 9) {
      metadata['channels'] = 2;
      metadata['channelMode'] = 'right_side';
    } else if (channelAssignment == 10) {
      metadata['channels'] = 2;
      metadata['channelMode'] = 'mid_side';
    }

    // Sample size
    final sampleSizeCode = (data[position + 3] >> 1) & 0x07;
    final sampleSizes = [0, 8, 12, 0, 16, 20, 24, 0]; // 0 = reserved/get from streaminfo
    if (sampleSizeCode < sampleSizes.length && sampleSizes[sampleSizeCode] != 0) {
      metadata['sampleSize'] = sampleSizes[sampleSizeCode];
    }

    return metadata;
  }

  /// Get human-readable name for FLAC metadata block type
  String _getBlockTypeName(int blockType) {
    switch (blockType) {
      case 0:
        return 'STREAMINFO';
      case 1:
        return 'PADDING';
      case 2:
        return 'APPLICATION';
      case 3:
        return 'SEEKTABLE';
      case 4:
        return 'VORBIS_COMMENT';
      case 5:
        return 'CUESHEET';
      case 6:
        return 'PICTURE';
      default:
        return 'UNKNOWN';
    }
  }
}
