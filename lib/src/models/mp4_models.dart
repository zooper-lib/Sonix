/// MP4-specific data models for container parsing and metadata
library;

/// Information about an MP4 container and its audio content
///
/// This class contains metadata extracted from an MP4 container, including
/// duration, bitrate information, codec details, and sample table data
/// needed for efficient seeking and chunked processing.
///
/// ## Usage
///
/// ```dart
/// // Typically created during MP4 container parsing
/// final containerInfo = MP4ContainerInfo(
///   duration: Duration(minutes: 3, seconds: 45),
///   bitrate: 128000, // 128 kbps
///   maxBitrate: 160000, // 160 kbps peak
///   codecName: 'AAC',
///   audioTrackId: 1,
///   sampleTable: sampleInfoList,
/// );
///
/// print('MP4 contains ${containerInfo.duration} of ${containerInfo.codecName} audio');
/// print('Average bitrate: ${containerInfo.bitrate ~/ 1000} kbps');
/// ```
class MP4ContainerInfo {
  /// Total duration of the audio content in the MP4 container
  final Duration duration;

  /// Average bitrate of the audio track in bits per second
  final int bitrate;

  /// Maximum bitrate of the audio track in bits per second
  ///
  /// For variable bitrate (VBR) content, this represents the peak bitrate.
  /// For constant bitrate (CBR) content, this will be the same as [bitrate].
  final int maxBitrate;

  /// Name of the audio codec used (e.g., 'AAC', 'AAC-LC', 'AAC-HE')
  final String codecName;

  /// Track ID of the audio track within the MP4 container
  ///
  /// MP4 files can contain multiple tracks (audio, video, subtitles).
  /// This identifies which track contains the audio data we're processing.
  final int audioTrackId;

  /// Sample table containing information about each audio sample/frame
  ///
  /// This table is used for efficient seeking and chunked processing.
  /// Each entry contains offset, size, and timing information for audio samples.
  final List<MP4SampleInfo> sampleTable;

  const MP4ContainerInfo({
    required this.duration,
    required this.bitrate,
    required this.maxBitrate,
    required this.codecName,
    required this.audioTrackId,
    required this.sampleTable,
  });

  /// Create MP4ContainerInfo from native metadata
  factory MP4ContainerInfo.fromNativeMetadata(Map<String, dynamic> metadata) {
    final sampleTableData = metadata['sampleTable'] as List<dynamic>? ?? [];
    final sampleTable = sampleTableData.cast<Map<String, dynamic>>().map((sample) => MP4SampleInfo.fromMap(sample)).toList();

    return MP4ContainerInfo(
      duration: Duration(microseconds: metadata['durationMicros'] as int? ?? 0),
      bitrate: metadata['bitrate'] as int? ?? 0,
      maxBitrate: metadata['maxBitrate'] as int? ?? 0,
      codecName: metadata['codecName'] as String? ?? 'Unknown',
      audioTrackId: metadata['audioTrackId'] as int? ?? 1,
      sampleTable: sampleTable,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'durationMicros': duration.inMicroseconds,
      'bitrate': bitrate,
      'maxBitrate': maxBitrate,
      'codecName': codecName,
      'audioTrackId': audioTrackId,
      'sampleTable': sampleTable.map((sample) => sample.toMap()).toList(),
    };
  }

  /// Get the total number of samples in the audio track
  int get totalSamples => sampleTable.length;

  /// Get the sample rate estimate based on duration and sample count
  ///
  /// This provides an approximation when exact sample rate isn't available
  /// from the container metadata.
  double get estimatedSampleRate {
    if (totalSamples == 0 || duration.inMicroseconds == 0) return 0.0;
    return totalSamples * 1000000.0 / duration.inMicroseconds;
  }

  /// Check if this is a variable bitrate (VBR) encoding
  bool get isVariableBitrate => maxBitrate > bitrate;

  /// Get the bitrate ratio (max/average) for VBR content
  double get bitrateRatio => bitrate > 0 ? maxBitrate / bitrate : 1.0;

