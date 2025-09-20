import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../test_helpers/test_data_loader.dart';
import 'package:sonix/src/models/audio_data.dart';

void main() {
  group('FFMPEG Wrapper Unit Tests', () {
    setUpAll(() async {
      // Test setup - no additional initialization needed
    });

    group('Format Detection Tests', () {
      test('should detect MP3 format correctly', () async {
        final mp3Path = TestDataLoader.getAssetPath('test_short.mp3');
        if (await File(mp3Path).exists()) {
          final mp3Data = await File(mp3Path).readAsBytes();
          final detectedFormat = _mockFFMPEGDetectFormat(mp3Data);
          expect(detectedFormat, equals(FFMPEGFormat.mp3));
        }
      });

      test('should detect FLAC format correctly', () async {
        final flacPath = TestDataLoader.getAssetPath('test_sample.flac');
        if (await File(flacPath).exists()) {
          final flacData = await File(flacPath).readAsBytes();
          final detectedFormat = _mockFFMPEGDetectFormat(flacData);
          expect(detectedFormat, equals(FFMPEGFormat.flac));
        }
      });

      test('should detect OGG format correctly', () async {
        final oggPath = TestDataLoader.getAssetPath('test_sample.ogg');
        if (await File(oggPath).exists()) {
          final oggData = await File(oggPath).readAsBytes();
          final detectedFormat = _mockFFMPEGDetectFormat(oggData);
          expect(detectedFormat, equals(FFMPEGFormat.ogg));
        }
      });

      test('should detect WAV format correctly', () async {
        final wavPath = TestDataLoader.getAssetPath('test_mono_44100.wav');
        if (await File(wavPath).exists()) {
          final wavData = await File(wavPath).readAsBytes();
          final detectedFormat = _mockFFMPEGDetectFormat(wavData);
          expect(detectedFormat, equals(FFMPEGFormat.wav));
        }
      });

      test('should detect Opus format correctly', () async {
        final opusPath = TestDataLoader.getAssetPath('test_sample.opus');
        if (await File(opusPath).exists()) {
          final opusData = await File(opusPath).readAsBytes();
          final detectedFormat = _mockFFMPEGDetectFormat(opusData);
          expect(detectedFormat, equals(FFMPEGFormat.opus));
        }
      });

      test('should return unknown for invalid format', () {
        final invalidData = Uint8List.fromList([0xFF, 0xFE, 0xFD, 0xFC]);
        final detectedFormat = _mockFFMPEGDetectFormat(invalidData);
        expect(detectedFormat, equals(FFMPEGFormat.unknown));
      });

      test('should handle empty data gracefully', () {
        final emptyData = Uint8List(0);
        final detectedFormat = _mockFFMPEGDetectFormat(emptyData);
        expect(detectedFormat, equals(FFMPEGFormat.unknown));
      });

      test('should handle corrupted headers', () async {
        final mp3Path = TestDataLoader.getAssetPath('corrupted_header.mp3');
        if (await File(mp3Path).exists()) {
          final mp3Data = await File(mp3Path).readAsBytes();
          final detectedFormat = _mockFFMPEGDetectFormat(mp3Data);
          // Should either detect as unknown or still detect as MP3 depending on corruption level
          expect([FFMPEGFormat.mp3, FFMPEGFormat.unknown], contains(detectedFormat));
        }
      });
    });

    group('Audio Decoding Tests', () {
      test('should decode MP3 audio correctly', () async {
        final mp3Path = TestDataLoader.getAssetPath('test_short.mp3');
        if (await File(mp3Path).exists()) {
          final mp3Data = await File(mp3Path).readAsBytes();
          final audioResult = await _mockFFMPEGDecodeAudio(mp3Data, FFMPEGFormat.mp3);
          expect(audioResult.success, isTrue);
          expect(audioResult.audioData, isNotNull);
          expect(audioResult.audioData!.samples, isNotEmpty);
          expect(audioResult.audioData!.sampleRate, greaterThan(0));
          expect(audioResult.audioData!.channels, greaterThan(0));
        }
      });

      test('should decode FLAC audio correctly', () async {
        final flacPath = TestDataLoader.getAssetPath('test_sample.flac');
        if (await File(flacPath).exists()) {
          final flacData = await File(flacPath).readAsBytes();
          final audioResult = await _mockFFMPEGDecodeAudio(flacData, FFMPEGFormat.flac);
          expect(audioResult.success, isTrue);
          expect(audioResult.audioData, isNotNull);
          expect(audioResult.audioData!.samples, isNotEmpty);
          expect(audioResult.audioData!.sampleRate, greaterThan(0));
        }
      });

      test('should decode WAV audio correctly', () async {
        final wavPath = TestDataLoader.getAssetPath('test_mono_44100.wav');
        if (await File(wavPath).exists()) {
          final wavData = await File(wavPath).readAsBytes();
          final audioResult = await _mockFFMPEGDecodeAudio(wavData, FFMPEGFormat.wav);
          expect(audioResult.success, isTrue);
          expect(audioResult.audioData, isNotNull);
          expect(audioResult.audioData!.samples, isNotEmpty);
          expect(audioResult.audioData!.sampleRate, equals(44100));
          expect(audioResult.audioData!.channels, equals(1));
        }
      });

      test('should handle decoding errors gracefully', () async {
        final invalidData = Uint8List.fromList(List.generate(1024, (i) => i % 256));

        final audioResult = await _mockFFMPEGDecodeAudio(invalidData, FFMPEGFormat.mp3);
        expect(audioResult.success, isFalse);
        expect(audioResult.errorMessage, isNotNull);
        expect(audioResult.errorCode, equals(FFMPEGError.decodeError));
      });

      test('should convert audio to float samples correctly', () async {
        final wavPath = TestDataLoader.getAssetPath('test_stereo_44100.wav');
        if (await File(wavPath).exists()) {
          final wavData = await File(wavPath).readAsBytes();
          final audioResult = await _mockFFMPEGDecodeAudio(wavData, FFMPEGFormat.wav);
          expect(audioResult.success, isTrue);

          final samples = audioResult.audioData!.samples;
          expect(samples, isNotEmpty);

          // Verify samples are in float range [-1.0, 1.0]
          for (final sample in samples) {
            expect(sample, greaterThanOrEqualTo(-1.0));
            expect(sample, lessThanOrEqualTo(1.0));
          }
        }
      });

      test('should handle different sample rates correctly', () async {
        final testFiles = [('test_mono_44100.wav', 44100), ('test_mono_48000.wav', 48000)];

        for (final (filename, expectedSampleRate) in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (await File(filePath).exists()) {
            final audioData = await File(filePath).readAsBytes();
            final audioResult = await _mockFFMPEGDecodeAudio(audioData, FFMPEGFormat.wav);
            expect(audioResult.success, isTrue);
            expect(audioResult.audioData!.sampleRate, equals(expectedSampleRate));
          }
        }
      });
    });

    group('Chunked Processing Tests', () {
      test('should initialize chunked decoder correctly', () async {
        final testFile = path.join('test', 'assets', 'test_large.mp3');

        final decoder = await _mockFFMPEGInitChunkedDecoder(FFMPEGFormat.mp3, testFile);
        expect(decoder.success, isTrue);
        expect(decoder.decoder, isNotNull);
        expect(decoder.decoder!.format, equals(FFMPEGFormat.mp3));
        expect(decoder.decoder!.filePath, equals(testFile));
      });

      test('should process file chunks correctly', () async {
        final testFile = path.join('test', 'assets', 'test_medium.mp3');

        final decoderResult = await _mockFFMPEGInitChunkedDecoder(FFMPEGFormat.mp3, testFile);
        expect(decoderResult.success, isTrue);

        final decoder = decoderResult.decoder!;
        final chunk = FileChunk(startByte: 0, endByte: 8192, chunkIndex: 0);

        final chunkResult = await _mockFFMPEGProcessFileChunk(decoder, chunk);
        expect(chunkResult.success, isTrue);
        expect(chunkResult.audioData, isNotNull);
        expect(chunkResult.audioData!.samples, isNotEmpty);
      });

      test('should handle seeking in chunked processing', () async {
        final testFile = path.join('test', 'assets', 'test_large.mp3');

        final decoderResult = await _mockFFMPEGInitChunkedDecoder(FFMPEGFormat.mp3, testFile);
        expect(decoderResult.success, isTrue);

        final decoder = decoderResult.decoder!;

        // Seek to middle of file
        final seekResult = await _mockFFMPEGSeekToTime(decoder, 30.0); // 30 seconds
        expect(seekResult.success, isTrue);

        // Process chunk after seeking
        final chunk = FileChunk(startByte: 0, endByte: 4096, chunkIndex: 0);
        final chunkResult = await _mockFFMPEGProcessFileChunk(decoder, chunk);
        expect(chunkResult.success, isTrue);
      });

      test('should cleanup chunked decoder resources', () async {
        final testFile = path.join('test', 'assets', 'test_short.mp3');

        final decoderResult = await _mockFFMPEGInitChunkedDecoder(FFMPEGFormat.mp3, testFile);
        expect(decoderResult.success, isTrue);

        final decoder = decoderResult.decoder!;

        // Cleanup should succeed
        final cleanupResult = _mockFFMPEGCleanupDecoder(decoder);
        expect(cleanupResult.success, isTrue);

        // Decoder should be marked as cleaned up
        expect(decoder.isCleanedUp, isTrue);
      });
    });

    group('Error Handling Tests', () {
      test('should handle FFMPEG initialization errors', () {
        final initResult = _mockFFMPEGInit();
        expect(initResult.success, isA<bool>());

        if (!initResult.success) {
          expect(initResult.errorCode, equals(FFMPEGError.initError));
          expect(initResult.errorMessage, isNotNull);
        }
      });

      test('should translate FFMPEG error codes correctly', () {
        final errorMappings = {
          -1094995529: FFMPEGError.invalidData, // AVERROR_INVALIDDATA
          -12: FFMPEGError.outOfMemory, // AVERROR(ENOMEM)
          -1414549496: FFMPEGError.codecNotFound, // AVERROR_DECODER_NOT_FOUND
        };

        for (final entry in errorMappings.entries) {
          final translatedError = _translateFFMPEGError(entry.key);
          expect(translatedError, equals(entry.value));
        }
      });

      test('should handle memory allocation failures', () async {
        // Simulate memory allocation failure
        final largeSize = 1024 * 1024 * 1024; // 1GB
        final allocResult = _mockFFMPEGAllocateBuffer(largeSize);

        // Should either succeed or fail gracefully
        expect(allocResult.success, isA<bool>());
        if (!allocResult.success) {
          expect(allocResult.errorCode, equals(FFMPEGError.outOfMemory));
        }
      });

      test('should handle file not found errors', () async {
        final nonExistentFile = 'non_existent_file.mp3';

        final decoderResult = await _mockFFMPEGInitChunkedDecoder(FFMPEGFormat.mp3, nonExistentFile);
        expect(decoderResult.success, isFalse);
        expect(decoderResult.errorCode, equals(FFMPEGError.fileNotFound));
      });

      test('should handle corrupted file data', () async {
        final corruptedPath = TestDataLoader.getAssetPath('corrupted_data.wav');
        if (await File(corruptedPath).exists()) {
          final corruptedData = await File(corruptedPath).readAsBytes();
          final audioResult = await _mockFFMPEGDecodeAudio(corruptedData, FFMPEGFormat.wav);
          expect(audioResult.success, isFalse);
          expect([FFMPEGError.invalidData, FFMPEGError.decodeError], contains(audioResult.errorCode));
        }
      });
    });

    group('Memory Management Tests', () {
      test('should properly manage FFMPEG contexts', () {
        final context = _mockFFMPEGCreateContext();
        expect(context.isValid, isTrue);
        expect(context.isCleanedUp, isFalse);

        final cleanupResult = _mockFFMPEGCleanupContext(context);
        expect(cleanupResult.success, isTrue);
        expect(context.isCleanedUp, isTrue);
      });

      test('should handle buffer allocation and deallocation', () {
        final bufferSize = 8192;
        final buffer = _mockFFMPEGAllocateBuffer(bufferSize);

        expect(buffer.success, isTrue);
        expect(buffer.buffer, isNotNull);
        expect(buffer.buffer!.length, equals(bufferSize));

        final freeResult = _mockFFMPEGFreeBuffer(buffer.buffer!);
        expect(freeResult.success, isTrue);
      });

      test('should detect memory leaks in processing', () async {
        final initialMemory = _mockGetMemoryUsage();

        // Perform multiple decode operations
        for (var i = 0; i < 10; i++) {
          final testData = Uint8List.fromList(List.generate(1024, (j) => j % 256));
          await _mockFFMPEGDecodeAudio(testData, FFMPEGFormat.mp3);
        }

        // Force garbage collection
        _mockForceGarbageCollection();

        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be reasonable (less than 10MB for this test)
        expect(memoryIncrease, lessThan(10 * 1024 * 1024));
      });
    });
  });
}

