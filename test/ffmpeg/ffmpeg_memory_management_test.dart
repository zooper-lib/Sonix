// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffi/ffi.dart';

import 'ffmpeg_setup_helper.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('FFMPEG Memory Management Tests', () {
    bool ffmpegAvailable = false;

    setUpAll(() async {
      // Setup FFMPEG libraries for testing using the fixtures directory
      FFMPEGSetupHelper.printFFMPEGStatus();
      ffmpegAvailable = await FFMPEGSetupHelper.setupFFMPEGForTesting();

      if (!ffmpegAvailable) {
        throw StateError(
          'FFMPEG not available - required for memory management tests. '
          'To set up FFMPEG for testing, run: '
          'dart run tool/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install',
        );
      }

      // Verify test files exist
      final testFiles = [
        'test/assets/Double-F the King - Your Blessing.wav',
        'test/assets/Double-F the King - Your Blessing.mp3',
        'test/assets/small_test.wav',
      ];

      for (final filePath in testFiles) {
        if (!File(filePath).existsSync()) {
          print('⚠️ Test file not found: $filePath');
        } else {
          print('✅ Test file available: $filePath');
        }
      }

      // Initialize FFMPEG
      final initResult = SonixNativeBindings.initFFMPEG();
      if (initResult != 0) {
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        throw StateError('Failed to initialize FFMPEG: $errorMsg');
      }
    });

    tearDownAll(() {
      // Cleanup FFMPEG
      SonixNativeBindings.cleanupFFMPEG();
    });

    group('Audio Data Memory Management', () {
      test('should properly allocate and free audio data memory', () async {
        const testFile = 'test/assets/small_test.wav';

        if (!File(testFile).existsSync()) {
          print('Skipping audio data memory test - file not found: $testFile');
          return;
        }

        final wavData = await File(testFile).readAsBytes();
        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          // Test multiple allocate/free cycles
          for (int i = 0; i < 10; i++) {
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, SONIX_FORMAT_WAV);

            expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully allocate audio data in iteration $i');

            if (audioDataPtr != nullptr) {
              final audioData = audioDataPtr.ref;
              expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples in iteration $i');
              expect(audioData.samples, isNot(equals(nullptr)), reason: 'Sample data pointer should be allocated in iteration $i');

              // Free immediately to test memory management
              SonixNativeBindings.freeAudioData(audioDataPtr);
            }
          }

          print('✅ Audio data allocation/deallocation cycles completed successfully');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle multiple audio formats without memory leaks', () async {
        final testFiles = [
          {'file': 'test/assets/Double-F the King - Your Blessing.wav', 'format': SONIX_FORMAT_WAV},
          {'file': 'test/assets/Double-F the King - Your Blessing.mp3', 'format': SONIX_FORMAT_MP3},
        ];

        for (final testCase in testFiles) {
          final testFile = testCase['file'] as String;
          final format = testCase['format'] as int;

          if (!File(testFile).existsSync()) {
            print('Skipping format test - file not found: $testFile');
            continue;
          }

          print('Testing memory management for: $testFile');

          final audioData = await File(testFile).readAsBytes();
          final dataPtr = malloc<Uint8>(audioData.length);
          final dataList = dataPtr.asTypedList(audioData.length);
          dataList.setAll(0, audioData);

          try {
            // Decode and immediately free to test memory handling
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, audioData.length, format);

            if (audioDataPtr != nullptr) {
              final decodedData = audioDataPtr.ref;
              expect(decodedData.sample_count, greaterThan(0), reason: 'Should have decoded samples');

              // Test that we can access the sample data without crashes
              if (decodedData.samples != nullptr && decodedData.sample_count > 0) {
                final samples = decodedData.samples.asTypedList(decodedData.sample_count);
                expect(samples.length, equals(decodedData.sample_count), reason: 'Sample array should be accessible');
              }

              // Free the audio data
              SonixNativeBindings.freeAudioData(audioDataPtr);
            }
          } finally {
            malloc.free(dataPtr);
          }
        }

        print('✅ Multi-format memory management test completed');
      });
    });

    group('FFMPEG Context Memory Management', () {
      test('should handle FFMPEG initialization and cleanup cycles', () {
        // Test multiple init/cleanup cycles to verify no memory leaks
        for (int i = 0; i < 5; i++) {
          // Cleanup current instance
          SonixNativeBindings.cleanupFFMPEG();

          // Re-initialize
          final initResult = SonixNativeBindings.initFFMPEG();
          expect(initResult, equals(SONIX_OK), reason: 'Should successfully re-initialize FFMPEG in cycle $i');

          // Verify backend type
          final backendType = SonixNativeBindings.getBackendType();
          expect(backendType, equals(SONIX_BACKEND_FFMPEG), reason: 'Should report FFMPEG backend after re-initialization');
        }

        print('✅ FFMPEG init/cleanup cycles completed successfully');
      });
    });

    group('Chunked Decoder Memory Management', () {
      test('should properly allocate and cleanup chunked decoder resources', () async {
        const testFile = 'test/assets/Double-F the King - Your Blessing.wav';

        if (!File(testFile).existsSync()) {
          print('Skipping chunked decoder memory test - file not found: $testFile');
          return;
        }

        final filePathPtr = testFile.toNativeUtf8();

        try {
          // Test multiple decoder allocation/cleanup cycles
          for (int cycle = 0; cycle < 3; cycle++) {
            final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<Char>());

            expect(decoder, isNot(equals(nullptr)), reason: 'Should successfully initialize chunked decoder in cycle $cycle');

            if (decoder != nullptr) {
              // Process a few chunks to test memory handling
              for (int i = 0; i < 3; i++) {
                final chunkPtr = malloc<SonixFileChunk>();
                chunkPtr.ref.chunk_index = i;

                try {
                  final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

                  if (result != nullptr) {
                    final chunkResult = result.ref;

                    if (chunkResult.success == 1 && chunkResult.audio_data != nullptr) {
                      // Verify we can access the chunk data
                      final audioData = chunkResult.audio_data.ref;
                      expect(audioData.sample_count, greaterThanOrEqualTo(0), reason: 'Should have valid sample count');
                    }

                    // Free chunk result immediately to test memory management
                    SonixNativeBindings.freeChunkResult(result);
                  }
                } finally {
                  malloc.free(chunkPtr);
                }
              }

              // Cleanup decoder
              SonixNativeBindings.cleanupChunkedDecoder(decoder);
            }
          }

          print('✅ Chunked decoder memory management cycles completed successfully');
        } finally {
          malloc.free(filePathPtr);
        }
      });

      test('should handle multiple simultaneous chunked decoders', () async {
        const testFile = 'test/assets/Double-F the King - Your Blessing.wav';

        if (!File(testFile).existsSync()) {
          print('Skipping multiple decoders memory test - file not found: $testFile');
          return;
        }

        final filePathPtr = testFile.toNativeUtf8();

        try {
          final decoders = <Pointer<SonixChunkedDecoder>>[];

          // Create multiple decoders to test memory allocation
          for (int i = 0; i < 3; i++) {
            final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<Char>());

            expect(decoder, isNot(equals(nullptr)), reason: 'Should successfully initialize chunked decoder $i');

            if (decoder != nullptr) {
              decoders.add(decoder);
            }
          }

          print('Created ${decoders.length} simultaneous chunked decoders');

          // Process a chunk with each decoder to test memory isolation
          for (int decoderIndex = 0; decoderIndex < decoders.length; decoderIndex++) {
            final decoder = decoders[decoderIndex];

            final chunkPtr = malloc<SonixFileChunk>();
            chunkPtr.ref.chunk_index = decoderIndex;

            try {
              final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

              if (result != nullptr) {
                final chunkResult = result.ref;

                if (chunkResult.success == 1) {
                  final audioData = chunkResult.audio_data.ref;
                  expect(audioData.sample_count, greaterThanOrEqualTo(0), reason: 'Decoder $decoderIndex should produce valid chunks');
                }

                SonixNativeBindings.freeChunkResult(result);
              }
            } finally {
              malloc.free(chunkPtr);
            }
          }

          // Cleanup all decoders
          for (final decoder in decoders) {
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          }

          print('✅ Multiple chunked decoders memory management completed successfully');
        } finally {
          malloc.free(filePathPtr);
        }
      });
    });

    group('Memory Stress Tests', () {
      test('should handle rapid allocation and deallocation without memory leaks', () async {
        const testFile = 'test/assets/small_test.wav';

        if (!File(testFile).existsSync()) {
          print('Skipping memory stress test - file not found: $testFile');
          return;
        }

        final wavData = await File(testFile).readAsBytes();
        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          final stopwatch = Stopwatch()..start();

          // Rapid allocation/deallocation cycles to test for memory leaks
          for (int i = 0; i < 100; i++) {
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, SONIX_FORMAT_WAV);

            if (audioDataPtr != nullptr) {
              // Verify the data is accessible
              final audioData = audioDataPtr.ref;
              expect(audioData.sample_count, greaterThan(0), reason: 'Should have valid sample count in iteration $i');

              // Immediately free without using the data (stress test)
              SonixNativeBindings.freeAudioData(audioDataPtr);
            }

            if (i % 25 == 0) {
              print('Completed $i rapid allocation/deallocation cycles');
            }
          }

          stopwatch.stop();
          print('✅ Rapid allocation/deallocation stress test completed in ${stopwatch.elapsedMilliseconds}ms');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle memory allocation with sequential chunk processing', () async {
        const testFile = 'test/assets/Double-F the King - Your Blessing.wav';

        if (!File(testFile).existsSync()) {
          print('Skipping chunk size memory test - file not found: $testFile');
          return;
        }

        final filePathPtr = testFile.toNativeUtf8();
        // Test multiple chunk processing cycles (chunk sizes are ignored by native code)
        final numChunks = [1, 2, 3, 5]; // Different numbers of chunks to process

        try {
          for (final chunks in numChunks) {
            final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<Char>());

            if (decoder != nullptr) {
              print('Testing with $chunks sequential chunk processing calls');

              // Process chunks sequentially
              for (int i = 0; i < chunks; i++) {
                final chunkPtr = malloc<SonixFileChunk>();
                chunkPtr.ref.chunk_index = i;

                try {
                  final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

                  if (result != nullptr) {
                    final chunkResult = result.ref;

                    if (chunkResult.success == 1 && chunkResult.audio_data != nullptr) {
                      // Verify memory allocation is working properly
                      final audioData = chunkResult.audio_data.ref;
                      expect(audioData.sample_count, greaterThanOrEqualTo(0), reason: 'Should handle sequential chunk processing');
                    }

                    SonixNativeBindings.freeChunkResult(result);
                  }
                } finally {
                  malloc.free(chunkPtr);
                }
              }

              SonixNativeBindings.cleanupChunkedDecoder(decoder);
            }
          }

          print('✅ Sequential chunk processing memory allocation test completed successfully');
        } finally {
          malloc.free(filePathPtr);
        }
      });
    });
  });
}
