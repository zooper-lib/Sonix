import 'dart:typed_data';
import '../models/file_chunk.dart';
import '../models/chunk_boundary.dart';
import 'format_chunk_parser.dart';

/// MP3-specific chunk parser that handles frame boundaries and ID3 tags
class MP3ChunkParser extends FormatChunkParser {
  @override
  String get format => 'MP3';

  @override
  List<ChunkBoundary> parseChunkBoundaries(FileChunk fileChunk) {
    final boundaries = <ChunkBoundary>[];
    final data = fileChunk.data;

    // Look for MP3 sync words and ID3 tags
    for (int i = 0; i < data.length - 1; i++) {
      // Check for MP3 sync word (0xFFE0 or higher)
      final syncWord = (data[i] << 8) | data[i + 1];
      if ((syncWord & 0xFFE0) == 0xFFE0) {
        // Validate this is actually an MP3 frame header
        if (_isValidMP3FrameHeader(data, i)) {
          boundaries.add(
            ChunkBoundary(position: fileChunk.startPosition + i, type: BoundaryType.frameStart, isSeekable: true, metadata: _parseMP3FrameHeader(data, i)),
          );
        }
      }

      // Check for ID3v2 tag (starts with "ID3")
      if (i <= data.length - 3 && data[i] == 0x49 && data[i + 1] == 0x44 && data[i + 2] == 0x33) {
        boundaries.add(ChunkBoundary(position: fileChunk.startPosition + i, type: BoundaryType.metadata, isSeekable: false, metadata: {'type': 'ID3v2'}));
      }
    }

    // Check for ID3v1 tag at the end (last 128 bytes, starts with "TAG")
    if (data.length >= 128) {
      final tagStart = data.length - 128;
      if (data[tagStart] == 0x54 && data[tagStart + 1] == 0x41 && data[tagStart + 2] == 0x47) {
        boundaries.add(
          ChunkBoundary(position: fileChunk.startPosition + tagStart, type: BoundaryType.metadata, isSeekable: false, metadata: {'type': 'ID3v1'}),
        );
      }
    }

    return boundaries;
  }

  @override
  Future<int> findNextSeekPoint(int fromPosition) async {
    // For MP3, any valid frame header is a seek point
    // This would typically involve reading small chunks from the file
    // For now, return the position as MP3 frames can start anywhere
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

    // MP3-specific validation
    if (chunk.data.isEmpty) {
      errors.add('MP3 chunk cannot be empty');
      return ChunkValidationResult(isValid: false, errors: errors, warnings: warnings);
    }

    // Check if chunk contains at least one valid MP3 frame or ID3 tag
    bool hasValidContent = false;
    final boundaries = parseChunkBoundaries(chunk);

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.frameStart || boundary.type == BoundaryType.metadata) {
        hasValidContent = true;
        break;
      }
    }

    if (!hasValidContent && !chunk.isLast) {
      warnings.add('MP3 chunk contains no recognizable frame headers or metadata');
    }

    return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings);
  }

  @override
  FormatMetadata? extractMetadata(FileChunk chunk) {
    final metadata = <String, dynamic>{};
    final boundaries = parseChunkBoundaries(chunk);

    int frameCount = 0;
    int id3TagCount = 0;

    for (final boundary in boundaries) {
      if (boundary.type == BoundaryType.frameStart) {
        frameCount++;
        // Add frame-specific metadata if available
        if (boundary.metadata != null) {
          metadata.addAll(boundary.metadata!);
        }
      } else if (boundary.type == BoundaryType.metadata) {
        id3TagCount++;
      }
    }

    metadata['frameCount'] = frameCount;
    metadata['id3TagCount'] = id3TagCount;
    metadata['chunkSize'] = chunk.size;

    return FormatMetadata(format: format, data: metadata);
  }

  @override
  int getRecommendedChunkSize(int fileSize) {
    // MP3 frames are typically 144-1728 bytes
    // Use larger chunks for better efficiency
    if (fileSize < 5 * 1024 * 1024) {
      // < 5MB
      return 512 * 1024; // 512KB
    } else if (fileSize < 50 * 1024 * 1024) {
      // < 50MB
      return 2 * 1024 * 1024; // 2MB
    } else {
      return 8 * 1024 * 1024; // 8MB
    }
  }

  @override
  int get minimumChunkSize => 32 * 1024; // 32KB - enough for multiple MP3 frames

  @override
  int get maximumChunkSize => 20 * 1024 * 1024; // 20MB

  /// Validate if the bytes at the given position form a valid MP3 frame header
  bool _isValidMP3FrameHeader(Uint8List data, int position) {
    if (position + 3 >= data.length) return false;

    final header = (data[position] << 24) | (data[position + 1] << 16) | (data[position + 2] << 8) | data[position + 3];

    // Check sync word (11 bits set)
    if ((header & 0xFFE00000) != 0xFFE00000) return false;

    // Check MPEG version (bits 19-20)
    final version = (header >> 19) & 0x3;
    if (version == 1) return false; // Reserved

    // Check layer (bits 17-18)
    final layer = (header >> 17) & 0x3;
    if (layer == 0) return false; // Reserved

    // Check bitrate (bits 12-15)
    final bitrate = (header >> 12) & 0xF;
    if (bitrate == 0 || bitrate == 15) return false; // Free or reserved

    // Check sample rate (bits 10-11)
    final sampleRate = (header >> 10) & 0x3;
    if (sampleRate == 3) return false; // Reserved

    return true;
  }

  /// Parse MP3 frame header and extract metadata
  Map<String, dynamic>? _parseMP3FrameHeader(Uint8List data, int position) {
    if (!_isValidMP3FrameHeader(data, position)) return null;

    final header = (data[position] << 24) | (data[position + 1] << 16) | (data[position + 2] << 8) | data[position + 3];

    final metadata = <String, dynamic>{};

    // MPEG version
    final version = (header >> 19) & 0x3;
    switch (version) {
      case 0:
        metadata['mpegVersion'] = '2.5';
        break;
      case 2:
        metadata['mpegVersion'] = '2';
        break;
      case 3:
        metadata['mpegVersion'] = '1';
        break;
    }

    // Layer
    final layer = (header >> 17) & 0x3;
    metadata['layer'] = 4 - layer;

    // Bitrate
    final bitrateIndex = (header >> 12) & 0xF;
    metadata['bitrateIndex'] = bitrateIndex;

    // Sample rate
    final sampleRateIndex = (header >> 10) & 0x3;
    metadata['sampleRateIndex'] = sampleRateIndex;

    // Padding
    final padding = (header >> 9) & 0x1;
    metadata['padding'] = padding == 1;

    // Channel mode
    final channelMode = (header >> 6) & 0x3;
    switch (channelMode) {
      case 0:
        metadata['channelMode'] = 'stereo';
        break;
      case 1:
        metadata['channelMode'] = 'joint_stereo';
        break;
      case 2:
        metadata['channelMode'] = 'dual_channel';
        break;
      case 3:
        metadata['channelMode'] = 'mono';
        break;
    }

    return metadata;
  }
}
