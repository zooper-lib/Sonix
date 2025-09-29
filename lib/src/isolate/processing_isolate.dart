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
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/downsampling_algorithm.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/utils/sonix_logger.dart';

/// Background isolate entry point for audio processing
///
/// This module provides the main entry point and processing logic for
/// background isolates that handle audio decoding and waveform generation.

/// Entry point for background processing isolates
///
/// This function is spawned as a new isolate and handles all audio processing
/// tasks sent from the main isolate. It listens for ProcessingRequest messages
/// and responds with ProcessingResponse messages.
void processingIsolateEntryPoint(SendPort handshakeSendPort) {
  // Initialize native bindings in this isolate context
  // This ensures FFMPEG context is properly set up for this isolate
  try {
    NativeAudioBindings.initialize();

    // Verify FFMPEG is available in this isolate
    if (!NativeAudioBindings.isFFMPEGAvailable) {
      throw FFIException(
        'FFMPEG not available in isolate',
        'FFMPEG libraries are required but not available in this isolate context. '
            'Run: dart run tools/download_ffmpeg_binaries.dart',
      );
    }
  } catch (e) {
    // FFMPEG initialization failed - this is now a critical error
    // Send error back to main isolate and terminate
    final errorMessage = ErrorMessage(
      id: 'init_error_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      errorMessage: 'Failed to initialize FFMPEG in isolate: $e',
      errorType: 'FFMPEGInitializationError',
      stackTrace: StackTrace.current.toString(),
    );

    // Try to send error back, then terminate
    try {
      handshakeSendPort.send(errorMessage.toJson());
    } catch (_) {
      // If we can't send the error, just terminate
    }
    return;
  }

  // Create receive port for this isolate
  final receivePort = ReceivePort();

  // Send our send port back to the main isolate for handshake
  handshakeSendPort.send(receivePort.sendPort);

  // Store the main isolate's send port for responses
  SendPort? mainSendPort;

  // Track active operations for cancellation support
  final Map<String, _ActiveOperation> activeOperations = {};

  // Listen for messages from the main isolate
  receivePort.listen(
    (dynamic message) async {
      try {
        if (message is SendPort) {
          // This is the main isolate's send port for responses
          mainSendPort = message;
        } else if (message is Map<String, dynamic>) {
          final isolateMessage = IsolateMessage.fromJson(message);
          if (mainSendPort != null) {
            await _handleIsolateMessage(isolateMessage, mainSendPort!, activeOperations);
          }
        } else if (message == 'shutdown') {
          // Handle isolate shutdown request
          _cleanupIsolateResources();
          receivePort.close();
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
    },
    onDone: () {
      // Cleanup resources when isolate is about to terminate
      _cleanupIsolateResources();
    },
  );
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
    // Check for cancellation before starting
    if (operation.isCancelled) {
      _sendCancellationResponse(mainSendPort, request.id);
      return;
    }

    // Step 1: Create appropriate decoder for the file format
    AudioDecoder? decoder;
    try {
      // Check for cancellation before decoder creation
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      decoder = AudioDecoderFactory.createDecoder(request.filePath);
      SonixLogger.debug('Created decoder: ${decoder.runtimeType}');
    } catch (error) {
      // Handle decoder creation errors immediately
      _sendErrorResponse(mainSendPort, request.id, error);
      return;
    }

    try {
      // Step 2: Check file size and determine processing strategy
      SonixLogger.debug('Starting file analysis and decoding...');

      // Check for cancellation before file analysis
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      // Get file size to determine processing strategy
      final file = File(request.filePath);
      final fileSize = await file.length();

      // AUTOMATIC PROCESSING STRATEGY SELECTION:
      //
      // The isolate automatically selects between two processing approaches:
      //
      // 1. File-Level Chunked Processing (files > 5MB):
      //    - Uses _processWithSelectiveDecoding() for memory efficiency
      //    - Reads audio file in chunks without loading entirely into memory
      //    - Samples specific time positions from the file
      //    - Memory usage stays low and controlled
      //    - Best for typical audio files where loading entire file would use too much RAM
      //
      // 2. In-Memory Processing (files ≤ 5MB):
      //    - Uses standard decoder.decode() to load entire file
      //    - Then processes with WaveformGenerator.generateInMemory()
      //    - Faster processing but higher memory usage
      //    - Best for very small files where speed is prioritized
      //
      // Both strategies ultimately use logical chunking (downsampling) for waveform
      // generation, but differ in how they manage memory during audio loading.
      //
      const chunkThreshold = 5 * 1024 * 1024; // 5MB threshold - use chunked processing for files > 5MB

      final AudioData audioData;

      if (fileSize > chunkThreshold && decoder is ChunkedAudioDecoder) {
        // Use file-level chunked processing for large files (memory-efficient)
        SonixLogger.debug('Using chunked processing for large file');
        audioData = await _processWithSelectiveDecoding(decoder, request.filePath, request.config, mainSendPort, request.id, operation);
      } else {
        // Use in-memory processing for smaller files (performance-optimized)
        SonixLogger.debug('Using in-memory processing for smaller file');
        SonixLogger.trace('About to call decoder.decode()...');
        try {
          audioData = await decoder.decode(request.filePath);
          SonixLogger.debug('decoder.decode() completed successfully');
        } catch (decodeError) {
          SonixLogger.error('decoder.decode() failed', decodeError);
          rethrow; // Re-throw to be handled by outer catch block
        }
      }

      // Check for cancellation after decoding
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      // Step 3: Generate waveform from audio data

      // Check for cancellation before waveform generation
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
      }

      final waveformData = await WaveformGenerator.generateInMemory(audioData, config: request.config);

      // Check for cancellation after waveform generation
      if (operation.isCancelled) {
        _sendCancellationResponse(mainSendPort, request.id);
        return;
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
  } catch (error, stackTrace) {
    SonixLogger.error('Caught error in main processing', error, stackTrace);
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

/// Send an error response back to the main isolate
void _sendErrorResponse(SendPort mainSendPort, String requestId, Object error) {
  String errorMessage;
  String errorType;

  if (error is SonixException) {
    errorMessage = error.message;
    errorType = error.runtimeType.toString();

    // Add backend information for debugging FFMPEG-related errors
    if (error is FFIException && error.message.contains('FFMPEG')) {
      errorMessage += ' (Backend: ${NativeAudioBindings.backendType})';
    }
  } else {
    errorMessage = error.toString();
    errorType = 'UnknownError';

    // Check if this might be an FFMPEG-related error
    if (errorMessage.contains('FFMPEG') || errorMessage.contains('ffmpeg')) {
      errorType = 'FFMPEGError';
      errorMessage += ' (Backend: ${NativeAudioBindings.backendType})';
    }
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
  _ActiveOperation operation,
) async {
  // Initialize decoder for chunked processing
  await decoder.initializeChunkedDecoding(filePath);

  // Check for cancellation after initialization
  if (operation.isCancelled) {
    throw Exception('Operation cancelled during selective decoder initialization');
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

  // Calculate how many sample positions we need
  final resolution = config.resolution;

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
    } catch (e) {
      // Add a zero amplitude for failed positions (silently handle errors)
      amplitudes.add(0.0);
    }
  }

  // Cleanup decoder resources
  await decoder.cleanupChunkedProcessing();

  return AudioData(samples: amplitudes, sampleRate: sampleRate, channels: channels, duration: estimatedDuration);
}

/// Cleanup FFMPEG resources when isolate shuts down
void _cleanupIsolateResources() {
  try {
    // Cleanup FFMPEG context in this isolate
    NativeAudioBindings.cleanup();
  } catch (e) {
    // Ignore cleanup errors during shutdown
  }
}