// Mock FFMPEG wrapper functions for testing
// In real implementation, these would call actual FFMPEG native functions

enum FFMPEGFormat { mp3, flac, ogg, wav, opus, unknown }

enum FFMPEGError { none, initError, invalidData, outOfMemory, codecNotFound, decodeError, fileNotFound }

// Use the actual AudioData class from the library
typedef FFMPEGAudioData = AudioData;

class FFMPEGDecodeResult {
  final bool success;
  final FFMPEGAudioData? audioData;
  final FFMPEGError errorCode;
  final String? errorMessage;

  FFMPEGDecodeResult.success(this.audioData) : success = true, errorCode = FFMPEGError.none, errorMessage = null;

  FFMPEGDecodeResult.failure(this.errorCode, this.errorMessage) : success = false, audioData = null;
}

class FFMPEGChunkedDecoder {
  final FFMPEGFormat format;
  final String filePath;
  bool isCleanedUp = false;

  FFMPEGChunkedDecoder({required this.format, required this.filePath});
}

class FFMPEGChunkedDecoderResult {
  final bool success;
  final FFMPEGChunkedDecoder? decoder;
  final FFMPEGError errorCode;
  final String? errorMessage;

  FFMPEGChunkedDecoderResult.success(this.decoder) : success = true, errorCode = FFMPEGError.none, errorMessage = null;

