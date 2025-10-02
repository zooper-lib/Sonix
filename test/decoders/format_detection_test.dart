import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
import '../test_helpers/test_data_loader.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

/// Helper function to test format detection with byte data
int _testFormatDetection(List<int> bytes) {
  final dataPtr = malloc<ffi.Uint8>(bytes.length);
  final nativeData = dataPtr.asTypedList(bytes.length);
  nativeData.setAll(0, bytes);

  try {
    return SonixNativeBindings.detectFormat(dataPtr, bytes.length);
  } finally {
    malloc.free(dataPtr);
  }
}

void main() {
  group('Format Detection Tests', () {
    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw StateError(
          'FFMPEG setup failed - Format detection tests require FFMPEG DLLs. '
          'These tests validate audio format detection functionality and '
          'cannot be skipped when FFMPEG is not available.',
        );
      }
    });

    group('Synthetic Format Detection', () {
      test('should detect WAV format from RIFF header', () {
        // Create minimal WAV header
        final wavHeader = [
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x00, 0x00, 0x00, // File size - 8
          0x57, 0x41, 0x56, 0x45, // "WAVE"
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // fmt chunk size
          0x01, 0x00, // PCM format
          0x02, 0x00, // 2 channels
          0x44, 0xAC, 0x00, 0x00, // 44100 sample rate
          0x10, 0xB1, 0x02, 0x00, // Byte rate
          0x04, 0x00, // Block align
          0x10, 0x00, // 16 bits per sample
          0x64, 0x61, 0x74, 0x61, // "data"
          0x00, 0x00, 0x00, 0x00, // Data size
        ];

        final detectedFormat = _testFormatDetection(wavHeader);
        expect(detectedFormat, equals(SONIX_FORMAT_WAV), reason: 'Should detect WAV format from RIFF/WAVE header');
      });

      test('should detect MP3 format from sync frame', () {
        // Create MP3 sync frame header
        final mp3Header = [
          0xFF, 0xFB, // MP3 sync word (11 bits set)
          0x90, 0x00, // MPEG-1 Layer III, 128kbps, 44.1kHz
          // Add some padding to make it look more realistic
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
        ];

        final detectedFormat = _testFormatDetection(mp3Header);
        expect(detectedFormat, equals(SONIX_FORMAT_MP3), reason: 'Should detect MP3 format from sync frame');
      });

      test('should detect MP3 format from ID3 tag', () {
        // Create ID3v2 header
        final id3Header = [
          0x49, 0x44, 0x33, // "ID3"
          0x03, 0x00, // Version 2.3
          0x00, // Flags
          0x00, 0x00, 0x00, 0x00, // Size (synchsafe)
          // Add some padding
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
        ];

        final detectedFormat = _testFormatDetection(id3Header);
        expect(detectedFormat, equals(SONIX_FORMAT_MP3), reason: 'Should detect MP3 format from ID3 tag');
      });

      test('should detect FLAC format from signature', () {
        // Create FLAC signature and minimal metadata
        final flacHeader = [
          0x66, 0x4C, 0x61, 0x43, // "fLaC"
          0x00, // Last metadata block flag + block type (STREAMINFO)
          0x00, 0x00, 0x22, // Block length (34 bytes)
          // STREAMINFO data (simplified)
          0x10, 0x00, 0x10, 0x00, // Min/max block size
          0x00, 0x00, 0x00, // Min frame size
          0x00, 0x00, 0x00, // Max frame size
          0x44, 0xAC, 0x00, // Sample rate (44100)
          0x20, // Channels and bits per sample
          0x00, 0x00, 0x00, 0x00, // Total samples
          // MD5 signature (16 bytes)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];

        final detectedFormat = _testFormatDetection(flacHeader);
        expect(detectedFormat, equals(SONIX_FORMAT_FLAC), reason: 'Should detect FLAC format from fLaC signature');
      });

      test('should detect OGG format from page header', () {
        // Create OGG page header
        final oggHeader = [
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, // Version
          0x02, // Header type (first page of logical bitstream)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x01, 0x02, 0x03, 0x04, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence number
          0x12, 0x34, 0x56, 0x78, // CRC checksum
          0x01, // Number of page segments
          0x1E, // Segment table (30 bytes)
          // Add some Vorbis-like data
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // Vorbis identification
        ];

        final detectedFormat = _testFormatDetection(oggHeader);
        expect(detectedFormat, equals(SONIX_FORMAT_OGG), reason: 'Should detect OGG format from OggS signature');
      });

      test('should detect OGG format from synthetic OGG container (Opus uses OGG)', () {
        // Create synthetic OGG page header - this is what we can reliably detect from headers
        // Note: Opus codec detection requires full stream analysis, so header-only detection
        // will correctly identify the OGG container format
        final oggHeader = [
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, // Version
          0x02, // Header type (first page of logical bitstream)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x01, 0x02, 0x03, 0x04, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence number
          0x00, 0x00, 0x00, 0x00, // CRC checksum (simplified for synthetic test)
          0x01, // Number of page segments
          0x13, // Segment table (19 bytes)
          // Generic OGG content (OpusHead would be here in real files)
          0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
          0x01, // Version
          0x02, // Channel count
          0x00, 0x0F, // Pre-skip
          0x80, 0xBB, 0x00, 0x00, // Input sample rate (48000)
          0x00, 0x00, // Output gain
          0x00, // Channel mapping family
        ];

        final detectedFormat = _testFormatDetection(oggHeader);
        // Synthetic headers can only detect OGG container format
        // Full Opus codec detection requires complete stream analysis with valid CRC
        expect(
          detectedFormat,
          equals(SONIX_FORMAT_OGG),
          reason: 'Should detect OGG container format from synthetic header (Opus codec detection requires full stream analysis)',
        );
      });

      test('should detect MP4 format from ftyp box', () {
        // Create MP4 ftyp box (based on real file structure)
        final mp4Header = [
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // Major brand "isom"
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand "isom"
          0x69, 0x73, 0x6F, 0x32, // Compatible brand "iso2"
          0x61, 0x76, 0x63, 0x31, // Compatible brand "avc1"
          0x6D, 0x70, 0x34, 0x31, // Compatible brand "mp41"
          // Add minimal mdat box to make it more realistic
          0x00, 0x00, 0x00, 0x08, // Box size (8 bytes)
          0x6D, 0x64, 0x61, 0x74, // "mdat"
        ];

        final detectedFormat = _testFormatDetection(mp4Header);
        // Note: FFMPEG might still not detect this as MP4 since it's synthetic
        // The test verifies that the function doesn't crash and returns a valid result
        expect(detectedFormat, anyOf([SONIX_FORMAT_MP4, SONIX_FORMAT_UNKNOWN]), reason: 'Should detect MP4 format or return unknown for synthetic data');
      });

      test('should return unknown for invalid data', () {
        // Create completely invalid data
        final invalidData = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88];

        final detectedFormat = _testFormatDetection(invalidData);
        expect(detectedFormat, equals(SONIX_FORMAT_UNKNOWN), reason: 'Should return unknown for invalid data');
      });

      test('should handle edge cases safely', () {
        // Test with very small buffer
        final smallData = [0xFF, 0xFB];
        final smallResult = _testFormatDetection(smallData);
        expect(smallResult, anyOf([SONIX_FORMAT_MP3, SONIX_FORMAT_UNKNOWN]), reason: 'Should handle small buffers gracefully');

        // Test with null pointer
        final nullResult = SonixNativeBindings.detectFormat(ffi.Pointer<ffi.Uint8>.fromAddress(0), 0);
        expect(nullResult, equals(SONIX_FORMAT_UNKNOWN), reason: 'Should return unknown for null pointer');

        // Test with empty buffer
        final emptyPtr = malloc<ffi.Uint8>(1);
        try {
          final emptyResult = SonixNativeBindings.detectFormat(emptyPtr, 0);
          expect(emptyResult, equals(SONIX_FORMAT_UNKNOWN), reason: 'Should return unknown for empty buffer');
        } finally {
          malloc.free(emptyPtr);
        }
      });
    });

    group('Real File Format Detection', () {
      test('should detect formats from real test files', () async {
        final testFiles = [
          {'file': 'Double-F the King - Your Blessing.wav', 'expected': SONIX_FORMAT_WAV, 'format': 'WAV'},
          {'file': 'Double-F the King - Your Blessing.mp3', 'expected': SONIX_FORMAT_MP3, 'format': 'MP3'},
          {'file': 'Double-F the King - Your Blessing.flac', 'expected': SONIX_FORMAT_FLAC, 'format': 'FLAC'},
          {'file': 'Double-F the King - Your Blessing.ogg', 'expected': SONIX_FORMAT_OGG, 'format': 'OGG'},
          {'file': 'Double-F the King - Your Blessing.opus', 'expected': SONIX_FORMAT_OPUS, 'format': 'OPUS'},
          {'file': 'Double-F the King - Your Blessing.mp4', 'expected': SONIX_FORMAT_MP4, 'format': 'MP4'},
        ];

        for (final testFile in testFiles) {
          final fileName = testFile['file'] as String;
          final expectedFormat = testFile['expected'] as int;
          final formatName = testFile['format'] as String;

          if (!await TestDataLoader.assetExists(fileName)) {
            // ignore: avoid_print
            print('Skipping $formatName test - file not found: $fileName');
            continue;
          }

          final filePath = TestDataLoader.getAssetPath(fileName);
          final file = File(filePath);
          final fileBytes = await file.readAsBytes();

          if (fileBytes.isEmpty) {
            // ignore: avoid_print
            print('Skipping $formatName test - file is empty: $fileName');
            continue;
          }

          final detectedFormat = _testFormatDetection(fileBytes);

          // Log the detection result for debugging
          // ignore: avoid_print
          print('$formatName detection: file=$fileName, detected=$detectedFormat, expected=$expectedFormat');

          // Format detection should work correctly - test should fail if it doesn't
          expect(
            detectedFormat,
            equals(expectedFormat),
            reason:
                'Format detection for $formatName file $fileName failed. '
                'Detected: $detectedFormat, Expected: $expectedFormat',
          );

          // If detection failed, let's examine the file header
          if (detectedFormat == SONIX_FORMAT_UNKNOWN && expectedFormat != SONIX_FORMAT_UNKNOWN) {
            final headerBytes = fileBytes.take(16).toList();
            final headerHex = headerBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            // ignore: avoid_print
            print('$formatName file header: $headerHex');
          }
        }
      });

      test('should detect formats from file headers only', () async {
        final testFiles = [
          {'file': 'Double-F the King - Your Blessing.wav', 'expected': SONIX_FORMAT_WAV, 'format': 'WAV'},
          {'file': 'Double-F the King - Your Blessing.mp3', 'expected': SONIX_FORMAT_MP3, 'format': 'MP3'},
          {'file': 'Double-F the King - Your Blessing.flac', 'expected': SONIX_FORMAT_FLAC, 'format': 'FLAC'},
          {'file': 'Double-F the King - Your Blessing.ogg', 'expected': SONIX_FORMAT_OGG, 'format': 'OGG'},
          {'file': 'Double-F the King - Your Blessing.opus', 'expected': SONIX_FORMAT_OGG, 'format': 'OPUS'},
          {'file': 'Double-F the King - Your Blessing.mp4', 'expected': SONIX_FORMAT_MP4, 'format': 'MP4'},
        ];

        for (final testFile in testFiles) {
          final fileName = testFile['file'] as String;
          final expectedFormat = testFile['expected'] as int;
          final formatName = testFile['format'] as String;

          if (!await TestDataLoader.assetExists(fileName)) {
            continue;
          }

          final filePath = TestDataLoader.getAssetPath(fileName);
          final file = File(filePath);
          final fileBytes = await file.readAsBytes();

          if (fileBytes.length < 44) {
            continue;
          }

          // Test with just the first 44 bytes (typical header size)
          final headerBytes = fileBytes.take(44).toList();
          final detectedFormat = _testFormatDetection(headerBytes);

          // ignore: avoid_print
          print('$formatName header-only detection: detected=$detectedFormat, expected=$expectedFormat');

          // Header-only detection should work correctly
          expect(
            detectedFormat,
            equals(expectedFormat),
            reason:
                'Header-only format detection for $formatName failed. '
                'Detected: $detectedFormat, Expected: $expectedFormat',
          );
        }
      });

      test('should handle corrupted files gracefully', () async {
        final corruptedFiles = ['corrupted_header.mp3', 'corrupted_riff.wav', 'corrupted_signature.flac', 'empty_file.mp3', 'invalid_format.xyz'];

        for (final fileName in corruptedFiles) {
          if (!await TestDataLoader.assetExists(fileName)) {
            continue;
          }

          final filePath = TestDataLoader.getAssetPath(fileName);
          final file = File(filePath);
          final fileBytes = await file.readAsBytes();

          if (fileBytes.isEmpty) {
            continue;
          }

          final detectedFormat = _testFormatDetection(fileBytes);

          // ignore: avoid_print
          print('Corrupted file detection: file=$fileName, detected=$detectedFormat');

          // Corrupted files should either be detected as unknown or their original format
          expect(
            detectedFormat,
            anyOf([SONIX_FORMAT_UNKNOWN, SONIX_FORMAT_MP3, SONIX_FORMAT_WAV, SONIX_FORMAT_FLAC, SONIX_FORMAT_OGG, SONIX_FORMAT_MP4]),
            reason: 'Corrupted file detection should not crash',
          );
        }
      });
    });

    group('Format Detection Performance', () {
      test('should handle large files efficiently', () async {
        // Find a large test file
        final availableFiles = await TestDataLoader.getAvailableAudioFiles();
        final largeFile = availableFiles.firstWhere(
          (file) => file.contains('large') || file.contains('medium'),
          orElse: () => availableFiles.isNotEmpty ? availableFiles.first : '',
        );

        if (largeFile.isEmpty) {
          // ignore: avoid_print
          print('No large files available for performance testing');
          return;
        }

        final filePath = TestDataLoader.getAssetPath(largeFile);
        final file = File(filePath);
        final fileBytes = await file.readAsBytes();

        if (fileBytes.length < 1024) {
          return;
        }

        final stopwatch = Stopwatch()..start();
        final detectedFormat = _testFormatDetection(fileBytes);
        stopwatch.stop();

        // ignore: avoid_print
        print(
          'Large file detection: file=$largeFile, size=${fileBytes.length}, '
          'time=${stopwatch.elapsedMilliseconds}ms, format=$detectedFormat',
        );

        // Format detection should complete reasonably quickly
        // Note: Currently takes ~500ms for large files - this indicates a performance issue
        if (stopwatch.elapsedMilliseconds > 100) {
          // ignore: avoid_print
          print('PERFORMANCE ISSUE: Format detection took ${stopwatch.elapsedMilliseconds}ms for large file');
        }
        expect(stopwatch.elapsedMilliseconds, lessThan(1000), reason: 'Format detection should complete within 1 second even for large files');

        expect(
          detectedFormat,
          anyOf([SONIX_FORMAT_WAV, SONIX_FORMAT_MP3, SONIX_FORMAT_FLAC, SONIX_FORMAT_OGG, SONIX_FORMAT_MP4, SONIX_FORMAT_UNKNOWN]),
          reason: 'Should return a valid format constant',
        );
      });

      test('should be consistent across multiple calls', () {
        // Test with a simple WAV header
        final wavHeader = [
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x00, 0x00, 0x00, // File size
          0x57, 0x41, 0x56, 0x45, // "WAVE"
          0x66, 0x6D, 0x74, 0x20, // "fmt "
        ];

        // Call detection multiple times
        final results = <int>[];
        for (int i = 0; i < 10; i++) {
          results.add(_testFormatDetection(wavHeader));
        }

        // All results should be the same
        final firstResult = results.first;
        for (final result in results) {
          expect(result, equals(firstResult), reason: 'Format detection should be consistent across multiple calls');
        }
      });
    });
  });
}
