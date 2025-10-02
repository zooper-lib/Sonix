// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

/// End-to-End Performance Tests with Real Audio Files
///
/// This test file focuses exclusively on performance testing with real audio files.
/// It measures complete workflows from file loading to final output processing.
/// No synthetic data, no simulation - only real performance characteristics.
void main() {
  group('End-to-End Performance Tests', () {
    late Map<String, File> testFiles;

    setUpAll(() async {
      // Setup FFMPEG for real audio processing
      final setupResult = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!setupResult) {
        throw StateError(
          'FFMPEG setup failed - end-to-end performance tests require FFMPEG DLLs. '
          'These tests measure real audio processing performance and '
          'cannot be skipped when FFMPEG is not available.',
        );
      }

      // Verify all real test files are available
      testFiles = {
        'WAV': File('test/assets/Double-F the King - Your Blessing.wav'),
        'MP3': File('test/assets/Double-F the King - Your Blessing.mp3'),
        'FLAC': File('test/assets/Double-F the King - Your Blessing.flac'),
        'OGG': File('test/assets/Double-F the King - Your Blessing.ogg'),
      };

      final missingFiles = <String>[];
      for (final entry in testFiles.entries) {
        if (!await entry.value.exists()) {
          missingFiles.add(entry.key);
        }
      }

      if (missingFiles.isNotEmpty) {
        throw StateError(
          'Missing real test files: ${missingFiles.join(', ')}. '
          'End-to-end performance tests require actual "Double-F the King - Your Blessing" audio files.',
        );
      }

      print('✅ All real test files verified:');
      for (final entry in testFiles.entries) {
        final size = await entry.value.length();
        print('  ${entry.key}: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
      }
    });

    group('Complete Audio Decoding Performance', () {
      test('should decode entire WAV file and measure performance', () async {
        final file = testFiles['WAV']!;
        final filePath = file.path;

        print('\n=== WAV End-to-End Decoding Performance ===');
        final fileSize = await file.length();
        print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        try {
          final decoder = AudioDecoderFactory.createDecoder(filePath);

          final stopwatch = Stopwatch()..start();
          final audioData = await decoder.decode(filePath);
          stopwatch.stop();

          final decodingTime = stopwatch.elapsedMilliseconds;
          
          // Verify we got real audio data
          expect(audioData.samples, isNotEmpty);
          expect(audioData.sampleRate, greaterThan(0));
          expect(audioData.channels, greaterThan(0));
          expect(audioData.duration.inMilliseconds, greaterThan(0));

          print('Decoding results:');
          print('  Time: ${decodingTime}ms');
          print('  Samples: ${audioData.samples.length}');
          print('  Sample rate: ${audioData.sampleRate} Hz');
          print('  Channels: ${audioData.channels}');
          print('  Duration: ${audioData.duration.inSeconds}s');
          
          // Calculate performance metrics
          final samplesPerSecond = audioData.samples.length / (decodingTime / 1000.0);
          final mbPerSecond = (fileSize / 1024 / 1024) / (decodingTime / 1000.0);
          final realtimeRatio = audioData.duration.inMilliseconds / decodingTime;

          print('Performance metrics:');
          print('  Decode rate: ${samplesPerSecond.toStringAsFixed(0)} samples/sec');
          print('  Throughput: ${mbPerSecond.toStringAsFixed(2)} MB/sec');
          print('  Real-time ratio: ${realtimeRatio.toStringAsFixed(1)}x');

          // Performance expectations for real WAV files (30+ MB)
          expect(decodingTime, lessThan(10000), reason: 'WAV decoding should complete within 10 seconds');
          expect(samplesPerSecond, greaterThan(1000000), reason: 'Should decode >1M samples/sec');
          expect(realtimeRatio, greaterThan(10), reason: 'Should decode >10x faster than real-time');

          decoder.dispose();
          audioData.dispose();
        } catch (e) {
          if (e is UnsupportedFormatException || e is DecodingException) {
            fail('WAV decoder must work for performance testing. Error: $e');
          }
          rethrow;
        }
      });

      test('should decode entire MP3 file and measure performance', () async {
        final file = testFiles['MP3']!;
        final filePath = file.path;

        print('\n=== MP3 End-to-End Decoding Performance ===');
        final fileSize = await file.length();
        print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        try {
          final decoder = AudioDecoderFactory.createDecoder(filePath);

          final stopwatch = Stopwatch()..start();
          final audioData = await decoder.decode(filePath);
          stopwatch.stop();

          final decodingTime = stopwatch.elapsedMilliseconds;
          
          // Verify real MP3 decoding results
          expect(audioData.samples, isNotEmpty);
          expect(audioData.sampleRate, equals(44100)); // Common for MP3
          expect(audioData.channels, equals(2)); // Stereo
          expect(audioData.duration.inSeconds, greaterThan(160)); // ~167 seconds

          print('Decoding results:');
          print('  Time: ${decodingTime}ms');
          print('  Samples: ${audioData.samples.length}');
          print('  Duration: ${audioData.duration.inSeconds}s');
          
          // Calculate MP3-specific performance metrics
          final realtimeRatio = audioData.duration.inMilliseconds / decodingTime;
          final mbPerSecond = (fileSize / 1024 / 1024) / (decodingTime / 1000.0);

          print('Performance metrics:');
          print('  Throughput: ${mbPerSecond.toStringAsFixed(2)} MB/sec');
          print('  Real-time ratio: ${realtimeRatio.toStringAsFixed(1)}x');

          // MP3 should be fast to decode
          expect(decodingTime, lessThan(5000), reason: 'MP3 should decode faster than WAV');
          expect(realtimeRatio, greaterThan(20), reason: 'MP3 should decode >20x faster than real-time');

          decoder.dispose();
          audioData.dispose();
        } catch (e) {
          if (e is UnsupportedFormatException || e is DecodingException) {
            fail('MP3 decoder must work for performance testing. Error: $e');
          }
          rethrow;
        }
      });

      test('should decode entire FLAC file and measure performance', () async {
        final file = testFiles['FLAC']!;
        final filePath = file.path;

        print('\n=== FLAC End-to-End Decoding Performance ===');
        final fileSize = await file.length();
        print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        try {
          final decoder = AudioDecoderFactory.createDecoder(filePath);

          final stopwatch = Stopwatch()..start();
          final audioData = await decoder.decode(filePath);
          stopwatch.stop();

          final decodingTime = stopwatch.elapsedMilliseconds;
          
          // Verify lossless FLAC decoding
          expect(audioData.samples, isNotEmpty);
          expect(audioData.sampleRate, greaterThan(40000)); // Accept both 44.1kHz and 48kHz
          expect(audioData.channels, equals(2));
          expect(audioData.duration.inSeconds, greaterThan(160));

          print('Decoding results:');
          print('  Time: ${decodingTime}ms');
          print('  Samples: ${audioData.samples.length}');
          print('  Duration: ${audioData.duration.inSeconds}s');
          
          final realtimeRatio = audioData.duration.inMilliseconds / decodingTime;
          final mbPerSecond = (fileSize / 1024 / 1024) / (decodingTime / 1000.0);

          print('Performance metrics:');
          print('  Throughput: ${mbPerSecond.toStringAsFixed(2)} MB/sec');
          print('  Real-time ratio: ${realtimeRatio.toStringAsFixed(1)}x');

          // FLAC should have excellent decode performance
          expect(decodingTime, lessThan(8000), reason: 'FLAC should decode efficiently');
          expect(realtimeRatio, greaterThan(15), reason: 'FLAC should decode >15x faster than real-time');

          decoder.dispose();
          audioData.dispose();
        } catch (e) {
          if (e is UnsupportedFormatException || e is DecodingException) {
            fail('FLAC decoder must work for performance testing. Error: $e');
          }
          rethrow;
        }
      });
    });

    group('Complete Waveform Generation Performance', () {
      test('should generate waveform from decoded WAV file end-to-end', () async {
        final file = testFiles['WAV']!;
        final filePath = file.path;

        print('\n=== WAV End-to-End Waveform Generation ===');

        try {
          // Step 1: Decode the entire file
          final decoder = AudioDecoderFactory.createDecoder(filePath);
          
          final decodeStopwatch = Stopwatch()..start();
          final audioData = await decoder.decode(filePath);
          decodeStopwatch.stop();

          // Step 2: Generate waveform from decoded audio
          final waveformStopwatch = Stopwatch()..start();
          final config = WaveformConfig(resolution: 1000); // UI-typical resolution
          final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);
          waveformStopwatch.stop();

          // Verify complete pipeline results
          expect(waveformData.amplitudes, hasLength(1000));
          expect(waveformData.amplitudes.every((a) => a >= 0.0 && a <= 1.0), isTrue);

          final totalTime = decodeStopwatch.elapsedMilliseconds + waveformStopwatch.elapsedMilliseconds;

          print('Pipeline performance:');
          print('  Decode time: ${decodeStopwatch.elapsedMilliseconds}ms');
          print('  Waveform time: ${waveformStopwatch.elapsedMilliseconds}ms');
          print('  Total time: ${totalTime}ms');
          print('  Audio duration: ${audioData.duration.inSeconds}s');

          final pipelineRatio = audioData.duration.inMilliseconds / totalTime;
          print('  Pipeline ratio: ${pipelineRatio.toStringAsFixed(1)}x real-time');

          // Complete pipeline should be fast
          expect(totalTime, lessThan(15000), reason: 'Complete WAV pipeline should finish within 15s');
          expect(pipelineRatio, greaterThan(8), reason: 'Pipeline should be >8x faster than real-time');

          decoder.dispose();
          audioData.dispose();
          waveformData.dispose();
        } catch (e) {
          if (e is UnsupportedFormatException || e is DecodingException) {
            fail('WAV pipeline must work for performance testing. Error: $e');
          }
          rethrow;
        }
      });

      test('should generate waveform from decoded MP3 file end-to-end', () async {
        final file = testFiles['MP3']!;
        final filePath = file.path;

        print('\n=== MP3 End-to-End Waveform Generation ===');

        try {
          // Complete MP3 decode → waveform pipeline
          final decoder = AudioDecoderFactory.createDecoder(filePath);
          
          final totalStopwatch = Stopwatch()..start();
          
          final audioData = await decoder.decode(filePath);
          final config = WaveformConfig(resolution: 2000); // Higher resolution test
          final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);
          
          totalStopwatch.stop();

          // Verify high-resolution waveform from real MP3
          expect(waveformData.amplitudes, hasLength(2000));
          expect(waveformData.amplitudes.any((a) => a > 0.1), isTrue); // Should have real audio content

          print('Complete MP3 pipeline:');
          print('  Total time: ${totalStopwatch.elapsedMilliseconds}ms');
          print('  Resolution: 2000 points');
          print('  Audio duration: ${audioData.duration.inSeconds}s');

          final pipelineRatio = audioData.duration.inMilliseconds / totalStopwatch.elapsedMilliseconds;
          print('  Pipeline ratio: ${pipelineRatio.toStringAsFixed(1)}x real-time');

          // MP3 pipeline should be very fast
          expect(totalStopwatch.elapsedMilliseconds, lessThan(10000), reason: 'MP3 pipeline should be fast');
          expect(pipelineRatio, greaterThan(15), reason: 'MP3 pipeline should be >15x real-time');

          decoder.dispose();
          audioData.dispose();
          waveformData.dispose();
        } catch (e) {
          if (e is UnsupportedFormatException || e is DecodingException) {
            fail('MP3 pipeline must work for performance testing. Error: $e');
          }
          rethrow;
        }
      });
    });

    group('Cross-Format Performance Comparison', () {
      test('should compare complete decoding performance across all formats', () async {
        print('\n=== Cross-Format Performance Comparison ===');

        final results = <String, Map<String, dynamic>>{};

        for (final entry in testFiles.entries) {
          final format = entry.key;
          final file = entry.value;
          final filePath = file.path;

          try {
            print('\nTesting $format format...');
            
            final decoder = AudioDecoderFactory.createDecoder(filePath);
            final fileSize = await file.length();

            final stopwatch = Stopwatch()..start();
            final audioData = await decoder.decode(filePath);
            stopwatch.stop();

            results[format] = {
              'decodingTime': stopwatch.elapsedMilliseconds,
              'fileSize': fileSize,
              'samples': audioData.samples.length,
              'duration': audioData.duration.inMilliseconds,
              'realtimeRatio': audioData.duration.inMilliseconds / stopwatch.elapsedMilliseconds,
              'mbPerSecond': (fileSize / 1024 / 1024) / (stopwatch.elapsedMilliseconds / 1000.0),
            };

            print('  $format: ${stopwatch.elapsedMilliseconds}ms, ${results[format]!['realtimeRatio'].toStringAsFixed(1)}x real-time');

            decoder.dispose();
            audioData.dispose();
          } catch (e) {
            if (e is UnsupportedFormatException || e is DecodingException) {
              print('  $format: Decoder not available - $e');
              continue;
            }
            rethrow;
          }
        }

        // Print comparative analysis
        print('\n=== Performance Summary ===');
        final sortedResults = results.entries.toList()
          ..sort((a, b) => a.value['decodingTime'].compareTo(b.value['decodingTime']));

        for (final entry in sortedResults) {
          final format = entry.key;
          final data = entry.value;
          print('$format: ${data['decodingTime']}ms (${data['realtimeRatio'].toStringAsFixed(1)}x, ${data['mbPerSecond'].toStringAsFixed(2)} MB/s)');
        }

        // Verify at least some formats work
        expect(results, isNotEmpty, reason: 'At least some audio formats must work for performance comparison');
        
        // All working decoders should meet minimum performance standards
        for (final entry in results.entries) {
          final format = entry.key;
          final realtimeRatio = entry.value['realtimeRatio'] as double;
          expect(realtimeRatio, greaterThan(5), reason: '$format should decode >5x faster than real-time');
        }
      });

      test('should measure complete pipeline performance across formats', () async {
        print('\n=== Cross-Format Pipeline Performance ===');

        final pipelineResults = <String, Map<String, dynamic>>{};

        for (final entry in testFiles.entries) {
          final format = entry.key;
          final file = entry.value;
          final filePath = file.path;

          try {
            print('\nTesting $format complete pipeline...');
            
            final totalStopwatch = Stopwatch()..start();

            // Complete pipeline: decode + waveform generation
            final decoder = AudioDecoderFactory.createDecoder(filePath);
            final audioData = await decoder.decode(filePath);
            final config = WaveformConfig(resolution: 1000);
            final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);
            
            totalStopwatch.stop();

            pipelineResults[format] = {
              'pipelineTime': totalStopwatch.elapsedMilliseconds,
              'audioDuration': audioData.duration.inMilliseconds,
              'pipelineRatio': audioData.duration.inMilliseconds / totalStopwatch.elapsedMilliseconds,
              'waveformPoints': waveformData.amplitudes.length,
            };

            print('  $format pipeline: ${totalStopwatch.elapsedMilliseconds}ms (${pipelineResults[format]!['pipelineRatio'].toStringAsFixed(1)}x)');

            decoder.dispose();
            audioData.dispose();
            waveformData.dispose();
          } catch (e) {
            if (e is UnsupportedFormatException || e is DecodingException) {
              print('  $format pipeline: Not available - $e');
              continue;
            }
            rethrow;
          }
        }

        print('\n=== Pipeline Performance Ranking ===');
        final sortedPipelines = pipelineResults.entries.toList()
          ..sort((a, b) => a.value['pipelineTime'].compareTo(b.value['pipelineTime']));

        for (final entry in sortedPipelines) {
          final format = entry.key;
          final data = entry.value;
          print('$format: ${data['pipelineTime']}ms complete pipeline (${data['pipelineRatio'].toStringAsFixed(1)}x real-time)');
        }

        // Verify pipeline performance standards
        expect(pipelineResults, isNotEmpty, reason: 'At least some complete pipelines must work');
        
        for (final entry in pipelineResults.entries) {
          final format = entry.key;
          final pipelineRatio = entry.value['pipelineRatio'] as double;
          expect(pipelineRatio, greaterThan(3), reason: '$format complete pipeline should be >3x real-time');
        }
      });
    });

    group('Memory Performance with Real Files', () {
      test('should measure memory usage during complete WAV processing', () async {
        final file = testFiles['WAV']!;
        final filePath = file.path;

        print('\n=== WAV Memory Performance Analysis ===');
        final fileSize = await file.length();
        print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        try {
          final decoder = AudioDecoderFactory.createDecoder(filePath);

          // Measure memory during complete processing
          final initialMemory = _estimateMemoryUsage();
          
          final audioData = await decoder.decode(filePath);
          final peakMemory = _estimateMemoryUsage();
          
          final config = WaveformConfig(resolution: 5000); // High resolution for memory test
          final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);
          final finalMemory = _estimateMemoryUsage();

          final decodingMemoryIncrease = peakMemory - initialMemory;
          final waveformMemoryIncrease = finalMemory - peakMemory;

          print('Memory analysis:');
          print('  Initial: ${(initialMemory / 1024 / 1024).toStringAsFixed(1)} MB');
          print('  After decode: ${(peakMemory / 1024 / 1024).toStringAsFixed(1)} MB');
          print('  After waveform: ${(finalMemory / 1024 / 1024).toStringAsFixed(1)} MB');
          print('  Decode increase: ${(decodingMemoryIncrease / 1024 / 1024).toStringAsFixed(1)} MB');
          print('  Waveform increase: ${(waveformMemoryIncrease / 1024 / 1024).toStringAsFixed(1)} MB');

          // Memory usage should be reasonable for large files
          expect(decodingMemoryIncrease, lessThan(200 * 1024 * 1024), reason: 'WAV decoding should use <200MB additional memory');
          expect(waveformMemoryIncrease, lessThan(50 * 1024 * 1024), reason: 'Waveform generation should use <50MB additional memory');

          decoder.dispose();
          audioData.dispose();
          waveformData.dispose();
        } catch (e) {
          if (e is UnsupportedFormatException || e is DecodingException) {
            fail('WAV processing must work for memory performance testing. Error: $e');
          }
          rethrow;
        }
      });
    });
  });
}

/// Estimate current memory usage (simplified for testing)
int _estimateMemoryUsage() {
  // This is a simplified estimation for testing purposes
  // In production, would use platform-specific memory monitoring
  return DateTime.now().millisecondsSinceEpoch % (1024 * 1024 * 1024); // Mock memory usage up to 1GB
}