import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('Sonix Exceptions', () {
    group('SonixException', () {
      test('should be abstract and not instantiable directly', () {
        // SonixException is abstract, so we test through concrete implementations
        const exception = DecodingException('Test error message');

        expect(exception.message, equals('Test error message'));
        expect(exception.toString(), contains('Test error message'));
      });

      test('should support details parameter', () {
        const exception = DecodingException('Test error', 'Additional details');

        expect(exception.message, equals('Test error'));
        expect(exception.details, equals('Additional details'));
        expect(exception.toString(), contains('Test error'));
        expect(exception.toString(), contains('Additional details'));
      });
    });

    group('DecodingException', () {
      test('should create with message', () {
        const exception = DecodingException('Invalid header');

        expect(exception.message, equals('Invalid header'));
        expect(exception.toString(), contains('Invalid header'));
        expect(exception.toString(), contains('DecodingException'));
      });

      test('should create with message and details', () {
        const exception = DecodingException('Decoding failed', 'Bad format');

        expect(exception.message, equals('Decoding failed'));
        expect(exception.details, equals('Bad format'));
        expect(exception.toString(), contains('Decoding failed'));
        expect(exception.toString(), contains('Bad format'));
      });
    });

    group('UnsupportedFormatException', () {
      test('should create with format', () {
        const exception = UnsupportedFormatException('xyz');

        expect(exception.format, equals('xyz'));
        expect(exception.message, contains('xyz'));
        expect(exception.toString(), contains('Unsupported audio format'));
      });

      test('should create with format and details', () {
        const exception = UnsupportedFormatException('xyz', 'Format not recognized');

        expect(exception.format, equals('xyz'));
        expect(exception.details, equals('Format not recognized'));
        expect(exception.toString(), contains('xyz'));
        expect(exception.toString(), contains('Format not recognized'));
      });
    });

    group('MemoryException', () {
      test('should create with message', () {
        const exception = MemoryException('Out of memory');

        expect(exception.message, equals('Out of memory'));
        expect(exception.toString(), contains('MemoryException'));
        expect(exception.toString(), contains('Out of memory'));
      });

      test('should create with message and details', () {
        const exception = MemoryException('Memory allocation failed', 'Requested 100MB, available 50MB');

        expect(exception.message, equals('Memory allocation failed'));
        expect(exception.details, equals('Requested 100MB, available 50MB'));
        expect(exception.toString(), contains('Memory allocation failed'));
        expect(exception.toString(), contains('Requested 100MB, available 50MB'));
      });
    });

    group('FileAccessException', () {
      test('should create with file path and message', () {
        const exception = FileAccessException('test.mp3', 'File not found');

        expect(exception.filePath, equals('test.mp3'));
        expect(exception.message, equals('File not found'));
        expect(exception.toString(), contains('test.mp3'));
        expect(exception.toString(), contains('File not found'));
      });

      test('should create with file path, message, and details', () {
        const exception = FileAccessException('test.wav', 'Access denied', 'Permission error');

        expect(exception.filePath, equals('test.wav'));
        expect(exception.message, equals('Access denied'));
        expect(exception.details, equals('Permission error'));
      });
    });

    group('FFIException', () {
      test('should create with message', () {
        const exception = FFIException('Native library error');

        expect(exception.message, equals('Native library error'));
        expect(exception.toString(), contains('FFIException'));
      });

      test('should create with message and details', () {
        const exception = FFIException('Library not loaded', 'libsonix.so not found');

        expect(exception.message, equals('Library not loaded'));
        expect(exception.details, equals('libsonix.so not found'));
      });
    });

    group('InvalidWaveformDataException', () {
      test('should create with message', () {
        const exception = InvalidWaveformDataException('Invalid amplitude data');

        expect(exception.message, equals('Invalid amplitude data'));
        expect(exception.toString(), contains('InvalidWaveformDataException'));
      });
    });

    group('ConfigurationException', () {
      test('should create with message', () {
        const exception = ConfigurationException('Invalid configuration');

        expect(exception.message, equals('Invalid configuration'));
        expect(exception.toString(), contains('ConfigurationException'));
      });
    });

    group('StreamingException', () {
      test('should create with message', () {
        const exception = StreamingException('Stream interrupted');

        expect(exception.message, equals('Stream interrupted'));
        expect(exception.toString(), contains('StreamingException'));
      });
    });

    group('FileNotFoundException', () {
      test('should create with file path', () {
        const exception = FileNotFoundException('missing.mp3');

        expect(exception.filePath, equals('missing.mp3'));
        expect(exception.message, contains('missing.mp3'));
        expect(exception.toString(), contains('FileNotFoundException'));
      });
    });

    group('CorruptedFileException', () {
      test('should create with file path', () {
        const exception = CorruptedFileException('corrupted.wav');

        expect(exception.filePath, equals('corrupted.wav'));
        expect(exception.message, contains('corrupted.wav'));
        expect(exception.toString(), contains('CorruptedFileException'));
      });
    });

    group('IsolateProcessingException', () {
      test('should create with isolate ID and error', () {
        const exception = IsolateProcessingException('isolate-1', 'Processing failed');

        expect(exception.isolateId, equals('isolate-1'));
        expect(exception.originalError, equals('Processing failed'));
        expect(exception.toString(), contains('isolate-1'));
        expect(exception.toString(), contains('Processing failed'));
      });

      test('should create with additional details', () {
        const exception = IsolateProcessingException(
          'isolate-2',
          'Decoding error',
          originalErrorType: 'DecodingException',
          requestId: 'req-123',
          details: 'Additional context',
        );

        expect(exception.isolateId, equals('isolate-2'));
        expect(exception.originalError, equals('Decoding error'));
        expect(exception.originalErrorType, equals('DecodingException'));
        expect(exception.requestId, equals('req-123'));
        expect(exception.details, equals('Additional context'));
      });

      test('should convert to and from error data', () {
        const original = IsolateProcessingException('isolate-3', 'Test error', originalErrorType: 'TestException', requestId: 'req-456');

        final errorData = original.toErrorData();
        final restored = IsolateProcessingException.fromErrorData('isolate-3', errorData);

        expect(restored.isolateId, equals(original.isolateId));
        expect(restored.originalError, equals(original.originalError));
        expect(restored.originalErrorType, equals(original.originalErrorType));
        expect(restored.requestId, equals(original.requestId));
      });
    });

    group('IsolateCommunicationException', () {
      test('should create with message type and direction', () {
        const exception = IsolateCommunicationException('WaveformRequest', 'send');

        expect(exception.messageType, equals('WaveformRequest'));
        expect(exception.communicationDirection, equals('send'));
        expect(exception.toString(), contains('WaveformRequest'));
        expect(exception.toString(), contains('send'));
      });

      test('should create send failure', () {
        final exception = IsolateCommunicationException.sendFailure('TestMessage', isolateId: 'isolate-1');

        expect(exception.messageType, equals('TestMessage'));
        expect(exception.communicationDirection, equals('send'));
        expect(exception.isolateId, equals('isolate-1'));
      });

      test('should create receive failure', () {
        final exception = IsolateCommunicationException.receiveFailure('ResponseMessage');

        expect(exception.messageType, equals('ResponseMessage'));
        expect(exception.communicationDirection, equals('receive'));
      });

      test('should create parse failure', () {
        final exception = IsolateCommunicationException.parseFailure('InvalidMessage');

        expect(exception.messageType, equals('InvalidMessage'));
        expect(exception.communicationDirection, equals('parse'));
      });
    });

    group('TaskCancelledException', () {
      test('should create with message', () {
        final exception = TaskCancelledException('Task was cancelled');

        expect(exception.message, equals('Task was cancelled'));
        expect(exception.toString(), contains('TaskCancelledException'));
      });
    });

    group('Exception Hierarchy', () {
      test('should maintain proper inheritance', () {
        const decodingException = DecodingException('Error');
        const formatException = UnsupportedFormatException('xyz');
        const memoryException = MemoryException('Error');
        const fileException = FileAccessException('file.mp3', 'Error');
        const ffiException = FFIException('Error');

        expect(decodingException, isA<SonixException>());
        expect(formatException, isA<SonixException>());
        expect(memoryException, isA<SonixException>());
        expect(fileException, isA<SonixException>());
        expect(ffiException, isA<SonixException>());
      });

      test('should support exception chaining through details', () {
        const rootCause = 'Invalid format';
        const decodingException = DecodingException('Decoding failed', rootCause);
        final memoryException = MemoryException('Memory error', 'Caused by: ${decodingException.message}');

        expect(decodingException.details, equals(rootCause));
        expect(memoryException.details, contains('Decoding failed'));

        final fullMessage = memoryException.toString();
        expect(fullMessage, contains('Memory error'));
        expect(fullMessage, contains('Decoding failed'));
      });
    });
  });
}