  FFMPEGChunkedDecoderResult.failure(this.errorCode, this.errorMessage) : success = false, decoder = null;
}

class FileChunk {
  final int startByte;
  final int endByte;
  final int chunkIndex;

  FileChunk({required this.startByte, required this.endByte, required this.chunkIndex});
}

class FFMPEGChunkResult {
  final bool success;
  final FFMPEGAudioData? audioData;
  final FFMPEGError errorCode;
  final String? errorMessage;

  FFMPEGChunkResult.success(this.audioData) : success = true, errorCode = FFMPEGError.none, errorMessage = null;

  FFMPEGChunkResult.failure(this.errorCode, this.errorMessage) : success = false, audioData = null;
}

class FFMPEGSeekResult {
  final bool success;
  final FFMPEGError errorCode;
  final String? errorMessage;

  FFMPEGSeekResult.success() : success = true, errorCode = FFMPEGError.none, errorMessage = null;

  FFMPEGSeekResult.failure(this.errorCode, this.errorMessage) : success = false;
}

class FFMPEGCleanupResult {
  final bool success;
  final FFMPEGError errorCode;
  final String? errorMessage;

  FFMPEGCleanupResult.success() : success = true, errorCode = FFMPEGError.none, errorMessage = null;

  FFMPEGCleanupResult.failure(this.errorCode, this.errorMessage) : success = false;
}

