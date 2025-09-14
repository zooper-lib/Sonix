/// Simple cancellation tests to verify core functionality
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/isolate/isolate_messages.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('Simple Cancellation Tests', () {
    test('ProcessingTask should support cancellation', () {
      // Arrange
      final task = ProcessingTask(id: 'test_task', filePath: 'test.mp3', config: const WaveformConfig(resolution: 100));

      // Act & Assert - Initial state
      expect(task.cancelToken.isCancelled, isFalse);
      expect(task.completer.isCompleted, isFalse);

      // Act - Cancel the task
      task.cancel();

      // Assert - After cancellation
      expect(task.cancelToken.isCancelled, isTrue);
      expect(task.completer.isCompleted, isTrue);
      expect(task.future, throwsA(isA<TaskCancelledException>()));
    });

    test('CancelToken should work correctly', () {
      // Arrange
      final cancelToken = CancelToken();

      // Act & Assert - Initial state
      expect(cancelToken.isCancelled, isFalse);

      // Act - Cancel
      cancelToken.cancel();

      // Assert - After cancellation
      expect(cancelToken.isCancelled, isTrue);

      // Act - Multiple cancels should be safe
      cancelToken.cancel();
      expect(cancelToken.isCancelled, isTrue);
    });

    test('CancellationRequest message should serialize correctly', () {
      // Arrange
      final timestamp = DateTime.now();
      final cancellation = CancellationRequest(id: 'cancel_1', timestamp: timestamp, requestId: 'request_to_cancel');

      // Act
      final json = cancellation.toJson();
      final deserialized = CancellationRequest.fromJson(json);

      // Assert
      expect(deserialized.id, equals(cancellation.id));
      expect(deserialized.timestamp, equals(cancellation.timestamp));
      expect(deserialized.requestId, equals(cancellation.requestId));
      expect(deserialized.messageType, equals('CancellationRequest'));
    });

    test('CancellationRequest should deserialize through IsolateMessage.fromJson', () {
      // Arrange
      final cancellation = CancellationRequest(id: 'polymorphic_test', timestamp: DateTime.now(), requestId: 'polymorphic_request');

      final json = cancellation.toJson();

      // Act
      final deserialized = IsolateMessage.fromJson(json);

      // Assert
      expect(deserialized, isA<CancellationRequest>());
      final cancelRequest = deserialized as CancellationRequest;
      expect(cancelRequest.requestId, equals('polymorphic_request'));
    });

    test('TaskCancelledException should work correctly', () {
      // Arrange & Act
      final exception = TaskCancelledException('Test cancellation message');

      // Assert
      expect(exception.message, equals('Test cancellation message'));
      expect(exception.toString(), contains('TaskCancelledException'));
      expect(exception.toString(), contains('Test cancellation message'));

      // Test throwing and catching
      expect(() => throw exception, throwsA(isA<TaskCancelledException>()));
    });
  });
}
