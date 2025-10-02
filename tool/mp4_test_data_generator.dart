// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Generates MP4 test files and reference data for comprehensive MP4 decoding testing
class MP4TestDataGenerator {
  static const String assetsPath = 'test/assets';
  static const String generatedPath = 'test/assets/generated';

  /// MP4 file size categories for testing
  static const Map<String, int> mp4FileSizes = {
    'tiny': 50 * 1024, // 50KB - minimal MP4 container
    'small': 500 * 1024, // 500KB - small audio file
    'medium': 5 * 1024 * 1024, // 5MB - medium audio file
  };

  /// MP4 audio characteristics for testing
  static const List<Map<String, dynamic>> mp4AudioCharacteristics = [
    {'sampleRate': 44100, 'channels': 2, 'bitrate': 128}, // Standard stereo
    {'sampleRate': 48000, 'channels': 2, 'bitrate': 192}, // High quality stereo
    {'sampleRate': 22050, 'channels': 1, 'bitrate': 64}, // Low quality mono
  ];

  /// Generates all MP4 test files and reference data
  static Future<void> generateAllMP4TestData({bool force = false}) async {
    await _ensureGeneratedDirectory();

    // Check if files already exist (unless forced)
    if (!force && await _hasMP4TestFiles()) {
      print('MP4 test files already exist, skipping generation (use force: true to regenerate)');
      return;
    }

    print('Generating comprehensive MP4 test file suite...');

    // Generate basic MP4 test files
    await _generateBasicMP4Files();

    // Generate comprehensive MP4 test suite
    await generateComprehensiveMP4TestSuite();

    // Generate corrupted MP4 files for error testing
    await _generateCorruptedMP4Files();

    // Generate MP4 files with specific error conditions
    await _generateMP4ErrorConditionFiles();

    print('All MP4 test data generated successfully');
  }

  /// Generates only essential MP4 test files (faster for regular testing)
  static Future<void> generateEssentialMP4TestData({bool force = false}) async {
    await _ensureGeneratedDirectory();

    // Check if essential files already exist (unless forced)
    if (!force && await _hasEssentialMP4TestFiles()) {
      print('Essential MP4 test files already exist, skipping generation');
      return;
    }

    print('Generating essential MP4 test files (optimized for speed)...');

    // Generate only basic MP4 test files with smaller sizes
    await _generateEssentialMP4Files();

    // Generate minimal set of corrupted MP4 files
    await _generateMinimalCorruptedMP4Files();

    // Generate essential error condition files
    await _generateEssentialMP4ErrorFiles();

    print('Essential MP4 test data generated successfully');
  }

  /// Checks if basic MP4 test files exist
  static Future<bool> _hasMP4TestFiles() async {
    final basicFiles = [
      '$generatedPath/mp4_tiny_44100_2ch.mp4',
      '$generatedPath/mp4_small_44100_2ch.mp4',
      '$generatedPath/mp4_medium_44100_2ch.mp4',
      '$generatedPath/corrupted_mp4_container.mp4',
      '$generatedPath/mp4_no_audio_track.mp4',
    ];

    for (final filePath in basicFiles) {
      if (!await File(filePath).exists()) {
        return false;
      }
    }
    return true;
  }

  /// Checks if essential MP4 test files exist
  static Future<bool> _hasEssentialMP4TestFiles() async {
    final essentialFiles = [
      '$generatedPath/mp4_tiny_44100_2ch.mp4',
      '$generatedPath/mp4_small_44100_2ch.mp4',
      '$generatedPath/corrupted_mp4_container.mp4',
      '$generatedPath/mp4_no_audio_track.mp4',
    ];

    // Check if at least 75% of essential files exist
    int existingFiles = 0;
    for (final filePath in essentialFiles) {
      if (await File(filePath).exists()) {
        existingFiles++;
      }
    }

    final threshold = (essentialFiles.length * 0.75).ceil();
    final hasEnoughFiles = existingFiles >= threshold;

    if (hasEnoughFiles) {
      print('Found $existingFiles/${essentialFiles.length} essential MP4 test files, skipping generation');
    }

    return hasEnoughFiles;
  }

