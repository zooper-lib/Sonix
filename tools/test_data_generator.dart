// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

/// Generates test audio files and reference data for comprehensive testing
class TestDataGenerator {
  static const String assetsPath = 'test/assets';
  static const String generatedPath = 'test/assets/generated';
  static const String largeFilesPath = 'test/assets/generated/large_files';

  /// File size categories for comprehensive testing
  static const Map<String, int> fileSizes = {
    'tiny': 100 * 1024, // 100KB
    'small': 1024 * 1024, // 1MB
    'medium': 10 * 1024 * 1024, // 10MB
    'large': 100 * 1024 * 1024, // 100MB
    'xlarge': 500 * 1024 * 1024, // 500MB
    'huge': 1024 * 1024 * 1024, // 1GB
    'massive': 5 * 1024 * 1024 * 1024, // 5GB (int limit consideration)
  };

  /// Audio characteristics for testing
  static const List<Map<String, dynamic>> audioCharacteristics = [
    {'sampleRate': 8000, 'channels': 1, 'bitDepth': 16}, // Low quality mono
    {'sampleRate': 22050, 'channels': 1, 'bitDepth': 16}, // Medium quality mono
    {'sampleRate': 44100, 'channels': 1, 'bitDepth': 16}, // CD quality mono
    {'sampleRate': 44100, 'channels': 2, 'bitDepth': 16}, // CD quality stereo
    {'sampleRate': 48000, 'channels': 2, 'bitDepth': 24}, // High quality stereo
    {'sampleRate': 96000, 'channels': 2, 'bitDepth': 24}, // Very high quality
    {'sampleRate': 44100, 'channels': 6, 'bitDepth': 16}, // 5.1 surround
  ];

  /// Supported audio formats
  static const List<String> supportedFormats = ['wav', 'mp3', 'flac', 'ogg'];

  /// Generates all test audio files and reference data
  static Future<void> generateAllTestData({bool force = false}) async {
    await _ensureAssetsDirectory();
    await _ensureGeneratedDirectory();
    await _ensureLargeFilesDirectory();

    // Check if files already exist (unless forced)
    if (!force && await _hasBasicTestFiles()) {
      print('Test files already exist, skipping generation (use force: true to regenerate)');
      return;
    }

    print('Generating comprehensive test file suite...');

    // Generate basic test files (existing functionality)
    await _generateValidAudioFiles();

    // Generate comprehensive test file suite
    await generateComprehensiveTestSuite();

    // Generate corrupted files for error testing
    await _generateCorruptedFiles();

    // Generate reference waveform data
    await _generateReferenceWaveformData();

    // Generate test configurations
    await _generateTestConfigurations();

    print('All test data generated successfully');
  }

  /// Generates only essential test files (faster for regular testing)
  static Future<void> generateEssentialTestData({bool force = false}) async {
    await _ensureAssetsDirectory();
    await _ensureGeneratedDirectory();

    // Check if essential files already exist (unless forced)
    if (!force && await _hasEssentialTestFiles()) {
      print('Essential test files already exist, skipping generation');
      return;
    }

    print('Generating essential test files (optimized for speed)...');

    // Generate only basic test files with smaller sizes
    await _generateEssentialValidAudioFiles();

    // Generate a minimal set of corrupted files
    await _generateMinimalCorruptedFiles();

    // Generate reference waveform data
    await _generateReferenceWaveformData();

    // Generate test configurations
    await _generateTestConfigurations();

    print('Essential test data generated successfully');
  }

  /// Checks if basic test files exist
  static Future<bool> _hasBasicTestFiles() async {
    final basicFiles = [
      '$generatedPath/mono_44100.wav',
      '$generatedPath/stereo_44100.wav',
      '$generatedPath/short_duration.mp3',
      '$generatedPath/sample_audio.flac',
    ];

    for (final filePath in basicFiles) {
      if (!await File(filePath).exists()) {
        return false;
      }
    }
    return true;
  }

  /// Checks if essential test files exist
  static Future<bool> _hasEssentialTestFiles() async {
    final essentialFiles = [
      '$generatedPath/mono_44100.wav',
      '$generatedPath/stereo_44100.wav',
      '$generatedPath/short_duration.mp3',
      '$generatedPath/sample_audio.flac',
      '$generatedPath/sample_audio.ogg',
      '$generatedPath/corrupted_header.mp3',
      '$generatedPath/empty_file.wav',
      '$generatedPath/invalid_format.xyz',
      '$assetsPath/reference_waveforms.json',
      '$assetsPath/test_configurations.json',
    ];

    // Check if at least 80% of essential files exist (allows for some missing files)
    int existingFiles = 0;
    for (final filePath in essentialFiles) {
      if (await File(filePath).exists()) {
        existingFiles++;
      }
    }

    final threshold = (essentialFiles.length * 0.8).ceil();
    final hasEnoughFiles = existingFiles >= threshold;

    if (hasEnoughFiles) {
      print('Found $existingFiles/${essentialFiles.length} essential test files, skipping generation');
    }

    return hasEnoughFiles;
  }