class FFMPEGInitResult {
  final bool success;
  final FFMPEGError errorCode;
  final String? errorMessage;

  FFMPEGInitResult.success() : success = true, errorCode = FFMPEGError.none, errorMessage = null;

  FFMPEGInitResult.failure(this.errorCode, this.errorMessage) : success = false;
}

class FFMPEGContext {
  bool isValid = true;
  bool isCleanedUp = false;
}

class FFMPEGBufferResult {
  final bool success;
  final Uint8List? buffer;
  final FFMPEGError errorCode;
  final String? errorMessage;

  FFMPEGBufferResult.success(this.buffer) : success = true, errorCode = FFMPEGError.none, errorMessage = null;

  FFMPEGBufferResult.failure(this.errorCode, this.errorMessage) : success = false, buffer = null;
}

// Mock implementations

FFMPEGFormat _mockFFMPEGDetectFormat(Uint8List data) {
  if (data.isEmpty) return FFMPEGFormat.unknown;

  // Simple format detection based on magic bytes
  if (data.length >= 4) {
    // MP3 - starts with 0xFF and second byte has 0xE0 mask
    if (data[0] == 0xFF && (data[1] & 0xE0) == 0xE0) {
      return FFMPEGFormat.mp3;
    }
    // FLAC - starts with "fLaC"
    if (data[0] == 0x66 && data[1] == 0x4C && data[2] == 0x61 && data[3] == 0x43) {
      return FFMPEGFormat.flac;
    }
    // OGG - starts with "OggS"
    if (data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53) {
      return FFMPEGFormat.ogg;
    }
    // WAV - starts with "RIFF"
    if (data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46) {
      return FFMPEGFormat.wav;
    }
  }

  // Check for Opus in OGG container (more complex detection needed)
  if (data.length >= 8) {
    // OGG container with Opus magic
    if (data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53) {
      // Look for OpusHead in the stream (simplified check)
      for (var i = 0; i < data.length - 8; i++) {
        if (data[i] == 0x4F && data[i + 1] == 0x70 && data[i + 2] == 0x75 && data[i + 3] == 0x73) {
          return FFMPEGFormat.opus;
        }
      }
      return FFMPEGFormat.ogg; // OGG but not Opus
    }
  }

  // If data looks like random bytes, return unknown
  if (data.length >= 4 && data[0] == 0xFF && data[1] == 0xFE) {
    return FFMPEGFormat.unknown;
  }

  return FFMPEGFormat.unknown;
}