  @override
  String toString() {
    return 'MP4ContainerInfo('
        'duration: $duration, '
        'bitrate: ${bitrate ~/ 1000}kbps, '
        'maxBitrate: ${maxBitrate ~/ 1000}kbps, '
        'codec: $codecName, '
        'trackId: $audioTrackId, '
        'samples: $totalSamples'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MP4ContainerInfo &&
        other.duration == duration &&
        other.bitrate == bitrate &&
        other.maxBitrate == maxBitrate &&
        other.codecName == codecName &&
        other.audioTrackId == audioTrackId &&
        _listEquals(other.sampleTable, sampleTable);
  }

  @override
  int get hashCode {
    return Object.hash(duration, bitrate, maxBitrate, codecName, audioTrackId, Object.hashAll(sampleTable));
  }

  /// Helper method to compare lists for equality
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Information about a single audio sample/frame in an MP4 file
///
/// Each MP4 audio sample represents a compressed audio frame (e.g., AAC frame).
/// This class contains the metadata needed to locate and decode individual
/// samples for seeking and chunked processing.
///
/// ## Usage
///
/// ```dart
/// // Typically created during sample table parsing
/// final sampleInfo = MP4SampleInfo(
///   offset: 1024, // Byte offset in file
///   size: 768,    // Size of this AAC frame
///   timestamp: Duration(milliseconds: 23), // Playback time
///   isKeyframe: true, // Can seek to this sample
/// );
///
/// // Use for seeking
/// if (sampleInfo.isKeyframe && sampleInfo.timestamp <= targetTime) {
///   // This is a good seek target
/// }
/// ```
class MP4SampleInfo {
  /// Byte offset of this sample in the MP4 file
  ///
  /// This is the absolute position in the file where this audio sample
  /// begins. Used for direct file access during chunked processing.
  final int offset;

  /// Size of this sample in bytes
  ///
  /// The number of bytes occupied by this compressed audio sample.
  /// For AAC, this is typically 200-2000 bytes per frame.
  final int size;

  /// Timestamp of this sample in the audio timeline
  ///
  /// The playback time when this sample should be played.
  /// Used for accurate seeking and time-based operations.
  final Duration timestamp;

  /// Whether this sample is a keyframe/sync sample
  ///
  /// Keyframes are samples that can be decoded independently without
  /// requiring previous samples. These are preferred seek targets.
  /// For AAC, most frames are keyframes.
  final bool isKeyframe;

  const MP4SampleInfo({required this.offset, required this.size, required this.timestamp, required this.isKeyframe});

  /// Create MP4SampleInfo from a map (typically from native code)
  factory MP4SampleInfo.fromMap(Map<String, dynamic> map) {
    return MP4SampleInfo(
      offset: map['offset'] as int? ?? 0,
      size: map['size'] as int? ?? 0,
      timestamp: Duration(microseconds: map['timestampMicros'] as int? ?? 0),
      isKeyframe: map['isKeyframe'] as bool? ?? false,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {'offset': offset, 'size': size, 'timestampMicros': timestamp.inMicroseconds, 'isKeyframe': isKeyframe};
  }

  /// Get the end offset of this sample in the file
  int get endOffset => offset + size;

  /// Check if this sample contains the given timestamp
  bool containsTimestamp(Duration timestamp, Duration nextSampleTimestamp) {
    return this.timestamp <= timestamp && timestamp < nextSampleTimestamp;
  }

  /// Calculate the duration of this sample based on the next sample's timestamp
  Duration durationUntil(MP4SampleInfo nextSample) {
    return nextSample.timestamp - timestamp;
  }

  @override
  String toString() {
    return 'MP4SampleInfo('
        'offset: $offset, '
        'size: $size, '
        'timestamp: ${timestamp.inMilliseconds}ms, '
        'keyframe: $isKeyframe'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MP4SampleInfo && other.offset == offset && other.size == size && other.timestamp == timestamp && other.isKeyframe == isKeyframe;
  }

  @override
  int get hashCode {
    return Object.hash(offset, size, timestamp, isKeyframe);
  }
}