  /// Generates comprehensive test suite with various sizes and characteristics
  static Future<void> generateComprehensiveTestSuite() async {
    print('Generating files of various sizes and characteristics...');

    for (final format in supportedFormats) {
      for (final sizeEntry in fileSizes.entries) {
        final sizeName = sizeEntry.key;
        final targetSize = sizeEntry.value;

        // Skip massive and huge files in CI/automated testing or when memory is limited
        if ((sizeName == 'massive' || sizeName == 'huge') && (Platform.environment['CI'] == 'true' || Platform.environment['SKIP_LARGE_FILES'] == 'true')) {
          print('Skipping $sizeName file generation in CI/limited memory environment');
          continue;
        }

        // Skip huge files by default to prevent memory issues
        if (sizeName == 'huge' || sizeName == 'massive') {
          print('Skipping $sizeName file generation to prevent memory issues');
          continue;
        }

        // Generate files with different audio characteristics
        for (int i = 0; i < audioCharacteristics.length; i++) {
          final characteristics = audioCharacteristics[i];
          final filename = '${format}_${sizeName}_${characteristics['sampleRate']}_${characteristics['channels']}ch.$format';

          try {
            await _generateTestFileWithSize(
              filename,
              format,
              targetSize,
              characteristics['sampleRate'],
              characteristics['channels'],
              characteristics['bitDepth'],
            );

            // Only generate one characteristic per size for very large files to save space
            if (targetSize > 100 * 1024 * 1024) break;
          } catch (e) {
            print('Warning: Failed to generate $filename: $e');
          }
        }
      }
    }
  }