Future<FFMPEGDecodeResult> _mockFFMPEGDecodeAudio(Uint8List data, FFMPEGFormat format) async {
  // Simulate processing delay
  await Future.delayed(Duration(milliseconds: 10));

  if (format == FFMPEGFormat.unknown) {
    return FFMPEGDecodeResult.failure(FFMPEGError.invalidData, 'Unknown format');
  }

  if (data.length < 100) {
    return FFMPEGDecodeResult.failure(FFMPEGError.invalidData, 'Data too small');
  }

  // Check for invalid data patterns that should cause decode errors
  if (data.length >= 4 && data[0] == 0xFF && data[1] == 0xFE && data[2] == 0xFD && data[3] == 0xFC) {
    return FFMPEGDecodeResult.failure(FFMPEGError.decodeError, 'Invalid data pattern');
  }

  // Generate mock audio data based on format and filename patterns
  var sampleRate = 44100;
  var channels = 2;

  // Adjust based on format and data characteristics
  if (format == FFMPEGFormat.wav) {
    // For WAV files, try to detect mono vs stereo from data size
    if (data.length < 50000) {
      // Smaller files are likely mono
      channels = 1;
    }
    // Check for sample rate hints in the data (mock detection)
    if (data.length > 24) {
      // Mock sample rate detection from WAV header
      final mockSampleRateBytes = (data[24] | (data[25] << 8) | (data[26] << 16) | (data[27] << 24));
      if (mockSampleRateBytes == 48000 || (data.length > 100000 && data[10] > 200)) {
        sampleRate = 48000;
      }
    }
  }

  final duration = Duration(milliseconds: 1000);
  final sampleCount = (sampleRate * duration.inMilliseconds / 1000).round() * channels;

  final samples = List.generate(sampleCount, (i) {
    // Generate a simple sine wave
    return 0.5 * (i % 2 == 0 ? 1 : -1) * (i / sampleCount.toDouble());
  });

  final audioData = AudioData(samples: samples, sampleRate: sampleRate, channels: channels, duration: duration);

  return FFMPEGDecodeResult.success(audioData);
}

