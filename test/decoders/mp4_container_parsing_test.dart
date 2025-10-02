import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';

void main() {
  group('MP4 Container Parsing', () {
    late MP4Decoder decoder;

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('MP4 Box Parsing', () {
      test('should parse ftyp box correctly', () {
        // Create synthetic ftyp box
        final ftypData = _createFtypBox('M4A ', 0, ['M4A ', 'mp42', 'isom']);

        final result = decoder.parseFtypBox(ftypData.sublist(8)); // Skip box header

        expect(result['majorBrand'], equals('M4A '));
        expect(result['minorVersion'], equals(0));
        expect(result['compatibleBrands'], contains('M4A '));
        expect(result['compatibleBrands'], contains('mp42'));
        expect(result['compatibleBrands'], contains('isom'));
      });

      test('should handle invalid ftyp box gracefully', () {
        final invalidData = Uint8List.fromList([0x00, 0x01, 0x02]); // Too short

        final result = decoder.parseFtypBox(invalidData);

        expect(result['majorBrand'], equals('unknown'));
        expect(result['minorVersion'], equals(0));
        expect(result['compatibleBrands'], isEmpty);
      });

      test('should parse mvhd box correctly', () {
        // Create synthetic mvhd box (version 0)
        final mvhdData = _createMvhdBox(version: 0, timeScale: 1000, duration: 180000);

        final result = decoder.parseMvhdBox(mvhdData.sublist(8)); // Skip box header

        expect(result['timeScale'], equals(1000));
        expect(result['duration'], equals(180000)); // 3 minutes at 1000 timescale
      });

      test('should parse stsd box for AAC audio', () {
        // Create synthetic stsd box with mp4a entry
        final stsdData = _createStsdBox(format: 'mp4a', channels: 2, sampleSize: 16, sampleRate: 44100);

        final result = decoder.parseStsdBox(stsdData.sublist(8)); // Skip box header

        expect(result['codecName'], equals('AAC')); // The parser converts 'mp4a' to 'AAC'
        expect(result['channels'], equals(2));
        expect(result['sampleSize'], equals(16));
        expect(result['sampleRate'], equals(44100));
      });

      test('should parse sample timing table (stts)', () {
        // Create synthetic stts box
        final sttsData = _createSttsBox([
          {'sampleCount': 100, 'sampleDelta': 1024},
          {'sampleCount': 50, 'sampleDelta': 512},
        ]);

        final result = decoder.parseSttsBox(sttsData.sublist(8)); // Skip box header

        expect(result, hasLength(2));
        expect(result[0]['sampleCount'], equals(100));
        expect(result[0]['sampleDelta'], equals(1024));
        expect(result[1]['sampleCount'], equals(50));
        expect(result[1]['sampleDelta'], equals(512));
      });

      test('should parse sample sizes table (stsz)', () {
        // Create synthetic stsz box with individual sample sizes
        final stszData = _createStszBox([768, 512, 1024, 256]);

        final result = decoder.parseStszBox(stszData.sublist(8)); // Skip box header

        expect(result, hasLength(4));
        expect(result[0], equals(768));
        expect(result[1], equals(512));
        expect(result[2], equals(1024));
        expect(result[3], equals(256));
      });

      test('should parse chunk offsets table (stco)', () {
        // Create synthetic stco box
        final stcoData = _createStcoBox([1024, 2048, 4096, 8192]);

        final result = decoder.parseStcoBox(stcoData.sublist(8)); // Skip box header

        expect(result, hasLength(4));
        expect(result[0], equals(1024));
        expect(result[1], equals(2048));
        expect(result[2], equals(4096));
        expect(result[3], equals(8192));
      });
    });

    group('Container Metadata Extraction', () {
      test('should extract audio track information from complete container', () {
        // Create a synthetic MP4 container with audio track
        final containerData = _createSyntheticMP4Container(
          duration: 180000, // 3 minutes
          timeScale: 1000,
          sampleRate: 44100,
          channels: 2,
          sampleSizes: List.generate(100, (i) => 768 + (i % 256)), // Variable sizes
          chunkOffsets: [32768, 100000, 200000, 300000],
        );

        // Parse the container
        final metadata = decoder.parseMP4Boxes(containerData);
        final audioTrack = decoder.findAudioTrack(metadata);

        expect(audioTrack, isNotNull);
        expect(audioTrack!['sampleRate'], equals(44100));
        expect(audioTrack['channels'], equals(2));
        expect(audioTrack['codecName'], equals('AAC'));
        expect(audioTrack['duration'], equals(180000));
        expect(audioTrack['timeScale'], equals(1000));
      });

      test('should handle container without audio track', () {
        // Create a container with only video track
        final containerData = _createSyntheticMP4Container(duration: 180000, timeScale: 1000, hasAudioTrack: false);

        final metadata = decoder.parseMP4Boxes(containerData);
        final audioTrack = decoder.findAudioTrack(metadata);

        expect(audioTrack, isNull);
      });

      test('should estimate bitrate correctly', () {
        // Test bitrate estimation for different sample rates and channels
        expect(decoder.estimateBitrate(44100, 2), equals(128000)); // Stereo 44.1kHz
        expect(decoder.estimateBitrate(44100, 1), equals(96000)); // Mono 44.1kHz
        expect(decoder.estimateBitrate(22050, 2), equals(96000)); // Stereo 22kHz
        expect(decoder.estimateBitrate(22050, 1), equals(64000)); // Mono 22kHz
        expect(decoder.estimateBitrate(11025, 2), equals(64000)); // Stereo 11kHz
        expect(decoder.estimateBitrate(11025, 1), equals(32000)); // Mono 11kHz
      });
    });

    group('Sample Index Building', () {
      test('should build sample index from parsed tables', () {
        final audioTrack = {
          'sampleSizes': [768, 512, 1024, 256, 768],
          'chunkOffsets': [32768, 100000],
          'sampleToChunk': [
            {'firstChunk': 1, 'samplesPerChunk': 3, 'sampleDescriptionIndex': 1},
            {'firstChunk': 2, 'samplesPerChunk': 2, 'sampleDescriptionIndex': 1},
          ],
          'sampleTimes': [
            {'sampleCount': 5, 'sampleDelta': 1024},
          ],
          'timeScale': 44100,
        };

        decoder.buildSampleIndexFromTables(audioTrack);

        // Should have 5 samples total (3 in first chunk, 2 in second chunk)
        expect(decoder.sampleOffsets, hasLength(5));
        expect(decoder.sampleTimestamps, hasLength(5));

        // Check first chunk samples
        expect(decoder.sampleOffsets[0], equals(32768));
        expect(decoder.sampleOffsets[1], equals(32768 + 768));
        expect(decoder.sampleOffsets[2], equals(32768 + 768 + 512));

        // Check second chunk samples
        expect(decoder.sampleOffsets[3], equals(100000));
        expect(decoder.sampleOffsets[4], equals(100000 + 256));

        // Check timestamps (1024 samples per frame at 44100 Hz = ~23.22ms per frame)
        expect(decoder.sampleTimestamps[0].inMilliseconds, equals(0));
        expect(decoder.sampleTimestamps[1].inMilliseconds, closeTo(23, 1));
        expect(decoder.sampleTimestamps[2].inMilliseconds, closeTo(46, 1));
      });

      test('should fall back to estimated index when tables are invalid', () {
        final audioTrack = <String, dynamic>{
          'sampleSizes': <int>[], // Empty sample sizes
          'chunkOffsets': <int>[], // Empty chunk offsets
        };

        expect(() => decoder.buildSampleIndexFromTables(audioTrack), throwsA(isA<MP4TrackException>()));
      });

      test('should build estimated sample index', () {
        decoder.sampleRate = 44100; // Set sample rate for calculations

        decoder.buildEstimatedSampleIndex(1000000); // 1MB file

        expect(decoder.sampleOffsets, isNotEmpty);
        expect(decoder.sampleTimestamps, isNotEmpty);
        expect(decoder.sampleOffsets.length, equals(decoder.sampleTimestamps.length));

        // Check that offsets are increasing
        for (int i = 1; i < decoder.sampleOffsets.length; i++) {
          expect(decoder.sampleOffsets[i], greaterThan(decoder.sampleOffsets[i - 1]));
        }

        // Check that timestamps are increasing
        for (int i = 1; i < decoder.sampleTimestamps.length; i++) {
          expect(decoder.sampleTimestamps[i], greaterThan(decoder.sampleTimestamps[i - 1]));
        }
      });
    });

    group('Error Handling', () {
      test('should handle invalid container data gracefully', () {
        final invalidData = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]); // Invalid MP4 data

        final result = decoder.parseMP4Boxes(invalidData);
        expect(result, isEmpty); // Should return empty metadata for invalid data
      });

      test('should handle corrupted box headers gracefully', () {
        // Create data with invalid box size
        final corruptedData = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, // Invalid large size
          0x66, 0x74, 0x79, 0x70, // 'ftyp' type
          0x00, 0x01, 0x02, 0x03, // Some data
        ]);

        final result = decoder.parseMP4Boxes(corruptedData);
        expect(result, isEmpty); // Should return empty metadata for corrupted data
      });

      test('should handle empty or null box data', () {
        expect(decoder.parseFtypBox(null), isA<Map<String, dynamic>>());
        expect(decoder.parseFtypBox(Uint8List(0)), isA<Map<String, dynamic>>());

        expect(decoder.parseMvhdBox(Uint8List(0)), isEmpty);
        expect(decoder.parseStsdBox(Uint8List(0)), isEmpty);
      });
    });

    group('Utility Methods', () {
      test('should read big-endian integers correctly', () {
        final data = Uint8List.fromList([
          0x12, 0x34, 0x56, 0x78, // 32-bit: 0x12345678
          0x9A, 0xBC, 0xDE, 0xF0, // 32-bit: 0x9ABCDEF0
          0x11, 0x22, // 16-bit: 0x1122
          0x33, 0x44, // 16-bit: 0x3344
        ]);

        expect(decoder.readUint32BE(data, 0), equals(0x12345678));
        expect(decoder.readUint32BE(data, 4), equals(0x9ABCDEF0));
        expect(decoder.readUint16BE(data, 8), equals(0x1122));
        expect(decoder.readUint16BE(data, 10), equals(0x3344));
      });

      test('should throw RangeError for out-of-bounds reads', () {
        final data = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

        expect(() => decoder.readUint32BE(data, 1), throwsA(isA<RangeError>()));
        expect(() => decoder.readUint16BE(data, 3), throwsA(isA<RangeError>()));
        expect(() => decoder.readUint64BE(data, 0), throwsA(isA<RangeError>()));
      });
    });
  });
}

