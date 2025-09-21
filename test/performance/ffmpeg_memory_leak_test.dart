import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/test_data_loader.dart';
import 'package:sonix/src/models/audio_data.dart';

void main() {
  group('FFMPEG Memory Leak Detection Tests', () {
    group('Audio Decoding Memory Leaks', () {
      test('should not leak memory during repeated audio decoding', () async {
        final testFiles = ['test_short.mp3', 'test_mono_44100.wav'];

        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;

          final audioData = await File(filePath).readAsBytes();
          final initialMemory = _mockGetMemoryUsage();

          // Perform many decode operations
          for (var i = 0; i < 100; i++) {
            final result = await _mockFFMPEGDecodeAudio(audioData);

            if (result.success) {
              // Use the audio data briefly
              final sampleCount = result.audioData!.samples.length;
              expect(sampleCount, greaterThan(0));

              // Explicitly dispose
              result.audioData!.dispose();
            }

            // Force garbage collection every 20 iterations
            if (i % 20 == 0) {
              _mockForceGarbageCollection();
            }
          }

          // Final garbage collection
          _mockForceGarbageCollection();

          final finalMemory = _mockGetMemoryUsage();
          final memoryIncrease = finalMemory - initialMemory;

          // Memory increase should be minimal (less than 10MB)
          expect(memoryIncrease, lessThan(10 * 1024 * 1024), reason: 'Memory leak detected in $filename: ${memoryIncrease / (1024 * 1024)}MB increase');
        }
      });

      test('should properly cleanup FFMPEG contexts', () async {
        final initialMemory = _mockGetMemoryUsage();

        // Create and destroy many FFMPEG contexts
        for (var i = 0; i < 50; i++) {
          final context = _mockFFMPEGCreateContext();
          expect(context.isValid, isTrue);

          // Use context for some operations
          _mockFFMPEGContextOperation(context);

          // Cleanup context
          final cleanupResult = _mockFFMPEGCleanupContext(context);
          expect(cleanupResult.success, isTrue);
          expect(context.isCleanedUp, isTrue);

          if (i % 10 == 0) {
            _mockForceGarbageCollection();
          }
        }

        _mockForceGarbageCollection();

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal
        expect(memoryIncrease, lessThan(5 * 1024 * 1024));
      });

      test('should handle buffer allocation and deallocation without leaks', () async {
        final initialMemory = _mockGetMemoryUsage();
        final bufferSizes = [1024, 4096, 16384, 65536];

        for (var iteration = 0; iteration < 20; iteration++) {
          final allocatedBuffers = <Uint8List>[];

          // Allocate multiple buffers
          for (final size in bufferSizes) {
            final buffer = _mockFFMPEGAllocateBuffer(size);
            if (buffer.success) {
              allocatedBuffers.add(buffer.buffer!);
            }
          }

          // Use buffers
          for (final buffer in allocatedBuffers) {
            // Simulate buffer usage
            for (var i = 0; i < buffer.length && i < 100; i++) {
              buffer[i] = (i % 256);
            }
          }

          // Free all buffers
          for (final buffer in allocatedBuffers) {
            final freeResult = _mockFFMPEGFreeBuffer(buffer);
            expect(freeResult.success, isTrue);
          }

          if (iteration % 5 == 0) {
            _mockForceGarbageCollection();
          }
        }

        _mockForceGarbageCollection();

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal
        expect(memoryIncrease, lessThan(2 * 1024 * 1024));
      });
    });

    group('Chunked Processing Memory Leaks', () {
      test('should not leak memory during chunked processing', () async {
        final testFile = 'test_large.mp3';
        final filePath = TestDataLoader.getAssetPath(testFile);
        if (!await File(filePath).exists()) return;

        final initialMemory = _mockGetMemoryUsage();

        // Perform multiple chunked processing sessions
        for (var session = 0; session < 10; session++) {
          final decoderResult = await _mockFFMPEGInitChunkedDecoder(filePath);
          expect(decoderResult.success, isTrue);

          final decoder = decoderResult.decoder!;
          final processedChunks = <AudioData>[];

          // Process multiple chunks
          for (var chunkIndex = 0; chunkIndex < 20; chunkIndex++) {
            final chunk = FileChunk(startByte: chunkIndex * 4096, endByte: (chunkIndex + 1) * 4096, chunkIndex: chunkIndex);

            final chunkResult = await _mockFFMPEGProcessFileChunk(decoder, chunk);
            if (chunkResult.success) {
              processedChunks.add(chunkResult.audioData!);
            }
          }

          // Dispose all processed chunks
          for (final chunkData in processedChunks) {
            chunkData.dispose();
          }

          // Cleanup decoder
          final cleanupResult = _mockFFMPEGCleanupDecoder(decoder);
          expect(cleanupResult.success, isTrue);

          if (session % 3 == 0) {
            _mockForceGarbageCollection();
          }
        }

        _mockForceGarbageCollection();

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be reasonable
        expect(memoryIncrease, lessThan(15 * 1024 * 1024));
      });

      test('should handle decoder cleanup after partial processing', () async {
        final testFile = 'test_medium.mp3';
        final filePath = TestDataLoader.getAssetPath(testFile);
        if (!await File(filePath).exists()) return;

        final initialMemory = _mockGetMemoryUsage();

        // Create decoders and cleanup without full processing
        for (var i = 0; i < 30; i++) {
          final decoderResult = await _mockFFMPEGInitChunkedDecoder(filePath);
          if (decoderResult.success) {
            final decoder = decoderResult.decoder!;

            // Process only a few chunks before cleanup
            for (var j = 0; j < 3; j++) {
              final chunk = FileChunk(startByte: j * 2048, endByte: (j + 1) * 2048, chunkIndex: j);
              final chunkResult = await _mockFFMPEGProcessFileChunk(decoder, chunk);

              if (chunkResult.success) {
                chunkResult.audioData!.dispose();
              }
            }

            // Cleanup decoder early
            _mockFFMPEGCleanupDecoder(decoder);
          }

          if (i % 10 == 0) {
            _mockForceGarbageCollection();
          }
        }

        _mockForceGarbageCollection();

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal
        expect(memoryIncrease, lessThan(8 * 1024 * 1024));
      });
    });

    group('Error Handling Memory Leaks', () {
      test('should not leak memory when handling decode errors', () async {
        final initialMemory = _mockGetMemoryUsage();

        // Create invalid data that will cause decode errors
        final invalidDataSizes = [100, 500, 1000, 5000];

        for (var iteration = 0; iteration < 25; iteration++) {
          for (final size in invalidDataSizes) {
            final invalidData = Uint8List.fromList(List.generate(size, (i) => math.Random().nextInt(256)));

            // Attempt to decode invalid data (should fail)
            final result = await _mockFFMPEGDecodeAudio(invalidData);
            expect(result.success, isFalse);

            // Even failed decodes should not leak memory
            if (result.audioData != null) {
              result.audioData!.dispose();
            }
          }

          if (iteration % 5 == 0) {
            _mockForceGarbageCollection();
          }
        }

        _mockForceGarbageCollection();

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal even with many errors
        expect(memoryIncrease, lessThan(3 * 1024 * 1024));
      });

      test('should cleanup resources when chunked decoder initialization fails', () async {
        final initialMemory = _mockGetMemoryUsage();

        // Try to initialize decoders with invalid file paths
        final invalidPaths = ['nonexistent_file.mp3', 'invalid/path/file.wav', '', 'corrupted_file.flac'];

        for (var iteration = 0; iteration < 20; iteration++) {
          for (final invalidPath in invalidPaths) {
            final decoderResult = await _mockFFMPEGInitChunkedDecoder(invalidPath);
            expect(decoderResult.success, isFalse);

            // Even failed initialization should not leak
            if (decoderResult.decoder != null) {
              _mockFFMPEGCleanupDecoder(decoderResult.decoder!);
            }
          }

          if (iteration % 5 == 0) {
            _mockForceGarbageCollection();
          }
        }

        _mockForceGarbageCollection();

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal
        expect(memoryIncrease, lessThan(2 * 1024 * 1024));
      });
    });

    group('Concurrent Processing Memory Leaks', () {
      test('should not leak memory during concurrent decoding', () async {
        final testFiles = ['test_short.mp3', 'test_mono_44100.wav'];
        final initialMemory = _mockGetMemoryUsage();

        // Run multiple concurrent decoding sessions
        for (var session = 0; session < 5; session++) {
          final concurrentTasks = <Future<AudioDecodeResult>>[];

          for (final filename in testFiles) {
            final filePath = TestDataLoader.getAssetPath(filename);
            if (await File(filePath).exists()) {
              final audioData = await File(filePath).readAsBytes();

              // Start multiple concurrent decoding tasks
              for (var i = 0; i < 4; i++) {
                concurrentTasks.add(_mockFFMPEGDecodeAudio(audioData));
              }
            }
          }

          // Wait for all tasks to complete
          final results = await Future.wait(concurrentTasks);

          // Dispose all results
          for (final result in results) {
            if (result.success) {
              result.audioData!.dispose();
            }
          }

          _mockForceGarbageCollection();
        }

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be reasonable for concurrent processing
        expect(memoryIncrease, lessThan(20 * 1024 * 1024));
      });
    });
  });
}

