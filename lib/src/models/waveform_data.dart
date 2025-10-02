import 'dart:convert';

import 'waveform_type.dart';
import 'waveform_metadata.dart';

/// The main data structure containing processed audio waveform information.
///
/// This class represents the result of audio processing and contains all the
/// information needed to visualize an audio waveform. It includes amplitude
/// data points, metadata about the source audio, and generation parameters.
///
/// ## Key Features
///
/// - **Memory Efficient**: Implements [Disposable] for explicit cleanup
/// - **Serializable**: Full JSON support for caching and storage
/// - **Comprehensive**: Includes both waveform and source audio metadata
/// - **Flexible Creation**: Multiple factory constructors for different use cases
///
/// ## Basic Usage
///
/// ```dart
/// // Generate from audio file using Sonix
/// final sonix = Sonix();
/// final waveformData = await sonix.generateWaveform('audio.mp3');
///
/// // Access amplitude values for visualization
/// print('Waveform has ${waveformData.amplitudes.length} points');
/// print('Audio duration: ${waveformData.duration}');
/// print('Sample rate: ${waveformData.sampleRate} Hz');
///
/// // Clean up when done
/// waveformData.dispose();
/// ```
///
/// ## Custom Creation
///
/// ```dart
/// // Create from existing amplitude data
/// final customWaveform = WaveformData.fromAmplitudes([
///   0.1, 0.5, 0.8, 0.3, 0.9, 0.2, 0.6, 0.4
/// ]);
///
/// // Create from JSON string (useful for caching)
/// final cachedWaveform = WaveformData.fromJsonString(jsonString);
/// ```
///
/// ## Serialization
///
/// ```dart
/// // Save to JSON for caching
/// final jsonString = waveformData.toJsonString();
/// await File('waveform_cache.json').writeAsString(jsonString);
///
/// // Restore from cached JSON
/// final cached = await File('waveform_cache.json').readAsString();
/// final waveformData = WaveformData.fromJsonString(cached);
/// ```
class WaveformData {
  /// Array of amplitude values representing the waveform visualization.
  ///
  /// Each value represents the amplitude at a specific time position,
  /// typically normalized to the range 0.0 to 1.0 where:
  /// - 0.0 = silence (no amplitude)
  /// - 1.0 = maximum amplitude in the audio
  ///
  /// The number of values equals the resolution specified during generation.
  /// Values are evenly distributed across the audio duration.
  ///
  /// ## Example
  /// ```dart
  /// // Access individual amplitude points
  /// for (int i = 0; i < waveformData.amplitudes.length; i++) {
  ///   final amplitude = waveformData.amplitudes[i];
  ///   final timePosition = (i / waveformData.amplitudes.length) *
  ///                       waveformData.duration.inMilliseconds;
  ///   print('At ${timePosition}ms: amplitude $amplitude');
  /// }
  /// ```
  final List<double> amplitudes;

  /// Total duration of the source audio file.
  ///
  /// This represents the complete playback time of the original audio,
  /// not the time it took to generate the waveform. Use this to calculate
  /// time positions when mapping amplitude indices to playback time.
  final Duration duration;

  /// Sample rate of the original audio in Hz (samples per second).
  ///
  /// Common values include:
  /// - 44,100 Hz: CD quality
  /// - 48,000 Hz: Professional audio
  /// - 22,050 Hz: Lower quality/streaming
  /// - 96,000 Hz: High-resolution audio
  ///
  /// This information helps with accurate time calculations and audio quality
  /// assessment.
  final int sampleRate;

  /// Metadata describing how this waveform was generated.
  ///
  /// Contains generation parameters, timing information, and configuration
  /// details. See [WaveformMetadata] for complete information.
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

