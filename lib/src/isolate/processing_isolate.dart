import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'isolate_messages.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/chunked_audio_decoder.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/downsampling_algorithm.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
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
            'Run: dart run tool/download_ffmpeg_binaries.dart',
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

/// Process large files using native chunked decoder with proper seeking
///
/// This method uses the native FFmpeg-based chunked decoder which:
/// 1. Properly handles encoder delay skipping
/// 2. Seeks accurately to time positions
/// 3. Decodes from proper frame boundaries
/// 4. Works correctly with all compressed formats (MP3, Opus, AAC, etc.)
///
/// The previous implementation tried to read arbitrary byte positions,
/// which doesn't work for compressed audio formats.
Future<AudioData> _processWithSelectiveDecoding(
  ChunkedAudioDecoder decoder,
  String filePath,
  WaveformConfig config,
  SendPort mainSendPort,
  String requestId,
  _ActiveOperation operation,
) async {
  // Import native bindings for direct access to chunked decoder
  final format = _detectAudioFormat(filePath);

  // Initialize native chunked decoder
  final filePathNative = filePath.toNativeUtf8();
  final nativeDecoder = SonixNativeBindings.initChunkedDecoder(format, filePathNative.cast());

  if (nativeDecoder.address == 0) {
    malloc.free(filePathNative);
    throw DecodingException('Failed to initialize native chunked decoder', 'Could not initialize native decoder for $filePath');
  }

  try {
    // Get file metadata to get ACCURATE duration from FFmpeg
    final file = File(filePath);
    final fileSize = await file.length();

    int sampleRate = 44100; // Default
    int channels = 2; // Default
    Duration? actualDuration; // Nullable until we get it from ffprobe or estimation

    // Get accurate duration using ffprobe (FFmpeg's metadata tool)
    // This is fast and doesn't require decoding
    try {
      final result = await Process.run('ffprobe', ['-v', 'quiet', '-print_format', 'json', '-show_format', '-show_streams', filePath]);

      if (result.exitCode == 0) {
        final jsonOutput = result.stdout as String;
        final data = jsonDecode(jsonOutput) as Map<String, dynamic>;

        // Get duration from format section
        if (data.containsKey('format')) {
          final formatData = data['format'] as Map<String, dynamic>;
          if (formatData.containsKey('duration')) {
            final durationSeconds = double.parse(formatData['duration'] as String);
            actualDuration = Duration(milliseconds: (durationSeconds * 1000).round());
          }
        }

        // Get sample rate and channels from streams
        if (data.containsKey('streams')) {
          final streams = data['streams'] as List;
          for (final stream in streams) {
            if (stream is Map<String, dynamic> && stream['codec_type'] == 'audio') {
              if (stream.containsKey('sample_rate')) {
                sampleRate = int.parse(stream['sample_rate'] as String);
              }
              if (stream.containsKey('channels')) {
                channels = stream['channels'] as int;
              }
              break;
            }
          }
        }
      } else {
        // ffprobe failed, fall back to estimation
        throw Exception('ffprobe failed');
      }
    } catch (e) {
      // If ffprobe fails, use more conservative estimate
      SonixLogger.debug('ffprobe failed, using file size estimation: $e');
      int estimatedBitrate;
      switch (format) {
        case 1: // MP3
          estimatedBitrate = 192000; // 192kbps average for MP3
          break;
        case 5: // Opus
          estimatedBitrate = 96000; // 96kbps average for Opus
          break;
        case 6: // MP4/AAC
          estimatedBitrate = 192000; // 192kbps average for AAC
          break;
        case 4: // OGG Vorbis
          estimatedBitrate = 160000; // 160kbps average for Vorbis
          break;
        default:
          estimatedBitrate = 128000; // Conservative fallback
      }

      final estimatedSeconds = (fileSize * 8) / estimatedBitrate;
      actualDuration = Duration(milliseconds: (estimatedSeconds * 1000).round());
    }

    // Ensure we have a duration (shouldn't happen, but defensive)
    actualDuration ??= Duration(seconds: 180);

    // Calculate resolution and sample positions
    final resolution = config.resolution;
    final amplitudes = <double>[];
    final durationMs = actualDuration.inMilliseconds;

    for (int i = 0; i < resolution; i++) {
      // Check for cancellation
      if (operation.isCancelled) {
        throw Exception('Operation cancelled during selective processing');
      }

      try {
        // Calculate time position for this waveform point
        final progress = resolution <= 1 ? 0.5 : i / (resolution - 1);
        final timePositionMs = (durationMs * progress).round();

        // Seek to this time position using native decoder
        // This properly handles frame boundaries and codec quirks
        final seekResult = SonixNativeBindings.seekToTime(nativeDecoder, timePositionMs);

        if (seekResult != 0) {
          // 0 = success in native code
          // Seek failed, use zero amplitude
          amplitudes.add(0.0);
          continue;
        }

        // Process a chunk at this position
        final chunkPtr = malloc<SonixFileChunk>();
        chunkPtr.ref.chunk_index = i;
        chunkPtr.ref.start_byte = 0; // Not used after seeking
        chunkPtr.ref.end_byte = 0; // Not used after seeking

        try {
          final result = SonixNativeBindings.processFileChunk(nativeDecoder, chunkPtr);

          double amplitude = 0.0;
          if (result.address != 0) {
            final resultData = result.ref;
            if (resultData.success == 1 && resultData.audio_data.address != 0) {
              final audioData = resultData.audio_data.ref;
              final sampleCount = audioData.sample_count;

              if (sampleCount > 0 && audioData.samples.address != 0) {
                // Extract samples and calculate amplitude
                final samples = audioData.samples.asTypedList(sampleCount);

                // Calculate amplitude based on algorithm
                if (config.algorithm == DownsamplingAlgorithm.rms) {
                  double sum = 0.0;
                  for (int j = 0; j < sampleCount; j++) {
                    final sample = samples[j];
                    sum += sample * sample;
                  }
                  amplitude = math.sqrt(sum / sampleCount);
                } else if (config.algorithm == DownsamplingAlgorithm.peak) {
                  double peak = 0.0;
                  for (int j = 0; j < sampleCount; j++) {
                    final abs = samples[j].abs();
                    if (abs > peak) peak = abs;
                  }
                  amplitude = peak;
                } else if (config.algorithm == DownsamplingAlgorithm.average) {
                  double sum = 0.0;
                  for (int j = 0; j < sampleCount; j++) {
                    sum += samples[j].abs();
                  }
                  amplitude = sum / sampleCount;
                } else {
                  // Default to RMS
                  double sum = 0.0;
                  for (int j = 0; j < sampleCount; j++) {
                    final sample = samples[j];
                    sum += sample * sample;
                  }
                  amplitude = math.sqrt(sum / sampleCount);
                }
              }
            }

            SonixNativeBindings.freeChunkResult(result);
          }

          amplitudes.add(amplitude);
        } finally {
          malloc.free(chunkPtr);
        }
      } catch (e) {
        SonixLogger.debug('Failed to decode at position $i: $e');
        amplitudes.add(0.0);
      }
    }

    return AudioData(samples: amplitudes, sampleRate: sampleRate, channels: channels, duration: actualDuration);
  } finally {
    // Always cleanup the native decoder
    SonixNativeBindings.cleanupChunkedDecoder(nativeDecoder);
    malloc.free(filePathNative);
  }
}

/// Detect audio format from file extension
int _detectAudioFormat(String filePath) {
  final extension = filePath.toLowerCase().split('.').last;
  switch (extension) {
    case 'mp3':
      return 1; // SONIX_FORMAT_MP3
    case 'wav':
      return 2; // SONIX_FORMAT_WAV
    case 'flac':
      return 3; // SONIX_FORMAT_FLAC
    case 'ogg':
      return 4; // SONIX_FORMAT_OGG
    case 'opus':
      return 5; // SONIX_FORMAT_OPUS
    case 'm4a':
    case 'mp4':
    case 'aac':
      return 6; // SONIX_FORMAT_MP4
    default:
      return 0; // SONIX_FORMAT_UNKNOWN
  }
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