  /// Generates comprehensive MP4 test suite with various sizes and characteristics
  static Future<void> generateComprehensiveMP4TestSuite() async {
    print('Generating MP4 files of various sizes and characteristics...');

    for (final sizeEntry in mp4FileSizes.entries) {
      final sizeName = sizeEntry.key;
      final targetSize = sizeEntry.value;

      // Generate files with different audio characteristics
      for (int i = 0; i < mp4AudioCharacteristics.length; i++) {
        final characteristics = mp4AudioCharacteristics[i];
        final filename = 'mp4_${sizeName}_${characteristics['sampleRate']}_${characteristics['channels']}ch.mp4';

        try {
          await _generateMP4FileWithSize(filename, targetSize, characteristics['sampleRate'], characteristics['channels'], characteristics['bitrate']);

          // Only generate one characteristic per size for medium files to save space
          if (targetSize > 1024 * 1024) break;
        } catch (e) {
          print('Warning: Failed to generate $filename: $e');
        }
      }
    }
  }

  static Future<void> _ensureGeneratedDirectory() async {
    final directory = Directory(generatedPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// Generates basic MP4 test files
  static Future<void> _generateBasicMP4Files() async {
    // Generate standard MP4 files for basic testing
    await _generateMP4File('mp4_tiny_44100_2ch.mp4', sampleRate: 44100, channels: 2, durationSeconds: 0.5, bitrate: 128);
    await _generateMP4File('mp4_small_44100_2ch.mp4', sampleRate: 44100, channels: 2, durationSeconds: 2.0, bitrate: 128);
    await _generateMP4File('mp4_medium_44100_2ch.mp4', sampleRate: 44100, channels: 2, durationSeconds: 10.0, bitrate: 128);

    // Generate files with different characteristics
    await _generateMP4File('mp4_mono_22050.mp4', sampleRate: 22050, channels: 1, durationSeconds: 1.0, bitrate: 64);
    await _generateMP4File('mp4_stereo_48000.mp4', sampleRate: 48000, channels: 2, durationSeconds: 1.0, bitrate: 192);
  }

  /// Generates essential MP4 test files (smaller, faster)
  static Future<void> _generateEssentialMP4Files() async {
    // Generate only the most essential MP4 files with shorter durations
    await _generateMP4File('mp4_tiny_44100_2ch.mp4', sampleRate: 44100, channels: 2, durationSeconds: 0.1, bitrate: 128);
    await _generateMP4File('mp4_small_44100_2ch.mp4', sampleRate: 44100, channels: 2, durationSeconds: 0.5, bitrate: 128);
    await _generateMP4File('mp4_medium_44100_2ch.mp4', sampleRate: 44100, channels: 2, durationSeconds: 1.0, bitrate: 128);
  }

  /// Generates an MP4 file with specific target size and audio characteristics
  static Future<void> _generateMP4FileWithSize(String filename, int targetSize, int sampleRate, int channels, int bitrate) async {
    final filePath = '$generatedPath/$filename';

    // Calculate approximate duration based on target size and bitrate
    final approximateDuration = (targetSize * 8) / (bitrate * 1000); // Convert to seconds
    final clampedDuration = approximateDuration.clamp(0.1, 60.0); // Reasonable bounds

    print('Generating $filename (target: ${_formatFileSize(targetSize)}, duration: ${clampedDuration.toStringAsFixed(1)}s)...');

    await generateSyntheticMP4File(filePath, sampleRate, channels, clampedDuration, bitrate);

    final actualSize = await File(filePath).length();
    print('Generated $filename: ${_formatFileSize(actualSize)}');
  }

  /// Generates an MP4 file with synthetic audio data
  static Future<void> _generateMP4File(
    String filename, {
    required int sampleRate,
    required int channels,
    required double durationSeconds,
    required int bitrate,
  }) async {
    final filePath = '$generatedPath/$filename';
    print('Generating: $filename');

    await generateSyntheticMP4File(filePath, sampleRate, channels, durationSeconds, bitrate);
  }

  /// Creates synthetic MP4 file with proper container structure
  static Future<void> generateSyntheticMP4File(String filePath, int sampleRate, int channels, double durationSeconds, int bitrate) async {
    // Calculate file size based on bitrate and duration
    final estimatedSize = ((bitrate * 1000 * durationSeconds) / 8).round() + 8192; // Add overhead for container
    final data = Uint8List(estimatedSize);

    int offset = 0;

    // Generate MP4 container structure
    offset = _writeMP4FileTypeBox(data, offset);
    offset = _writeMP4MovieBox(data, offset, sampleRate, channels, durationSeconds, bitrate);
    offset = _writeMP4MediaDataBox(data, offset, estimatedSize - offset - 8);

    // Trim to actual size
    final actualData = data.sublist(0, offset);

    final file = File(filePath);
    await file.writeAsBytes(actualData);
  }

  /// Writes MP4 ftyp (file type) box
  static int _writeMP4FileTypeBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    // Box size (32 bytes)
    view.setUint32(offset, 32, Endian.big);
    offset += 4;

    // Box type 'ftyp'
    view.setUint32(offset, 0x66747970, Endian.big); // 'ftyp'
    offset += 4;

    // Major brand 'mp41'
    view.setUint32(offset, 0x6D703431, Endian.big); // 'mp41'
    offset += 4;

    // Minor version
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Compatible brands: 'mp41', 'isom'
    view.setUint32(offset, 0x6D703431, Endian.big); // 'mp41'
    offset += 4;
    view.setUint32(offset, 0x69736F6D, Endian.big); // 'isom'
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big); // padding
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big); // padding
    offset += 4;