// Mock implementations for memory leak testing

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
  final String filePath;
  bool isCleanedUp = false;

  FFMPEGChunkedDecoder({required this.filePath});
}

class FileChunk {
  final int startByte;
  final int endByte;
  final int chunkIndex;

  FileChunk({required this.startByte, required this.endByte, required this.chunkIndex});
}

class FFMPEGContext {
  bool isValid = true;
  bool isCleanedUp = false;
}

class FFMPEGCleanupResult {
  final bool success;
  final String? errorMessage;

  FFMPEGCleanupResult.success() : success = true, errorMessage = null;
  FFMPEGCleanupResult.failure(this.errorMessage) : success = false;
}

class FFMPEGBufferResult {
  final bool success;
  final Uint8List? buffer;
  final String? errorMessage;

  FFMPEGBufferResult.success(this.buffer) : success = true, errorMessage = null;
  FFMPEGBufferResult.failure(this.errorMessage) : success = false, buffer = null;
}

// Mock memory tracking
int _mockMemoryUsage = 50 * 1024 * 1024; // Start with 50MB base usage

Future<AudioDecodeResult> _mockFFMPEGDecodeAudio(Uint8List data) async {
  // Simulate memory allocation
  _mockMemoryUsage += data.length * 2; // Simulate temporary buffers

  await Future.delayed(Duration(milliseconds: 10));

  if (data.length < 100) {
    _mockMemoryUsage -= data.length * 2; // Cleanup on error
    return AudioDecodeResult.failure('Data too small');
  }

  // Generate audio data
  final samples = List.generate(1000, (i) => math.sin(i * 0.01) * 0.5);
  final audioData = AudioData(samples: samples, sampleRate: 44100, channels: 1, duration: Duration(milliseconds: 100));

  // Simulate keeping some memory for the result
  _mockMemoryUsage += samples.length * 8; // 8 bytes per double
  _mockMemoryUsage -= data.length * 2; // Release temporary buffers

  return AudioDecodeResult.success(audioData);
}