// Helper functions to create synthetic MP4 box data for testing

Uint8List _createFtypBox(String majorBrand, int minorVersion, List<String> compatibleBrands) {
  final data = <int>[];

  // Box size (will be calculated)
  final contentSize = 8 + 4 + 4 + (compatibleBrands.length * 4);
  data.addAll(_uint32ToBytes(contentSize));

  // Box type 'ftyp'
  data.addAll('ftyp'.codeUnits);

  // Major brand
  data.addAll(majorBrand.padRight(4).substring(0, 4).codeUnits);

  // Minor version
  data.addAll(_uint32ToBytes(minorVersion));

  // Compatible brands
  for (final brand in compatibleBrands) {
    data.addAll(brand.padRight(4).substring(0, 4).codeUnits);
  }

  return Uint8List.fromList(data);
}

Uint8List _createMvhdBox({required int version, required int timeScale, required int duration}) {
  final data = <int>[];

  // Box size (will be calculated based on version)
  final contentSize = version == 1 ? 120 : 108;
  data.addAll(_uint32ToBytes(contentSize));

  // Box type 'mvhd'
  data.addAll('mvhd'.codeUnits);

  // Version and flags
  data.add(version);
  data.addAll([0x00, 0x00, 0x00]); // Flags

  if (version == 1) {
    // 64-bit timestamps
    data.addAll(_uint64ToBytes(0)); // Creation time
    data.addAll(_uint64ToBytes(0)); // Modification time
    data.addAll(_uint32ToBytes(timeScale));
    data.addAll(_uint64ToBytes(duration));
  } else {
    // 32-bit timestamps
    data.addAll(_uint32ToBytes(0)); // Creation time
    data.addAll(_uint32ToBytes(0)); // Modification time
    data.addAll(_uint32ToBytes(timeScale));
    data.addAll(_uint32ToBytes(duration));
  }

  // Add remaining mvhd fields (rate, volume, reserved, matrix, etc.)
  data.addAll(List.filled(contentSize - data.length, 0));

  return Uint8List.fromList(data);
}

