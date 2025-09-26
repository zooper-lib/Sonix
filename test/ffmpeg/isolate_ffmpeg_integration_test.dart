import 'dart:isolate';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

/// Tests for isolate-based processing with real FFMPEG contexts
///
/// This test suite verifies that:
/// 1. FFMPEG is properly initialized in background isolates
/// 2. Audio processing works correctly across isolate boundaries
/// 3. Error handling works when FFMPEG is not available
/// 4. Resource cleanup happens properly in isolates
void main() {
  group('FFMPEG Isolate Integration Tests', () {
    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw Exception('FFMPEG libraries not available for testing');
      }
    });

    test('should initialize FFMPEG successfully in main thread', () async {
      // Verify that FFMPEG is available in main thread
      expect(NativeAudioBindings.isFFMPEGAvailable, isTrue);
      expect(NativeAudioBindings.backendType, equals('FFMPEG'));
    });

    test('should initialize FFMPEG successfully in background isolate', () async {
      // Test FFMPEG initialization in a background isolate
      final receivePort = ReceivePort();

      await Isolate.spawn(_testFFMPEGInIsolate, receivePort.sendPort);

      final result = await receivePort.first as Map<String, dynamic>;
      receivePort.close();

      expect(result['success'], isTrue, reason: result['error'] ?? 'Unknown error');
      expect(result['isFFMPEGAvailable'], isTrue);
      expect(result['backendType'], equals('FFMPEG'));
    });

    test('should handle format detection in background isolate', () async {
      // Test format detection in a background isolate
      final receivePort = ReceivePort();

      // Create some test data (MP3 header)
      final mp3Header = Uint8List.fromList([
        0xFF, 0xFB, 0x90, 0x00, // MP3 frame header
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]);

      await Isolate.spawn(_testFormatDetectionInIsolate, {'sendPort': receivePort.sendPort, 'testData': mp3Header});

      final result = await receivePort.first as Map<String, dynamic>;
      receivePort.close();

      expect(result['success'], isTrue, reason: result['error'] ?? 'Unknown error');
      expect(result['detectedFormat'], isNotNull);
    });

    test('should handle FFMPEG cleanup properly in isolate', () async {
      // Test cleanup in a background isolate
      final receivePort = ReceivePort();

      await Isolate.spawn(_testFFMPEGCleanupInIsolate, receivePort.sendPort);

      final result = await receivePort.first as Map<String, dynamic>;
      receivePort.close();

      expect(result['success'], isTrue, reason: result['error'] ?? 'Unknown error');
      expect(result['cleanupCompleted'], isTrue);
    });

    test('should handle errors gracefully in isolate', () async {
      // Test error handling in a background isolate
      final receivePort = ReceivePort();

      await Isolate.spawn(_testErrorHandlingInIsolate, receivePort.sendPort);

      final result = await receivePort.first as Map<String, dynamic>;
      receivePort.close();

      expect(result['success'], isTrue, reason: result['error'] ?? 'Unknown error');
      expect(result['errorHandled'], isTrue);
    });

    test('should handle FFMPEG cleanup properly in main thread', () {
      // Test cleanup doesn't crash in main thread
      expect(() => NativeAudioBindings.cleanup(), returnsNormally);
    });
  });
}

/// Test FFMPEG initialization in an isolate
void _testFFMPEGInIsolate(SendPort sendPort) {
  try {
    // Initialize FFMPEG in this isolate
    NativeAudioBindings.initialize();

    // Check if FFMPEG is available
    final isAvailable = NativeAudioBindings.isFFMPEGAvailable;
    final backendType = NativeAudioBindings.backendType;

    sendPort.send({'success': true, 'isFFMPEGAvailable': isAvailable, 'backendType': backendType});
  } catch (e) {
    sendPort.send({'success': false, 'error': e.toString(), 'isFFMPEGAvailable': false, 'backendType': 'unknown'});
  }
}

/// Test format detection in an isolate
void _testFormatDetectionInIsolate(Map<String, dynamic> params) {
  final sendPort = params['sendPort'] as SendPort;
  final testData = params['testData'] as Uint8List;

  try {
    // Initialize FFMPEG in this isolate
    NativeAudioBindings.initialize();

    // Test format detection
    final detectedFormat = NativeAudioBindings.detectFormat(testData);

    sendPort.send({'success': true, 'detectedFormat': detectedFormat.toString()});
  } catch (e) {
    sendPort.send({'success': false, 'error': e.toString(), 'detectedFormat': null});
  }
}

/// Test FFMPEG cleanup in an isolate
void _testFFMPEGCleanupInIsolate(SendPort sendPort) {
  try {
    // Initialize FFMPEG in this isolate
    NativeAudioBindings.initialize();

    // Verify it's working
    final isAvailable = NativeAudioBindings.isFFMPEGAvailable;

    // Clean up FFMPEG
    NativeAudioBindings.cleanup();

    sendPort.send({'success': true, 'cleanupCompleted': true, 'wasAvailable': isAvailable});
  } catch (e) {
    sendPort.send({'success': false, 'error': e.toString(), 'cleanupCompleted': false});
  }
}

/// Test error handling in an isolate
void _testErrorHandlingInIsolate(SendPort sendPort) {
  try {
    // Initialize FFMPEG in this isolate
    NativeAudioBindings.initialize();

    // Try to decode invalid data to trigger error handling
    final invalidData = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

    bool errorHandled = false;
    try {
      NativeAudioBindings.detectFormat(invalidData);
    } catch (e) {
      // Error was properly handled
      errorHandled = true;
    }

    sendPort.send({'success': true, 'errorHandled': errorHandled});
  } catch (e) {
    sendPort.send({'success': false, 'error': e.toString(), 'errorHandled': false});
  }
}
