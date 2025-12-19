// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('MP4 Decoder Integration Tests', () {
    late MP4Decoder decoder;
    late String testMP4FilePath;

    setUpAll(() async {
      testMP4FilePath = 'test/assets/Double-F the King - Your Blessing.mp4';

      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw Exception('FFMPEG libraries not available for testing');
      }
    });

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Real MP4 File Decoding', () {
      test('should decode real MP4 file successfully', () async {
        final testFile = File(testMP4FilePath);
        if (!testFile.existsSync()) {
          fail('Real MP4 test file not found: $testMP4FilePath');
        }

        final audioData = await decoder.decode(testMP4FilePath);

        expect(audioData, isA<AudioData>());
        expect(audioData.samples.length, greaterThan(0));
        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, inInclusiveRange(1, 8)); // Support up to 8 channels
        expect(audioData.duration.inMilliseconds, greaterThan(0));

        // Verify audio data integrity
        expect(audioData.samples.every((sample) => sample.isFinite), isTrue);
        expect(audioData.samples.any((sample) => sample != 0.0), isTrue); // Should have non-zero samples

        print('MP4 Integration Test Results:');
        print('  File size: ${await testFile.length()} bytes');
        print('  Sample count: ${audioData.samples.length}');
        print('  Sample rate: ${audioData.sampleRate} Hz');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds} ms');
      });

      test('should fail chunked decoding initialization (known limitation)', () async {
        final testFile = File(testMP4FilePath);
        if (!testFile.existsSync()) {
          fail('Real MP4 test file not found: $testMP4FilePath');
        }

        // Currently, chunked decoding has issues with MP4 container parsing
        // The full decode method works (uses FFMPEG directly) but chunked processing
        // fails to properly parse the MP4 container structure
        expect(() => decoder.initializeChunkedDecoding(testMP4FilePath), throwsA(isA<MP4TrackException>()));

        expect(decoder.isInitialized, isFalse);
      });

      test('should demonstrate performance with full file decoding', () async {
        final testFile = File(testMP4FilePath);
        if (!testFile.existsSync()) {
          fail('Real MP4 test file not found: $testMP4FilePath');
        }

        final stopwatch = Stopwatch()..start();
        final audioData = await decoder.decode(testMP4FilePath);
        stopwatch.stop();

        final fileSize = await testFile.length();
        final throughputMBps = (fileSize / 1024 / 1024) / (stopwatch.elapsedMilliseconds / 1000);

        print('MP4 Full File Performance:');
        print('  File size: ${fileSize ~/ 1024} KB');
        print('  Processing time: ${stopwatch.elapsedMilliseconds} ms');
        print('  Throughput: ${throughputMBps.toStringAsFixed(2)} MB/s');
        print('  Samples processed: ${audioData.samples.length}');
        print('  Duration: ${audioData.duration.inMilliseconds} ms');

        expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // Should complete within 30 seconds
        expect(audioData.samples.length, greaterThan(0));
      });
    });

    group('Known Limitations', () {
      test('chunked processing not yet supported', () async {
        final testFile = File(testMP4FilePath);
        if (!testFile.existsSync()) {
          fail('Real MP4 test file not found: $testMP4FilePath');
        }

        // Document current limitation: chunked processing fails due to MP4 container parsing issues
        // Full file decoding works via FFMPEG, but the native MP4 container parser needs work
        expect(() => decoder.initializeChunkedDecoding(testMP4FilePath), throwsA(isA<MP4TrackException>()));

        // The error indicates "No audio track found in MP4 container"
        // This suggests the MP4 container parsing logic needs improvement
      });
    });
  });
}
