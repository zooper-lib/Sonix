// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('MP3 Decoder Diagnostic Tests', () {
    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw Exception('FFMPEG libraries not available for testing');
      }
    });

    test('should identify segmentation fault location', () async {
      print('=== MP3 Decoder Segmentation Fault Diagnostic ===');

      // Step 1: Test native library loading
      print('Step 1: Testing native library loading...');
      try {
        NativeAudioBindings.initialize();
        print('✓ Native bindings initialized successfully');
      } catch (e) {
        print('✗ Native bindings initialization failed: $e');
        fail('Native bindings initialization failed: $e');
      }

      // Step 2: Test backend detection
      print('Step 2: Testing backend detection...');
      try {
        final backendType = NativeAudioBindings.backendType;
        print('✓ Backend type detected: $backendType');
      } catch (e) {
        print('✗ Backend detection failed: $e');
        fail('Backend detection failed: $e');
      }

      // Step 3: Test format detection with minimal data
      print('Step 3: Testing format detection with minimal data...');
      try {
        final minimalMp3Header = Uint8List.fromList([
          0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, // ID3v2 header
          0xFF, 0xFB, 0x90, 0x00, // MP3 sync frame
        ]);
        final format = NativeAudioBindings.detectFormat(minimalMp3Header);
        print('✓ Format detection successful: $format');
      } catch (e) {
        print('✗ Format detection failed: $e');
        fail('Format detection failed: $e');
      }

      // Step 4: Test with actual file (this is likely where the segfault occurs)
      print('Step 4: Testing with actual MP3 file...');
      final testFile = File('test/assets/test_short.mp3');
      if (!testFile.existsSync()) {
        print('⚠ Short test file not found, using main test file');
        final mainTestFile = File('test/assets/Double-F the King - Your Blessing.mp3');
        if (!mainTestFile.existsSync()) {
          fail('No test MP3 files available');
        }

        // Try with just the first 1KB to minimize crash impact
        final bytes = await mainTestFile.readAsBytes();
        final smallSample = Uint8List.fromList(bytes.take(1024).toList());

        try {
          final format = NativeAudioBindings.detectFormat(smallSample);
          print('✓ Small sample format detection: $format');
        } catch (e) {
          print('✗ Small sample format detection failed: $e');
          fail('Small sample format detection failed: $e');
        }

        // This is likely where the segfault occurs
        print('Step 5: Testing actual decoding (SEGFAULT EXPECTED HERE)...');
        try {
          final audioData = NativeAudioBindings.decodeAudio(smallSample, AudioFormat.mp3);
          print('✓ Decoding successful - this should not happen if there\'s a segfault');
          print('  Samples: ${audioData.samples.length}');
        } catch (e) {
          print('✗ Decoding failed: $e');
          fail('Decoding failed: $e');
        }
      } else {
        final bytes = await testFile.readAsBytes();
        try {
          final audioData = NativeAudioBindings.decodeAudio(bytes, AudioFormat.mp3);
          print('✓ Short file decoding successful');
          print('  Samples: ${audioData.samples.length}');
        } catch (e) {
          print('✗ Short file decoding failed: $e');
          fail('Short file decoding failed: $e');
        }
      }

      print('=== Diagnostic Complete ===');
    });
  });
}
