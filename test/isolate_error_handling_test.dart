/// Unit tests for isolate error handling across boundaries
///
/// Tests the comprehensive error handling system including serialization,
/// deserialization, recovery mechanisms, and isolate crash detection.
library;

import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/isolate/error_serializer.dart';
import 'package:sonix/src/isolate/isolate_health_monitor.dart';
import 'package:sonix/src/isolate/isolate_messages.dart';

void main() {
  group('IsolateProcessingException', () {
    test('should create exception with all fields', () {
      const exception = IsolateProcessingException(
        'isolate_123',
        'Processing failed',
        originalErrorType: 'DecodingException',
        isolateStackTrace: 'Stack trace here',
        requestId: 'request_456',
        details: 'Additional details',
      );

      expect(exception.isolateId, equals('isolate_123'));
      expect(exception.originalError, equals('Processing failed'));
      expect(exception.originalErrorType, equals('DecodingException'));
      expect(exception.isolateStackTrace, equals('Stack trace here'));
      expect(exception.requestId, equals('request_456'));
      expect(exception.details, equals('Additional details'));
      expect(exception.message, contains('Processing failed in isolate isolate_123'));
    });

    test('should create from error data', () {
      final errorData = {'message': 'Test error', 'type': 'TestException', 'stackTrace': 'Test stack trace', 'requestId': 'req_123', 'details': 'Test details'};

      final exception = IsolateProcessingException.fromErrorData('isolate_456', errorData);

      expect(exception.isolateId, equals('isolate_456'));
      expect(exception.originalError, equals('Test error'));
      expect(exception.originalErrorType, equals('TestException'));
      expect(exception.isolateStackTrace, equals('Test stack trace'));
      expect(exception.requestId, equals('req_123'));
      expect(exception.details, equals('Test details'));
    });

    test('should convert to error data', () {
      const exception = IsolateProcessingException('isolate_789', 'Test error message', originalErrorType: 'CustomException', requestId: 'req_789');

      final errorData = exception.toErrorData();

      expect(errorData['message'], equals('Test error message'));
      expect(errorData['type'], equals('CustomException'));
      expect(errorData['requestId'], equals('req_789'));
      expect(errorData['isolateId'], equals('isolate_789'));
    });

    test('should format toString correctly', () {
      const exception = IsolateProcessingException(
        'isolate_test',
        'Error occurred',
        originalErrorType: 'TestError',
        requestId: 'req_test',
        details: 'Test details',
        isolateStackTrace: 'Test stack',
      );

      final string = exception.toString();

      expect(string, contains('IsolateProcessingException'));
      expect(string, contains('isolate_test'));
      expect(string, contains('Error occurred'));
      expect(string, contains('Error Type: TestError'));
      expect(string, contains('Request ID: req_test'));
      expect(string, contains('Details: Test details'));
      expect(string, contains('Isolate Stack Trace:\nTest stack'));
    });
  });

  group('IsolateCommunicationException', () {
    test('should create send failure exception', () {
      final exception = IsolateCommunicationException.sendFailure(
        'ProcessingRequest',
        isolateId: 'isolate_123',
        cause: 'Network error',
        details: 'Failed to send message',
      );

      expect(exception.messageType, equals('ProcessingRequest'));
      expect(exception.communicationDirection, equals('send'));
      expect(exception.isolateId, equals('isolate_123'));
      expect(exception.cause, equals('Network error'));
      expect(exception.details, equals('Failed to send message'));
    });

    test('should create receive failure exception', () {
      final exception = IsolateCommunicationException.receiveFailure('ProcessingResponse', isolateId: 'isolate_456');

      expect(exception.messageType, equals('ProcessingResponse'));
      expect(exception.communicationDirection, equals('receive'));
      expect(exception.isolateId, equals('isolate_456'));
    });

    test('should create parse failure exception', () {
      final exception = IsolateCommunicationException.parseFailure('ProgressUpdate', cause: 'Invalid JSON');

      expect(exception.messageType, equals('ProgressUpdate'));
      expect(exception.communicationDirection, equals('parse'));
      expect(exception.cause, equals('Invalid JSON'));
    });

    test('should format toString correctly', () {
      final exception = IsolateCommunicationException.sendFailure('TestMessage', isolateId: 'test_isolate', cause: 'Test cause', details: 'Test details');

      final string = exception.toString();

      expect(string, contains('IsolateCommunicationException'));
      expect(string, contains('Failed to send message of type TestMessage'));
      expect(string, contains('with isolate test_isolate'));
      expect(string, contains('Cause: Test cause'));
      expect(string, contains('Details: Test details'));
    });
  });

  group('ErrorSerializer', () {
    test('should serialize and deserialize SonixException', () {
      const originalError = DecodingException('Test decoding error', 'Test details');
      final stackTrace = StackTrace.current;

      final serialized = ErrorSerializer.serializeError(originalError, stackTrace);
      final deserialized = ErrorSerializer.deserializeError(serialized);

      expect(deserialized, isA<DecodingException>());
      expect(deserialized.message, equals('Test decoding error'));
      expect(deserialized.details, equals('Test details'));
    });

    test('should serialize and deserialize IsolateProcessingException', () {
      const originalError = IsolateProcessingException('isolate_test', 'Processing failed', originalErrorType: 'TestError', requestId: 'req_123');

      final serialized = ErrorSerializer.serializeError(originalError);
      final deserialized = ErrorSerializer.deserializeError(serialized);

      expect(deserialized, isA<IsolateProcessingException>());
      final isolateError = deserialized as IsolateProcessingException;
      expect(isolateError.isolateId, equals('isolate_test'));
      expect(isolateError.originalError, equals('Processing failed'));
      expect(isolateError.originalErrorType, equals('TestError'));
      expect(isolateError.requestId, equals('req_123'));
    });

    test('should serialize and deserialize IsolateCommunicationException', () {
      final originalError = IsolateCommunicationException.sendFailure('TestMessage', isolateId: 'test_isolate', cause: 'Test cause');

      final serialized = ErrorSerializer.serializeError(originalError);
      final deserialized = ErrorSerializer.deserializeError(serialized);

      expect(deserialized, isA<IsolateCommunicationException>());
      final commError = deserialized as IsolateCommunicationException;
      expect(commError.messageType, equals('TestMessage'));
      expect(commError.communicationDirection, equals('send'));
      expect(commError.isolateId, equals('test_isolate'));
    });

    test('should handle non-Sonix exceptions', () {
      final originalError = ArgumentError('Invalid argument');

      final serialized = ErrorSerializer.serializeError(originalError);
      final deserialized = ErrorSerializer.deserializeError(serialized);

      expect(deserialized, isA<SonixError>());
      expect(deserialized.message, contains('Invalid argument'));
    });

    test('should create error message for isolate communication', () {
      final error = DecodingException('Test error');
      final stackTrace = StackTrace.current;

      final errorMessage = ErrorSerializer.createErrorMessage(messageId: 'msg_123', error: error, stackTrace: stackTrace, requestId: 'req_456');

      expect(errorMessage['messageType'], equals('ErrorMessage'));
      expect(errorMessage['id'], equals('msg_123'));
      expect(errorMessage['requestId'], equals('req_456'));
      expect(errorMessage['errorMessage'], equals('Test error'));
      expect(errorMessage['errorType'], equals('DecodingException'));
      expect(errorMessage['errorData'], isA<Map<String, dynamic>>());
    });

    test('should extract error from error message', () {
      final errorMessage = {
        'errorData': {'type': 'DecodingException', 'message': 'Test decoding error', 'details': 'Test details'},
      };

      final extracted = ErrorSerializer.extractError(errorMessage);

      expect(extracted, isA<DecodingException>());
      expect(extracted.message, equals('Test decoding error'));
      expect(extracted.details, equals('Test details'));
    });

    test('should identify recoverable errors', () {
      expect(ErrorSerializer.isRecoverableError(IsolateCommunicationException.sendFailure('test')), isTrue);
      expect(ErrorSerializer.isRecoverableError(const MemoryException('test')), isTrue);
      expect(ErrorSerializer.isRecoverableError(const DecodingException('test')), isTrue);
      expect(ErrorSerializer.isRecoverableError(const FileNotFoundException('test.mp3')), isFalse);
      expect(ErrorSerializer.isRecoverableError(const CorruptedFileException('test.mp3')), isFalse);
      expect(ErrorSerializer.isRecoverableError(const UnsupportedFormatException('xyz')), isFalse);
    });

    test('should calculate retry delays', () {
      final commError = IsolateCommunicationException.sendFailure('test');
      final memoryError = const MemoryException('test');
      final decodingError = const DecodingException('test');

      final commDelay = ErrorSerializer.getRetryDelay(commError, 1);
      final memoryDelay = ErrorSerializer.getRetryDelay(memoryError, 1);
      final decodingDelay = ErrorSerializer.getRetryDelay(decodingError, 1);

      expect(commDelay.inMilliseconds, lessThan(memoryDelay.inMilliseconds));
      expect(decodingDelay.inMilliseconds, greaterThan(0));
    });
  });

  group('IsolateHealthMonitor', () {
    late IsolateHealthMonitor monitor;

    setUp(() {
      monitor = IsolateHealthMonitor(healthCheckInterval: const Duration(milliseconds: 100), responseTimeout: const Duration(milliseconds: 50));
    });

    tearDown(() {
      monitor.dispose();
    });

    test('should create initial health state', () {
      final health = IsolateHealth.initial();

      expect(health.status, equals(IsolateHealthStatus.healthy));
      expect(health.failedHealthChecks, equals(0));
      expect(health.completedTasks, equals(0));
      expect(health.failedTasks, equals(0));
    });

    test('should mark health as healthy after success', () {
      final initialHealth = IsolateHealth.initial();
      final updatedHealth = initialHealth.markHealthy();

      expect(updatedHealth.status, equals(IsolateHealthStatus.healthy));
      expect(updatedHealth.failedHealthChecks, equals(0));
      expect(updatedHealth.completedTasks, equals(1));
    });

    test('should mark health as unhealthy after failure', () {
      final initialHealth = IsolateHealth.initial();
      final error = const DecodingException('Test error');
      final updatedHealth = initialHealth.markUnhealthy(error);

      expect(updatedHealth.status, equals(IsolateHealthStatus.unresponsive));
      expect(updatedHealth.failedHealthChecks, equals(1));
      expect(updatedHealth.failedTasks, equals(1));
      expect(updatedHealth.lastError, equals(error));
    });

    test('should mark as crashed after multiple failures', () {
      var health = IsolateHealth.initial();
      final error = const DecodingException('Test error');

      // First two failures should be unresponsive
      health = health.markUnhealthy(error);
      expect(health.status, equals(IsolateHealthStatus.unresponsive));

      health = health.markUnhealthy(error);
      expect(health.status, equals(IsolateHealthStatus.unresponsive));

      // Third failure should be crashed
      health = health.markUnhealthy(error);
      expect(health.status, equals(IsolateHealthStatus.crashed));
      expect(health.needsRestart, isTrue);
    });

    test('should track isolate statistics', () {
      final receivePort = ReceivePort();
      final sendPort = receivePort.sendPort;

      monitor.startMonitoring('test_isolate', sendPort);

      final health = monitor.getHealth('test_isolate');
      expect(health, isNotNull);
      expect(health!.status, equals(IsolateHealthStatus.healthy));

      final stats = monitor.getStatistics();
      expect(stats['totalIsolates'], equals(1));
      expect(stats['healthyIsolates'], equals(1));

      receivePort.close();
    });

    test('should handle success and failure reports', () {
      final receivePort = ReceivePort();
      final sendPort = receivePort.sendPort;

      monitor.startMonitoring('test_isolate', sendPort);

      monitor.reportSuccess('test_isolate');
      var health = monitor.getHealth('test_isolate');
      expect(health!.completedTasks, equals(1));

      monitor.reportFailure('test_isolate', const DecodingException('Test'));
      health = monitor.getHealth('test_isolate');
      expect(health!.failedTasks, equals(1));
      expect(health.status, equals(IsolateHealthStatus.unresponsive));

      receivePort.close();
    });

    test('should call callbacks on health changes', () {
      final receivePort = ReceivePort();
      final sendPort = receivePort.sendPort;

      String? callbackIsolateId;
      IsolateHealth? callbackHealth;

      monitor.onHealthChanged((isolateId, health) {
        callbackIsolateId = isolateId;
        callbackHealth = health;
      });

      monitor.startMonitoring('test_isolate', sendPort);
      monitor.reportFailure('test_isolate', const DecodingException('Test'));

      expect(callbackIsolateId, equals('test_isolate'));
      expect(callbackHealth?.status, equals(IsolateHealthStatus.unresponsive));

      receivePort.close();
    });

    test('should call crash callbacks when isolate crashes', () {
      final receivePort = ReceivePort();
      final sendPort = receivePort.sendPort;

      String? crashedIsolateId;
      Object? crashError;

      monitor.onIsolateCrashed((isolateId, error) {
        crashedIsolateId = isolateId;
        crashError = error;
      });

      monitor.startMonitoring('test_isolate', sendPort);

      // Report multiple failures to trigger crash
      final error = const DecodingException('Test');
      monitor.reportFailure('test_isolate', error);
      monitor.reportFailure('test_isolate', error);
      monitor.reportFailure('test_isolate', error);

      expect(crashedIsolateId, equals('test_isolate'));
      expect(crashError, equals(error));

      receivePort.close();
    });
  });

  group('Integration Tests', () {
    test('should handle complete error flow from serialization to recovery', () async {
      // Create an error in an isolate context
      const originalError = DecodingException('File corrupted', 'Invalid header');
      final stackTrace = StackTrace.current;

      // Serialize the error for cross-isolate communication
      final serializedError = ErrorSerializer.serializeError(originalError, stackTrace);

      // Create an error message
      final errorMessage = ErrorSerializer.createErrorMessage(messageId: 'error_123', error: originalError, stackTrace: stackTrace, requestId: 'req_456');

      // Simulate message transmission
      final messageJson = errorMessage;

      // Deserialize on the receiving side
      final receivedMessage = ErrorMessage.fromJson(messageJson);
      expect(receivedMessage.errorType, equals('DecodingException'));
      expect(receivedMessage.errorMessage, equals('File corrupted'));
      expect(receivedMessage.requestId, equals('req_456'));

      // Extract the original error
      final extractedError = ErrorSerializer.extractError(messageJson);
      expect(extractedError, isA<DecodingException>());
      expect(extractedError.message, equals('File corrupted'));
      expect(extractedError.details, equals('Invalid header'));

      // Check if error is recoverable
      final isRecoverable = ErrorSerializer.isRecoverableError(extractedError);
      expect(isRecoverable, isTrue);

      // Calculate retry delay
      final retryDelay = ErrorSerializer.getRetryDelay(extractedError, 1);
      expect(retryDelay.inMilliseconds, greaterThan(0));
    });

    test('should handle isolate crash scenario', () async {
      final monitor = IsolateHealthMonitor(healthCheckInterval: const Duration(milliseconds: 50), responseTimeout: const Duration(milliseconds: 25));

      final receivePort = ReceivePort();
      final sendPort = receivePort.sendPort;

      String? crashedIsolateId;
      Object? crashError;

      monitor.onIsolateCrashed((isolateId, error) {
        crashedIsolateId = isolateId;
        crashError = error;
      });

      // Start monitoring
      monitor.startMonitoring('test_isolate', sendPort);

      // Simulate multiple failures leading to crash
      final error = IsolateProcessingException('test_isolate', 'Processing failed', requestId: 'req_123');

      monitor.reportFailure('test_isolate', error);
      monitor.reportFailure('test_isolate', error);
      monitor.reportFailure('test_isolate', error);

      // Verify crash was detected
      expect(crashedIsolateId, equals('test_isolate'));
      expect(crashError, equals(error));

      final health = monitor.getHealth('test_isolate');
      expect(health?.needsRestart, isTrue);

      receivePort.close();
      monitor.dispose();
    });
  });
}
