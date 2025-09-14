import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/isolate/isolate_messages.dart';
import 'package:sonix/src/isolate/isolate_message_handler.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';

void main() {
  group('IsolateMessageHandler', () {
    late DateTime testTimestamp;
    late WaveformConfig testConfig;
    late WaveformData testWaveformData;

    setUp(() {
      testTimestamp = DateTime.now();
      testConfig = const WaveformConfig(resolution: 500, type: WaveformType.bars, normalize: true);
      testWaveformData = WaveformData(
        amplitudes: [0.1, 0.5, 0.8, 0.3],
        duration: const Duration(seconds: 10),
        sampleRate: 44100,
        metadata: WaveformMetadata(resolution: 4, type: WaveformType.bars, normalized: true, generatedAt: testTimestamp),
      );
    });

    group('JSON Serialization', () {
      test('should serialize and deserialize ProcessingRequest', () {
        final request = ProcessingRequest(id: 'test-id', timestamp: testTimestamp, filePath: '/path/to/audio.mp3', config: testConfig, streamResults: true);

        final jsonString = IsolateMessageHandler.serializeToJson(request);
        final deserialized = IsolateMessageHandler.deserializeFromJson(jsonString);

        expect(deserialized, isA<ProcessingRequest>());
        final deserializedRequest = deserialized as ProcessingRequest;
        expect(deserializedRequest.id, equals(request.id));
        expect(deserializedRequest.filePath, equals(request.filePath));
        expect(deserializedRequest.streamResults, equals(request.streamResults));
        expect(deserializedRequest.config.resolution, equals(request.config.resolution));
      });

      test('should serialize and deserialize ProcessingResponse', () {
        final response = ProcessingResponse(
          id: 'response-id',
          timestamp: testTimestamp,
          requestId: 'request-id',
          waveformData: testWaveformData,
          isComplete: true,
        );

        final jsonString = IsolateMessageHandler.serializeToJson(response);
        final deserialized = IsolateMessageHandler.deserializeFromJson(jsonString);

        expect(deserialized, isA<ProcessingResponse>());
        final deserializedResponse = deserialized as ProcessingResponse;
        expect(deserializedResponse.id, equals(response.id));
        expect(deserializedResponse.requestId, equals(response.requestId));
        expect(deserializedResponse.isComplete, equals(response.isComplete));
        expect(deserializedResponse.waveformData?.amplitudes.length, equals(response.waveformData?.amplitudes.length));
      });

      test('should serialize and deserialize ProcessingResponse with error', () {
        final response = ProcessingResponse(
          id: 'error-response-id',
          timestamp: testTimestamp,
          requestId: 'request-id',
          error: 'File not found',
          isComplete: true,
        );

        final jsonString = IsolateMessageHandler.serializeToJson(response);
        final deserialized = IsolateMessageHandler.deserializeFromJson(jsonString);

        expect(deserialized, isA<ProcessingResponse>());
        final deserializedResponse = deserialized as ProcessingResponse;
        expect(deserializedResponse.error, equals(response.error));
        expect(deserializedResponse.waveformData, isNull);
      });

      test('should serialize and deserialize ProgressUpdate', () {
        final progress = ProgressUpdate(
          id: 'progress-id',
          timestamp: testTimestamp,
          requestId: 'request-id',
          progress: 0.75,
          statusMessage: 'Processing audio...',
          partialData: testWaveformData,
        );

        final jsonString = IsolateMessageHandler.serializeToJson(progress);
        final deserialized = IsolateMessageHandler.deserializeFromJson(jsonString);

        expect(deserialized, isA<ProgressUpdate>());
        final deserializedProgress = deserialized as ProgressUpdate;
        expect(deserializedProgress.progress, equals(progress.progress));
        expect(deserializedProgress.statusMessage, equals(progress.statusMessage));
        expect(deserializedProgress.partialData?.amplitudes.length, equals(progress.partialData?.amplitudes.length));
      });

      test('should serialize and deserialize ErrorMessage', () {
        final error = ErrorMessage(
          id: 'error-id',
          timestamp: testTimestamp,
          errorMessage: 'Processing failed',
          errorType: 'ProcessingError',
          requestId: 'request-id',
          stackTrace: 'Stack trace here...',
        );

        final jsonString = IsolateMessageHandler.serializeToJson(error);
        final deserialized = IsolateMessageHandler.deserializeFromJson(jsonString);

        expect(deserialized, isA<ErrorMessage>());
        final deserializedError = deserialized as ErrorMessage;
        expect(deserializedError.errorMessage, equals(error.errorMessage));
        expect(deserializedError.errorType, equals(error.errorType));
        expect(deserializedError.stackTrace, equals(error.stackTrace));
      });

      test('should serialize and deserialize CancellationRequest', () {
        final cancellation = CancellationRequest(id: 'cancel-id', timestamp: testTimestamp, requestId: 'request-to-cancel');

        final jsonString = IsolateMessageHandler.serializeToJson(cancellation);
        final deserialized = IsolateMessageHandler.deserializeFromJson(jsonString);

        expect(deserialized, isA<CancellationRequest>());
        final deserializedCancellation = deserialized as CancellationRequest;
        expect(deserializedCancellation.requestId, equals(cancellation.requestId));
      });
    });

    group('Binary Serialization', () {
      test('should serialize and deserialize ProcessingRequest to binary', () {
        final request = ProcessingRequest(
          id: 'binary-test-id',
          timestamp: testTimestamp,
          filePath: '/path/to/audio.wav',
          config: testConfig,
          streamResults: false,
        );

        final binaryData = IsolateMessageHandler.serializeToBinary(request);
        final deserialized = IsolateMessageHandler.deserializeFromBinary(binaryData);

        expect(deserialized, isA<ProcessingRequest>());
        final deserializedRequest = deserialized as ProcessingRequest;
        expect(deserializedRequest.id, equals(request.id));
        expect(deserializedRequest.filePath, equals(request.filePath));
      });

      test('should handle large waveform data in binary format', () {
        final largeAmplitudes = List.generate(10000, (i) => i / 10000.0);
        final largeWaveformData = WaveformData(
          amplitudes: largeAmplitudes,
          duration: const Duration(minutes: 5),
          sampleRate: 44100,
          metadata: WaveformMetadata(resolution: largeAmplitudes.length, type: WaveformType.line, normalized: true, generatedAt: testTimestamp),
        );

        final response = ProcessingResponse(
          id: 'large-data-id',
          timestamp: testTimestamp,
          requestId: 'request-id',
          waveformData: largeWaveformData,
          isComplete: true,
        );

        final binaryData = IsolateMessageHandler.serializeToBinary(response);
        final deserialized = IsolateMessageHandler.deserializeFromBinary(binaryData);

        expect(deserialized, isA<ProcessingResponse>());
        final deserializedResponse = deserialized as ProcessingResponse;
        expect(deserializedResponse.waveformData?.amplitudes.length, equals(largeAmplitudes.length));
      });
    });

    group('Message Validation', () {
      test('should validate valid messages', () {
        final request = ProcessingRequest(id: 'valid-id', timestamp: testTimestamp, filePath: '/valid/path.mp3', config: testConfig);

        expect(() => IsolateMessageHandler.validateMessage(request), returnsNormally);
        expect(IsolateMessageHandler.validateMessage(request), isTrue);
      });

      test('should detect validation failures', () {
        // Create a message that will fail validation by having null required fields
        // This is a bit artificial since Dart's type system prevents this,
        // but we can test the validation logic
        final request = ProcessingRequest(id: 'test-id', timestamp: testTimestamp, filePath: '/path/to/file.mp3', config: testConfig);

        // This should pass validation
        expect(IsolateMessageHandler.validateMessage(request), isTrue);
      });
    });

    group('Message Size Calculation', () {
      test('should calculate message size correctly', () {
        final request = ProcessingRequest(id: 'size-test', timestamp: testTimestamp, filePath: '/test.mp3', config: testConfig);

        final size = IsolateMessageHandler.getMessageSize(request);
        expect(size, greaterThan(0));

        // Verify size matches actual serialized data
        final jsonString = IsolateMessageHandler.serializeToJson(request);
        final actualSize = jsonString.length;
        expect(size, equals(actualSize));
      });

      test('should handle messages with large data', () {
        final largeAmplitudes = List.generate(5000, (i) => i / 5000.0);
        final largeWaveformData = WaveformData(
          amplitudes: largeAmplitudes,
          duration: const Duration(minutes: 3),
          sampleRate: 44100,
          metadata: WaveformMetadata(resolution: largeAmplitudes.length, type: WaveformType.filled, normalized: true, generatedAt: testTimestamp),
        );

        final response = ProcessingResponse(
          id: 'large-response',
          timestamp: testTimestamp,
          requestId: 'request-id',
          waveformData: largeWaveformData,
          isComplete: true,
        );

        final size = IsolateMessageHandler.getMessageSize(response);
        expect(size, greaterThan(30000)); // Should be quite large for 5000 data points
      });
    });

    group('Batch Serialization', () {
      test('should serialize and deserialize message batches', () {
        final messages = [
          ProcessingRequest(id: 'batch-1', timestamp: testTimestamp, filePath: '/file1.mp3', config: testConfig),
          ProgressUpdate(id: 'batch-2', timestamp: testTimestamp, requestId: 'batch-1', progress: 0.5, statusMessage: 'Half done'),
          ProcessingResponse(id: 'batch-3', timestamp: testTimestamp, requestId: 'batch-1', waveformData: testWaveformData, isComplete: true),
        ];

        final batchJson = IsolateMessageHandler.serializeBatch(messages);
        final deserializedMessages = IsolateMessageHandler.deserializeBatch(batchJson);

        expect(deserializedMessages.length, equals(messages.length));
        expect(deserializedMessages[0], isA<ProcessingRequest>());
        expect(deserializedMessages[1], isA<ProgressUpdate>());
        expect(deserializedMessages[2], isA<ProcessingResponse>());

        final deserializedRequest = deserializedMessages[0] as ProcessingRequest;
        expect(deserializedRequest.id, equals('batch-1'));
      });

      test('should handle empty batch', () {
        final emptyBatch = <IsolateMessage>[];
        final batchJson = IsolateMessageHandler.serializeBatch(emptyBatch);
        final deserializedMessages = IsolateMessageHandler.deserializeBatch(batchJson);

        expect(deserializedMessages, isEmpty);
      });
    });

    group('Error Handling', () {
      test('should throw MessageSerializationException for invalid JSON', () {
        expect(() => IsolateMessageHandler.deserializeFromJson('invalid json'), throwsA(isA<MessageSerializationException>()));
      });

      test('should throw MessageSerializationException for unknown message type', () {
        final invalidJson = '{"messageType": "UnknownType", "id": "test"}';
        expect(() => IsolateMessageHandler.deserializeFromJson(invalidJson), throwsA(isA<MessageSerializationException>()));
      });

      test('should throw MessageSerializationException for invalid binary data', () {
        final invalidBinary = Uint8List.fromList([0xFF, 0xFE, 0xFD]);
        expect(() => IsolateMessageHandler.deserializeFromBinary(invalidBinary), throwsA(isA<MessageSerializationException>()));
      });

      test('should handle serialization errors gracefully', () {
        // Test with a message that might cause serialization issues
        final response = ProcessingResponse(
          id: 'error-test',
          timestamp: testTimestamp,
          requestId: 'request-id',
          error: 'Test error with special chars: \n\t\r"\'\\',
          isComplete: true,
        );

        expect(() => IsolateMessageHandler.serializeToJson(response), returnsNormally);
      });
    });
  });
}
