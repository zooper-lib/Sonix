/// MP4-specific exceptions for container parsing and decoding errors
library;

import 'sonix_exceptions.dart';

/// Exception thrown when MP4 container parsing fails
///
/// This exception is raised when the library encounters issues while parsing
/// the MP4 container structure, such as invalid box headers, corrupted
/// metadata, or unsupported container features.
///
/// ## Common Causes
///
/// - Corrupted or truncated MP4 files
/// - Invalid MP4 box structure or headers
/// - Unsupported MP4 container variants
/// - Missing required boxes (moov, trak, mdia, etc.)
/// - Encrypted or DRM-protected content
///
/// ## Usage
///
/// ```dart
/// try {
///   final containerInfo = await mp4Decoder.parseContainer(filePath);
/// } on MP4ContainerException catch (e) {
///   if (e.message.contains('truncated')) {
///     // Handle incomplete file
///     showError('File appears to be incomplete or corrupted');
///   } else if (e.message.contains('encrypted')) {
///     // Handle DRM content
///     showError('This file is protected and cannot be processed');
///   } else {
///     // Generic container error
///     showError('Unable to read MP4 file: ${e.message}');
///   }
///
///   // Log technical details for debugging
///   logger.error('MP4 container error: ${e.details}');
/// }
/// ```
///
/// ## Error Recovery
///
/// Some container errors may be recoverable by:
/// - Attempting to read with different parsing strategies
/// - Skipping corrupted sections if possible
/// - Using alternative metadata sources
class MP4ContainerException extends DecodingException {
  /// The specific container operation that failed
  final String? operation;

  /// The MP4 box type that caused the error (if applicable)
  final String? boxType;

  /// The file offset where the error occurred (if known)
  final int? fileOffset;

  const MP4ContainerException(String message, {String? details, this.operation, this.boxType, this.fileOffset}) : super(message, details);

  @override
  String get message => 'MP4 container error: ${super.message}';

  /// Create exception for invalid box structure
  factory MP4ContainerException.invalidBox(String boxType, {String? details, int? fileOffset}) {
    return MP4ContainerException('Invalid or corrupted $boxType box', details: details, operation: 'box_parsing', boxType: boxType, fileOffset: fileOffset);
  }

  /// Create exception for missing required box
  factory MP4ContainerException.missingBox(String boxType, {String? details}) {
    return MP4ContainerException('Required $boxType box not found in MP4 container', details: details, operation: 'box_validation', boxType: boxType);
  }

  /// Create exception for truncated file
  factory MP4ContainerException.truncatedFile({String? details, int? fileOffset}) {
    return MP4ContainerException('MP4 file appears to be truncated or incomplete', details: details, operation: 'file_reading', fileOffset: fileOffset);
  }

  /// Create exception for encrypted content
  factory MP4ContainerException.encryptedContent({String? details}) {
    return MP4ContainerException('MP4 file is encrypted or DRM-protected', details: details, operation: 'content_validation');
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('MP4ContainerException: MP4 container error: ${super.message}');

    if (operation != null) {
      buffer.write('\nOperation: $operation');
    }

    if (boxType != null) {
      buffer.write('\nBox Type: $boxType');
    }

    if (fileOffset != null) {
      buffer.write('\nFile Offset: $fileOffset');
    }

    if (details != null) {
      buffer.write('\nDetails: $details');
    }

    return buffer.toString();
  }
}

