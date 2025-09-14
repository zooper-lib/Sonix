/// Background isolate entry point for audio processing
///
/// This module provides the main entry point and processing logic for
/// background isolates that handle audio decoding and waveform generation.
library;

import 'dart:async';
import 'dart:isolate';

import 'isolate_messages.dart';
import '../decoders/audio_decoder_factory.dart';
import '../decoders/audio_decoder.dart';
import '../processing/waveform_generator.dart';
import '../exceptions/sonix_exceptions.dart';

/// Entry point for background processing isolates
///
/// This function is spawned as a new isolate and handles all audio processing
/// tasks sent from the main isolate. It listens for ProcessingRequest messages
/// and responds with ProcessingResponse messages.
void processingIsolateEntryPoint(SendPort handshakeSendPort) {
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
          await _handleIsolateMessage(isolateMessage, mainSendPort!);
        }
      }
    } catch (error, stackTrace) {
      // Send error back to main isolate if we have the send port
      if (mainSendPort != null) {
        try {
          final errorMessage = ErrorMessage(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            timestamp: DateTime.now(),
            errorMessage: error.toString(),
            errorType: 'IsolateProcessingError',
            stackTrace: stackTrace.toString(),
          );
          mainSendPort!.send(errorMessage.toJson());
        } catch (sendError) {
          // If we can't even send the error, there's not much we can do
          // The isolate will likely be considered crashed by the health monitor
        }
      }
    }
  });
}

/// Handle messages received in the background isolate
Future<void> _handleIsolateMessage(IsolateMessage message, SendPort mainSendPort) async {
  if (message is ProcessingRequest) {
    await _processWaveformRequest(message, mainSendPort);
  } else if (message is CancellationRequest) {
    // Handle cancellation - in a real implementation you'd track active operations
    // and cancel them here
    await _handleCancellationRequest(message, mainSendPort);
  }
}

/// Process a waveform generation request in the background isolate
Future<void> _processWaveformRequest(ProcessingRequest request, SendPort mainSendPort) async {
  try {
    // Send initial progress update if streaming is enabled
    if (request.streamResults) {
      final progressUpdate = ProgressUpdate(
        id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        requestId: request.id,
        progress: 0.0,
        statusMessage: 'Starting audio file processing',
      );
      mainSendPort.send(progressUpdate.toJson());
    }

    // Step 1: Create appropriate decoder for the file format
    AudioDecoder? decoder;
    try {
      decoder = AudioDecoderFactory.createDecoder(request.filePath);
    } catch (error) {
      // Handle decoder creation errors immediately
      _sendErrorResponse(mainSendPort, request.id, error);
      return;
    }

    try {
      // Send progress update for decoding phase
      if (request.streamResults) {
        final progressUpdate = ProgressUpdate(
          id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          requestId: request.id,
          progress: 0.2,
          statusMessage: 'Decoding audio file',
        );
        mainSendPort.send(progressUpdate.toJson());
      }

      // Step 2: Decode the audio file
      final audioData = await decoder!.decode(request.filePath);

      // Send progress update for waveform generation phase
      if (request.streamResults) {
        final progressUpdate = ProgressUpdate(
          id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          requestId: request.id,
          progress: 0.6,
          statusMessage: 'Generating waveform data',
        );
        mainSendPort.send(progressUpdate.toJson());
      }

      // Step 3: Generate waveform from audio data
      final waveformData = await WaveformGenerator.generate(audioData, config: request.config);

      // Send final progress update
      if (request.streamResults) {
        final progressUpdate = ProgressUpdate(
          id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          requestId: request.id,
          progress: 1.0,
          statusMessage: 'Waveform generation complete',
        );
        mainSendPort.send(progressUpdate.toJson());
      }

      // Send completion response
      final response = ProcessingResponse(
        id: 'response_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        requestId: request.id,
        waveformData: waveformData,
        isComplete: true,
      );

      mainSendPort.send(response.toJson());
    } finally {
      // Always dispose of the decoder to free resources
      decoder?.dispose();
    }
  } catch (error, stackTrace) {
    // Send error response
    _sendErrorResponse(mainSendPort, request.id, error);
  }
}

/// Send an error response back to the main isolate
void _sendErrorResponse(SendPort mainSendPort, String requestId, Object error) {
  String errorMessage;
  String errorType;

  if (error is SonixException) {
    errorMessage = error.message;
    errorType = error.runtimeType.toString();
  } else {
    errorMessage = error.toString();
    errorType = 'UnknownError';
  }

  final errorResponse = ProcessingResponse(
    id: 'error_response_${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    requestId: requestId,
    error: '$errorType: $errorMessage',
    isComplete: true,
  );

  mainSendPort.send(errorResponse.toJson());
}

/// Handle cancellation requests
Future<void> _handleCancellationRequest(CancellationRequest request, SendPort mainSendPort) async {
  // In a more sophisticated implementation, we would:
  // 1. Track active operations by request ID
  // 2. Cancel the specific operation
  // 3. Clean up any resources
  // 4. Send a cancellation confirmation

  // For now, we'll just acknowledge the cancellation
  final response = ProcessingResponse(
    id: 'cancellation_response_${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    requestId: request.requestId,
    error: 'Operation cancelled',
    isComplete: true,
  );

  mainSendPort.send(response.toJson());
}
