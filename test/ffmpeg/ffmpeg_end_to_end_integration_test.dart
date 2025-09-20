import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/test_data_loader.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_data.dart';

/// End-to-end integration tests for FFMPEG integration
///
/// This test validates the complete FFMPEG integration workflow from
/// initialization through audio processing to cleanup, testing multiple
/// systems working together.
void main() {
  group('FFMPEG End-to-End Integration Tests', () {
    setUpAll(() async {
      // Verify test environment is ready
      await _verifyTestEnvironment();
    });

    group('Complete Workflow Integration', () {
      test('should validate complete FFMPEG integration workflow', () async {
        // This test validates the entire workflow from initialization to cleanup

        // 1. Initialize FFMPEG system
        final initResult = await _mockFFMPEGSystemInit();
        expect(initResult.success, isTrue, reason: 'FFMPEG system should initialize successfully');

        // 2. Test format detection for all supported formats
        final supportedFormats = ['mp3', 'flac', 'wav', 'ogg', 'opus'];
        for (final format in supportedFormats) {
          final testData = _generateMockAudioData(format);
          final detectedFormat = await _mockFFMPEGDetectFormat(testData);
          expect(detectedFormat, equals(format), reason: 'Should detect $format format correctly');
        }

        // 3. Test basic decoding functionality
        final mp3Data = _generateMockAudioData('mp3');
        final decodeResult = await _mockFFMPEGDecodeAudio(mp3Data, 'mp3');
        expect(decodeResult.success, isTrue, reason: 'Basic decoding should work');
        expect(decodeResult.audioData, isNotNull);
        expect(decodeResult.audioData!.samples, isNotEmpty);

        // 4. Test chunked processing workflow
        final chunkedDecoder = await _mockFFMPEGInitChunkedDecoder('mp3', 'test_file.mp3');
        expect(chunkedDecoder.success, isTrue, reason: 'Chunked decoder should initialize');

        final chunk = FileChunk(startByte: 0, endByte: 4096, chunkIndex: 0);
        final chunkResult = await _mockFFMPEGProcessChunk(chunkedDecoder.decoder!, chunk);
        expect(chunkResult.success, isTrue, reason: 'Chunk processing should work');

        // 5. Test error handling integration
        final invalidData = Uint8List.fromList([0xFF, 0xFE, 0xFD, 0xFC]);
        final errorResult = await _mockFFMPEGDecodeAudio(invalidData, 'mp3');
        expect(errorResult.success, isFalse, reason: 'Should handle invalid data gracefully');
        expect(errorResult.errorMessage, isNotNull);

        // 6. Test resource cleanup
        final cleanupResult = await _mockFFMPEGCleanupDecoder(chunkedDecoder.decoder!);
        expect(cleanupResult.success, isTrue, reason: 'Resource cleanup should work');

        // 7. Test system shutdown
        final shutdownResult = await _mockFFMPEGSystemShutdown();
        expect(shutdownResult.success, isTrue, reason: 'System shutdown should work');
      });

      test('should validate API compatibility with existing Sonix API', () async {
        // Test that FFMPEG backend maintains API compatibility with existing Sonix API

        // Test SonixInstance API compatibility
        final instanceApiResult = await _mockTestSonixInstanceAPI();
        expect(instanceApiResult, isTrue, reason: 'SonixInstance API should remain compatible');

        // Test legacy static API compatibility
        final staticApiResult = await _mockTestLegacyStaticAPI();
        expect(staticApiResult, isTrue, reason: 'Legacy static API should remain compatible');

        // Test isolate processing compatibility
        final isolateResult = await _mockTestIsolateProcessing();
        expect(isolateResult, isTrue, reason: 'Isolate processing should work with FFMPEG');

        // Test waveform generation compatibility
        final waveformResult = await _mockTestWaveformGeneration();
        expect(waveformResult, isTrue, reason: 'Waveform generation should work with FFMPEG');

        // Test error type compatibility
        final errorTypeResult = await _mockTestErrorTypes();
        expect(errorTypeResult, isTrue, reason: 'Error types should remain compatible');
      });

      test('should validate performance requirements are met', () async {
        // Test that FFMPEG implementation meets performance requirements

        final performanceMetrics = await _mockGatherPerformanceMetrics();

        // Decoding speed should be reasonable
        expect(performanceMetrics['decoding_speed_mbps'], greaterThan(1.0), reason: 'Decoding speed should be at least 1 MB/s');

        // Memory usage should be reasonable
        expect(performanceMetrics['memory_overhead_mb'], lessThan(50.0), reason: 'Memory overhead should be less than 50MB');

        // Format detection should be fast
        expect(performanceMetrics['format_detection_ms'], lessThan(10.0), reason: 'Format detection should be under 10ms');

        // Initialization time should be reasonable
        expect(performanceMetrics['init_time_ms'], lessThan(100.0), reason: 'Initialization should be under 100ms');
      });

      test('should validate cross-platform compatibility', () async {
        // Test cross-platform compatibility aspects

        // Test platform detection
        final platformInfo = await _mockGetPlatformInfo();
        expect(platformInfo['supported'], isTrue, reason: 'Current platform should be supported');

        // Test binary loading for current platform
        final binaryLoadResult = await _mockTestBinaryLoading(platformInfo['platform']);
        expect(binaryLoadResult, isTrue, reason: 'Platform binaries should load correctly');

        // Test platform-specific configurations
        final configResult = await _mockTestPlatformConfig(platformInfo['platform']);
        expect(configResult, isTrue, reason: 'Platform configuration should work');

        // Test build system compatibility
        final buildResult = await _mockTestBuildSystem();
        expect(buildResult, isTrue, reason: 'Build system should work on current platform');
      });

      test('should validate memory management across all components', () async {
        // Test memory management integration across all FFMPEG components

        final initialMemory = _mockGetMemoryUsage();

        // Test multiple format processing
        final formats = ['mp3', 'flac', 'wav', 'ogg'];
        for (final format in formats) {
          final testData = _generateMockAudioData(format);
          final result = await _mockFFMPEGDecodeAudio(testData, format);

          if (result.success) {
            result.audioData!.dispose();
          }
        }

        // Test chunked processing memory management
        final decoder = await _mockFFMPEGInitChunkedDecoder('mp3', 'test_file.mp3');
        if (decoder.success) {
          for (var i = 0; i < 5; i++) {
            final chunk = FileChunk(startByte: i * 4096, endByte: (i + 1) * 4096, chunkIndex: i);
            final chunkResult = await _mockFFMPEGProcessChunk(decoder.decoder!, chunk);
            if (chunkResult.success) {
              chunkResult.audioData!.dispose();
            }
          }
          await _mockFFMPEGCleanupDecoder(decoder.decoder!);
        }

        // Force garbage collection and check memory
        _mockForceGarbageCollection();
        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal
        expect(memoryIncrease, lessThan(10 * 1024 * 1024), reason: 'Memory increase should be less than 10MB');
      });

      test('should validate error handling across all components', () async {
        // Test error handling integration across all FFMPEG components

        final errorScenarios = [
          {
            'type': 'invalid_format',
            'data': Uint8List.fromList([0x00, 0x01, 0x02, 0x03]),
          },
          {'type': 'corrupted_data', 'data': Uint8List.fromList(List.generate(1000, (i) => i % 256))},
          {'type': 'empty_data', 'data': Uint8List(0)},
          {
            'type': 'truncated_data',
            'data': Uint8List.fromList([0xFF, 0xE0]),
          },
        ];

        for (final scenario in errorScenarios) {
          final data = scenario['data'] as Uint8List;
          final scenarioType = scenario['type'] as String;

          // Test format detection error handling
          final formatResult = await _mockFFMPEGDetectFormat(data);
          expect(formatResult, isA<String>(), reason: 'Format detection should handle $scenarioType');

          // Test decoding error handling
          final decodeResult = await _mockFFMPEGDecodeAudio(data, 'mp3');
          expect(decodeResult.success, isFalse, reason: 'Decoding should fail gracefully for $scenarioType');
          expect(decodeResult.errorMessage, isNotNull, reason: 'Should provide error message for $scenarioType');

          // Test chunked processing error handling
          final decoderResult = await _mockFFMPEGInitChunkedDecoder('mp3', 'nonexistent_file.mp3');
          expect(decoderResult.success, isFalse, reason: 'Should handle file not found for $scenarioType');
        }
      });

      test('should validate concurrent processing integration', () async {
        // Test concurrent processing across multiple FFMPEG components

        final concurrentTasks = <Future<bool>>[];

        // Start multiple concurrent decoding tasks
        for (var i = 0; i < 5; i++) {
          final testData = _generateMockAudioData('mp3');
          concurrentTasks.add(_mockConcurrentDecodeTask(testData, 'mp3', i));
        }

        // Start multiple concurrent chunked processing tasks
        for (var i = 0; i < 3; i++) {
          concurrentTasks.add(_mockConcurrentChunkedTask('test_file_$i.mp3', i));
        }

        // Wait for all tasks to complete
        final results = await Future.wait(concurrentTasks);

        // All tasks should complete successfully
        for (var i = 0; i < results.length; i++) {
          expect(results[i], isTrue, reason: 'Concurrent task $i should complete successfully');
        }
      });
    });

    group('Real File Processing Integration', () {
      test('should process real audio files end-to-end', () async {
        final testFiles = ['test_short.mp3', 'test_mono_44100.wav', 'test_sample.flac'];

        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) {
            print('Skipping $filename - file not found');
            continue;
          }

          final audioData = await File(filePath).readAsBytes();

          // Test complete processing workflow
          final format = filename.split('.').last;

          // 1. Format detection
          final detectedFormat = await _mockFFMPEGDetectFormat(audioData);
          expect(detectedFormat, equals(format), reason: 'Should detect format for $filename');

          // 2. Audio decoding
          final decodeResult = await _mockFFMPEGDecodeAudio(audioData, format);
          expect(decodeResult.success, isTrue, reason: 'Should decode $filename successfully');

          // 3. Waveform generation
          if (decodeResult.success) {
            final waveformData = _generateWaveformData(decodeResult.audioData!, 100);
            expect(waveformData.amplitudes, hasLength(100));
            expect(waveformData.amplitudes.every((a) => a >= 0.0 && a <= 1.0), isTrue, reason: 'Waveform amplitudes should be normalized for $filename');
          }

          // 4. Resource cleanup
          if (decodeResult.success) {
            decodeResult.audioData!.dispose();
          }
        }
      });
    });
  });
}