/// Exception thrown when MP4 audio codec is unsupported or fails to initialize
///
/// This exception occurs when the MP4 container is valid but contains an
/// audio codec that cannot be processed, or when the codec decoder fails
/// to initialize properly.
///
/// ## Common Causes
///
/// - Unsupported audio codecs (e.g., AC-3, DTS, proprietary codecs)
/// - Unsupported AAC profiles or configurations
/// - Codec initialization failures
/// - Missing codec libraries or dependencies
/// - Corrupted codec-specific data
///
/// ## Usage
///
/// ```dart
/// try {
///   await mp4Decoder.initializeDecoder();
/// } on MP4CodecException catch (e) {
///   // Check if it's a known unsupported codec
///   if (e.codecName == 'AC-3' || e.codecName == 'DTS') {
///     showError('${e.codecName} audio is not supported. Please use AAC format.');
///   } else if (e.codecName.startsWith('AAC')) {
///     showError('This AAC variant is not supported: ${e.codecName}');
///   } else {
///     showError('Unsupported audio codec: ${e.codecName}');
///   }
///
///   // Suggest alternatives
///   showInfo('Supported formats: AAC-LC, AAC-HE');
/// }
/// ```
///
/// ## Supported Codecs
///
/// The MP4 decoder currently supports:
/// - AAC-LC (Low Complexity)
/// - AAC-HE (High Efficiency)
/// - AAC-HEv2 (High Efficiency v2)
class MP4CodecException extends UnsupportedFormatException {
  /// The specific codec that is unsupported or failed
  final String codecName;

  /// The codec profile or variant (if available)
  final String? codecProfile;

  /// The codec configuration that caused the error
  final String? codecConfig;

  /// Whether this codec is theoretically supported but failed to initialize
  final bool initializationFailure;

  const MP4CodecException(this.codecName, {String? details, this.codecProfile, this.codecConfig, this.initializationFailure = false})
    : super(codecName, details);

  @override
  String get message =>
      'Unsupported MP4 audio codec: $codecName'
      '${codecProfile != null ? ' ($codecProfile)' : ''}';

  /// Create exception for completely unsupported codec
  factory MP4CodecException.unsupportedCodec(String codecName, {String? codecProfile, String? details}) {
    return MP4CodecException(
      codecName,
      codecProfile: codecProfile,
      details: details ?? 'This codec is not supported by the MP4 decoder',
      initializationFailure: false,
    );
  }

  /// Create exception for codec initialization failure
  factory MP4CodecException.initializationFailed(String codecName, {String? codecProfile, String? codecConfig, String? details}) {
    return MP4CodecException(
      codecName,
      codecProfile: codecProfile,
      codecConfig: codecConfig,
      details: details ?? 'Failed to initialize codec decoder',
      initializationFailure: true,
    );
  }

  /// Create exception for unsupported AAC profile
  factory MP4CodecException.unsupportedAACProfile(String profile, {String? details}) {
    final combinedDetails = details != null ? '$details. Supported: LC, HE, HEv2' : 'This AAC profile is not supported. Supported: LC, HE, HEv2';
    return MP4CodecException('AAC', codecProfile: profile, details: combinedDetails, initializationFailure: false);
  }

  /// Get a user-friendly error message with suggestions
  String get userFriendlyMessage {
    if (codecName == 'AAC' && codecProfile != null) {
      return 'This AAC variant ($codecProfile) is not supported. '
          'Please use AAC-LC format.';
    } else if (codecName.startsWith('AAC')) {
      return 'This AAC format is not supported. Please use standard AAC-LC.';
    } else if (['AC-3', 'DTS', 'TrueHD', 'DTS-HD'].contains(codecName)) {
      return '$codecName audio is not supported. Please convert to AAC format.';
    } else {
      return 'Audio codec "$codecName" is not supported. Please use AAC format.';
    }
  }

  /// Get list of suggested alternative formats
  List<String> get suggestedAlternatives {
    return ['AAC-LC', 'AAC-HE', 'MP3', 'FLAC', 'WAV'];
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('MP4CodecException: Unsupported MP4 audio codec: $codecName');

    if (codecProfile != null) {
      buffer.write(' ($codecProfile)');
    }

    if (initializationFailure) {
      buffer.write(' [Initialization Failed]');
    }

    if (codecConfig != null) {
      buffer.write('\nCodec Config: $codecConfig');
    }

    if (details != null) {
      buffer.write('\nDetails: $details');
    }

    return buffer.toString();
  }
}