  static Future<void> _ensureAssetsDirectory() async {
    final directory = Directory(assetsPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static Future<void> _ensureGeneratedDirectory() async {
    final directory = Directory(generatedPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static Future<void> _ensureLargeFilesDirectory() async {
    final directory = Directory(largeFilesPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// Generates a test file with specific target size and audio characteristics
  static Future<void> _generateTestFileWithSize(String filename, String format, int targetSize, int sampleRate, int channels, int bitDepth) async {
    final isLargeFile = targetSize > 50 * 1024 * 1024; // 50MB threshold
    final filePath = isLargeFile ? '$largeFilesPath/$filename' : '$generatedPath/$filename';

    print('Generating $filename (target: ${formatFileSize(targetSize)})...');

    switch (format.toLowerCase()) {
      case 'wav':
        await generateWavFileWithSize(filePath, targetSize, sampleRate, channels, bitDepth);
        break;
      case 'mp3':
        await _generateMp3FileWithSize(filePath, targetSize, sampleRate, channels);
        break;
      case 'flac':
        await _generateFlacFileWithSize(filePath, targetSize, sampleRate, channels, bitDepth);
        break;
      case 'ogg':
        await _generateOggFileWithSize(filePath, targetSize, sampleRate, channels);
        break;
      default:
        throw ArgumentError('Unsupported format: $format');
    }

    final actualSize = await File(filePath).length();
    print('Generated $filename: ${formatFileSize(actualSize)}');
  }

  /// Generates WAV file with specific target size
  static Future<void> generateWavFileWithSize(String filePath, int targetSize, int sampleRate, int channels, int bitDepth) async {
    final bytesPerSample = bitDepth ~/ 8;
    final headerSize = 44;
    final dataSize = targetSize - headerSize;
    final totalSamples = dataSize ~/ (bytesPerSample * channels);
    final durationSeconds = totalSamples / sampleRate;

    final samples = _generateSyntheticAudioWithDuration(sampleRate, channels, durationSeconds);
    final wavData = _createWavDataWithBitDepth(samples, sampleRate, channels, bitDepth);

    final file = File(filePath);
    await file.writeAsBytes(wavData);
  }

  /// Generates MP3 file with specific target size (synthetic)
  static Future<void> _generateMp3FileWithSize(String filePath, int targetSize, int sampleRate, int channels) async {
    // Create synthetic MP3-like data with proper headers
    final data = Uint8List(targetSize);

    // MP3 frame header pattern
    final frameSize = 417; // Typical MP3 frame size for 128kbps
    int offset = 0;

    while (offset + frameSize < targetSize) {
      // MP3 sync word and header
      data[offset] = 0xFF;
      data[offset + 1] = 0xFB; // MPEG-1 Layer III
      data[offset + 2] = 0x90; // 128kbps, 44.1kHz
      data[offset + 3] = 0x00;

      // Fill frame with synthetic audio-like data
      final random = math.Random(offset);
      for (int i = 4; i < frameSize && offset + i < targetSize; i++) {
        data[offset + i] = random.nextInt(256);
      }

      offset += frameSize;
    }

    final file = File(filePath);
    await file.writeAsBytes(data);
  }

  /// Generates FLAC file with specific target size (synthetic)
  static Future<void> _generateFlacFileWithSize(String filePath, int targetSize, int sampleRate, int channels, int bitDepth) async {
    final data = Uint8List(targetSize);

    // FLAC signature
    data[0] = 0x66; // 'f'
    data[1] = 0x4C; // 'L'
    data[2] = 0x61; // 'a'
    data[3] = 0x43; // 'C'

    // STREAMINFO metadata block header
    data[4] = 0x00; // Last metadata block flag + block type
    data[5] = 0x00; // Block length (3 bytes)
    data[6] = 0x00;
    data[7] = 0x22; // 34 bytes

    // STREAMINFO data (simplified)
    final streamInfo = ByteData.view(data.buffer, 8, 34);
    streamInfo.setUint16(0, 4096, Endian.big); // Min block size
    streamInfo.setUint16(2, 4096, Endian.big); // Max block size
    streamInfo.setUint32(10, sampleRate << 12 | (channels - 1) << 9 | (bitDepth - 1) << 4, Endian.big);

    // Fill rest with synthetic FLAC frame data
    final random = math.Random(42);
    for (int i = 42; i < targetSize; i++) {
      data[i] = random.nextInt(256);
    }

    final file = File(filePath);
    await file.writeAsBytes(data);
  }

  /// Generates OGG file with specific target size (synthetic)
  static Future<void> _generateOggFileWithSize(String filePath, int targetSize, int sampleRate, int channels) async {
    final data = Uint8List(targetSize);

    // OGG page header pattern
    final pageSize = 4096; // Typical OGG page size
    int offset = 0;

    while (offset + 27 < targetSize) {
      // Minimum OGG page header size
      // OGG page header
      data[offset] = 0x4F; // 'O'
      data[offset + 1] = 0x67; // 'g'
      data[offset + 2] = 0x67; // 'g'
      data[offset + 3] = 0x53; // 'S'
      data[offset + 4] = 0x00; // Version
      data[offset + 5] = 0x02; // Header type (continued page)

      // Fill page with synthetic Vorbis-like data
      final pageEnd = math.min(offset + pageSize, targetSize);
      final random = math.Random(offset);
      for (int i = offset + 27; i < pageEnd; i++) {
        data[i] = random.nextInt(256);
      }

      offset += pageSize;
    }

    final file = File(filePath);
    await file.writeAsBytes(data);
  }

  /// Generates synthetic audio with specific duration
  static List<double> _generateSyntheticAudioWithDuration(int sampleRate, int channels, double durationSeconds) {
    final totalSamples = (sampleRate * durationSeconds * channels).round();
    final samples = <double>[];

    for (int i = 0; i < totalSamples; i++) {
      final time = i / (sampleRate * channels);
      final channel = i % channels;

      // Generate different frequencies for different channels
      final frequency = 440.0 + (channel * 220.0); // A4 and higher

      // Create a complex waveform with harmonics
      final fundamental = 0.5 * math.sin(2.0 * math.pi * frequency * time);
      final harmonic2 = 0.25 * math.sin(2.0 * math.pi * frequency * 2 * time);
      final harmonic3 = 0.125 * math.sin(2.0 * math.pi * frequency * 3 * time);

      // Add some amplitude modulation
      final modulation = 1.0 + 0.3 * math.sin(time * 2.0);

      final sample = (fundamental + harmonic2 + harmonic3) * modulation * 0.7;
      samples.add(sample.clamp(-1.0, 1.0));
    }

    return samples;
  }

  /// Creates WAV file data with specific bit depth
  static Uint8List _createWavDataWithBitDepth(List<double> samples, int sampleRate, int channels, int bitDepth) {
    final bytesPerSample = bitDepth ~/ 8;
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
    buffer.setUint16(34, bitDepth, Endian.little);
    buffer.setUint32(36, 0x64617461, Endian.big); // "data"
    buffer.setUint32(40, dataSize, Endian.little);

    // Audio data
    for (int i = 0; i < samples.length; i++) {
      switch (bitDepth) {
        case 16:
          final sample = (samples[i] * 32767).round().clamp(-32768, 32767);
          buffer.setInt16(44 + i * 2, sample, Endian.little);
          break;
        case 24:
          final sample = (samples[i] * 8388607).round().clamp(-8388608, 8388607);
          final bytes = ByteData(4)..setInt32(0, sample, Endian.little);
          buffer.setUint8(44 + i * 3, bytes.getUint8(0));
          buffer.setUint8(44 + i * 3 + 1, bytes.getUint8(1));
          buffer.setUint8(44 + i * 3 + 2, bytes.getUint8(2));
          break;
        case 32:
          buffer.setFloat32(44 + i * 4, samples[i], Endian.little);
          break;
        default:
          throw ArgumentError('Unsupported bit depth: $bitDepth');
      }
    }

    return buffer.buffer.asUint8List();
  }

  /// Formats file size for human-readable output
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Generates valid audio files for testing
  static Future<void> _generateValidAudioFiles() async {
    // Generate WAV files with different configurations
    await _generateWavFile('mono_44100.wav', sampleRate: 44100, channels: 1, durationSeconds: 1);
    await _generateWavFile('stereo_44100.wav', sampleRate: 44100, channels: 2, durationSeconds: 1);
    await _generateWavFile('mono_48000.wav', sampleRate: 48000, channels: 1, durationSeconds: 1);

    // Generate files of different sizes for performance testing
    await _generateWavFile('short_duration.wav', sampleRate: 44100, channels: 1, durationSeconds: 0.1);
    await _generateWavFile('medium_duration.wav', sampleRate: 44100, channels: 2, durationSeconds: 10);
    await _generateWavFile('long_duration.wav', sampleRate: 44100, channels: 2, durationSeconds: 60);

    // Generate synthetic MP3-like data (placeholder for actual MP3 generation)
    await _generateSyntheticAudioFile('short_duration.mp3', format: 'mp3', durationSeconds: 1);
    await _generateSyntheticAudioFile('medium_duration.mp3', format: 'mp3', durationSeconds: 10);
    await _generateSyntheticAudioFile('long_duration.mp3', format: 'mp3', durationSeconds: 60);

    // Generate other format placeholders
    await _generateSyntheticAudioFile('sample_audio.flac', format: 'flac', durationSeconds: 2);
    await _generateSyntheticAudioFile('sample_audio.ogg', format: 'ogg', durationSeconds: 2);
  }

  /// Generates essential valid audio files (smaller, faster for regular testing)
  static Future<void> _generateEssentialValidAudioFiles() async {
    // Generate only the most essential WAV files with shorter durations
    await _generateWavFile('mono_44100.wav', sampleRate: 44100, channels: 1, durationSeconds: 0.5);
    await _generateWavFile('stereo_44100.wav', sampleRate: 44100, channels: 2, durationSeconds: 0.5);

    // Generate minimal files for different sizes (much smaller than full suite)
    await _generateWavFile('short_duration.wav', sampleRate: 44100, channels: 1, durationSeconds: 0.1);
    await _generateWavFile('medium_duration.wav', sampleRate: 44100, channels: 2, durationSeconds: 1.0); // Reduced from 10s

    // Generate minimal synthetic files for other formats
    await _generateSyntheticAudioFile('short_duration.mp3', format: 'mp3', durationSeconds: 0.5);
    await _generateSyntheticAudioFile('sample_audio.flac', format: 'flac', durationSeconds: 0.5);
    await _generateSyntheticAudioFile('sample_audio.ogg', format: 'ogg', durationSeconds: 0.5);

    // Generate tiny files for each size category to satisfy test requirements
    await _generateTinyTestFiles();
  }

  /// Generates tiny test files for size categories (for testing without large files)
  static Future<void> _generateTinyTestFiles() async {
    // Generate tiny files for each format and size category (but keep them small)
    for (final format in supportedFormats) {
      for (final sizeName in ['tiny', 'small', 'medium']) {
        final filename = '${format}_${sizeName}_44100_2ch.$format';

        // Use very small durations to keep file sizes minimal
        final duration = sizeName == 'tiny' ? 0.01 : (sizeName == 'small' ? 0.05 : 0.1);

        try {
          switch (format.toLowerCase()) {
            case 'wav':
              await _generateWavFile(filename, sampleRate: 44100, channels: 2, durationSeconds: duration);
              break;
            default:
              await _generateSyntheticAudioFile(filename, format: format, durationSeconds: duration);
              break;
          }
        } catch (e) {
          print('Warning: Failed to generate tiny file $filename: $e');
        }
      }
    }
  }

  /// Generates a WAV file with synthetic audio data
  static Future<void> _generateWavFile(String filename, {required int sampleRate, required int channels, required double durationSeconds}) async {
    final samples = _generateSyntheticAudio(sampleRate, channels, durationSeconds);
    final wavData = _createWavData(samples, sampleRate, channels);

    final file = File('$generatedPath/$filename');
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
    final file = File('$generatedPath/$filename');
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
    print('Generating corrupted files for error testing...');

    // Generate corrupted files for each format
    for (final format in supportedFormats) {
      await _generateCorruptedFilesForFormat(format);
    }

    // Additional error scenarios
    await _generateAdditionalErrorScenarios();

    print('Generated corrupted test files');
  }

  /// Generates minimal set of corrupted files for essential testing
  static Future<void> _generateMinimalCorruptedFiles() async {
    print('Generating minimal corrupted files for error testing...');

    // Generate only essential corrupted files
    await _generateCorruptedMp3Files();
    await _generateCorruptedWavFiles();

    // Generate minimal additional error scenarios
    await File('$generatedPath/empty_file.mp3').writeAsBytes(Uint8List(0));
    await File('$generatedPath/invalid_format.xyz').writeAsString('This is not audio data');

    print('Generated minimal corrupted test files');
  }

  /// Generates corrupted files for a specific format
  static Future<void> _generateCorruptedFilesForFormat(String format) async {
    switch (format.toLowerCase()) {
      case 'mp3':
        await _generateCorruptedMp3Files();
        break;
      case 'wav':
        await _generateCorruptedWavFiles();
        break;
      case 'flac':
        await _generateCorruptedFlacFiles();
        break;
      case 'ogg':
        await _generateCorruptedOggFiles();
        break;
    }
  }

  /// Generates corrupted MP3 files
  static Future<void> _generateCorruptedMp3Files() async {
    // Corrupted header
    final corruptedHeader = Uint8List(1000);
    corruptedHeader[0] = 0xFF; // Start of MP3 sync
    corruptedHeader[1] = 0x00; // Corrupted second byte
    await File('$generatedPath/corrupted_header.mp3').writeAsBytes(corruptedHeader);

    // Invalid sync pattern
    final invalidSync = Uint8List(1000);
    invalidSync[0] = 0xFE; // Invalid sync word
    invalidSync[1] = 0xFB;
    await File('$generatedPath/invalid_sync.mp3').writeAsBytes(invalidSync);

    // Corrupted frame data
    await _generateMp3FileWithSize('$generatedPath/corrupted_frame_data.mp3', 10000, 44100, 2);
    final corruptedFrameData = await File('$generatedPath/corrupted_frame_data.mp3').readAsBytes();
    // Corrupt every 100th byte in frame data
    for (int i = 100; i < corruptedFrameData.length; i += 100) {
      corruptedFrameData[i] = 0x00;
    }
    await File('$generatedPath/corrupted_frame_data.mp3').writeAsBytes(corruptedFrameData);
  }

  /// Generates corrupted WAV files
  static Future<void> _generateCorruptedWavFiles() async {
    // Corrupted RIFF header
    final corruptedRiff = _createWavData([0.5, -0.5, 0.8, -0.8], 44100, 1);
    corruptedRiff[0] = 0x00; // Corrupt RIFF signature
    await File('$generatedPath/corrupted_riff.wav').writeAsBytes(corruptedRiff);

    // Invalid format chunk
    final invalidFormat = _createWavData([0.5, -0.5, 0.8, -0.8], 44100, 1);
    invalidFormat[20] = 0xFF; // Corrupt format type
    await File('$generatedPath/invalid_format_chunk.wav').writeAsBytes(invalidFormat);

    // Corrupted data section
    final corruptedData = _createWavData([0.5, -0.5, 0.8, -0.8], 44100, 1);
    for (int i = 44; i < corruptedData.length; i += 10) {
      corruptedData[i] = 0xFF;
    }
    await File('$generatedPath/corrupted_data.wav').writeAsBytes(corruptedData);

    // Mismatched data size
    final mismatchedSize = _createWavData([0.5, -0.5, 0.8, -0.8], 44100, 1);
    final sizeBuffer = ByteData.view(mismatchedSize.buffer, 40, 4);
    sizeBuffer.setUint32(0, 999999, Endian.little); // Wrong data size
    await File('$generatedPath/mismatched_size.wav').writeAsBytes(mismatchedSize);
  }

  /// Generates corrupted FLAC files
  static Future<void> _generateCorruptedFlacFiles() async {
    // Corrupted signature
    final corruptedSig = Uint8List(1000);
    corruptedSig[0] = 0x66; // 'f'
    corruptedSig[1] = 0x4C; // 'L'
    corruptedSig[2] = 0x61; // 'a'
    corruptedSig[3] = 0x00; // Corrupted 'C'
    await File('$generatedPath/corrupted_signature.flac').writeAsBytes(corruptedSig);

    // Invalid metadata block
    await _generateFlacFileWithSize('$generatedPath/invalid_metadata.flac', 5000, 44100, 2, 16);
    final invalidMeta = await File('$generatedPath/invalid_metadata.flac').readAsBytes();
    invalidMeta[4] = 0xFF; // Corrupt metadata block header
    await File('$generatedPath/invalid_metadata.flac').writeAsBytes(invalidMeta);

    // Truncated file
    await _generateFlacFileWithSize('$generatedPath/truncated.flac', 5000, 44100, 2, 16);
    final truncated = await File('$generatedPath/truncated.flac').readAsBytes();
    final truncatedData = truncated.sublist(0, truncated.length ~/ 2);
    await File('$generatedPath/truncated.flac').writeAsBytes(truncatedData);
  }

  /// Generates corrupted OGG files
  static Future<void> _generateCorruptedOggFiles() async {
    // Corrupted page header
    final corruptedPage = Uint8List(1000);
    corruptedPage[0] = 0x4F; // 'O'
    corruptedPage[1] = 0x67; // 'g'
    corruptedPage[2] = 0x00; // Corrupted 'g'
    corruptedPage[3] = 0x53; // 'S'
    await File('$generatedPath/corrupted_page.ogg').writeAsBytes(corruptedPage);

    // Invalid page structure
    await _generateOggFileWithSize('$generatedPath/invalid_page_structure.ogg', 5000, 44100, 2);
    final invalidPage = await File('$generatedPath/invalid_page_structure.ogg').readAsBytes();
    invalidPage[5] = 0xFF; // Corrupt page type
    await File('$generatedPath/invalid_page_structure.ogg').writeAsBytes(invalidPage);
  }

  /// Generates additional error scenarios
  static Future<void> _generateAdditionalErrorScenarios() async {
    // Empty files for each format
    for (final format in supportedFormats) {
      await File('$generatedPath/empty_file.$format').writeAsBytes(Uint8List(0));
    }

    // Files with only headers (no data)
    final wavHeaderOnly = _createWavData([], 44100, 1);
    await File('$generatedPath/header_only.wav').writeAsBytes(wavHeaderOnly.sublist(0, 44));

    // Invalid format extensions
    await File('$generatedPath/invalid_format.xyz').writeAsString('This is not audio data');
    await File('$generatedPath/text_file.mp3').writeAsString('This is a text file with mp3 extension');

    // Binary garbage files
    final random = math.Random(42);
    final garbageData = Uint8List.fromList(List.generate(1000, (_) => random.nextInt(256)));
    await File('$generatedPath/garbage_data.wav').writeAsBytes(garbageData);
    await File('$generatedPath/garbage_data.mp3').writeAsBytes(garbageData);

    // Files with partial headers
    final partialMp3 = Uint8List(2);
    partialMp3[0] = 0xFF;
    partialMp3[1] = 0xFB;
    await File('$generatedPath/partial_header.mp3').writeAsBytes(partialMp3);
  }

  /// Generates reference waveform data for validation
  static Future<void> _generateReferenceWaveformData() async {
    final referenceData = {
      'mono_44100.wav': {
        'duration_ms': 500, // Updated to match essential test data duration
        'sample_rate': 44100,
        'channels': 1,
        'expected_amplitudes_1000': _generateExpectedAmplitudes(1000),
        'expected_amplitudes_500': _generateExpectedAmplitudes(500),
        'expected_amplitudes_100': _generateExpectedAmplitudes(100),
        'peak_amplitude': 0.65, // Approximate peak from synthetic data
        'rms_amplitude': 0.35, // Approximate RMS from synthetic data
      },
      'stereo_44100.wav': {
        'duration_ms': 500, // Updated to match essential test data duration
        'sample_rate': 44100,
        'channels': 2,
        'expected_amplitudes_1000': _generateExpectedAmplitudes(1000),
        'expected_amplitudes_500': _generateExpectedAmplitudes(500),
        'expected_amplitudes_100': _generateExpectedAmplitudes(100),
        'peak_amplitude': 0.65,
        'rms_amplitude': 0.35,
      },
      'short_duration.wav': {
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
        {'name': 'small_file', 'file': 'short_duration.wav', 'max_memory_mb': 2},
        {'name': 'medium_file', 'file': 'medium_duration.wav', 'max_memory_mb': 10},
        {'name': 'large_file', 'file': 'long_duration.wav', 'max_memory_mb': 50},
      ],
      'error_test_scenarios': [
        {'name': 'corrupted_header', 'file': 'corrupted_header.mp3', 'expected_exception': 'DecodingException'},
        {'name': 'corrupted_data', 'file': 'corrupted_data.wav', 'expected_exception': 'DecodingException'},
        {'name': 'truncated_file', 'file': 'truncated.flac', 'expected_exception': 'DecodingException'},
        {'name': 'invalid_format', 'file': 'invalid_format.xyz', 'expected_exception': 'UnsupportedFormatException'},
        {'name': 'empty_file', 'file': 'empty_file.mp3', 'expected_exception': 'DecodingException'},
      ],
    };

    final file = File('$assetsPath/test_configurations.json');
    await file.writeAsString(jsonEncode(configurations));
    print('Generated test configurations');
  }
}

/// Utility class for loading test data in tests
class TestDataLoader {
  static const String assetsPath = 'test/assets';
  static const String generatedPath = 'test/assets/generated';
  static const String largeFilesPath = 'test/assets/generated/large_files';

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
    // Check if it's a large file first
    final largeFilePath = '$largeFilesPath/$filename';
    if (File(largeFilePath).existsSync()) {
      return largeFilePath;
    }

    // Check generated directory
    final generatedFilePath = '$generatedPath/$filename';
    if (File(generatedFilePath).existsSync()) {
      return generatedFilePath;
    }

    // Fall back to assets directory (for existing test files)
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

  /// Lists all test files of a specific format
  static Future<List<String>> getTestFilesForFormat(String format) async {
    final files = <String>[];

    // Check regular assets directory (for existing test files)
    final assetsDir = Directory(assetsPath);
    if (await assetsDir.exists()) {
      await for (final entity in assetsDir.list()) {
        if (entity is File && entity.path.endsWith('.$format')) {
          files.add(entity.path.split(Platform.pathSeparator).last);
        }
      }
    }

    // Check generated directory
    final generatedDir = Directory(generatedPath);
    if (await generatedDir.exists()) {
      await for (final entity in generatedDir.list()) {
        if (entity is File && entity.path.endsWith('.$format')) {
          files.add(entity.path.split(Platform.pathSeparator).last);
        }
      }
    }

    // Check large files directory
    final largeDir = Directory(largeFilesPath);
    if (await largeDir.exists()) {
      await for (final entity in largeDir.list()) {
        if (entity is File && entity.path.endsWith('.$format')) {
          files.add(entity.path.split(Platform.pathSeparator).last);
        }
      }
    }

    return files;
  }

  /// Gets all test files grouped by size category
  static Future<Map<String, List<String>>> getTestFilesBySize() async {
    final filesBySize = <String, List<String>>{};

    for (final sizeEntry in TestDataGenerator.fileSizes.entries) {
      final sizeName = sizeEntry.key;
      filesBySize[sizeName] = [];

      for (final format in TestDataGenerator.supportedFormats) {
        final files = await getTestFilesForFormat(format);
        final sizeFiles = files.where((f) => f.contains('_${sizeName}_')).toList();
        filesBySize[sizeName]!.addAll(sizeFiles);
      }
    }

    return filesBySize;
  }

  /// Gets corrupted test files for error testing
  static Future<List<String>> getCorruptedTestFiles() async {
    final files = <String>[];
    final assetsDir = Directory(assetsPath);

    if (await assetsDir.exists()) {
      await for (final entity in assetsDir.list()) {
        if (entity is File) {
          final filename = entity.path.split('/').last;
          if (filename.contains('corrupted_') ||
              filename.contains('invalid_') ||
              filename.contains('truncated') ||
              filename.contains('empty_') ||
              filename.contains('garbage_') ||
              filename.contains('partial_')) {
            files.add(filename);
          }
        }
      }
    }

    return files;
  }
}

/// Test file validation and metadata extraction utilities
class TestFileValidator {
  /// Validates a test file and extracts metadata
  static Future<TestFileMetadata> validateAndExtractMetadata(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Test file not found', filePath);
    }

    final size = await file.length();
    final extension = filePath.split('.').last.toLowerCase();
    final data = await file.readAsBytes();

    return TestFileMetadata(
      filePath: filePath,
      size: size,
      format: extension,
      isValid: _validateFileFormat(data, extension),
      metadata: await _extractFormatMetadata(data, extension),
      checksum: _calculateChecksum(data),
    );
  }

  /// Validates file format based on header signatures
  static bool _validateFileFormat(Uint8List data, String expectedFormat) {
    if (data.isEmpty) return false;

    switch (expectedFormat.toLowerCase()) {
      case 'wav':
        return data.length >= 12 &&
            data[0] == 0x52 &&
            data[1] == 0x49 &&
            data[2] == 0x46 &&
            data[3] == 0x46 && // "RIFF"
            data[8] == 0x57 &&
            data[9] == 0x41 &&
            data[10] == 0x56 &&
            data[11] == 0x45; // "WAVE"

      case 'mp3':
        return data.length >= 2 && data[0] == 0xFF && (data[1] & 0xE0) == 0xE0; // MP3 sync word

      case 'flac':
        return data.length >= 4 && data[0] == 0x66 && data[1] == 0x4C && data[2] == 0x61 && data[3] == 0x43; // "fLaC"

      case 'ogg':
        return data.length >= 4 && data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53; // "OggS"

      default:
        return false;
    }
  }

  /// Extracts format-specific metadata
  static Future<Map<String, dynamic>> _extractFormatMetadata(Uint8List data, String format) async {
    final metadata = <String, dynamic>{};

    switch (format.toLowerCase()) {
      case 'wav':
        metadata.addAll(_extractWavMetadata(data));
        break;
      case 'mp3':
        metadata.addAll(_extractMp3Metadata(data));
        break;
      case 'flac':
        metadata.addAll(_extractFlacMetadata(data));
        break;
      case 'ogg':
        metadata.addAll(_extractOggMetadata(data));
        break;
    }

    return metadata;
  }

  /// Extracts WAV metadata
  static Map<String, dynamic> _extractWavMetadata(Uint8List data) {
    if (data.length < 44) return {'error': 'File too short for WAV header'};

    final buffer = ByteData.view(data.buffer);

    try {
      return {
        'format': 'WAV',
        'audioFormat': buffer.getUint16(20, Endian.little),
        'channels': buffer.getUint16(22, Endian.little),
        'sampleRate': buffer.getUint32(24, Endian.little),
        'byteRate': buffer.getUint32(28, Endian.little),
        'blockAlign': buffer.getUint16(32, Endian.little),
        'bitsPerSample': buffer.getUint16(34, Endian.little),
        'dataSize': buffer.getUint32(40, Endian.little),
      };
    } catch (e) {
      return {'error': 'Failed to parse WAV header: $e'};
    }
  }

  /// Extracts MP3 metadata (basic frame info)
  static Map<String, dynamic> _extractMp3Metadata(Uint8List data) {
    if (data.length < 4) return {'error': 'File too short for MP3 header'};

    try {
      final header = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];

      // Extract basic MP3 frame information
      final version = (header >> 19) & 0x3;
      final layer = (header >> 17) & 0x3;
      final bitrateIndex = (header >> 12) & 0xF;
      final sampleRateIndex = (header >> 10) & 0x3;
      final channelMode = (header >> 6) & 0x3;

      return {
        'format': 'MP3',
        'version': version,
        'layer': layer,
        'bitrateIndex': bitrateIndex,
        'sampleRateIndex': sampleRateIndex,
        'channelMode': channelMode,
        'estimatedFrames': _countMp3Frames(data),
      };
    } catch (e) {
      return {'error': 'Failed to parse MP3 header: $e'};
    }
  }

  /// Extracts FLAC metadata
  static Map<String, dynamic> _extractFlacMetadata(Uint8List data) {
    if (data.length < 42) return {'error': 'File too short for FLAC header'};

    try {
      // Skip "fLaC" signature and read STREAMINFO block
      final buffer = ByteData.view(data.buffer, 8);

      return {
        'format': 'FLAC',
        'minBlockSize': buffer.getUint16(0, Endian.big),
        'maxBlockSize': buffer.getUint16(2, Endian.big),
        'hasStreamInfo': data[4] == 0x00, // First metadata block should be STREAMINFO
      };
    } catch (e) {
      return {'error': 'Failed to parse FLAC header: $e'};
    }
  }

  /// Extracts OGG metadata
  static Map<String, dynamic> _extractOggMetadata(Uint8List data) {
    if (data.length < 27) return {'error': 'File too short for OGG header'};

    try {
      return {'format': 'OGG', 'version': data[4], 'headerType': data[5], 'estimatedPages': _countOggPages(data)};
    } catch (e) {
      return {'error': 'Failed to parse OGG header: $e'};
    }
  }

  /// Counts MP3 frames in the file
  static int _countMp3Frames(Uint8List data) {
    int frameCount = 0;
    int offset = 0;

    while (offset < data.length - 1) {
      if (data[offset] == 0xFF && (data[offset + 1] & 0xE0) == 0xE0) {
        frameCount++;
        offset += 417; // Approximate frame size, should be calculated properly
      } else {
        offset++;
      }
    }

    return frameCount;
  }

  /// Counts OGG pages in the file
  static int _countOggPages(Uint8List data) {
    int pageCount = 0;
    int offset = 0;

    while (offset < data.length - 3) {
      if (data[offset] == 0x4F && data[offset + 1] == 0x67 && data[offset + 2] == 0x67 && data[offset + 3] == 0x53) {
        pageCount++;
        offset += 4096; // Approximate page size
      } else {
        offset++;
      }
    }

    return pageCount;
  }

  /// Calculates a simple checksum for file integrity
  static String _calculateChecksum(Uint8List data) {
    int checksum = 0;
    for (int i = 0; i < data.length; i++) {
      checksum = (checksum + data[i]) & 0xFFFFFFFF;
    }
    return checksum.toRadixString(16).padLeft(8, '0');
  }
}

/// Metadata information for test files
class TestFileMetadata {
  final String filePath;
  final int size;
  final String format;
  final bool isValid;
  final Map<String, dynamic> metadata;
  final String checksum;

  const TestFileMetadata({
    required this.filePath,
    required this.size,
    required this.format,
    required this.isValid,
    required this.metadata,
    required this.checksum,
  });

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() => {'filePath': filePath, 'size': size, 'format': format, 'isValid': isValid, 'metadata': metadata, 'checksum': checksum};

  /// Creates from JSON
  factory TestFileMetadata.fromJson(Map<String, dynamic> json) => TestFileMetadata(
    filePath: json['filePath'],
    size: json['size'],
    format: json['format'],
    isValid: json['isValid'],
    metadata: Map<String, dynamic>.from(json['metadata']),
    checksum: json['checksum'],
  );
}

/// Test file management and cleanup utilities
class TestFileManager {
  /// Cleans up large test files to save disk space
  static Future<void> cleanupLargeFiles() async {
    final largeDir = Directory(TestDataGenerator.largeFilesPath);

    if (await largeDir.exists()) {
      print('Cleaning up large test files...');

      await for (final entity in largeDir.list()) {
        if (entity is File) {
          final size = await entity.length();
          if (size > 100 * 1024 * 1024) {
            // Files larger than 100MB
            await entity.delete();
            print('Deleted large file: ${entity.path}');
          }
        }
      }
    }
  }

  /// Cleans up all generated test files
  static Future<void> cleanupAllGeneratedFiles() async {
    final generatedDir = Directory(TestDataGenerator.generatedPath);

    if (await generatedDir.exists()) {
      print('Cleaning up all generated test files...');
      await generatedDir.delete(recursive: true);
      print('Deleted generated directory: ${generatedDir.path}');
    }

    // Also clean up any legacy generated files in the main assets directory
    await _cleanupLegacyGeneratedFiles();
  }

  /// Cleans up legacy generated files from the main assets directory
  static Future<void> _cleanupLegacyGeneratedFiles() async {
    final assetsDir = Directory(TestDataGenerator.assetsPath);

    if (await assetsDir.exists()) {
      print('Cleaning up legacy generated files...');

      await for (final entity in assetsDir.list()) {
        if (entity is File) {
          final filename = entity.path.split(Platform.pathSeparator).last;

          // Check if it's a generated file pattern
          if (_isGeneratedFile(filename)) {
            await entity.delete();
            print('Deleted legacy file: $filename');
          }
        }
      }
    }
  }

  /// Checks if a filename matches generated file patterns
  static bool _isGeneratedFile(String filename) {
    final generatedPatterns = [
      RegExp(r'.*_(tiny|small|medium|large|xlarge|huge|massive)_.*\.(wav|mp3|flac|ogg)$'),
      RegExp(r'^corrupted_.*'),
      RegExp(r'^invalid_.*'),
      RegExp(r'^garbage_.*'),
      RegExp(r'^empty_file\..*'),
      RegExp(r'^header_only\..*'),
      RegExp(r'^partial_.*'),
      RegExp(r'^text_file\..*'),
      RegExp(r'^truncated\..*'),
      RegExp(r'^mismatched_.*'),
    ];

    return generatedPatterns.any((pattern) => pattern.hasMatch(filename));
  }

  /// Validates all test files and generates a report
  static Future<Map<String, dynamic>> validateAllTestFiles() async {
    final report = <String, dynamic>{
      'validFiles': <String>[],
      'invalidFiles': <String>[],
      'corruptedFiles': <String>[],
      'totalSize': 0,
      'validationErrors': <String>[],
    };

    // Validate regular test files
    await _validateFilesInDirectory(TestDataLoader.assetsPath, report);

    // Validate large test files
    await _validateFilesInDirectory(TestDataLoader.largeFilesPath, report);

    return report;
  }

  static Future<void> _validateFilesInDirectory(String dirPath, Map<String, dynamic> report) async {
    final dir = Directory(dirPath);

    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          final metadata = await TestFileValidator.validateAndExtractMetadata(entity.path);

          if (metadata.isValid) {
            report['validFiles'].add(entity.path);
          } else {
            report['invalidFiles'].add(entity.path);
          }

          report['totalSize'] += metadata.size;
        } catch (e) {
          report['validationErrors'].add('${entity.path}: $e');
        }
      }
    }
  }

  /// Generates a comprehensive test file inventory
  static Future<void> generateTestFileInventory() async {
    final inventory = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'filesByFormat': <String, List<String>>{},
      'filesBySize': <String, List<String>>{},
      'corruptedFiles': <String>[],
      'totalFiles': 0,
      'totalSize': 0,
    };

    // Group files by format
    for (final format in TestDataGenerator.supportedFormats) {
      inventory['filesByFormat'][format] = await TestDataLoader.getTestFilesForFormat(format);
    }

    // Group files by size
    inventory['filesBySize'] = await TestDataLoader.getTestFilesBySize();

    // Get corrupted files
    inventory['corruptedFiles'] = await TestDataLoader.getCorruptedTestFiles();

    // Calculate totals
    for (final files in inventory['filesByFormat'].values) {
      inventory['totalFiles'] += (files as List).length;
    }

    final inventoryFile = File('${TestDataLoader.assetsPath}/test_file_inventory.json');
    await inventoryFile.writeAsString(jsonEncode(inventory));

    print('Generated test file inventory: ${inventoryFile.path}');
  }
}