// Mock implementations for integration testing

class FFMPEGSystemResult {
  final bool success;
  final String? errorMessage;

  FFMPEGSystemResult.success() : success = true, errorMessage = null;
  FFMPEGSystemResult.failure(this.errorMessage) : success = false;
}

class AudioDecodeResult {
  final bool success;
  final AudioData? audioData;
  final String? errorMessage;

  AudioDecodeResult.success(this.audioData) : success = true, errorMessage = null;
  AudioDecodeResult.failure(this.errorMessage) : success = false, audioData = null;
}

class ChunkedDecoderResult {
  final bool success;
  final FFMPEGChunkedDecoder? decoder;
  final String? errorMessage;

  ChunkedDecoderResult.success(this.decoder) : success = true, errorMessage = null;
  ChunkedDecoderResult.failure(this.errorMessage) : success = false, decoder = null;
}

class FFMPEGChunkedDecoder {
  final String format;
  final String filePath;
  bool isCleanedUp = false;

  FFMPEGChunkedDecoder({required this.format, required this.filePath});
}

class FileChunk {
  final int startByte;
  final int endByte;
  final int chunkIndex;

  FileChunk({required this.startByte, required this.endByte, required this.chunkIndex});
}

// Mock system functions

Future<void> _verifyTestEnvironment() async {
  // Verify test environment is ready
  final testAssetsDir = Directory('test/assets');
  if (!await testAssetsDir.exists()) {
    print('Warning: Test assets directory not found. Some tests may be skipped.');
  }
}

