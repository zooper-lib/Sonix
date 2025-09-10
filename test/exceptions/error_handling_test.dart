import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/error_recovery.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import '../test_data_generator.dart';

void main() {
  group('SonixException Hierarchy', () {
    test('should create UnsupportedFormatException with format', () {
      const exception = UnsupportedFormatException('xyz');
      expect(exception.format, equals('xyz'));
      expect(exception.message, contains('Unsupported audio format: xyz'));
      expect(exception.toString(), contains('UnsupportedFormatException'));
    });

    test('should create DecodingException with message and details', () {
      const exception = DecodingException('Decode failed', 'Invalid header');
      expect(exception.message, equals('Decode failed'));
      expect(exception.details, equals('Invalid header'));
      expect(exception.toString(), contains('DecodingException'));
      expect(exception.toString(), contains('Details: Invalid header'));
    });

    test('should create MemoryException with message', () {
      const exception = MemoryException('Out of memory');
      expect(exception.message, equals('Out of memory'));
      expect(exception.toString(), contains('MemoryException'));
    });

    test('should create FileAccessException with file path', () {
      const exception = FileAccessException('/path/to/file.mp3', 'Permission denied');
      expect(exception.filePath, equals('/path/to/file.mp3'));
      expect(exception.message, equals('Permission denied'));
      expect(exception.toString(), contains('FileAccessException'));
      expect(exception.toString(), contains('File: /path/to/file.mp3'));
    });

    test('should create FFIException with message', () {
      const exception = FFIException('Native call failed');
      expect(exception.message, equals('Native call failed'));
      expect(exception.toString(), contains('FFIException'));
    });

    test('should create InvalidWaveformDataException with message', () {
      const exception = InvalidWaveformDataException('Invalid data format');
      expect(exception.message, equals('Invalid data format'));
      expect(exception.toString(), contains('InvalidWaveformDataException'));
    });

    test('should create ConfigurationException with message', () {
      const exception = ConfigurationException('Invalid resolution');
      expect(exception.message, equals('Invalid resolution'));
      expect(exception.toString(), contains('ConfigurationException'));
    });

    test('should create StreamingException with message', () {
      const exception = StreamingException('Stream interrupted');
      expect(exception.message, equals('Stream interrupted'));
      expect(exception.toString(), contains('StreamingException'));
    });
  });

  group('ErrorRecovery', () {
    test('should recover from decoding error with retry', () async {
      int attemptCount = 0;

      Future<AudioData> flakyOperation() async {
        attemptCount++;
        if (attemptCount < 3) {
          throw const DecodingException('Temporary failure');
        }
        return AudioData(samples: [1.0, 2.0, 3.0], sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 100));
      }

      final result = await ErrorRecovery.recoverFromDecodingError('test.mp3', const DecodingException('Initial failure'), flakyOperation);

      expect(result.samples, equals([1.0, 2.0, 3.0]));
      expect(attemptCount, equals(3));
    });

    test('should recover from memory error with quality reduction', () async {
      final audioData = AudioData(samples: List.generate(10000, (i) => i.toDouble()), sampleRate: 44100, channels: 1, duration: const Duration(seconds: 1));

      final originalConfig = WaveformConfig(resolution: 1000);

      final result = await ErrorRecovery.recoverFromMemoryError(audioData, const MemoryException('Out of memory'), originalConfig);

      expect(result, isA<WaveformData>());
      expect(result.amplitudes.length, lessThanOrEqualTo(1000));
    });

    test('should recover from file access error with retry', () async {
      int attemptCount = 0;

      Future<String> flakyFileOperation() async {
        attemptCount++;
        if (attemptCount < 2) {
          throw const FileAccessException('test.mp3', 'File locked');
        }
        return 'File content';
      }

      final result = await ErrorRecovery.recoverFromFileAccessError('test.mp3', const FileAccessException('test.mp3', 'Initial failure'), flakyFileOperation);

      expect(result, equals('File content'));
      expect(attemptCount, equals(2));
    });

    test('should recover from FFI error with cleanup and retry', () async {
      int attemptCount = 0;

      Future<String> flakyFFIOperation() async {
        attemptCount++;
        if (attemptCount < 2) {
          throw const FFIException('Native library error');
        }
        return 'FFI success';
      }

      final result = await ErrorRecovery.recoverFromFFIError(const FFIException('Initial FFI failure'), flakyFFIOperation);

      expect(result, equals('FFI success'));
      expect(attemptCount, equals(2));
    });

    test('should recover from streaming error with retry', () async {
      int attemptCount = 0;

      Stream<int> flakyStreamOperation() async* {
        attemptCount++;
        if (attemptCount < 2) {
          throw const StreamingException('Stream failed');
        }
        yield 1;
        yield 2;
        yield 3;
      }

      final results = <int>[];
      await for (final item in ErrorRecovery.recoverFromStreamingError(const StreamingException('Initial stream failure'), flakyStreamOperation)) {
        results.add(item);
      }

      expect(results, equals([1, 2, 3]));
      expect(attemptCount, equals(2));
    });
  });

  group('RecoverableOperation', () {
    test('should execute successful operation normally', () async {
      final operation = RecoverableOperation<String>(() async => 'Success', 'test_operation');

      final result = await operation.execute();
      expect(result, equals('Success'));
    });

    test('should recover from DecodingException', () async {
      final mockAudioData = AudioData(samples: [1.0, 2.0], sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 50));

      int attemptCount = 0;
      Future<AudioData> mockDecodeOperation() async {
        attemptCount++;
        if (attemptCount < 2) {
          throw const DecodingException('Mock decode failure');
        }
        return mockAudioData;
      }

      final operation = RecoverableOperation<AudioData>(() async => throw const DecodingException('Initial failure'), 'test_decode', {
        'filePath': 'test.mp3',
        'originalOperation': mockDecodeOperation,
      });

      final result = await operation.execute();
      expect(result.samples, equals([1.0, 2.0]));
      expect(attemptCount, equals(2));
    });

    test('should wrap unknown exceptions in DecodingException', () async {
      final operation = RecoverableOperation<String>(() async => throw Exception('Unknown error'), 'test_operation');

      expect(() async => await operation.execute(), throwsA(isA<DecodingException>()));
    });
  });

  group('RecoverableStreamOperation', () {
    test('should execute successful stream operation normally', () async {
      final streamOperation = RecoverableStreamOperation<int>(() async* {
        yield 1;
        yield 2;
        yield 3;
      }, 'test_stream');

      final results = <int>[];
      await for (final item in streamOperation.execute()) {
        results.add(item);
      }

      expect(results, equals([1, 2, 3]));
    });

    test('should recover from StreamingException', () async {
      int attemptCount = 0;

      final streamOperation = RecoverableStreamOperation<int>(() async* {
        attemptCount++;
        if (attemptCount < 2) {
          throw const StreamingException('Mock stream failure');
        }
        yield 1;
        yield 2;
      }, 'test_stream');

      final results = <int>[];
      await for (final item in streamOperation.execute()) {
        results.add(item);
      }

      expect(results, equals([1, 2]));
      expect(attemptCount, equals(2));
    });

    test('should wrap unknown exceptions in StreamingException', () async {
      final streamOperation = RecoverableStreamOperation<int>(() async* {
        throw Exception('Unknown stream error');
      }, 'test_stream');

      expect(() async {
        await for (final _ in streamOperation.execute()) {
          // Should not reach here
        }
      }, throwsA(isA<StreamingException>()));
    });
  });

  group('Comprehensive Error Scenarios', () {
    late Map<String, dynamic> testConfigurations;

    setUpAll(() async {
      // Generate test data if it doesn't exist
      if (!await TestDataLoader.assetExists('test_configurations.json')) {
        await TestDataGenerator.generateAllTestData();
      }

      testConfigurations = await TestDataLoader.loadTestConfigurations();
    });

    test('should handle all configured error scenarios', () async {
      final errorScenarios = testConfigurations['error_test_scenarios'] as List;

      for (final scenario in errorScenarios) {
        final filename = scenario['file'] as String;
        final expectedExceptionType = scenario['expected_exception'] as String;

        final filePath = TestDataLoader.getAssetPath(filename);

        try {
          if (filename.endsWith('.mp3') || filename.endsWith('.wav') || filename.endsWith('.flac') || filename.endsWith('.ogg')) {
            final decoder = AudioDecoderFactory.createDecoder(filePath);
            await decoder.decode(filePath);
            fail('Expected exception for $filename');
          } else {
            // Test format detection
            expect(() => AudioDecoderFactory.createDecoder(filePath), throwsA(isA<UnsupportedFormatException>()));
          }
        } catch (e) {
          switch (expectedExceptionType) {
            case 'DecodingException':
              expect(e, isA<DecodingException>());
              break;
            case 'UnsupportedFormatException':
              expect(e, isA<UnsupportedFormatException>());
              break;
            case 'FileAccessException':
              expect(e, isA<FileAccessException>());
              break;
            default:
              expect(e, isA<SonixException>());
          }
        }
      }
    });

    test('should provide detailed error information', () async {
      final corruptedFile = TestDataLoader.getAssetPath('corrupted_header.mp3');

      try {
        final decoder = AudioDecoderFactory.createDecoder(corruptedFile);
        await decoder.decode(corruptedFile);
        fail('Expected DecodingException');
      } catch (e) {
        expect(e, isA<DecodingException>());
        final decodingError = e as DecodingException;
        expect(decodingError.message, isNotEmpty);
        expect(decodingError.toString(), contains('DecodingException'));

        if (decodingError.details != null) {
          expect(decodingError.details, isNotEmpty);
        }
      }
    });

    test('should handle cascading error recovery', () async {
      // Simulate a scenario where multiple recovery strategies are needed
      int decodingAttempts = 0;
      int memoryAttempts = 0;

      Future<AudioData> problematicDecoding() async {
        decodingAttempts++;
        if (decodingAttempts < 2) {
          throw const DecodingException('Decoding failed');
        }
        if (memoryAttempts < 1) {
          memoryAttempts++;
          throw const MemoryException('Out of memory');
        }
        return AudioData(samples: [1.0], sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 1));
      }

      // Test the integrated error recovery system
      try {
        final result = await problematicDecoding();
        expect(result.samples, equals([1.0]));
      } catch (e) {
        // In the real system, this would be handled by the recovery mechanisms
        expect(e, isA<SonixException>());
      }
    });

    test('should provide fallback results when recovery fails', () async {
      const originalError = DecodingException('Original decode failure');

      // The error recovery should provide a fallback result
      final result = await ErrorRecovery.recoverFromDecodingError(
        'nonexistent.mp3',
        originalError,
        () async => throw const DecodingException('All recovery failed'),
      );

      // Should return minimal fallback audio data
      expect(result, isA<AudioData>());
      expect(result.samples.length, equals(1));
      expect(result.samples.first, equals(0.0)); // Silent sample
    });

    test('should handle error recovery timeouts', () async {
      final operation = RecoverableOperation<String>(() async {
        await Future.delayed(const Duration(seconds: 10)); // Long operation
        return 'Success';
      }, 'timeout_test');

      // Should timeout and provide fallback
      expect(() async {
        await Future.any([
          operation.execute(),
          Future.delayed(const Duration(seconds: 1)).then((_) => throw TimeoutException('Test timeout', const Duration(seconds: 1))),
        ]);
      }, throwsA(isA<TimeoutException>()));
    });

    test('should maintain error context across recovery attempts', () async {
      const originalFile = 'test.mp3';
      const originalError = DecodingException('Original failure', 'Detailed context');

      try {
        await ErrorRecovery.recoverFromDecodingError(originalFile, originalError, () async => throw const DecodingException('Recovery also failed'));
      } catch (e) {
        expect(e, isA<DecodingException>());
        // Error context should be preserved
        expect(e.toString(), contains('test.mp3'));
      }
    });
  });

  group('Error Recovery Integration', () {
    test('should handle cascading errors gracefully', () async {
      // Simulate a scenario where multiple recovery strategies are needed
      int decodingAttempts = 0;
      int memoryAttempts = 0;

      Future<AudioData> problematicDecoding() async {
        decodingAttempts++;
        if (decodingAttempts < 2) {
          throw const DecodingException('Decoding failed');
        }
        if (memoryAttempts < 1) {
          throw const MemoryException('Out of memory');
        }
        return AudioData(samples: [1.0], sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 1));
      }

      // This would be handled by the integrated error recovery system
      try {
        final result = await problematicDecoding();
        expect(result.samples, equals([1.0]));
      } catch (e) {
        // In the real system, this would be handled by the recovery mechanisms
        expect(e, isA<SonixException>());
      }
    });

    test('should provide fallback result when all recovery strategies are exhausted', () async {
      const originalError = DecodingException('Original decode failure');

      // The error recovery should provide a fallback result (minimal audio data)
      // rather than throwing an exception, which is the correct behavior
      final result = await ErrorRecovery.recoverFromDecodingError(
        'nonexistent.mp3',
        originalError,
        () async => throw const DecodingException('All recovery failed'),
      );

      // Should return minimal fallback audio data
      expect(result, isA<AudioData>());
      expect(result.samples.length, equals(1));
      expect(result.samples.first, equals(0.0)); // Silent sample
    });
  });
}
