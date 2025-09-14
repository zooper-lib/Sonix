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

  // Track active operations for cancellation support
  final Map<String, _ActiveOperation> activeOperations = {};

  // Listen for messages from the main isolate
  receivePort.listen((dynamic message) async {
    try {
      if (message is SendPort) {
        // This is the main isolate's send port for responses
        mainSendPort = message;
      } else if (message is Map<String, dynamic>) {
        final isolateMessage = IsolateMessage.fromJson(message);
        if (mainSendPort != null) {
          await _handleIsolateMessage(isolateMessage, mainSendPort!, activeOperations);
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

/// Represents an active operation in the background isolate
class _ActiveOperation {
  final String requestId;
  final Completer<void> completer;
  bool isCancelled = false;

  _ActiveOperation(this.requestId) : completer = Completer<void>();

  void cancel() {
    isCancelled = true;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void complete() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> get future => completer.future;
}

/// Handle messages received in the background isolate
Future<void> _handleIsolateMessage(IsolateMessage message, SendPort mainSendPort, Map<String, _ActiveOperation> activeOperations) async {
  if (message is ProcessingRequest) {
    await _processWaveformRequest(message, mainSendPort, activeOperations);
  } else if (message is CancellationRequest) {
    await _handleCancellationRequest(message, mainSendPort, activeOperations);
  }
}

/// Process a waveform generation request in the background isolate
Future<void> _processWaveformRequest(ProcessingRequest request, SendPort mainSendPort, Map<String, _ActiveOperation> activeOperations) async {
  // Create and track the active operation
  final operation = _ActiveOperation(request.id);
  activeOperations[request.id] = operation;

  try {
    // Send initial progress update if streaming is enabled
    if (request.streamResults) {
      _sendProgressUpdate(mainSendPort, request.id, 0.0, 'Initializing audio processing');
    }

    // Check for cancellation before starting
    if (operation.isCancelled) {
      _sendCancellationResponse(mainSendPort, request.id);
      return;
    }

    // Step 1: Create appropriate decoder for the file format
    AudioDecoder? decoder;
    try {
      if (request.streamResults) {
        _sendProgressUpdate(mainSendPort, request.id, 0.1, 'Creating audio decoder');
      }

      // Check for cancellation before decoder creation
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      decoder = AudioDecoderFactory.createDecoder(request.filePath);
    } catch (error) {
      // Handle decoder creation errors immediately
      _sendErrorResponse(mainSendPort, request.id, error);
      return;
    }

    try {
      // Step 2: Decode the audio file with progress updates
      if (request.streamResults) {
        _sendProgressUpdate(mainSendPort, request.id, 0.2, 'Reading audio file');
      }

      // Check for cancellation before decoding
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      final audioData = await decoder!.decode(request.filePath);

      // Check for cancellation after decoding
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      if (request.streamResults) {
        _sendProgressUpdate(mainSendPort, request.id, 0.5, 'Audio decoding complete');
      }

      // Step 3: Generate waveform from audio data with progress updates
      if (request.streamResults) {
        _sendProgressUpdate(mainSendPort, request.id, 0.6, 'Analyzing audio data');
      }

      // Check for cancellation before waveform generation
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      final waveformData = await WaveformGenerator.generate(audioData, config: request.config);

      // Check for cancellation after waveform generation
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      if (request.streamResults) {
        _sendProgressUpdate(mainSendPort, request.id, 0.9, 'Finalizing waveform data');
      }

      // Send final progress update before completion
      if (request.streamResults) {
        _sendProgressUpdate(mainSendPort, request.id, 1.0, 'Waveform generation complete');
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
  } catch (error) {
    // Send error response only if not cancelled
    if (!operation.isCancelled) {
      _sendErrorResponse(mainSendPort, request.id, error);
    }
  } finally {
    // Clean up the active operation
    activeOperations.remove(request.id);
    operation.complete();
  }
}

/// Send a progress update to the main isolate
void _sendProgressUpdate(SendPort mainSendPort, String requestId, double progress, String statusMessage) {
  final progressUpdate = ProgressUpdate(
    id: 'progress_${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    requestId: requestId,
    progress: progress,
    statusMessage: statusMessage,
  );
  mainSendPort.send(progressUpdate.toJson());
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
Future<void> _handleCancellationRequest(CancellationRequest request, SendPort mainSendPort, Map<String, _ActiveOperation> activeOperations) async {
  final operation = activeOperations[request.requestId];

  if (operation != null) {
    // Cancel the active operation
    operation.cancel();

    // Send cancellation confirmation
    _sendCancellationResponse(mainSendPort, request.requestId);
  } else {
    // Operation not found (might have already completed)
    final response = ProcessingResponse(
      id: 'cancellation_response_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      requestId: request.requestId,
      error: 'Operation not found or already completed',
      isComplete: true,
    );

    mainSendPort.send(response.toJson());
  }
}

/// Send a cancellation response back to the main isolate
void _sendCancellationResponse(SendPort mainSendPort, String requestId) {
  final response = ProcessingResponse(
    id: 'cancellation_response_${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    requestId: requestId,
    error: 'Operation cancelled',
    isComplete: true,
  );

  mainSendPort.send(response.toJson());
}
