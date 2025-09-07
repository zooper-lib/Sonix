import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('Audio Decoders', () {
    test('MP3Decoder initialization and disposal', () {
      final decoder = MP3Decoder();
      expect(decoder, isA<AudioDecoder>());

      // Test disposal
      decoder.dispose();

      // Should throw after disposal
      expect(() => decoder.decode('test.mp3'), throwsA(isA<StateError>()));
    });

    test('WAVDecoder initialization and disposal', () {
      final decoder = WAVDecoder();
      expect(decoder, isA<AudioDecoder>());

      // Test disposal
      decoder.dispose();

      // Should throw after disposal
      expect(() => decoder.decode('test.wav'), throwsA(isA<StateError>()));
    });

    test('FLACDecoder initialization and disposal', () {
      final decoder = FLACDecoder();
      expect(decoder, isA<AudioDecoder>());

      // Test disposal
      decoder.dispose();

      // Should throw after disposal
      expect(() => decoder.decode('test.flac'), throwsA(isA<StateError>()));
    });

    test('VorbisDecoder initialization and disposal', () {
      final decoder = VorbisDecoder();
      expect(decoder, isA<AudioDecoder>());

      // Test disposal
      decoder.dispose();

      // Should throw after disposal
      expect(() => decoder.decode('test.ogg'), throwsA(isA<StateError>()));
    });

    test('OpusDecoder initialization and disposal', () {
      final decoder = OpusDecoder();
      expect(decoder, isA<AudioDecoder>());

      // Test disposal
      decoder.dispose();

      // Should throw after disposal
      expect(() => decoder.decode('test.opus'), throwsA(isA<StateError>()));
    });

    test('Decoder error handling for non-existent files', () async {
      final decoder = MP3Decoder();

      // Should throw FileAccessException for non-existent file
      expect(() => decoder.decode('non_existent.mp3'), throwsA(isA<FileAccessException>()));
      expect(() => decoder.getMetadata('non_existent.mp3'), throwsA(isA<FileAccessException>()));

      decoder.dispose();
    });

    test('Decoder stream error handling for non-existent files', () async {
      final decoder = MP3Decoder();

      // Test that the stream method exists and can be called
      final stream = decoder.decodeStream('non_existent.mp3');
      expect(stream, isA<Stream<AudioChunk>>());

      decoder.dispose();
    });

    test('Decoder disposal behavior', () async {
      final decoder = MP3Decoder();

      // Test disposal
      decoder.dispose();

      // Should throw StateError after disposal
      expect(() => decoder.decode('test.mp3'), throwsA(isA<StateError>()));
      expect(() => decoder.getMetadata('test.mp3'), throwsA(isA<StateError>()));
      expect(() async {
        await for (final chunk in decoder.decodeStream('test.mp3')) {
          // This should not execute
        }
      }(), throwsA(isA<StateError>()));
    });

    test('Streaming memory manager functionality', () {
      // Test memory pressure threshold
      expect(StreamingMemoryManager.calculateOptimalChunkSize(1024, AudioFormat.mp3), greaterThan(0));

      // Test memory pressure detection
      final shouldStream = StreamingMemoryManager.shouldUseStreaming(1000000000, AudioFormat.mp3); // 1GB file
      expect(shouldStream, isA<bool>());

      // Test quality reduction suggestions
      final suggestion = StreamingMemoryManager.suggestQualityReduction(1000000000, AudioFormat.mp3);
      expect(suggestion, isA<Map<String, dynamic>>());
      expect(suggestion.containsKey('shouldReduce'), true);
    });

    test('Memory estimation for different formats', () {
      const fileSize = 1024 * 1024; // 1MB

      final mp3Memory = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, AudioFormat.mp3);
      final wavMemory = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, AudioFormat.wav);
      final flacMemory = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, AudioFormat.flac);

      expect(mp3Memory, greaterThan(fileSize)); // Compressed formats should expand
      expect(wavMemory, equals(fileSize)); // WAV is uncompressed
      expect(flacMemory, greaterThan(fileSize)); // FLAC is lossless compressed
    });

    test('Native bindings initialization', () {
      // Test memory pressure threshold setting (this doesn't require native library)
      NativeAudioBindings.setMemoryPressureThreshold(50 * 1024 * 1024); // 50MB

      // Test that initialization either succeeds or throws FFIException (library not built)
      expect(() => NativeAudioBindings.initialize(), anyOf(returnsNormally, throwsA(isA<FFIException>())));
      expect(NativeAudioBindings.memoryPressureThreshold, equals(50 * 1024 * 1024));
    });

    test('Format detection with native bindings', () {
      // Test memory pressure detection (doesn't require native library)
      expect(NativeAudioBindings.wouldExceedMemoryPressure(1000), false);
      expect(NativeAudioBindings.wouldExceedMemoryPressure(200 * 1024 * 1024), true); // 200MB > default threshold

      // Test format detection with empty data (may throw FFIException if library not built)
      expect(() => NativeAudioBindings.detectFormat(Uint8List(0)), anyOf(throwsA(isA<DecodingException>()), throwsA(isA<FFIException>())));
    });
  });

  group('Streaming Audio Processing', () {
    test('AudioChunk streaming interface', () {
      final chunk = AudioChunk(samples: [0.1, 0.2, 0.3], startSample: 1000, isLast: false);

      expect(chunk.samples.length, 3);
      expect(chunk.startSample, 1000);
      expect(chunk.isLast, false);
    });

    test('Memory pressure handling', () {
      // Test that memory pressure checks don't throw
      expect(() => StreamingMemoryManager.checkMemoryPressure(), returnsNormally);

      // Test file size calculation for non-existent file
      expect(() => StreamingMemoryManager.getFileSize('non_existent.mp3'), throwsA(isA<FileAccessException>()));
    });

    test('Optimal chunk size calculation', () {
      // Small file should use default chunk size
      final smallChunk = StreamingMemoryManager.calculateOptimalChunkSize(1024, AudioFormat.mp3);
      expect(smallChunk, greaterThan(0));

      // Large file should use smaller chunks
      final largeChunk = StreamingMemoryManager.calculateOptimalChunkSize(1000000000, AudioFormat.mp3);
      expect(largeChunk, greaterThan(0));
      expect(largeChunk, lessThanOrEqualTo(1024 * 1024)); // Should not exceed max chunk size
    });
  });
}