    return offset;
  }

  /// Writes MP4 moov (movie) box with track information
  static int _writeMP4MovieBox(Uint8List data, int offset, int sampleRate, int channels, double durationSeconds, int bitrate) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'moov'
    view.setUint32(offset, 0x6D6F6F76, Endian.big); // 'moov'
    offset += 4;

    // Movie header box (mvhd)
    offset = _writeMP4MovieHeaderBox(data, offset, durationSeconds);

    // Track box (trak) for audio
    offset = _writeMP4TrackBox(data, offset, sampleRate, channels, durationSeconds, bitrate);

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Writes MP4 mvhd (movie header) box
  static int _writeMP4MovieHeaderBox(Uint8List data, int offset, double durationSeconds) {
    final view = ByteData.view(data.buffer);

    // Box size (108 bytes for version 0)
    view.setUint32(offset, 108, Endian.big);
    offset += 4;

    // Box type 'mvhd'
    view.setUint32(offset, 0x6D766864, Endian.big); // 'mvhd'
    offset += 4;

    // Version and flags
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Creation time
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Modification time
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Timescale (1000 units per second)
    view.setUint32(offset, 1000, Endian.big);
    offset += 4;

    // Duration in timescale units
    view.setUint32(offset, (durationSeconds * 1000).round(), Endian.big);
    offset += 4;

    // Rate (1.0 in 16.16 fixed point)
    view.setUint32(offset, 0x00010000, Endian.big);
    offset += 4;

    // Volume (1.0 in 8.8 fixed point)
    view.setUint16(offset, 0x0100, Endian.big);
    offset += 2;

    // Reserved
    view.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    // Reserved (2 x 32-bit)
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Matrix (9 x 32-bit) - identity matrix
    final identityMatrix = [0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x40000000];
    for (final value in identityMatrix) {
      view.setUint32(offset, value, Endian.big);
      offset += 4;
    }

    // Pre-defined (6 x 32-bit)
    for (int i = 0; i < 6; i++) {
      view.setUint32(offset, 0x00000000, Endian.big);
      offset += 4;
    }

    // Next track ID
    view.setUint32(offset, 2, Endian.big);
    offset += 4;

    return offset;
  }

  /// Writes MP4 trak (track) box for audio
  static int _writeMP4TrackBox(Uint8List data, int offset, int sampleRate, int channels, double durationSeconds, int bitrate) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'trak'
    view.setUint32(offset, 0x7472616B, Endian.big); // 'trak'
    offset += 4;

    // Track header box (tkhd)
    offset = _writeMP4TrackHeaderBox(data, offset, durationSeconds);

    // Media box (mdia)
    offset = _writeMP4MediaBox(data, offset, sampleRate, channels, durationSeconds, bitrate);

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Writes MP4 tkhd (track header) box
  static int _writeMP4TrackHeaderBox(Uint8List data, int offset, double durationSeconds) {
    final view = ByteData.view(data.buffer);

    // Box size (92 bytes for version 0)
    view.setUint32(offset, 92, Endian.big);
    offset += 4;

    // Box type 'tkhd'
    view.setUint32(offset, 0x746B6864, Endian.big); // 'tkhd'
    offset += 4;

    // Version and flags (track enabled)
    view.setUint32(offset, 0x00000007, Endian.big);
    offset += 4;

    // Creation time
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Modification time
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Track ID
    view.setUint32(offset, 1, Endian.big);
    offset += 4;

    // Reserved
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Duration in movie timescale units
    view.setUint32(offset, (durationSeconds * 1000).round(), Endian.big);
    offset += 4;

    // Reserved (2 x 32-bit)
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Layer
    view.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    // Alternate group
    view.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    // Volume (1.0 for audio track)
    view.setUint16(offset, 0x0100, Endian.big);
    offset += 2;

    // Reserved
    view.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    // Matrix (9 x 32-bit) - identity matrix
    final identityMatrix = [0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x40000000];
    for (final value in identityMatrix) {
      view.setUint32(offset, value, Endian.big);
      offset += 4;
    }

    // Width and height (0 for audio)
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    return offset;
  }

  /// Writes MP4 mdia (media) box
  static int _writeMP4MediaBox(Uint8List data, int offset, int sampleRate, int channels, double durationSeconds, int bitrate) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'mdia'
    view.setUint32(offset, 0x6D646961, Endian.big); // 'mdia'
    offset += 4;

    // Media header box (mdhd)
    offset = _writeMP4MediaHeaderBox(data, offset, sampleRate, durationSeconds);

    // Handler reference box (hdlr)
    offset = _writeMP4HandlerBox(data, offset);

    // Media information box (minf)
    offset = _writeMP4MediaInfoBox(data, offset, sampleRate, channels, bitrate);

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Writes MP4 mdhd (media header) box
  static int _writeMP4MediaHeaderBox(Uint8List data, int offset, int sampleRate, double durationSeconds) {
    final view = ByteData.view(data.buffer);

    // Box size (32 bytes for version 0)
    view.setUint32(offset, 32, Endian.big);
    offset += 4;

    // Box type 'mdhd'
    view.setUint32(offset, 0x6D646864, Endian.big); // 'mdhd'
    offset += 4;

    // Version and flags
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Creation time
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Modification time
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Timescale (sample rate)
    view.setUint32(offset, sampleRate, Endian.big);
    offset += 4;

    // Duration in media timescale units
    view.setUint32(offset, (durationSeconds * sampleRate).round(), Endian.big);
    offset += 4;

    // Language (undetermined = 0x55C4)
    view.setUint16(offset, 0x55C4, Endian.big);
    offset += 2;

    // Pre-defined
    view.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    return offset;
  }

  /// Writes MP4 hdlr (handler) box for audio
  static int _writeMP4HandlerBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    // Box size (33 bytes)
    view.setUint32(offset, 33, Endian.big);
    offset += 4;

    // Box type 'hdlr'
    view.setUint32(offset, 0x68646C72, Endian.big); // 'hdlr'
    offset += 4;

    // Version and flags
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Pre-defined
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Handler type 'soun' (sound)
    view.setUint32(offset, 0x736F756E, Endian.big); // 'soun'
    offset += 4;

    // Reserved (3 x 32-bit)
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Name (null-terminated string)
    data[offset] = 0x00; // Empty name
    offset += 1;

    return offset;
  }

  /// Writes MP4 minf (media information) box
  static int _writeMP4MediaInfoBox(Uint8List data, int offset, int sampleRate, int channels, int bitrate) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'minf'
    view.setUint32(offset, 0x6D696E66, Endian.big); // 'minf'
    offset += 4;

    // Sound media header box (smhd)
    offset = _writeMP4SoundMediaHeaderBox(data, offset);

    // Data information box (dinf)
    offset = _writeMP4DataInfoBox(data, offset);

    // Sample table box (stbl)
    offset = _writeMP4SampleTableBox(data, offset, sampleRate, channels, bitrate);

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Writes MP4 smhd (sound media header) box
  static int _writeMP4SoundMediaHeaderBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    // Box size (16 bytes)
    view.setUint32(offset, 16, Endian.big);
    offset += 4;

    // Box type 'smhd'
    view.setUint32(offset, 0x736D6864, Endian.big); // 'smhd'
    offset += 4;

    // Version and flags
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Balance (0.0 in 8.8 fixed point)
    view.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    // Reserved
    view.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    return offset;
  }

  /// Writes MP4 dinf (data information) box
  static int _writeMP4DataInfoBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'dinf'
    view.setUint32(offset, 0x64696E66, Endian.big); // 'dinf'
    offset += 4;

    // Data reference box (dref)
    offset = _writeMP4DataReferenceBox(data, offset);

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Writes MP4 dref (data reference) box
  static int _writeMP4DataReferenceBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    // Box size (28 bytes)
    view.setUint32(offset, 28, Endian.big);
    offset += 4;

    // Box type 'dref'
    view.setUint32(offset, 0x64726566, Endian.big); // 'dref'
    offset += 4;

    // Version and flags
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Entry count
    view.setUint32(offset, 1, Endian.big);
    offset += 4;

    // URL entry
    view.setUint32(offset, 12, Endian.big); // Entry size
    offset += 4;
    view.setUint32(offset, 0x75726C20, Endian.big); // 'url '
    offset += 4;
    view.setUint32(offset, 0x00000001, Endian.big); // Self-contained flag
    offset += 4;

    return offset;
  }

  /// Writes MP4 stbl (sample table) box
  static int _writeMP4SampleTableBox(Uint8List data, int offset, int sampleRate, int channels, int bitrate) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'stbl'
    view.setUint32(offset, 0x7374626C, Endian.big); // 'stbl'
    offset += 4;

    // Sample description box (stsd)
    offset = _writeMP4SampleDescriptionBox(data, offset, sampleRate, channels);

    // Time-to-sample box (stts)
    offset = _writeMP4TimeToSampleBox(data, offset);

    // Sample-to-chunk box (stsc)
    offset = _writeMP4SampleToChunkBox(data, offset);

    // Sample size box (stsz)
    offset = _writeMP4SampleSizeBox(data, offset);

    // Chunk offset box (stco)
    offset = _writeMP4ChunkOffsetBox(data, offset);

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Writes MP4 stsd (sample description) box
  static int _writeMP4SampleDescriptionBox(Uint8List data, int offset, int sampleRate, int channels) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'stsd'
    view.setUint32(offset, 0x73747364, Endian.big); // 'stsd'
    offset += 4;

    // Version and flags
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // Entry count
    view.setUint32(offset, 1, Endian.big);
    offset += 4;

    // AAC audio sample entry
    offset = _writeMP4AACSampleEntry(data, offset, sampleRate, channels);

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Writes MP4 AAC sample entry
  static int _writeMP4AACSampleEntry(Uint8List data, int offset, int sampleRate, int channels) {
    final view = ByteData.view(data.buffer);

    // Sample entry size (36 bytes + esds box)
    view.setUint32(offset, 72, Endian.big);
    offset += 4;

    // Sample entry type 'mp4a'
    view.setUint32(offset, 0x6D703461, Endian.big); // 'mp4a'
    offset += 4;

    // Reserved (6 bytes)
    for (int i = 0; i < 6; i++) {
      data[offset++] = 0x00;
    }

    // Data reference index
    view.setUint16(offset, 1, Endian.big);
    offset += 2;

    // Audio sample entry fields
    view.setUint32(offset, 0x00000000, Endian.big); // Reserved
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big); // Reserved
    offset += 4;
    view.setUint16(offset, channels, Endian.big); // Channel count
    offset += 2;
    view.setUint16(offset, 16, Endian.big); // Sample size (16-bit)
    offset += 2;
    view.setUint16(offset, 0x0000, Endian.big); // Pre-defined
    offset += 2;
    view.setUint16(offset, 0x0000, Endian.big); // Reserved
    offset += 2;
    view.setUint32(offset, sampleRate << 16, Endian.big); // Sample rate (16.16 fixed point)
    offset += 4;

    // Elementary stream descriptor box (esds)
    offset = _writeMP4ElementaryStreamDescriptorBox(data, offset, sampleRate, channels);

    return offset;
  }

  /// Writes MP4 esds (elementary stream descriptor) box
  static int _writeMP4ElementaryStreamDescriptorBox(Uint8List data, int offset, int sampleRate, int channels) {
    final view = ByteData.view(data.buffer);

    // Box size (36 bytes)
    view.setUint32(offset, 36, Endian.big);
    offset += 4;

    // Box type 'esds'
    view.setUint32(offset, 0x65736473, Endian.big); // 'esds'
    offset += 4;

    // Version and flags
    view.setUint32(offset, 0x00000000, Endian.big);
    offset += 4;

    // ES descriptor tag and length
    data[offset++] = 0x03; // ES_DescrTag
    data[offset++] = 0x17; // Length (23 bytes)

    // ES ID
    view.setUint16(offset, 0x0001, Endian.big);
    offset += 2;

    // Flags (no URL, no OCR stream)
    data[offset++] = 0x00;

    // Decoder config descriptor
    data[offset++] = 0x04; // DecoderConfigDescrTag
    data[offset++] = 0x0F; // Length (15 bytes)

    // Object type (AAC LC)
    data[offset++] = 0x40; // MPEG-4 Audio

    // Stream type and upstream flag
    data[offset++] = 0x15; // Audio stream

    // Buffer size (3 bytes)
    data[offset++] = 0x00;
    data[offset++] = 0x00;
    data[offset++] = 0x00;

    // Max bitrate
    view.setUint32(offset, 128000, Endian.big);
    offset += 4;

    // Average bitrate
    view.setUint32(offset, 128000, Endian.big);
    offset += 4;

    // Decoder specific info
    data[offset++] = 0x05; // DecSpecificInfoTag
    data[offset++] = 0x02; // Length (2 bytes)

    // AAC audio specific config (simplified)
    data[offset++] = 0x12; // AAC LC, 44.1kHz
    data[offset++] = 0x10; // Stereo

    // SL config descriptor
    data[offset++] = 0x06; // SLConfigDescrTag
    data[offset++] = 0x01; // Length (1 byte)
    data[offset++] = 0x02; // Pre-defined SL config

    return offset;
  }

  /// Writes remaining sample table boxes (simplified)
  static int _writeMP4TimeToSampleBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    view.setUint32(offset, 24, Endian.big); // Box size
    offset += 4;
    view.setUint32(offset, 0x73747473, Endian.big); // 'stts'
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big); // Version and flags
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // Entry count
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // Sample count
    offset += 4;
    view.setUint32(offset, 1024, Endian.big); // Sample delta
    offset += 4;

    return offset;
  }

  static int _writeMP4SampleToChunkBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    view.setUint32(offset, 28, Endian.big); // Box size
    offset += 4;
    view.setUint32(offset, 0x73747363, Endian.big); // 'stsc'
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big); // Version and flags
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // Entry count
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // First chunk
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // Samples per chunk
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // Sample description index
    offset += 4;

    return offset;
  }

  static int _writeMP4SampleSizeBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    view.setUint32(offset, 20, Endian.big); // Box size
    offset += 4;
    view.setUint32(offset, 0x7374737A, Endian.big); // 'stsz'
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big); // Version and flags
    offset += 4;
    view.setUint32(offset, 0, Endian.big); // Sample size (0 = variable)
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // Sample count
    offset += 4;

    return offset;
  }

  static int _writeMP4ChunkOffsetBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);

    view.setUint32(offset, 20, Endian.big); // Box size
    offset += 4;
    view.setUint32(offset, 0x7374636F, Endian.big); // 'stco'
    offset += 4;
    view.setUint32(offset, 0x00000000, Endian.big); // Version and flags
    offset += 4;
    view.setUint32(offset, 1, Endian.big); // Entry count
    offset += 4;
    view.setUint32(offset, offset + 4, Endian.big); // Chunk offset (points to mdat)
    offset += 4;

    return offset;
  }

  /// Writes MP4 mdat (media data) box
  static int _writeMP4MediaDataBox(Uint8List data, int offset, int dataSize) {
    final view = ByteData.view(data.buffer);

    // Box size
    view.setUint32(offset, dataSize + 8, Endian.big);
    offset += 4;

    // Box type 'mdat'
    view.setUint32(offset, 0x6D646174, Endian.big); // 'mdat'
    offset += 4;

    // Fill with synthetic AAC data
    final random = math.Random(42); // Fixed seed for reproducible tests
    for (int i = 0; i < dataSize; i++) {
      data[offset + i] = random.nextInt(256);
    }

    return offset + dataSize;
  }

  /// Generates corrupted MP4 files for error testing
  static Future<void> _generateCorruptedMP4Files() async {
    print('Generating corrupted MP4 files for error testing...');

    // Corrupted container structure
    await generateCorruptedMP4Container();

    // Invalid MP4 signature
    await generateInvalidMP4Signature();

    // Truncated MP4 file
    await generateTruncatedMP4File();

    // MP4 with corrupted boxes
    await _generateMP4WithCorruptedBoxes();

    print('Generated corrupted MP4 test files');
  }

  /// Generates minimal set of corrupted MP4 files for essential testing
  static Future<void> _generateMinimalCorruptedMP4Files() async {
    print('Generating minimal corrupted MP4 files for error testing...');

    // Generate only essential corrupted files
    await generateCorruptedMP4Container();
    await generateInvalidMP4Signature();

    print('Generated minimal corrupted MP4 test files');
  }

  /// Generates MP4 files with specific error conditions
  static Future<void> _generateMP4ErrorConditionFiles() async {
    print('Generating MP4 files with specific error conditions...');

    // MP4 with no audio track (video only)
    await _generateMP4NoAudioTrack();

    // MP4 with unsupported codec
    await _generateMP4UnsupportedCodec();

    // Empty MP4 file
    await _generateEmptyMP4File();

    print('Generated MP4 error condition test files');
  }

  /// Generates essential MP4 error condition files
  static Future<void> _generateEssentialMP4ErrorFiles() async {
    print('Generating essential MP4 error condition files...');

    // Generate only essential error condition files
    await _generateMP4NoAudioTrack();
    await _generateEmptyMP4File();

    print('Generated essential MP4 error condition test files');
  }

  /// Generates corrupted MP4 container
  static Future<void> generateCorruptedMP4Container() async {
    final data = Uint8List(1000);

    // Start with valid ftyp signature
    final view = ByteData.view(data.buffer);
    view.setUint32(0, 32, Endian.big); // Box size
    view.setUint32(4, 0x66747970, Endian.big); // 'ftyp'

    // Corrupt the rest of the container structure
    for (int i = 32; i < data.length; i++) {
      data[i] = 0xFF; // Invalid data
    }

    final file = File('$generatedPath/corrupted_mp4_container.mp4');
    await file.writeAsBytes(data);
  }

  /// Generates MP4 with invalid signature
  static Future<void> generateInvalidMP4Signature() async {
    final data = Uint8List(1000);

    // Invalid ftyp signature
    final view = ByteData.view(data.buffer);
    view.setUint32(0, 32, Endian.big); // Box size
    view.setUint32(4, 0x66747900, Endian.big); // Invalid 'fty\0'

    final file = File('$generatedPath/invalid_mp4_signature.mp4');
    await file.writeAsBytes(data);
  }

  /// Generates truncated MP4 file
  static Future<void> generateTruncatedMP4File() async {
    // Generate a normal MP4 file first
    await _generateMP4File('temp_full.mp4', sampleRate: 44100, channels: 2, durationSeconds: 1.0, bitrate: 128);

    // Read and truncate it
    final fullData = await File('$generatedPath/temp_full.mp4').readAsBytes();
    final truncatedData = fullData.sublist(0, fullData.length ~/ 2);

    final file = File('$generatedPath/truncated_mp4.mp4');
    await file.writeAsBytes(truncatedData);

    // Clean up temp file
    await File('$generatedPath/temp_full.mp4').delete();
  }

  /// Generates MP4 with corrupted boxes
  static Future<void> _generateMP4WithCorruptedBoxes() async {
    // Generate a normal MP4 file first
    await _generateMP4File('temp_normal.mp4', sampleRate: 44100, channels: 2, durationSeconds: 1.0, bitrate: 128);

    // Read and corrupt specific boxes
    final data = await File('$generatedPath/temp_normal.mp4').readAsBytes();

    // Corrupt moov box (if found)
    for (int i = 0; i < data.length - 4; i++) {
      if (data[i] == 0x6D && data[i + 1] == 0x6F && data[i + 2] == 0x6F && data[i + 3] == 0x76) {
        // Found 'moov', corrupt it
        data[i] = 0x00;
        break;
      }
    }

    final file = File('$generatedPath/corrupted_boxes.mp4');
    await file.writeAsBytes(data);

    // Clean up temp file
    await File('$generatedPath/temp_normal.mp4').delete();
  }

  /// Generates MP4 with no audio track (video only)
  static Future<void> _generateMP4NoAudioTrack() async {
    final data = Uint8List(500);
    int offset = 0;

    // Generate MP4 container with video track only
    offset = _writeMP4FileTypeBox(data, offset);

    // Movie box with video track
    final view = ByteData.view(data.buffer);
    final movieStartOffset = offset;
    offset += 4; // Reserve space for box size

    view.setUint32(offset, 0x6D6F6F76, Endian.big); // 'moov'
    offset += 4;

    // Movie header
    offset = _writeMP4MovieHeaderBox(data, offset, 1.0);

    // Video track (no audio track)
    offset = _writeMP4VideoTrackBox(data, offset);

    // Write movie box size
    final movieBoxSize = offset - movieStartOffset;
    view.setUint32(movieStartOffset, movieBoxSize, Endian.big);

    // Media data box (empty)
    view.setUint32(offset, 8, Endian.big); // Box size
    offset += 4;
    view.setUint32(offset, 0x6D646174, Endian.big); // 'mdat'
    offset += 4;

    final actualData = data.sublist(0, offset);
    final file = File('$generatedPath/mp4_no_audio_track.mp4');
    await file.writeAsBytes(actualData);
  }

  /// Writes a simplified video track box
  static int _writeMP4VideoTrackBox(Uint8List data, int offset) {
    final view = ByteData.view(data.buffer);
    final startOffset = offset;

    // Reserve space for box size
    offset += 4;

    // Box type 'trak'
    view.setUint32(offset, 0x7472616B, Endian.big); // 'trak'
    offset += 4;

    // Simplified track header for video
    view.setUint32(offset, 92, Endian.big); // tkhd size
    offset += 4;
    view.setUint32(offset, 0x746B6864, Endian.big); // 'tkhd'
    offset += 4;
    view.setUint32(offset, 0x00000007, Endian.big); // flags (enabled)
    offset += 4;

    // Fill rest with zeros/defaults for video track
    for (int i = 0; i < 20; i++) {
      view.setUint32(offset, 0x00000000, Endian.big);
      offset += 4;
    }

    // Write actual box size
    final boxSize = offset - startOffset;
    view.setUint32(startOffset, boxSize, Endian.big);

    return offset;
  }

  /// Generates MP4 with unsupported codec
  static Future<void> _generateMP4UnsupportedCodec() async {
    // Generate normal MP4 structure but with unsupported codec
    await _generateMP4File('temp_unsupported.mp4', sampleRate: 44100, channels: 2, durationSeconds: 1.0, bitrate: 128);

    // Read and modify codec information
    final data = await File('$generatedPath/temp_unsupported.mp4').readAsBytes();

    // Find and replace 'mp4a' with unsupported codec 'xxxx'
    for (int i = 0; i < data.length - 4; i++) {
      if (data[i] == 0x6D && data[i + 1] == 0x70 && data[i + 2] == 0x34 && data[i + 3] == 0x61) {
        // Found 'mp4a', replace with 'xxxx'
        data[i] = 0x78; // 'x'
        data[i + 1] = 0x78; // 'x'
        data[i + 2] = 0x78; // 'x'
        data[i + 3] = 0x78; // 'x'
        break;
      }
    }

    final file = File('$generatedPath/mp4_unsupported_codec.mp4');
    await file.writeAsBytes(data);

    // Clean up temp file
    await File('$generatedPath/temp_unsupported.mp4').delete();
  }

  /// Generates empty MP4 file
  static Future<void> _generateEmptyMP4File() async {
    final file = File('$generatedPath/empty_mp4.mp4');
    await file.writeAsBytes(Uint8List(0));
  }

  /// Formats file size for human-readable output
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Main function to run MP4 test data generation
Future<void> main(List<String> args) async {
  final force = args.contains('--force') || args.contains('-f');
  final essential = args.contains('--essential') || args.contains('-e');

  try {
    if (essential) {
      await MP4TestDataGenerator.generateEssentialMP4TestData(force: force);
    } else {
      await MP4TestDataGenerator.generateAllMP4TestData(force: force);
    }

    print('\nMP4 test data generation completed successfully!');
    print('Generated files are located in: test/assets/generated/');
  } catch (e) {
    print('Error generating MP4 test data: $e');
    exit(1);
  }
}