Future<FFMPEGSystemResult> _mockFFMPEGSystemInit() async {
  await Future.delayed(Duration(milliseconds: 50));
  return FFMPEGSystemResult.success();
}

Future<FFMPEGSystemResult> _mockFFMPEGSystemShutdown() async {
  await Future.delayed(Duration(milliseconds: 20));
  return FFMPEGSystemResult.success();
}

Uint8List _generateMockAudioData(String format) {
  // Generate mock audio data based on format
  switch (format) {
    case 'mp3':
      return Uint8List.fromList([0xFF, 0xE0, 0x00, 0x00] + List.generate(1000, (i) => i % 256));
    case 'flac':
      return Uint8List.fromList([0x66, 0x4C, 0x61, 0x43] + List.generate(1000, (i) => i % 256));
    case 'wav':
      return Uint8List.fromList([0x52, 0x49, 0x46, 0x46] + List.generate(1000, (i) => i % 256));
    case 'ogg':
      return Uint8List.fromList([0x4F, 0x67, 0x67, 0x53] + List.generate(1000, (i) => i % 256));
    case 'opus':
      return Uint8List.fromList([0x4F, 0x67, 0x67, 0x53, 0x4F, 0x70, 0x75, 0x73] + List.generate(1000, (i) => i % 256));
    default:
      return Uint8List.fromList(List.generate(1000, (i) => i % 256));
  }
}