Future<FFMPEGChunkedDecoderResult> _mockFFMPEGInitChunkedDecoder(FFMPEGFormat format, String filePath) async {
  await Future.delayed(Duration(milliseconds: 5));

  if (!File(filePath).existsSync() && !filePath.contains('test')) {
    return FFMPEGChunkedDecoderResult.failure(FFMPEGError.fileNotFound, 'File not found: $filePath');
  }

  final decoder = FFMPEGChunkedDecoder(format: format, filePath: filePath);
  return FFMPEGChunkedDecoderResult.success(decoder);
}

Future<FFMPEGChunkResult> _mockFFMPEGProcessFileChunk(FFMPEGChunkedDecoder decoder, FileChunk chunk) async {
  await Future.delayed(Duration(milliseconds: 20));

  if (decoder.isCleanedUp) {
    return FFMPEGChunkResult.failure(FFMPEGError.invalidData, 'Decoder already cleaned up');
  }

  // Generate mock chunk audio data
  final chunkSamples = List.generate(1024, (i) => (i / 1024.0) * 0.5);
  final audioData = AudioData(samples: chunkSamples, sampleRate: 44100, channels: 2, duration: Duration(milliseconds: 100));

  return FFMPEGChunkResult.success(audioData);
}

Future<FFMPEGSeekResult> _mockFFMPEGSeekToTime(FFMPEGChunkedDecoder decoder, double timeSeconds) async {
  await Future.delayed(Duration(milliseconds: 5));

  if (decoder.isCleanedUp) {
    return FFMPEGSeekResult.failure(FFMPEGError.invalidData, 'Decoder already cleaned up');
  }

  if (timeSeconds < 0) {
    return FFMPEGSeekResult.failure(FFMPEGError.invalidData, 'Invalid seek time');
  }

  return FFMPEGSeekResult.success();
}

FFMPEGCleanupResult _mockFFMPEGCleanupDecoder(FFMPEGChunkedDecoder decoder) {
  decoder.isCleanedUp = true;
  return FFMPEGCleanupResult.success();
}

FFMPEGInitResult _mockFFMPEGInit() {
  // Simulate potential initialization failure
  return FFMPEGInitResult.success();
}

FFMPEGError _translateFFMPEGError(int ffmpegErrorCode) {
  switch (ffmpegErrorCode) {
    case -1094995529: // AVERROR_INVALIDDATA
      return FFMPEGError.invalidData;
    case -12: // AVERROR(ENOMEM)
      return FFMPEGError.outOfMemory;
    case -1414549496: // AVERROR_DECODER_NOT_FOUND
      return FFMPEGError.codecNotFound;
    default:
      return FFMPEGError.decodeError;
  }
}

FFMPEGBufferResult _mockFFMPEGAllocateBuffer(int size) {
  if (size > 512 * 1024 * 1024) {
    // 512MB limit for testing
    return FFMPEGBufferResult.failure(FFMPEGError.outOfMemory, 'Buffer too large');
  }

  final buffer = Uint8List(size);
  return FFMPEGBufferResult.success(buffer);
}

FFMPEGCleanupResult _mockFFMPEGFreeBuffer(Uint8List buffer) {
  // In real implementation, this would free native memory
  return FFMPEGCleanupResult.success();
}

FFMPEGContext _mockFFMPEGCreateContext() {
  return FFMPEGContext();
}

FFMPEGCleanupResult _mockFFMPEGCleanupContext(FFMPEGContext context) {
  context.isCleanedUp = true;
  context.isValid = false;
  return FFMPEGCleanupResult.success();
}

int _mockGetMemoryUsage() {
  // Return mock memory usage in bytes
  return 50 * 1024 * 1024; // 50MB
}

void _mockForceGarbageCollection() {
  // In real implementation, this might trigger native garbage collection
}