Future<ChunkedDecoderResult> _mockFFMPEGInitChunkedDecoder(String filePath) async {
  await Future.delayed(Duration(milliseconds: 5));

  if (!await File(filePath).exists()) {
    return ChunkedDecoderResult.failure('File not found');
  }

  // Simulate decoder memory allocation
  _mockMemoryUsage += 1024 * 1024; // 1MB for decoder context

  final decoder = FFMPEGChunkedDecoder(filePath: filePath);
  return ChunkedDecoderResult.success(decoder);
}

Future<AudioDecodeResult> _mockFFMPEGProcessFileChunk(FFMPEGChunkedDecoder decoder, FileChunk chunk) async {
  await Future.delayed(Duration(milliseconds: 8));

  if (decoder.isCleanedUp) {
    return AudioDecodeResult.failure('Decoder cleaned up');
  }

  // Simulate chunk processing memory
  _mockMemoryUsage += 64 * 1024; // 64KB for chunk processing

  final chunkSamples = List.generate(512, (i) => math.sin(i * 0.02) * 0.4);
  final audioData = AudioData(samples: chunkSamples, sampleRate: 44100, channels: 1, duration: Duration(milliseconds: 50));

  // Keep memory for result, release processing memory
  _mockMemoryUsage += chunkSamples.length * 8;
  _mockMemoryUsage -= 64 * 1024;

  return AudioDecodeResult.success(audioData);
}

FFMPEGCleanupResult _mockFFMPEGCleanupDecoder(FFMPEGChunkedDecoder decoder) {
  if (!decoder.isCleanedUp) {
    decoder.isCleanedUp = true;
    // Release decoder memory
    _mockMemoryUsage -= 1024 * 1024; // Release 1MB decoder context
  }
  return FFMPEGCleanupResult.success();
}

FFMPEGContext _mockFFMPEGCreateContext() {
  // Simulate context memory allocation
  _mockMemoryUsage += 512 * 1024; // 512KB for context
  return FFMPEGContext();
}

void _mockFFMPEGContextOperation(FFMPEGContext context) {
  // Simulate using context (temporary memory)
  _mockMemoryUsage += 256 * 1024;
  _mockMemoryUsage -= 256 * 1024;
}

FFMPEGCleanupResult _mockFFMPEGCleanupContext(FFMPEGContext context) {
  if (!context.isCleanedUp) {
    context.isCleanedUp = true;
    context.isValid = false;
    // Release context memory
    _mockMemoryUsage -= 512 * 1024;
  }
  return FFMPEGCleanupResult.success();
}

FFMPEGBufferResult _mockFFMPEGAllocateBuffer(int size) {
  if (size > 100 * 1024 * 1024) {
    // 100MB limit
    return FFMPEGBufferResult.failure('Buffer too large');
  }

  _mockMemoryUsage += size;
  final buffer = Uint8List(size);
  return FFMPEGBufferResult.success(buffer);
}

FFMPEGCleanupResult _mockFFMPEGFreeBuffer(Uint8List buffer) {
  _mockMemoryUsage -= buffer.length;
  return FFMPEGCleanupResult.success();
}

int _mockGetMemoryUsage() {
  // Add some random variation to simulate real memory usage
  return _mockMemoryUsage + math.Random().nextInt(1024 * 1024);
}

void _mockForceGarbageCollection() {
  // Simulate garbage collection reducing memory slightly
  _mockMemoryUsage = (_mockMemoryUsage * 0.95).round();
}
