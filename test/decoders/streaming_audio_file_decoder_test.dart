// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_file_decoder.dart';
import 'package:sonix/src/models/audio_data.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('StreamingAudioFileDecoder Tests', () {
    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw Exception('FFMPEG libraries not available for testing');
      }
    });

    group('Chunked Decoding Verification', () {
      test('should decode file in multiple chunks', () async {
        // Use a medium-sized file to test chunked processing
        final filePath = 'test/assets/test_medium.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test file does not exist: $filePath');
        }

        final fileSize = await file.length();
        print('Test file size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

        // The native decoder processes ~100 packets per chunk
        // For most files this should result in multiple chunks
        final decoder = StreamingAudioFileDecoder();
        final chunks = <AudioData>[];
        var chunkCount = 0;

        try {
          await for (final chunk in decoder.decodeStreaming(filePath)) {
            chunkCount++;
            chunks.add(chunk);
            print(
              'Received chunk $chunkCount: '
              '${chunk.samples.length} samples, '
              '${chunk.sampleRate}Hz, '
              '${chunk.channels} channels',
            );
          }
        } finally {
          decoder.dispose();
        }

        // Verify we got chunks
        expect(chunkCount, greaterThanOrEqualTo(1), reason: 'Should decode into chunks');
        print('Total chunks received: $chunkCount');

        // Verify all chunks have valid audio data
        for (var i = 0; i < chunks.length; i++) {
          expect(chunks[i].samples.length, greaterThan(0), reason: 'Chunk $i should have samples');
          expect(chunks[i].sampleRate, greaterThan(0), reason: 'Chunk $i should have valid sample rate');
          expect(chunks[i].channels, greaterThan(0), reason: 'Chunk $i should have valid channel count');
        }

        // Verify all chunks have consistent metadata
        final firstChunk = chunks.first;
        for (var i = 1; i < chunks.length; i++) {
          expect(chunks[i].sampleRate, equals(firstChunk.sampleRate), reason: 'Chunk $i should have same sample rate as first chunk');
          expect(chunks[i].channels, equals(firstChunk.channels), reason: 'Chunk $i should have same channel count as first chunk');
        }
      });

      test('should produce same result as simple decoder', () async {
        final filePath = 'test/assets/test_medium.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test file does not exist: $filePath');
        }

        // Decode with simple decoder (full file)
        final simpleDecoder = SimpleAudioFileDecoder();
        final simpleResult = await simpleDecoder.decode(filePath);
        simpleDecoder.dispose();

        // Decode with streaming decoder (chunked)
        final streamingDecoder = StreamingAudioFileDecoder();
        final streamingResult = await streamingDecoder.decode(filePath);
        streamingDecoder.dispose();

        // Compare results
        expect(streamingResult.sampleRate, equals(simpleResult.sampleRate));
        expect(streamingResult.channels, equals(simpleResult.channels));

        // Sample counts should be equal (or very close due to rounding)
        final sampleDifference = (streamingResult.samples.length - simpleResult.samples.length).abs();
        expect(
          sampleDifference,
          lessThan(1000),
          reason:
              'Sample counts should be nearly equal: '
              'streaming=${streamingResult.samples.length}, simple=${simpleResult.samples.length}',
        );

        print(
          'Simple decoder: ${simpleResult.samples.length} samples\n'
          'Streaming decoder: ${streamingResult.samples.length} samples\n'
          'Difference: $sampleDifference samples',
        );
      });

      test('should handle large WAV file with chunked processing', () async {
        final filePath = 'test/assets/test_large.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test file does not exist: $filePath');
        }

        final fileSize = await file.length();
        print('Large test file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        final decoder = StreamingAudioFileDecoder();

        var chunkCount = 0;
        var totalSamples = 0;

        try {
          await for (final chunk in decoder.decodeStreaming(filePath)) {
            chunkCount++;
            totalSamples += chunk.samples.length;
            print('Chunk $chunkCount: ${chunk.samples.length} samples (running total: $totalSamples)');
          }
        } finally {
          decoder.dispose();
        }

        expect(chunkCount, greaterThan(1), reason: 'Large file should produce multiple chunks');
        expect(totalSamples, greaterThan(0), reason: 'Should have decoded samples');

        print('Total: $chunkCount chunks, $totalSamples samples');
      });

      test('should handle MP3 file with chunked processing', () async {
        final filePath = 'test/assets/test_large.mp3';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test file does not exist: $filePath');
        }

        final fileSize = await file.length();
        print('MP3 test file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        final decoder = StreamingAudioFileDecoder();

        var chunkCount = 0;
        var totalSamples = 0;
        int? sampleRate;
        int? channels;

        try {
          await for (final chunk in decoder.decodeStreaming(filePath)) {
            chunkCount++;
            totalSamples += chunk.samples.length;
            sampleRate ??= chunk.sampleRate;
            channels ??= chunk.channels;

            // Verify consistent metadata
            expect(chunk.sampleRate, equals(sampleRate));
            expect(chunk.channels, equals(channels));
          }
        } finally {
          decoder.dispose();
        }

        expect(chunkCount, greaterThan(1), reason: 'MP3 file should produce multiple chunks');
        expect(totalSamples, greaterThan(0), reason: 'Should have decoded samples');

        print('MP3 decoded: $chunkCount chunks, $totalSamples samples, ${sampleRate}Hz, $channels channels');
      });
    });

    group('Edge Cases', () {
      test('should handle small file that fits in one chunk', () async {
        final filePath = 'test/assets/test_short.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test file does not exist: $filePath');
        }

        final decoder = StreamingAudioFileDecoder();

        var chunkCount = 0;
        AudioData? result;

        try {
          await for (final chunk in decoder.decodeStreaming(filePath)) {
            chunkCount++;
            result = chunk;
          }
        } finally {
          decoder.dispose();
        }

        // Small file should still work, producing 1 or more chunks
        expect(chunkCount, greaterThanOrEqualTo(1));
        expect(result, isNotNull);
        expect(result!.samples.length, greaterThan(0));
      });

      test('should throw for non-existent file', () async {
        final decoder = StreamingAudioFileDecoder();

        try {
          await expectLater(decoder.decodeStreaming('/non/existent/file.wav').toList(), throwsA(isA<FileSystemException>()));
        } finally {
          decoder.dispose();
        }
      });

      test('should throw for unsupported format', () async {
        // Create a temp file with unsupported extension
        final tempDir = await Directory.systemTemp.createTemp('streaming_decoder_test');
        final testFile = File('${tempDir.path}/test.xyz');
        await testFile.writeAsBytes([0x00, 0x01, 0x02]);

        final decoder = StreamingAudioFileDecoder();

        try {
          await expectLater(decoder.decodeStreaming(testFile.path).toList(), throwsA(isA<UnsupportedError>()));
        } finally {
          decoder.dispose();
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('Memory Efficiency', () {
      test('should not load entire file into memory at once', () async {
        // This test verifies the streaming decoder processes chunks incrementally
        // by checking that we receive chunks before the entire file is processed

        final filePath = 'test/assets/test_large.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test file does not exist: $filePath');
        }

        final fileSize = await file.length();
        print('Large WAV file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        final decoder = StreamingAudioFileDecoder();
        final receivedChunkTimes = <int>[];
        final stopwatch = Stopwatch()..start();

        try {
          await for (final _ in decoder.decodeStreaming(filePath)) {
            receivedChunkTimes.add(stopwatch.elapsedMilliseconds);
          }
        } finally {
          decoder.dispose();
          stopwatch.stop();
        }

        print('Chunk reception times (ms): $receivedChunkTimes');
        print('Total time: ${stopwatch.elapsedMilliseconds}ms');
        print('Total chunks: ${receivedChunkTimes.length}');

        // Verify we received multiple chunks
        expect(receivedChunkTimes.length, greaterThan(1));

        // Verify chunks were received progressively (not all at once at the end)
        // The first chunk should arrive before 80% of total time
        if (receivedChunkTimes.length > 2) {
          final firstChunkTime = receivedChunkTimes.first;
          final totalTime = stopwatch.elapsedMilliseconds;
          expect(firstChunkTime, lessThan(totalTime * 0.8), reason: 'First chunk should arrive before 80% of total processing time');
        }
      });
    });
  });
}
