/// Mock processing isolate for testing
///
/// This provides a mock implementation of the processing isolate that
/// doesn't require real audio files or decoders for testing.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:sonix/src/isolate/isolate_messages.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/waveform_type.dart';
import 'package:sonix/src/models/waveform_metadata.dart';

/// Mock entry point for background processing isolates used in tests
void mockProcessingIsolateEntryPoint(SendPort handshakeSendPort) {
  // Create receive port for this isolate
  final receivePort = ReceivePort();

  // Send our send port back to the main isolate for handshake
  handshakeSendPort.send(receivePort.sendPort);

  // Store the main isolate's send port for responses
  SendPort? mainSendPort;

  // Listen for messages from the main isolate
  receivePort.listen((dynamic message) async {
    try {
      if (message is SendPort) {
        // This is the main isolate's send port for responses
        mainSendPort = message;
      } else if (message is Map<String, dynamic>) {
        final isolateMessage = IsolateMessage.fromJson(message);
        if (mainSendPort != null) {
          await _handleMockIsolateMessage(isolateMessage, mainSendPort!);
        }
      }
    } catch (error, stackTrace) {
      // Send error back to main isolate if we have the send port
      if (mainSendPort != null) {
        final errorMessage = ErrorMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          errorMessage: error.toString(),
          errorType: 'MockIsolateProcessingError',
          stackTrace: stackTrace.toString(),
        );
        mainSendPort!.send(errorMessage.toJson());
      }
    }
  });
}

/// Handle messages received in the mock background isolate
Future<void> _handleMockIsolateMessage(IsolateMessage message, SendPort mainSendPort) async {
  if (message is ProcessingRequest) {
    await _processMockWaveformRequest(message, mainSendPort);
  } else if (message is CancellationRequest) {
    await _handleMockCancellationRequest(message, mainSendPort);
  } else if (message.messageType == 'HealthCheckRequest') {
    await _handleMockHealthCheckRequest(message, mainSendPort);
  }
}

/// Process a mock waveform generation request
Future<void> _processMockWaveformRequest(ProcessingRequest request, SendPort mainSendPort) async {
  try {
    // Check for specific error conditions that tests expect
    if (request.filePath.contains('non_existent') || request.filePath.contains('nonexistent')) {
      _sendMockErrorResponse(mainSendPort, request.id, 'FileNotFoundException: File not found: ${request.filePath}');
      return;
    }

    if (request.filePath.contains('empty') || request.filePath.contains('corrupted')) {
      _sendMockErrorResponse(mainSendPort, request.id, 'DecodingException: Invalid or corrupted audio file');
      return;
    }

    if (request.filePath.endsWith('.xyz') || request.filePath.contains('unsupported')) {
      _sendMockErrorResponse(mainSendPort, request.id, 'UnsupportedFormatException: Unsupported audio format');
      return;
    }

    // Send initial progress update if streaming is enabled
    if (request.streamResults) {
      final progressUpdate = ProgressUpdate(
        id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        requestId: request.id,
        progress: 0.0,
        statusMessage: 'Starting mock processing',
      );
      mainSendPort.send(progressUpdate.toJson());
    }

    // Simulate some processing time
    await Future.delayed(const Duration(milliseconds: 10));

    // Send progress update for decoding phase
    if (request.streamResults) {
      final progressUpdate = ProgressUpdate(
        id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        requestId: request.id,
        progress: 0.5,
        statusMessage: 'Mock decoding complete',
      );
      mainSendPort.send(progressUpdate.toJson());
    }

    // Simulate more processing time
    await Future.delayed(const Duration(milliseconds: 10));

    // Generate mock waveform data based on the requested configuration
    final resolution = request.config.resolution;
    final waveformType = request.config.type;
    final normalize = request.config.normalize;

    // Generate different patterns based on waveform type
    List<double> mockAmplitudes;
    if (waveformType == WaveformType.line) {
      // Generate a sine wave pattern for line type
      mockAmplitudes = List.generate(resolution, (i) {
        final phase = (i / resolution) * 2 * math.pi;
        final amplitude = (math.sin(phase) + 1) / 2; // Normalize to 0-1
        return normalize ? amplitude : amplitude * 32767; // Scale if not normalized
      });
    } else {
      // Generate a sawtooth pattern for bars type
      mockAmplitudes = List.generate(resolution, (i) {
        final amplitude = (i / resolution) * 0.8;
        return normalize ? amplitude : amplitude * 32767; // Scale if not normalized
      });
    }

    final mockWaveformData = WaveformData(
      amplitudes: mockAmplitudes,
      sampleRate: 44100,
      duration: const Duration(seconds: 3),
      metadata: WaveformMetadata(resolution: resolution, type: waveformType, normalized: normalize, generatedAt: DateTime.now()),
    );

    // Send final progress update
    if (request.streamResults) {
      final progressUpdate = ProgressUpdate(
        id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        requestId: request.id,
        progress: 1.0,
        statusMessage: 'Mock processing complete',
      );
      mainSendPort.send(progressUpdate.toJson());
    }

    // Send completion response
    final response = ProcessingResponse(
      id: 'response_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      requestId: request.id,
      waveformData: mockWaveformData,
      isComplete: true,
    );

    mainSendPort.send(response.toJson());
  } catch (error) {
    // Send error response
    _sendMockErrorResponse(mainSendPort, request.id, 'MockError: ${error.toString()}');
  }
}

/// Send a mock error response
void _sendMockErrorResponse(SendPort mainSendPort, String requestId, String errorMessage) {
  final errorResponse = ProcessingResponse(
    id: 'error_response_${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    requestId: requestId,
    error: errorMessage,
    isComplete: true,
  );

  mainSendPort.send(errorResponse.toJson());
}

/// Handle mock cancellation requests
Future<void> _handleMockCancellationRequest(CancellationRequest request, SendPort mainSendPort) async {
  final response = ProcessingResponse(
    id: 'cancellation_response_${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    requestId: request.requestId,
    error: 'Mock operation cancelled',
    isComplete: true,
  );

  mainSendPort.send(response.toJson());
}

/// Handle mock health check requests
Future<void> _handleMockHealthCheckRequest(IsolateMessage request, SendPort mainSendPort) async {
  final response = {
    'messageType': 'HealthCheckResponse',
    'id': 'health_response_${DateTime.now().millisecondsSinceEpoch}',
    'timestamp': DateTime.now().toIso8601String(),
    'memoryUsage': 1024 * 1024, // 1MB mock usage
    'activeTasks': 0,
    'statusInfo': {'status': 'healthy', 'uptime': '00:01:00'},
  };

  mainSendPort.send(response);
}