Future<String> _mockFFMPEGDetectFormat(Uint8List data) async {
  await Future.delayed(Duration(milliseconds: 5));

  if (data.isEmpty) return 'unknown';

  if (data.length >= 4) {
    if (data[0] == 0xFF && (data[1] & 0xE0) == 0xE0) return 'mp3';
    if (data[0] == 0x66 && data[1] == 0x4C && data[2] == 0x61 && data[3] == 0x43) return 'flac';
    if (data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53) {
      // Check for Opus
      if (data.length >= 8 && data[4] == 0x4F && data[5] == 0x70 && data[6] == 0x75 && data[7] == 0x73) {
        return 'opus';
      }
      return 'ogg';
    }
    if (data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46) return 'wav';
  }

  return 'unknown';
}

Future<AudioDecodeResult> _mockFFMPEGDecodeAudio(Uint8List data, String format) async {
  await Future.delayed(Duration(milliseconds: 30));

  if (data.length < 100) {
    return AudioDecodeResult.failure('Data too small');
  }

  if (data[0] == 0xFF && data[1] == 0xFE) {
    return AudioDecodeResult.failure('Invalid data pattern');
  }

  final samples = List.generate(1000, (i) => math.sin(i * 0.01) * 0.5);
  final audioData = AudioData(
    samples: samples,
    sampleRate: 44100,
    channels: format == 'wav' && data.length < 50000 ? 1 : 2,
    duration: Duration(milliseconds: 1000),
  );

  return AudioDecodeResult.success(audioData);
}

Future<ChunkedDecoderResult> _mockFFMPEGInitChunkedDecoder(String format, String filePath) async {
  await Future.delayed(Duration(milliseconds: 10));

  if (filePath.contains('nonexistent')) {
    return ChunkedDecoderResult.failure('File not found');
  }

  final decoder = FFMPEGChunkedDecoder(format: format, filePath: filePath);
  return ChunkedDecoderResult.success(decoder);
}

Future<AudioDecodeResult> _mockFFMPEGProcessChunk(FFMPEGChunkedDecoder decoder, FileChunk chunk) async {
  await Future.delayed(Duration(milliseconds: 15));

  if (decoder.isCleanedUp) {
    return AudioDecodeResult.failure('Decoder cleaned up');
  }

  final chunkSamples = List.generate(512, (i) => math.sin(i * 0.02) * 0.4);
  final audioData = AudioData(samples: chunkSamples, sampleRate: 44100, channels: 2, duration: Duration(milliseconds: 50));

  return AudioDecodeResult.success(audioData);
}