/// Exception thrown when MP4 audio track is missing, invalid, or inaccessible
///
/// This exception occurs when the MP4 container is valid but has issues
/// with the audio track itself, such as missing audio tracks, corrupted
/// track data, or unsupported track configurations.
///
/// ## Common Causes
///
/// - MP4 files with no audio tracks (video-only)
/// - Multiple audio tracks with unsupported selection
/// - Corrupted audio track metadata
/// - Encrypted or protected audio tracks
/// - Invalid sample table or chunk offset data
///
/// ## Usage
///
/// ```dart
/// try {
///   final audioTrack = await mp4Decoder.findAudioTrack();
/// } on MP4TrackException catch (e) {
///   if (e.trackId != null) {
///     showError('Audio track ${e.trackId} is corrupted or invalid');
///   } else if (e.message.contains('no audio')) {
///     showError('This MP4 file contains no audio tracks');
///   } else {
///     showError('Audio track error: ${e.message}');
///   }
///
///   // Log technical details
///   logger.warning('MP4 track error: ${e.details}');
/// }
/// ```
///
/// ## Recovery Strategies
///
/// - For multi-track files, try selecting different audio tracks
/// - For corrupted tracks, attempt partial recovery if possible
/// - For missing tracks, inform user that file is video-only
class MP4TrackException extends DecodingException {
  /// The track ID that caused the error (if applicable)
  final int? trackId;

  /// The type of track operation that failed
  final String? operation;

  /// The number of audio tracks found (if relevant)
  final int? audioTrackCount;

  /// Whether the track exists but is corrupted
  final bool isCorrupted;

  const MP4TrackException(String message, {String? details, this.trackId, this.operation, this.audioTrackCount, this.isCorrupted = false})
    : super(message, details);

  @override
  String get message => 'MP4 track error: ${super.message}';

  /// Create exception for missing audio tracks
  factory MP4TrackException.noAudioTracks({String? details}) {
    return MP4TrackException('No audio tracks found in MP4 file', details: details, operation: 'track_discovery', audioTrackCount: 0);
  }

  /// Create exception for corrupted audio track
  factory MP4TrackException.corruptedTrack(int trackId, {String? details, String? operation}) {
    return MP4TrackException('Audio track $trackId is corrupted or invalid', details: details, trackId: trackId, operation: operation, isCorrupted: true);
  }

  /// Create exception for invalid sample table
  factory MP4TrackException.invalidSampleTable(int trackId, {String? details}) {
    return MP4TrackException(
      'Invalid or corrupted sample table for track $trackId',
      details: details,
      trackId: trackId,
      operation: 'sample_table_parsing',
      isCorrupted: true,
    );
  }

  /// Create exception for encrypted track
  factory MP4TrackException.encryptedTrack(int trackId, {String? details}) {
    return MP4TrackException('Audio track $trackId is encrypted or protected', details: details, trackId: trackId, operation: 'track_access');
  }

  /// Create exception for unsupported track configuration
  factory MP4TrackException.unsupportedConfiguration(int trackId, String configuration, {String? details}) {
    return MP4TrackException(
      'Unsupported track configuration for track $trackId: $configuration',
      details: details,
      trackId: trackId,
      operation: 'track_validation',
    );
  }

  /// Get a user-friendly error message
  String get userFriendlyMessage {
    if (audioTrackCount == 0) {
      return 'This MP4 file contains no audio. It may be a video-only file.';
    } else if (isCorrupted && trackId != null) {
      return 'The audio track in this MP4 file is corrupted and cannot be processed.';
    } else if (message.contains('encrypted')) {
      return 'This MP4 file is protected and cannot be processed.';
    } else {
      return 'There was a problem with the audio track in this MP4 file.';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('MP4TrackException: MP4 track error: ${super.message}');

    if (trackId != null) {
      buffer.write('\nTrack ID: $trackId');
    }

    if (operation != null) {
      buffer.write('\nOperation: $operation');
    }

    if (audioTrackCount != null) {
      buffer.write('\nAudio Tracks Found: $audioTrackCount');
    }

    if (isCorrupted) {
      buffer.write('\nTrack Status: Corrupted');
    }

    if (details != null) {
      buffer.write('\nDetails: $details');
    }

    return buffer.toString();
  }
}
