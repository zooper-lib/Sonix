import 'dart:convert';

import '../utils/lru_cache.dart';

/// Types of waveform visualization
enum WaveformType { bars, line, filled }

/// Metadata about waveform generation
class WaveformMetadata {
  /// Resolution (number of data points)
  final int resolution;

  /// Type of waveform visualization
  final WaveformType type;

  /// Whether the data has been normalized
  final bool normalized;

  /// When the waveform was generated
  final DateTime generatedAt;

  const WaveformMetadata({required this.resolution, required this.type, required this.normalized, required this.generatedAt});

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {'resolution': resolution, 'type': type.name, 'normalized': normalized, 'generatedAt': generatedAt.toIso8601String()};
  }

  /// Create from JSON
  factory WaveformMetadata.fromJson(Map<String, dynamic> json) {
    return WaveformMetadata(
      resolution: json['resolution'] as int,
      type: WaveformType.values.firstWhere((e) => e.name == json['type'], orElse: () => WaveformType.bars),
      normalized: json['normalized'] as bool,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'WaveformMetadata(resolution: $resolution, type: $type, '
        'normalized: $normalized, generatedAt: $generatedAt)';
  }
}

/// Processed waveform data for visualization
class WaveformData implements Disposable {
  /// Amplitude values for each data point (0.0 to 1.0)
  final List<double> amplitudes;

  /// Duration of the original audio
  final Duration duration;

  /// Sample rate of the original audio
  final int sampleRate;

  /// Metadata about the waveform generation
  final WaveformMetadata metadata;

  const WaveformData({required this.amplitudes, required this.duration, required this.sampleRate, required this.metadata});

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {'amplitudes': amplitudes, 'duration': duration.inMicroseconds, 'sampleRate': sampleRate, 'metadata': metadata.toJson()};
  }

  /// Create from JSON
  factory WaveformData.fromJson(Map<String, dynamic> json) {
    return WaveformData(
      amplitudes: (json['amplitudes'] as List).cast<double>(),
      duration: Duration(microseconds: json['duration'] as int),
      sampleRate: json['sampleRate'] as int,
      metadata: WaveformMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  /// Create from pre-generated amplitude data (simplified for display only)
  factory WaveformData.fromAmplitudes(List<double> amplitudes) {
    return WaveformData(
      amplitudes: amplitudes,
      duration: const Duration(seconds: 1), // Default duration
      sampleRate: 44100, // Default sample rate
      metadata: WaveformMetadata(resolution: amplitudes.length, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
    );
  }

  /// Create from JSON string
  factory WaveformData.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return WaveformData.fromJson(json);
  }

  /// Create from amplitude list in JSON string format
  factory WaveformData.fromAmplitudeString(String amplitudeString) {
    final List<double> amplitudes = (jsonDecode(amplitudeString) as List).cast<double>();
    return WaveformData.fromAmplitudes(amplitudes);
  }

  /// Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Dispose of resources (for memory management)
  @override
  void dispose() {
    // Clear the amplitudes list to help with garbage collection
    amplitudes.clear();
  }

  @override
  String toString() {
    return 'WaveformData(amplitudes: ${amplitudes.length}, duration: $duration, '
        'sampleRate: $sampleRate, metadata: $metadata)';
  }
}

/// Represents a chunk of waveform data for streaming processing
class WaveformChunk {
  /// Amplitude values in this chunk
  final List<double> amplitudes;

  /// Starting time offset for this chunk
  final Duration startTime;

  /// Whether this is the last chunk in the stream
  final bool isLast;

  const WaveformChunk({required this.amplitudes, required this.startTime, required this.isLast});

  @override
  String toString() {
    return 'WaveformChunk(amplitudes: ${amplitudes.length}, '
        'startTime: $startTime, isLast: $isLast)';
  }
}