Uint8List _createStsdBox({required String format, required int channels, required int sampleSize, required int sampleRate}) {
  final data = <int>[];

  // Box size (will be calculated at the end)
  final sizePos = data.length;
  data.addAll([0, 0, 0, 0]); // Placeholder for size

  // Box type 'stsd'
  data.addAll('stsd'.codeUnits);

  // Version and flags
  data.addAll([0x00, 0x00, 0x00, 0x00]);

  // Entry count
  data.addAll(_uint32ToBytes(1));

  // Sample description entry
  final entryStart = data.length;
  data.addAll([0, 0, 0, 0]); // Placeholder for sample description size
  data.addAll(format.codeUnits); // Format (e.g., 'mp4a')
  data.addAll(List.filled(6, 0)); // Reserved
  data.addAll(_uint16ToBytes(channels));
  data.addAll(_uint16ToBytes(sampleSize));
  data.addAll(_uint32ToBytes(0)); // Pre-defined and reserved
  data.addAll(_uint32ToBytes(sampleRate << 16)); // Sample rate (16.16 fixed point)

  // Calculate and set the sample description size
  final entrySize = data.length - entryStart;
  final entrySizeBytes = _uint32ToBytes(entrySize);
  for (int i = 0; i < 4; i++) {
    data[entryStart + i] = entrySizeBytes[i];
  }

  // Calculate and set the total box size
  final totalSize = data.length;
  final totalSizeBytes = _uint32ToBytes(totalSize);
  for (int i = 0; i < 4; i++) {
    data[sizePos + i] = totalSizeBytes[i];
  }

  return Uint8List.fromList(data);
}

