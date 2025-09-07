import 'dart:typed_data';

import 'native_audio_bindings.dart';
import '../decoders/audio_decoder.dart';
import '../exceptions/sonix_exceptions.dart';

/// Simple test class for FFI integration
class FFITest {
  /// Test basic FFI functionality
  static void testFFIIntegration() {
    print('Testing FFI integration...');

    try {
      // Test initialization
      NativeAudioBindings.initialize();
      print('✓ Native bindings initialized successfully');
    } catch (e) {
      print('✗ Failed to initialize native bindings: $e');
      return;
    }

    // Test format detection with sample data
    _testFormatDetection();

    // Test decoding (will fail with placeholder implementation)
    _testDecoding();

    print('FFI integration test completed');
  }

  static void _testFormatDetection() {
    print('\nTesting format detection...');

    try {
      // Test with empty data
      final emptyData = Uint8List(0);
      try {
        NativeAudioBindings.detectFormat(emptyData);
        print('✗ Should have thrown exception for empty data');
      } catch (e) {
        print('✓ Correctly handled empty data: ${e.runtimeType}');
      }

      // Test with MP3-like data (ID3 header)
      final mp3Data = Uint8List.fromList([0x49, 0x44, 0x33, 0x03, 0x00]);
      final mp3Format = NativeAudioBindings.detectFormat(mp3Data);
      print('✓ MP3 detection result: $mp3Format');

      // Test with WAV-like data (RIFF header)
      final wavData = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // file size
        0x57, 0x41, 0x56, 0x45, // WAVE
      ]);
      final wavFormat = NativeAudioBindings.detectFormat(wavData);
      print('✓ WAV detection result: $wavFormat');

      // Test with unknown data
      final unknownData = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      final unknownFormat = NativeAudioBindings.detectFormat(unknownData);
      print('✓ Unknown format detection result: $unknownFormat');
    } catch (e) {
      print('✗ Format detection test failed: $e');
    }
  }

  static void _testDecoding() {
    print('\nTesting audio decoding...');

    try {
      // Test with sample MP3-like data (will fail with placeholder)
      final mp3Data = Uint8List.fromList([0x49, 0x44, 0x33, 0x03, 0x00]);

      try {
        NativeAudioBindings.decodeAudio(mp3Data, AudioFormat.mp3);
        print('✗ Decoding should have failed with placeholder implementation');
      } catch (e) {
        print('✓ Decoding correctly failed (expected with placeholder): ${e.runtimeType}');
        if (e is DecodingException) {
          print('  Error message: ${e.message}');
        }
      }
    } catch (e) {
      print('✗ Decoding test failed unexpectedly: $e');
    }
  }
}
