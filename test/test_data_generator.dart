// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

/// Generates test audio files and reference data for comprehensive testing
class TestDataGenerator {
  static const String assetsPath = 'test/assets';

  /// Generates all test audio files and reference data
  static Future<void> generateAllTestData() async {
    await _ensureAssetsDirectory();

    // Generate valid audio files
    await _generateValidAudioFiles();

    // Generate corrupted files for error testing
    await _generateCorruptedFiles();

    // Generate reference waveform data
    await _generateReferenceWaveformData();

    // Generate test configurations
    await _generateTestConfigurations();

    print('All test data generated successfully');
  }

  static Future<void> _ensureAssetsDirectory() async {
    final directory = Directory(assetsPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// Generates valid audio files for testing
  static Future<void> _generateValidAudioFiles() async {
    // Generate WAV files with different configurations
    await _generateWavFile('test_mono_44100.wav', sampleRate: 44100, channels: 1, durationSeconds: 1);
    await _generateWavFile('test_stereo_44100.wav', sampleRate: 44100, channels: 2, durationSeconds: 1);
    await _generateWavFile('test_mono_48000.wav', sampleRate: 48000, channels: 1, durationSeconds: 1);

    // Generate files of different sizes for performance testing
    await _generateWavFile('test_short.wav', sampleRate: 44100, channels: 1, durationSeconds: 0.1);
    await _generateWavFile('test_medium.wav', sampleRate: 44100, channels: 2, durationSeconds: 10);
    await _generateWavFile('test_large.wav', sampleRate: 44100, channels: 2, durationSeconds: 60);

    // Generate synthetic MP3-like data (placeholder for actual MP3 generation)
    await _generateSyntheticAudioFile('test_short.mp3', format: 'mp3', durationSeconds: 1);
    await _generateSyntheticAudioFile('test_medium.mp3', format: 'mp3', durationSeconds: 10);
    await _generateSyntheticAudioFile('test_large.mp3', format: 'mp3', durationSeconds: 60);

    // Generate other format placeholders
    await _generateSyntheticAudioFile('test_sample.flac', format: 'flac', durationSeconds: 2);
    await _generateSyntheticAudioFile('test_sample.ogg', format: 'ogg', durationSeconds: 2);
    await _generateSyntheticAudioFile('test_sample.opus', format: 'opus', durationSeconds: 2);
  }

  /// Generates a WAV file with synthetic audio data
  static Future<void> _generateWavFile(String filename, {required int sampleRate, required int channels, required double durationSeconds}) async {
    final samples = _generateSyntheticAudio(sampleRate, channels, durationSeconds);
    final wavData = _createWavData(samples, sampleRate, channels);

    final file = File('$assetsPath/$filename');
    await file.writeAsBytes(wavData);
    print('Generated: $filename');
  }

  /// Generates synthetic audio data (sine wave with some variation)
  static List<double> _generateSyntheticAudio(int sampleRate, int channels, double durationSeconds) {
    final totalSamples = (sampleRate * durationSeconds * channels).round();
    final samples = <double>[];

    for (int i = 0; i < totalSamples; i++) {
      final time = i / (sampleRate * channels);
      final channel = i % channels;

      // Generate different frequencies for different channels
      final frequency = 440.0 + (channel * 220.0); // A4 and A5

      // Create a sine wave with some amplitude variation
      final amplitude = 0.5 * (1.0 + 0.3 * math.sin(time * 2.0));
      final sample = amplitude * math.sin(2.0 * math.pi * frequency * time);

      samples.add(sample);
    }

    return samples;
  }

  /// Creates WAV file data from audio samples
  static Uint8List _createWavData(List<double> samples, int sampleRate, int channels) {
    final bytesPerSample = 2; // 16-bit
    final dataSize = samples.length * bytesPerSample;
    final fileSize = 44 + dataSize - 8;

    final buffer = ByteData(44 + dataSize);

    // WAV header
    buffer.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    buffer.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    buffer.setUint32(16, 16, Endian.little); // PCM header size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
    buffer.setUint16(32, channels * bytesPerSample, Endian.little);
    buffer.setUint16(34, bytesPerSample * 8, Endian.little);
    buffer.setUint32(36, 0x64617461, Endian.big); // "data"
    buffer.setUint32(40, dataSize, Endian.little);

    // Audio data (convert to 16-bit PCM)
    for (int i = 0; i < samples.length; i++) {
      final sample = (samples[i] * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// Generates synthetic audio files for non-WAV formats
  static Future<void> _generateSyntheticAudioFile(String filename, {required String format, required double durationSeconds}) async {
    // For testing purposes, we'll create files with synthetic headers
    // In a real implementation, you'd use proper encoding libraries

    final data = _createSyntheticFormatData(format, durationSeconds);
    final file = File('$assetsPath/$filename');
    await file.writeAsBytes(data);
    print('Generated: $filename');
  }

  /// Creates synthetic data for different audio formats
  static Uint8List _createSyntheticFormatData(String format, double durationSeconds) {
    final dataSize = (44100 * 2 * durationSeconds).round(); // Approximate size
    final data = Uint8List(dataSize);

    switch (format.toLowerCase()) {
      case 'mp3':
        // MP3 header signature
        data[0] = 0xFF;
        data[1] = 0xFB;
        data[2] = 0x90;
        data[3] = 0x00;
        break;
      case 'flac':
        // FLAC header signature
        data[0] = 0x66; // 'f'
        data[1] = 0x4C; // 'L'
        data[2] = 0x61; // 'a'
        data[3] = 0x43; // 'C'
        break;
      case 'ogg':
        // OGG header signature
        data[0] = 0x4F; // 'O'
        data[1] = 0x67; // 'g'
        data[2] = 0x67; // 'g'
        data[3] = 0x53; // 'S'
        break;
      case 'opus':
        // Opus in OGG container
        data[0] = 0x4F; // 'O'
        data[1] = 0x67; // 'g'
        data[2] = 0x67; // 'g'
        data[3] = 0x53; // 'S'
        // Add Opus identification header later in the stream
        break;
    }

    // Fill with synthetic audio-like data
    final random = math.Random(42); // Fixed seed for reproducible tests
    for (int i = 4; i < data.length; i++) {
      data[i] = random.nextInt(256);
    }

    return data;
  }

  /// Generates corrupted files for error testing
  static Future<void> _generateCorruptedFiles() async {
    // Corrupted MP3 header
    final corruptedMp3 = Uint8List(1000);
    corruptedMp3[0] = 0xFF; // Start of MP3 header
    corruptedMp3[1] = 0x00; // Corrupted second byte
    await File('$assetsPath/corrupted_header.mp3').writeAsBytes(corruptedMp3);

    // Corrupted WAV data
    final corruptedWav = _createWavData([0.5, -0.5, 0.8, -0.8], 44100, 1);
    // Corrupt the data section
    for (int i = 44; i < corruptedWav.length; i += 10) {
      corruptedWav[i] = 0xFF;
    }
    await File('$assetsPath/corrupted_data.wav').writeAsBytes(corruptedWav);

    // Truncated FLAC
    final truncatedFlac = _createSyntheticFormatData('flac', 1.0);
    final truncated = truncatedFlac.sublist(0, truncatedFlac.length ~/ 2);
    await File('$assetsPath/truncated.flac').writeAsBytes(truncated);

    // Invalid format
    await File('$assetsPath/invalid_format.xyz').writeAsString('This is not audio data');

    // Empty file
    await File('$assetsPath/empty_file.mp3').writeAsBytes(Uint8List(0));

    print('Generated corrupted test files');
  }

  /// Generates reference waveform data for validation
  static Future<void> _generateReferenceWaveformData() async {
    final referenceData = {
      'test_mono_44100.wav': {
        'duration_ms': 1000,
        'sample_rate': 44100,
        'channels': 1,
        'expected_amplitudes_1000': _generateExpectedAmplitudes(1000),
        'expected_amplitudes_500': _generateExpectedAmplitudes(500),
        'expected_amplitudes_100': _generateExpectedAmplitudes(100),
        'peak_amplitude': 0.65, // Approximate peak from synthetic data
        'rms_amplitude': 0.35, // Approximate RMS from synthetic data
      },
      'test_stereo_44100.wav': {
        'duration_ms': 1000,
        'sample_rate': 44100,
        'channels': 2,
        'expected_amplitudes_1000': _generateExpectedAmplitudes(1000),
        'expected_amplitudes_500': _generateExpectedAmplitudes(500),
        'expected_amplitudes_100': _generateExpectedAmplitudes(100),
        'peak_amplitude': 0.65,
        'rms_amplitude': 0.35,
      },
      'test_short.wav': {
        'duration_ms': 100,
        'sample_rate': 44100,
        'channels': 1,
        'expected_amplitudes_100': _generateExpectedAmplitudes(100),
        'peak_amplitude': 0.65,
        'rms_amplitude': 0.35,
      },
    };

    final file = File('$assetsPath/reference_waveforms.json');
    await file.writeAsString(jsonEncode(referenceData));
    print('Generated reference waveform data');
  }

  /// Generates expected amplitude values for testing
  static List<double> _generateExpectedAmplitudes(int resolution) {
    final amplitudes = <double>[];

    for (int i = 0; i < resolution; i++) {
      final time = i / resolution;
      // Simulate the expected waveform pattern from our synthetic audio
      final amplitude = 0.5 * (1.0 + 0.3 * math.sin(time * 2.0 * math.pi));
      amplitudes.add(amplitude);
    }

    return amplitudes;
  }

  /// Generates test configurations for various scenarios
  static Future<void> _generateTestConfigurations() async {
    final configurations = {
      'performance_test_configs': [
        {'name': 'low_resolution', 'resolution': 100, 'expected_processing_time_ms': 50, 'expected_memory_usage_mb': 1},
        {'name': 'medium_resolution', 'resolution': 1000, 'expected_processing_time_ms': 200, 'expected_memory_usage_mb': 5},
        {'name': 'high_resolution', 'resolution': 5000, 'expected_processing_time_ms': 1000, 'expected_memory_usage_mb': 20},
      ],
      'memory_test_configs': [
        {'name': 'small_file', 'file': 'test_short.wav', 'max_memory_mb': 2},
        {'name': 'medium_file', 'file': 'test_medium.wav', 'max_memory_mb': 10},
        {'name': 'large_file', 'file': 'test_large.wav', 'max_memory_mb': 50},
      ],
      'error_test_scenarios': [
        {'name': 'corrupted_header', 'file': 'corrupted_header.mp3', 'expected_exception': 'DecodingException'},
        {'name': 'corrupted_data', 'file': 'corrupted_data.wav', 'expected_exception': 'DecodingException'},
        {'name': 'truncated_file', 'file': 'truncated.flac', 'expected_exception': 'DecodingException'},
        {'name': 'invalid_format', 'file': 'invalid_format.xyz', 'expected_exception': 'UnsupportedFormatException'},
        {'name': 'empty_file', 'file': 'empty_file.mp3', 'expected_exception': 'DecodingException'},
      ],
      'format_test_files': {
        'mp3': ['test_short.mp3', 'test_medium.mp3', 'test_large.mp3'],
        'wav': ['test_mono_44100.wav', 'test_stereo_44100.wav', 'test_mono_48000.wav'],
        'flac': ['test_sample.flac'],
        'ogg': ['test_sample.ogg'],
        'opus': ['test_sample.opus'],
      },
    };

    final file = File('$assetsPath/test_configurations.json');
    await file.writeAsString(jsonEncode(configurations));
    print('Generated test configurations');
  }
}

/// Utility class for loading test data in tests
class TestDataLoader {
  static const String assetsPath = 'test/assets';

  /// Loads reference waveform data
  static Future<Map<String, dynamic>> loadReferenceWaveforms() async {
    final file = File('$assetsPath/reference_waveforms.json');
    final content = await file.readAsString();
    return jsonDecode(content);
  }

  /// Loads test configurations
  static Future<Map<String, dynamic>> loadTestConfigurations() async {
    final file = File('$assetsPath/test_configurations.json');
    final content = await file.readAsString();
    return jsonDecode(content);
  }

  /// Gets the full path to a test asset file
  static String getAssetPath(String filename) {
    return '$assetsPath/$filename';
  }

  /// Checks if a test asset file exists
  static Future<bool> assetExists(String filename) async {
    final file = File(getAssetPath(filename));
    return await file.exists();
  }

  /// Gets the size of a test asset file
  static Future<int> getAssetSize(String filename) async {
    final file = File(getAssetPath(filename));
    return await file.length();
  }
}
