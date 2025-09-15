/// Background isolate entry point for audio processing
///
/// This module provides the main entry point and processing logic for
/// background isolates that handle audio decoding and waveform generation.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'isolate_messages.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/chunked_audio_decoder.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_algorithms.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

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
      // Step 2: Check file size and determine processing strategy
      if (request.streamResults) {
        _sendProgressUpdate(mainSendPort, request.id, 0.2, 'Analyzing file size');
      }

      // Check for cancellation before file analysis
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      // Get file size to determine processing strategy
      final file = File(request.filePath);
      final fileSize = await file.length();
      const chunkThreshold = 50 * 1024 * 1024; // 50MB threshold

      final AudioData audioData;

      if (fileSize > chunkThreshold && decoder is ChunkedAudioDecoder) {
        // Use selective decoding for large files
        if (request.streamResults) {
          _sendProgressUpdate(mainSendPort, request.id, 0.25, 'Using selective decoding for large file (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB)');
        }

        audioData = await _processWithSelectiveDecoding(decoder, request.filePath, request.config, mainSendPort, request.id, request.streamResults, operation);
      } else {
        // Use regular processing for smaller files
        if (request.streamResults) {
          _sendProgressUpdate(mainSendPort, request.id, 0.25, 'Reading audio file (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB)');
        }

        audioData = await decoder.decode(request.filePath);
      }

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
      decoder.dispose();
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

/// Process large files using selective decoding at strategic time positions
///
/// Instead of decoding the entire file, this method:
/// 1. Estimates the file duration
/// 2. Calculates strategic time positions based on desired resolution
/// 3. Seeks to each position and decodes a small chunk
/// 4. Extracts amplitude from each chunk to build the waveform
///
/// This is much more efficient for large files as it only decodes what's needed.
Future<AudioData> _processWithSelectiveDecoding(
  ChunkedAudioDecoder decoder,
  String filePath,
  WaveformConfig config,
  SendPort mainSendPort,
  String requestId,
  bool streamResults,
  _ActiveOperation operation,
) async {
  // Initialize decoder for chunked processing
  await decoder.initializeChunkedDecoding(filePath);

  // Check for cancellation after initialization
  if (operation.isCancelled) {
    throw Exception('Operation cancelled during selective decoder initialization');
  }

  if (streamResults) {
    _sendProgressUpdate(mainSendPort, requestId, 0.1, 'Estimating file duration');
  }

  // Get file metadata and estimate duration
  final metadata = decoder.getFormatMetadata();
  final sampleRate = metadata['sampleRate'] as int? ?? 44100;
  final channels = metadata['channels'] as int? ?? 2;

  // Estimate duration from file size and format
  Duration? estimatedDuration = await decoder.estimateDuration();
  if (estimatedDuration == null) {
    // Fallback: estimate from file size (rough approximation)
    final file = File(filePath);
    final fileSize = await file.length();
    // Rough estimate: assume 128kbps average bitrate for MP3
    final estimatedSeconds = (fileSize * 8) / (128 * 1000);
    estimatedDuration = Duration(seconds: estimatedSeconds.round());
  }

  if (streamResults) {
    _sendProgressUpdate(mainSendPort, requestId, 0.2, 'Planning selective decode positions');
  }

  // Calculate how many sample positions we need
  final resolution = config.resolution;

  if (streamResults) {
    _sendProgressUpdate(mainSendPort, requestId, 0.3, 'Beginning selective decode');
  }

  // Sample audio at each position
  final amplitudes = <double>[];
  final file = File(filePath);
  final fileSize = await file.length();

  for (int i = 0; i < resolution; i++) {
    // Check for cancellation during processing
    if (operation.isCancelled) {
      throw Exception('Operation cancelled during selective processing');
    }

    try {
      // Use a simple approach: distribute sample positions across the file
      // Don't rely on duration estimation for byte positioning
      final progress = resolution <= 1 ? 0.5 : i / (resolution - 1); // 0.0 to 1.0
      final bytePosition = (fileSize * progress).round();

      // Ensure byte position is within valid bounds
      final safeBytePosition = math.max(0, math.min(bytePosition, fileSize - (16 * 1024)));

      // Read a small chunk directly from the calculated position
      const chunkSize = 16 * 1024; // 16KB
      final endPosition = math.min(fileSize, safeBytePosition + chunkSize);

      final chunkData = await file.openRead(safeBytePosition, endPosition).fold<List<int>>([], (previous, element) => previous..addAll(element));

      if (chunkData.isNotEmpty) {
        // Create a file chunk for processing
        final fileChunk = FileChunk(
          data: Uint8List.fromList(chunkData),
          startPosition: safeBytePosition,
          endPosition: endPosition,
          isLast: i == resolution - 1,
        );

        // Process this chunk to get audio samples
        final audioChunks = await decoder.processFileChunk(fileChunk);

        // Extract amplitude from the decoded chunk
        double amplitude = 0.0;
        if (audioChunks.isNotEmpty) {
          final samples = audioChunks.first.samples;
          if (samples.isNotEmpty) {
            // Calculate amplitude from this chunk
            if (config.algorithm == DownsamplingAlgorithm.rms) {
              // RMS calculation
              double sum = 0.0;
              for (final sample in samples) {
                sum += sample * sample;
              }
              amplitude = math.sqrt(sum / samples.length);
            } else {
              // Peak calculation
              amplitude = samples.map((s) => s.abs()).reduce(math.max);
            }
          }
        }

        amplitudes.add(amplitude);
      } else {
        // No data at this position
        amplitudes.add(0.0);
      }

      // Send progress updates
      if (streamResults && i % 50 == 0) {
        // Reduce frequency for better performance
        final progress = 0.3 + (i / resolution) * 0.6; // 30% to 90%
        _sendProgressUpdate(mainSendPort, requestId, progress, 'Sampling position ${i + 1}/$resolution');
      }
    } catch (e) {
      // Add a zero amplitude for failed positions (silently handle errors)
      amplitudes.add(0.0);
    }
  }

  // Cleanup decoder resources
  await decoder.cleanupChunkedProcessing();

  if (streamResults) {
    _sendProgressUpdate(mainSendPort, requestId, 0.9, 'Finalizing waveform data');
  }

  return AudioData(samples: amplitudes, sampleRate: sampleRate, channels: channels, duration: estimatedDuration);
}