Uint8List _createSttsBox(List<Map<String, int>> entries) {
  final data = <int>[];

  // Box size
  final contentSize = 8 + 4 + 4 + (entries.length * 8);
  data.addAll(_uint32ToBytes(contentSize));

  // Box type 'stts'
  data.addAll('stts'.codeUnits);

  // Version and flags
  data.addAll([0x00, 0x00, 0x00, 0x00]);

  // Entry count
  data.addAll(_uint32ToBytes(entries.length));

  // Entries
  for (final entry in entries) {
    data.addAll(_uint32ToBytes(entry['sampleCount']!));
    data.addAll(_uint32ToBytes(entry['sampleDelta']!));
  }

  return Uint8List.fromList(data);
}

Uint8List _createStszBox(List<int> sampleSizes) {
  final data = <int>[];

  // Box size
  final contentSize = 8 + 4 + 4 + 4 + (sampleSizes.length * 4);
  data.addAll(_uint32ToBytes(contentSize));

  // Box type 'stsz'
  data.addAll('stsz'.codeUnits);

  // Version and flags
  data.addAll([0x00, 0x00, 0x00, 0x00]);

  // Sample size (0 for individual sizes)
  data.addAll(_uint32ToBytes(0));

  // Sample count
  data.addAll(_uint32ToBytes(sampleSizes.length));

  // Individual sample sizes
  for (final size in sampleSizes) {
    data.addAll(_uint32ToBytes(size));
  }

  return Uint8List.fromList(data);
}

Uint8List _createStcoBox(List<int> chunkOffsets) {
  final data = <int>[];

  // Box size
  final contentSize = 8 + 4 + 4 + (chunkOffsets.length * 4);
  data.addAll(_uint32ToBytes(contentSize));

  // Box type 'stco'
  data.addAll('stco'.codeUnits);

  // Version and flags
  data.addAll([0x00, 0x00, 0x00, 0x00]);

  // Entry count
  data.addAll(_uint32ToBytes(chunkOffsets.length));

  // Chunk offsets
  for (final offset in chunkOffsets) {
    data.addAll(_uint32ToBytes(offset));
  }

  return Uint8List.fromList(data);
}