  /// Creates a [WaveformData] instance with pre-generated amplitude values.
  ///
  /// This factory constructor is useful when you have amplitude data from
  /// another source or want to create test/demo waveforms. It generates
  /// default metadata with current timestamp.
  ///
  /// **Parameters:**
  /// - [amplitudes]: List of amplitude values (should be 0.0 to 1.0 range)
  ///
  /// **Returns:** [WaveformData] with default audio properties
  ///
  /// ## Example
  /// ```dart
  /// // Create a simple test waveform
  /// final testAmplitudes = List.generate(100, (i) =>
  ///   math.sin(i * 0.1) * 0.5 + 0.5); // Sine wave pattern
  /// final waveform = WaveformData.fromAmplitudes(testAmplitudes);
  ///
  /// // Use in a widget
  /// WaveformWidget(waveformData: waveform)
  /// ```
  ///
  /// **Note:** Uses default duration (1 second) and sample rate (44,100 Hz).
  /// For accurate time representation, use the main constructor with real
  /// audio metadata.
  factory WaveformData.fromAmplitudes(List<double> amplitudes) {
    return WaveformData(
      amplitudes: amplitudes,
      duration: const Duration(seconds: 1), // Default duration
      sampleRate: 44100, // Default sample rate
      metadata: WaveformMetadata(resolution: amplitudes.length, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
    );
  }

  /// Creates a [WaveformData] instance from a JSON string.
  ///
  /// Deserializes a complete waveform data structure that was previously
  /// saved using [toJsonString]. This is useful for caching generated
  /// waveforms to avoid expensive regeneration.
  ///
  /// **Parameters:**
  /// - [jsonString]: Valid JSON string created by [toJsonString]
  ///
  /// **Returns:** Fully restored [WaveformData] instance
  ///
  /// **Throws:** [FormatException] if JSON string is invalid
  ///
  /// ## Example
  /// ```dart
  /// // Save waveform data
  /// final originalWaveform = await sonix.generateWaveform('audio.mp3');
  /// final jsonString = originalWaveform.toJsonString();
  /// await File('cache.json').writeAsString(jsonString);
  ///
  /// // Later, restore from cache
  /// final cachedJson = await File('cache.json').readAsString();
  /// final restoredWaveform = WaveformData.fromJsonString(cachedJson);
  ///
  /// // Verify integrity
  /// assert(restoredWaveform.amplitudes.length ==
  ///        originalWaveform.amplitudes.length);
  /// ```
  factory WaveformData.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return WaveformData.fromJson(json);
  }

  /// Creates a [WaveformData] instance from amplitude values in JSON format.
  ///
  /// This is a simplified version of [fromJsonString] that only requires
  /// the amplitude array in JSON format. Useful when you only have the
  /// waveform shape data without metadata.
  ///
  /// **Parameters:**
  /// - [amplitudeString]: JSON array string containing amplitude values
  ///
  /// **Returns:** [WaveformData] with default metadata
  ///
  /// ## Example
  /// ```dart
  /// // From a JSON array string
  /// final amplitudeJson = '[0.1, 0.5, 0.8, 0.3, 0.9, 0.2]';
  /// final waveform = WaveformData.fromAmplitudeString(amplitudeJson);
  ///
  /// // From API response containing only amplitudes
  /// final response = await http.get('/api/waveform/123');
  /// final waveform = WaveformData.fromAmplitudeString(response.body);
  /// ```
  factory WaveformData.fromAmplitudeString(String amplitudeString) {
    final List<double> amplitudes = (jsonDecode(amplitudeString) as List).cast<double>();
    return WaveformData.fromAmplitudes(amplitudes);
  }

  /// Converts the waveform data to a JSON string for serialization.
  ///
  /// This creates a complete JSON representation including all amplitude data,
  /// metadata, and audio properties. The resulting string can be stored in
  /// files, databases, or transmitted over networks.
  ///
  /// **Returns:** Complete JSON string representation
  ///
  /// ## Example
  /// ```dart
  /// final waveform = await sonix.generateWaveform('audio.mp3');
  ///
  /// // Save to local storage
  /// final jsonString = waveform.toJsonString();
  /// SharedPreferences prefs = await SharedPreferences.getInstance();
  /// await prefs.setString('cached_waveform', jsonString);
  ///
  /// // Save to file
  /// final file = File('waveform_cache.json');
  /// await file.writeAsString(jsonString);
  /// ```
  ///
  /// **See also:** [fromJsonString] for restoring from JSON
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Releases memory resources used by this waveform data.
  ///
  /// This method clears the amplitude data array to help with garbage collection
  /// and reduce memory usage. Call this when the waveform data is no longer needed,
  /// especially for large waveforms or in memory-constrained environments.
  ///
  /// **Important:** After calling dispose(), this object should not be used further.
  /// Accessing [amplitudes] after disposal will result in an empty list.
  ///
  /// ## Example
  /// ```dart
  /// final waveform = await sonix.generateWaveform('large_audio.mp3');
  ///
  /// // Use the waveform data
  /// WaveformWidget(waveformData: waveform);
  ///
  /// // Clean up when done (e.g., in dispose() method)
  /// waveform.dispose();
  /// ```
  ///
  /// **Best Practice:** Always dispose of waveform data in your widget's
  /// dispose() method or when changing to different audio files.
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
