import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/isolate/isolate_messages.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';

void main() {
  group('IsolateMessages', () {
    late DateTime testTimestamp;
    late WaveformConfig testConfig;
    late WaveformData testWaveformData;

    setUp(() {
      testTimestamp = DateTime.now();
      testConfig = const WaveformConfig(resolution: 1000, type: WaveformType.bars, normalize: true);
      testWaveformData = WaveformData(
        amplitudes: [0.1, 0.2, 0.3, 0.4, 0.5],
        duration: const Duration(seconds: 5),
        sampleRate: 44100,
        metadata: WaveformMetadata(resolution: 5, type: WaveformType.bars, normalized: true, generatedAt: testTimestamp),
      );
    });

    group('ProcessingRequest', () {
      test('should create ProcessingRequest with required fields', () {
        final request = ProcessingRequest(id: 'test-request', timestamp: testTimestamp, filePath: '/path/to/audio.mp3', config: testConfig);

        expect(request.id, equals('test-request'));
        expect(request.filePath, equals('/path/to/audio.mp3'));
        expect(request.config, equals(testConfig));
        expect(request.streamResults, isFalse);
        expect(request.messageType, equals('ProcessingRequest'));
      });

      test('should create ProcessingRequest with streaming enabled', () {
        final request = ProcessingRequest(
          id: 'streaming-request',
          timestamp: testTimestamp,
          filePath: '/path/to/large_audio.flac',
          config: testConfig,
          streamResults: true,
        );

        expect(request.streamResults, isTrue);
      });

      test('should serialize and deserialize correctly', () {
        final request = ProcessingRequest(id: 'serialize-test', timestamp: testTimestamp, filePath: '/test/file.wav', config: testConfig, streamResults: true);

        final json = request.toJson();
        final deserialized = ProcessingRequest.fromJson(json);

        expect(deserialized.id, equals(request.id));
        expect(deserialized.filePath, equals(request.filePath));
        expect(deserialized.streamResults, equals(request.streamResults));
        expect(deserialized.config.resolution, equals(request.config.resolution));
        expect(deserialized.timestamp, equals(request.timestamp));
      });
    });

    group('ProcessingResponse', () {
      test('should create successful ProcessingResponse', () {
        final response = ProcessingResponse(
          id: 'success-response',
          timestamp: testTimestamp,
          requestId: 'original-request',
          waveformData: testWaveformData,
          isComplete: true,
        );

        expect(response.id, equals('success-response'));
        expect(response.requestId, equals('original-request'));
        expect(response.waveformData, equals(testWaveformData));
        expect(response.error, isNull);
        expect(response.isComplete, isTrue);
        expect(response.messageType, equals('ProcessingResponse'));
      });

      test('should create error ProcessingResponse', () {
        final response = ProcessingResponse(
          id: 'error-response',
          timestamp: testTimestamp,
          requestId: 'failed-request',
          error: 'File not found',
          isComplete: true,
        );

        expect(response.error, equals('File not found'));
        expect(response.waveformData, isNull);
        expect(response.isComplete, isTrue);
      });

      test('should create partial ProcessingResponse for streaming', () {
        final response = ProcessingResponse(
          id: 'partial-response',
          timestamp: testTimestamp,
          requestId: 'streaming-request',
          waveformData: testWaveformData,
          isComplete: false,
        );

        expect(response.isComplete, isFalse);
        expect(response.waveformData, isNotNull);
      });

      test('should serialize and deserialize correctly', () {
        final response = ProcessingResponse(
          id: 'serialize-response',
          timestamp: testTimestamp,
          requestId: 'test-request',
          waveformData: testWaveformData,
          isComplete: true,
        );

        final json = response.toJson();
        final deserialized = ProcessingResponse.fromJson(json);

        expect(deserialized.id, equals(response.id));
        expect(deserialized.requestId, equals(response.requestId));
        expect(deserialized.isComplete, equals(response.isComplete));
        expect(deserialized.waveformData?.amplitudes.length, equals(response.waveformData?.amplitudes.length));
      });

      test('should serialize and deserialize error response correctly', () {
        final response = ProcessingResponse(
          id: 'error-serialize',
          timestamp: testTimestamp,
          requestId: 'test-request',
          error: 'Processing failed',
          isComplete: true,
        );

        final json = response.toJson();
        final deserialized = ProcessingResponse.fromJson(json);

        expect(deserialized.error, equals(response.error));
        expect(deserialized.waveformData, isNull);
      });
    });

    group('ProgressUpdate', () {
      test('should create ProgressUpdate with basic progress', () {
        final progress = ProgressUpdate(id: 'progress-1', timestamp: testTimestamp, requestId: 'processing-request', progress: 0.5);

        expect(progress.id, equals('progress-1'));
        expect(progress.requestId, equals('processing-request'));
        expect(progress.progress, equals(0.5));
        expect(progress.statusMessage, isNull);
        expect(progress.partialData, isNull);
        expect(progress.messageType, equals('ProgressUpdate'));
      });

      test('should create ProgressUpdate with status message', () {
        final progress = ProgressUpdate(
          id: 'progress-2',
          timestamp: testTimestamp,
          requestId: 'processing-request',
          progress: 0.75,
          statusMessage: 'Decoding audio data...',
        );

        expect(progress.statusMessage, equals('Decoding audio data...'));
      });

      test('should create ProgressUpdate with partial data', () {
        final progress = ProgressUpdate(
          id: 'progress-3',
          timestamp: testTimestamp,
          requestId: 'streaming-request',
          progress: 0.3,
          partialData: testWaveformData,
        );

        expect(progress.partialData, equals(testWaveformData));
      });

      test('should serialize and deserialize correctly', () {
        final progress = ProgressUpdate(
          id: 'serialize-progress',
          timestamp: testTimestamp,
          requestId: 'test-request',
          progress: 0.85,
          statusMessage: 'Almost done...',
          partialData: testWaveformData,
        );

        final json = progress.toJson();
        final deserialized = ProgressUpdate.fromJson(json);

        expect(deserialized.id, equals(progress.id));
        expect(deserialized.requestId, equals(progress.requestId));
        expect(deserialized.progress, equals(progress.progress));
        expect(deserialized.statusMessage, equals(progress.statusMessage));
        expect(deserialized.partialData?.amplitudes.length, equals(progress.partialData?.amplitudes.length));
      });

      test('should handle progress bounds correctly', () {
        // Test minimum progress
        final minProgress = ProgressUpdate(id: 'min-progress', timestamp: testTimestamp, requestId: 'test-request', progress: 0.0);
        expect(minProgress.progress, equals(0.0));

        // Test maximum progress
        final maxProgress = ProgressUpdate(id: 'max-progress', timestamp: testTimestamp, requestId: 'test-request', progress: 1.0);
        expect(maxProgress.progress, equals(1.0));
      });
    });

    group('ErrorMessage', () {
      test('should create ErrorMessage with required fields', () {
        final error = ErrorMessage(id: 'error-1', timestamp: testTimestamp, errorMessage: 'File processing failed', errorType: 'ProcessingError');

        expect(error.id, equals('error-1'));
        expect(error.errorMessage, equals('File processing failed'));
        expect(error.errorType, equals('ProcessingError'));
        expect(error.requestId, isNull);
        expect(error.stackTrace, isNull);
        expect(error.messageType, equals('ErrorMessage'));
      });

      test('should create ErrorMessage with optional fields', () {
        final error = ErrorMessage(
          id: 'error-2',
          timestamp: testTimestamp,
          errorMessage: 'Isolate communication failed',
          errorType: 'CommunicationError',
          requestId: 'failed-request',
          stackTrace: 'Stack trace information...',
        );

        expect(error.requestId, equals('failed-request'));
        expect(error.stackTrace, equals('Stack trace information...'));
      });

      test('should serialize and deserialize correctly', () {
        final error = ErrorMessage(
          id: 'serialize-error',
          timestamp: testTimestamp,
          errorMessage: 'Test error message',
          errorType: 'TestError',
          requestId: 'test-request',
          stackTrace: 'Test stack trace',
        );

        final json = error.toJson();
        final deserialized = ErrorMessage.fromJson(json);

        expect(deserialized.id, equals(error.id));
        expect(deserialized.errorMessage, equals(error.errorMessage));
        expect(deserialized.errorType, equals(error.errorType));
        expect(deserialized.requestId, equals(error.requestId));
        expect(deserialized.stackTrace, equals(error.stackTrace));
      });
    });

    group('CancellationRequest', () {
      test('should create CancellationRequest', () {
        final cancellation = CancellationRequest(id: 'cancel-1', timestamp: testTimestamp, requestId: 'request-to-cancel');

        expect(cancellation.id, equals('cancel-1'));
        expect(cancellation.requestId, equals('request-to-cancel'));
        expect(cancellation.messageType, equals('CancellationRequest'));
      });

      test('should serialize and deserialize correctly', () {
        final cancellation = CancellationRequest(id: 'serialize-cancel', timestamp: testTimestamp, requestId: 'cancel-this-request');

        final json = cancellation.toJson();
        final deserialized = CancellationRequest.fromJson(json);

        expect(deserialized.id, equals(cancellation.id));
        expect(deserialized.requestId, equals(cancellation.requestId));
        expect(deserialized.timestamp, equals(cancellation.timestamp));
      });
    });

    group('IsolateMessage.fromJson', () {
      test('should deserialize ProcessingRequest from JSON', () {
        final request = ProcessingRequest(id: 'test-request', timestamp: testTimestamp, filePath: '/test.mp3', config: testConfig);

        final json = request.toJson();
        final deserialized = IsolateMessage.fromJson(json);

        expect(deserialized, isA<ProcessingRequest>());
        expect(deserialized.id, equals(request.id));
      });

      test('should deserialize ProcessingResponse from JSON', () {
        final response = ProcessingResponse(
          id: 'test-response',
          timestamp: testTimestamp,
          requestId: 'test-request',
          waveformData: testWaveformData,
          isComplete: true,
        );

        final json = response.toJson();
        final deserialized = IsolateMessage.fromJson(json);

        expect(deserialized, isA<ProcessingResponse>());
        expect(deserialized.id, equals(response.id));
      });

      test('should deserialize ProgressUpdate from JSON', () {
        final progress = ProgressUpdate(id: 'test-progress', timestamp: testTimestamp, requestId: 'test-request', progress: 0.5);

        final json = progress.toJson();
        final deserialized = IsolateMessage.fromJson(json);

        expect(deserialized, isA<ProgressUpdate>());
        expect(deserialized.id, equals(progress.id));
      });

      test('should deserialize ErrorMessage from JSON', () {
        final error = ErrorMessage(id: 'test-error', timestamp: testTimestamp, errorMessage: 'Test error', errorType: 'TestError');

        final json = error.toJson();
        final deserialized = IsolateMessage.fromJson(json);

        expect(deserialized, isA<ErrorMessage>());
        expect(deserialized.id, equals(error.id));
      });

      test('should deserialize CancellationRequest from JSON', () {
        final cancellation = CancellationRequest(id: 'test-cancel', timestamp: testTimestamp, requestId: 'test-request');

        final json = cancellation.toJson();
        final deserialized = IsolateMessage.fromJson(json);

        expect(deserialized, isA<CancellationRequest>());
        expect(deserialized.id, equals(cancellation.id));
      });

      test('should throw ArgumentError for unknown message type', () {
        final invalidJson = {'messageType': 'UnknownMessageType', 'id': 'test-id', 'timestamp': testTimestamp.toIso8601String()};

        expect(() => IsolateMessage.fromJson(invalidJson), throwsA(isA<ArgumentError>()));
      });
    });
  });
}