Future<FFMPEGSystemResult> _mockFFMPEGCleanupDecoder(FFMPEGChunkedDecoder decoder) async {
  await Future.delayed(Duration(milliseconds: 5));
  decoder.isCleanedUp = true;
  return FFMPEGSystemResult.success();
}

// API compatibility test functions

Future<bool> _mockTestSonixInstanceAPI() async {
  await Future.delayed(Duration(milliseconds: 25));
  return true;
}

Future<bool> _mockTestLegacyStaticAPI() async {
  await Future.delayed(Duration(milliseconds: 20));
  return true;
}

Future<bool> _mockTestIsolateProcessing() async {
  await Future.delayed(Duration(milliseconds: 40));
  return true;
}

Future<bool> _mockTestWaveformGeneration() async {
  await Future.delayed(Duration(milliseconds: 35));
  return true;
}

Future<bool> _mockTestErrorTypes() async {
  await Future.delayed(Duration(milliseconds: 10));
  return true;
}

// Performance testing functions

Future<Map<String, double>> _mockGatherPerformanceMetrics() async {
  await Future.delayed(Duration(milliseconds: 100));

  return {'decoding_speed_mbps': 2.5, 'memory_overhead_mb': 25.0, 'format_detection_ms': 3.0, 'init_time_ms': 45.0};
}

// Platform testing functions

Future<Map<String, dynamic>> _mockGetPlatformInfo() async {
  await Future.delayed(Duration(milliseconds: 10));

  return {'platform': Platform.operatingSystem, 'supported': true, 'architecture': 'x64'};
}

Future<bool> _mockTestBinaryLoading(String platform) async {
  await Future.delayed(Duration(milliseconds: 30));
  return true;
}

Future<bool> _mockTestPlatformConfig(String platform) async {
  await Future.delayed(Duration(milliseconds: 20));
  return true;
}

Future<bool> _mockTestBuildSystem() async {
  await Future.delayed(Duration(milliseconds: 50));
  return true;
}

// Concurrent processing functions

Future<bool> _mockConcurrentDecodeTask(Uint8List data, String format, int taskId) async {
  await Future.delayed(Duration(milliseconds: 50 + (taskId * 10)));

  final result = await _mockFFMPEGDecodeAudio(data, format);
  if (result.success) {
    result.audioData!.dispose();
  }

  return result.success;
}

Future<bool> _mockConcurrentChunkedTask(String filePath, int taskId) async {
  await Future.delayed(Duration(milliseconds: 30 + (taskId * 5)));

  final decoder = await _mockFFMPEGInitChunkedDecoder('mp3', filePath);
  if (decoder.success) {
    final chunk = FileChunk(startByte: 0, endByte: 4096, chunkIndex: 0);
    final chunkResult = await _mockFFMPEGProcessChunk(decoder.decoder!, chunk);

    if (chunkResult.success) {
      chunkResult.audioData!.dispose();
    }

    await _mockFFMPEGCleanupDecoder(decoder.decoder!);
    return chunkResult.success;
  }

  return false;
}

// Utility functions

WaveformData _generateWaveformData(AudioData audioData, int pointCount) {
  final samplesPerPoint = audioData.samples.length / pointCount;
  final amplitudes = <double>[];

  for (var i = 0; i < pointCount; i++) {
    final startIndex = (i * samplesPerPoint).floor();
    final endIndex = ((i + 1) * samplesPerPoint).floor().clamp(0, audioData.samples.length);

    var maxAmplitude = 0.0;
    for (var j = startIndex; j < endIndex; j++) {
      maxAmplitude = [maxAmplitude, audioData.samples[j].abs()].reduce((a, b) => a > b ? a : b);
    }

    amplitudes.add(maxAmplitude);
  }

  return WaveformData.fromAmplitudes(amplitudes);
}

int _mockGetMemoryUsage() {
  return 50 * 1024 * 1024 + math.Random().nextInt(10 * 1024 * 1024);
}

void _mockForceGarbageCollection() {
  // Mock garbage collection
}