Uint8List _createSyntheticMP4Container({
  required int duration,
  required int timeScale,
  int sampleRate = 44100,
  int channels = 2,
  List<int>? sampleSizes,
  List<int>? chunkOffsets,
  bool hasAudioTrack = true,
}) {
  final data = <int>[];

  // Create ftyp box
  final ftypBox = _createFtypBox('M4A ', 0, ['M4A ', 'mp42', 'isom']);
  data.addAll(ftypBox);

  if (hasAudioTrack) {
    // Create a complete moov box with audio track
    final moovData = <int>[];

    // mvhd box
    final mvhdBox = _createMvhdBox(version: 0, timeScale: timeScale, duration: duration);
    moovData.addAll(mvhdBox);

    // Create trak box with audio track
    final trakData = <int>[];

    // tkhd box (track header)
    final tkhdData = <int>[];
    tkhdData.addAll(_uint32ToBytes(92)); // Box size
    tkhdData.addAll('tkhd'.codeUnits);
    tkhdData.addAll([0x00, 0x00, 0x00, 0x07]); // Version and flags (track enabled)
    tkhdData.addAll(_uint32ToBytes(0)); // Creation time
    tkhdData.addAll(_uint32ToBytes(0)); // Modification time
    tkhdData.addAll(_uint32ToBytes(1)); // Track ID
    tkhdData.addAll(_uint32ToBytes(0)); // Reserved
    tkhdData.addAll(_uint32ToBytes(duration)); // Duration
    tkhdData.addAll(List.filled(60, 0)); // Reserved fields, matrix, etc.
    trakData.addAll(tkhdData);

    // mdia box (media)
    final mdiaData = <int>[];

    // mdhd box (media header)
    final mdhdData = <int>[];
    mdhdData.addAll(_uint32ToBytes(32)); // Box size
    mdhdData.addAll('mdhd'.codeUnits);
    mdhdData.addAll([0x00, 0x00, 0x00, 0x00]); // Version and flags
    mdhdData.addAll(_uint32ToBytes(0)); // Creation time
    mdhdData.addAll(_uint32ToBytes(0)); // Modification time
    mdhdData.addAll(_uint32ToBytes(timeScale)); // Time scale
    mdhdData.addAll(_uint32ToBytes(duration)); // Duration
    mdhdData.addAll([0x55, 0xC4, 0x00, 0x00]); // Language and pre_defined
    mdiaData.addAll(mdhdData);

    // hdlr box (handler)
    final hdlrData = <int>[];
    hdlrData.addAll(_uint32ToBytes(33)); // Box size
    hdlrData.addAll('hdlr'.codeUnits);
    hdlrData.addAll([0x00, 0x00, 0x00, 0x00]); // Version and flags
    hdlrData.addAll([0x00, 0x00, 0x00, 0x00]); // Pre-defined
    hdlrData.addAll('soun'.codeUnits); // Handler type (sound)
    hdlrData.addAll(List.filled(12, 0)); // Reserved
    hdlrData.add(0); // Name (empty string)
    mdiaData.addAll(hdlrData);

    // minf box (media information) - simplified
    final minfData = <int>[];

    // stbl box (sample table) - simplified
    final stblData = <int>[];

    // stsd box (sample description)
    final stsdBox = _createStsdBox(format: 'mp4a', channels: channels, sampleSize: 16, sampleRate: sampleRate);
    stblData.addAll(stsdBox);

    // Add sample table info if provided
    if (sampleSizes != null) {
      final stszBox = _createStszBox(sampleSizes);
      stblData.addAll(stszBox);
    }

    if (chunkOffsets != null) {
      final stcoBox = _createStcoBox(chunkOffsets);
      stblData.addAll(stcoBox);
    }

    // Wrap stbl in minf
    final stblSize = 8 + stblData.length;
    minfData.addAll(_uint32ToBytes(stblSize));
    minfData.addAll('stbl'.codeUnits);
    minfData.addAll(stblData);

    // Wrap minf in mdia
    final minfSize = 8 + minfData.length;
    mdiaData.addAll(_uint32ToBytes(minfSize));
    mdiaData.addAll('minf'.codeUnits);
    mdiaData.addAll(minfData);

    // Wrap mdia in trak
    final mdiaSize = 8 + mdiaData.length;
    trakData.addAll(_uint32ToBytes(mdiaSize));
    trakData.addAll('mdia'.codeUnits);
    trakData.addAll(mdiaData);

    // Add trak to moov
    final trakSize = 8 + trakData.length;
    moovData.addAll(_uint32ToBytes(trakSize));
    moovData.addAll('trak'.codeUnits);
    moovData.addAll(trakData);

    // Create moov box header
    final moovSize = 8 + moovData.length;
    data.addAll(_uint32ToBytes(moovSize));
    data.addAll('moov'.codeUnits);
    data.addAll(moovData);
  }

  return Uint8List.fromList(data);
}

// Utility functions for byte conversion

List<int> _uint32ToBytes(int value) {
  return [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
}

List<int> _uint64ToBytes(int value) {
  return [..._uint32ToBytes((value >> 32) & 0xFFFFFFFF), ..._uint32ToBytes(value & 0xFFFFFFFF)];
}

List<int> _uint16ToBytes(int value) {
  return [(value >> 8) & 0xFF, value & 0xFF];
}
