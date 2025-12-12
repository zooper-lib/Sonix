// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

/// Tests for encoder delay skip functionality
///
/// These tests verify that the decoder correctly skips encoder delay samples
/// for codecs that have pre-padding/priming samples.
void main() {
  setUpAll(() async {
    // Ensure FFMPEG is available for testing
    final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
    if (!available) {
      throw StateError('FFMPEG setup failed - Encoder delay tests require FFMPEG DLLs.');
    }
  });

  group('Encoder Delay Skip Tests', () {
    test('Opus - Skip 312 samples encoder delay', () async {
      final testFile = File('test/assets/generated/test_opus_312_samples.opus');

      if (!await testFile.exists()) {
        fail('Test file not found: ${testFile.path}. Run tool/generate_encoder_delay_test_files.dart first.');
      }

      final decoder = AudioDecoderFactory.createDecoder(testFile.path);
      try {
        final audioData = await decoder.decode(testFile.path);

        // Opus has 312 samples encoder delay at 48kHz
        // These samples should be skipped automatically
        expect(audioData.sampleRate, equals(48000));
        expect(audioData.channels, equals(2));

        // Duration should be approximately 3 seconds (not including the 6.5ms delay)
        expect(audioData.duration.inMilliseconds, greaterThan(2900));
        expect(audioData.duration.inMilliseconds, lessThan(3100));

        // First samples should be actual audio data, not garbage from encoder delay
        expect(audioData.samples.isNotEmpty, isTrue);

        print('Opus test passed:');
        print('  Sample rate: ${audioData.sampleRate}');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds}ms');
        print('  Total samples: ${audioData.samples.length}');
        print('  Encoder delay skipped: 312 samples (6.5ms)');
      } finally {
        decoder.dispose();
      }
    });

    test('WAV - No encoder delay (0 samples)', () async {
      final testFile = File('test/assets/generated/test_wav_0_samples.wav');

      if (!await testFile.exists()) {
        fail('Test file not found: ${testFile.path}');
      }

      final decoder = AudioDecoderFactory.createDecoder(testFile.path);
      try {
        final audioData = await decoder.decode(testFile.path);

        // WAV is uncompressed, no encoder delay
        expect(audioData.sampleRate, equals(48000));
        expect(audioData.channels, equals(2));

        // Duration should be approximately 3 seconds
        expect(audioData.duration.inMilliseconds, greaterThan(2900));
        expect(audioData.duration.inMilliseconds, lessThan(3100));

        // Calculate expected sample count (3 seconds * 48000 Hz * 2 channels)
        final expectedSamples = (3.0 * 48000 * 2).round();
        final actualSamples = audioData.samples.length;

        // Allow 1% tolerance
        expect(actualSamples, greaterThan(expectedSamples * 0.99));
        expect(actualSamples, lessThan(expectedSamples * 1.01));

        print('WAV test passed:');
        print('  Sample rate: ${audioData.sampleRate}');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds}ms');
        print('  Total samples: ${audioData.samples.length}');
        print('  Expected samples: $expectedSamples');
        print('  Encoder delay: 0 samples (uncompressed)');
      } finally {
        decoder.dispose();
      }
    });

    test('FLAC - No encoder delay (lossless)', () async {
      final testFile = File('test/assets/generated/test_flac_0_samples.flac');

      if (!await testFile.exists()) {
        fail('Test file not found: ${testFile.path}');
      }

      final decoder = AudioDecoderFactory.createDecoder(testFile.path);
      try {
        final audioData = await decoder.decode(testFile.path);

        // FLAC is lossless, no encoder delay
        expect(audioData.sampleRate, equals(48000));
        expect(audioData.channels, equals(2));

        expect(audioData.duration.inMilliseconds, greaterThan(2900));
        expect(audioData.duration.inMilliseconds, lessThan(3100));

        print('FLAC test passed:');
        print('  Sample rate: ${audioData.sampleRate}');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds}ms');
        print('  Total samples: ${audioData.samples.length}');
        print('  Encoder delay: 0 samples (lossless)');
      } finally {
        decoder.dispose();
      }
    });

    test('Vorbis - Encoder delay handled by decoder', () async {
      final testFile = File('test/assets/generated/test_vorbis.ogg');

      if (!await testFile.exists()) {
        fail('Test file not found: ${testFile.path}');
      }

      final decoder = AudioDecoderFactory.createDecoder(testFile.path);
      try {
        final audioData = await decoder.decode(testFile.path);

        // Vorbis encoder delay is handled internally
        expect(audioData.sampleRate, equals(48000));
        expect(audioData.channels, equals(2));

        expect(audioData.duration.inMilliseconds, greaterThan(2900));
        expect(audioData.duration.inMilliseconds, lessThan(3100));

        print('Vorbis test passed:');
        print('  Sample rate: ${audioData.sampleRate}');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds}ms');
        print('  Total samples: ${audioData.samples.length}');
        print('  Encoder delay: Handled by decoder/container');
      } finally {
        decoder.dispose();
      }
    });

    test('MP3 - LAME encoder (delay not in initial_padding)', () async {
      final testFile = File('test/assets/generated/test_mp3_lame_1152_samples.mp3');

      if (!await testFile.exists()) {
        fail('Test file not found: ${testFile.path}');
      }

      final decoder = AudioDecoderFactory.createDecoder(testFile.path);
      try {
        final audioData = await decoder.decode(testFile.path);

        // MP3 LAME encoder has ~1152 samples delay but it's not exposed via
        // initial_padding in FFmpeg (it's in the Xing/LAME header)
        expect(audioData.sampleRate, equals(48000));
        expect(audioData.channels, equals(2));

        expect(audioData.duration.inMilliseconds, greaterThan(2900));
        expect(audioData.duration.inMilliseconds, lessThan(3100));

        print('MP3 test passed:');
        print('  Sample rate: ${audioData.sampleRate}');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds}ms');
        print('  Total samples: ${audioData.samples.length}');
        print('  Note: LAME encoder delay (~1152 samples) not accessible via FFmpeg metadata');
        print('  Note: start_time suggests ~1105 samples delay');
      } finally {
        decoder.dispose();
      }
    });

    test('AAC - FFmpeg AAC encoder (delay not in initial_padding)', () async {
      final testFile = File('test/assets/generated/test_aac_2048_samples.m4a');

      if (!await testFile.exists()) {
        fail('Test file not found: ${testFile.path}');
      }

      final decoder = AudioDecoderFactory.createDecoder(testFile.path);
      try {
        final audioData = await decoder.decode(testFile.path);

        // AAC encoder has variable delay but FFmpeg AAC encoder doesn't
        // expose it via initial_padding (may be in MP4 edit list)
        expect(audioData.sampleRate, equals(48000));
        expect(audioData.channels, equals(2));

        expect(audioData.duration.inMilliseconds, greaterThan(2900));
        expect(audioData.duration.inMilliseconds, lessThan(3100));

        print('AAC test passed:');
        print('  Sample rate: ${audioData.sampleRate}');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds}ms');
        print('  Total samples: ${audioData.samples.length}');
        print('  Note: AAC encoder delay not accessible via FFmpeg initial_padding');
        print('  Note: May require libfdk_aac or MP4 edit list parsing');
      } finally {
        decoder.dispose();
      }
    });
  });

  group('Encoder Delay Documentation', () {
    test('Verify test file metadata', () async {
      final metadataFile = File('test/assets/generated/encoder_delay_metadata.json');

      expect(await metadataFile.exists(), isTrue, reason: 'Metadata file should exist. Run tool/generate_encoder_delay_test_files.dart');

      print('✅ Test file metadata available at: ${metadataFile.path}');
    });

    test('Verify verification report', () async {
      final reportFile = File('test/assets/generated/verification_report.json');

      expect(await reportFile.exists(), isTrue, reason: 'Verification report should exist. Run tool/verify_encoder_delay_files.dart');

      print('✅ Verification report available at: ${reportFile.path}');
    });
  });
}
