/// Simple isolate runner for waveform generation
///
/// Provides a straightforward way to run waveform generation in a single
/// background isolate without the complexity of a pool.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/processing/audio_file_processor.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';

/// Runs waveform generation in a background isolate
///
/// This class provides a simple way to offload audio processing to a
/// background isolate, preventing UI thread blocking.
///
/// Example:
/// ```dart
/// final runner = IsolateRunner();
/// final waveformData = await runner.run(
///   'audio.mp3',
///   WaveformConfig(resolution: 1000),
/// );
/// ```
class IsolateRunner {
  /// Creates a new isolate runner
  const IsolateRunner();

  /// Runs waveform generation in a background isolate
  ///
  /// Spawns a new isolate, processes the audio file, generates waveform data,
  /// and returns the result. The isolate is automatically cleaned up after
  /// processing completes.
  ///
  /// [filePath] - Path to the audio file to process
  /// [config] - Configuration for waveform generation
  ///
  /// Returns [WaveformData] containing the generated waveform
  ///
  /// Throws [IsolateSpawnException] if the isolate fails to spawn
  /// Throws [SonixException] subclasses for processing errors
  Future<WaveformData> run(String filePath, WaveformConfig config) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final completer = Completer<WaveformData>();

    void cleanup(Isolate? isolate) {
      receivePort.close();
      errorPort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }

    // Spawn the isolate with error and exit handlers
    late Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _IsolateEntryPoint.process,
        _IsolateParams(
          filePath: filePath,
          config: config,
          sendPort: receivePort.sendPort,
        ),
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );
    } catch (e) {
      cleanup(null);
      throw IsolateSpawnException('Failed to spawn processing isolate: $e');
    }

    // Handle errors from the isolate
    errorPort.listen((message) {
      if (!completer.isCompleted) {
        cleanup(isolate);
        if (message is List && message.length >= 2) {
          completer.completeError(
            IsolateProcessingException(
              'isolate_error',
              message[0].toString(),
              details: message[1]?.toString(),
            ),
          );
        } else {
          completer.completeError(
            IsolateProcessingException(
              'isolate_error',
              'Unknown error from isolate: $message',
            ),
          );
        }
      }
    });

    // Handle isolate exit without sending a result
    exitPort.listen((message) {
      if (!completer.isCompleted) {
        cleanup(isolate);
        completer.completeError(
          IsolateProcessingException(
            'isolate_exit',
            'Isolate exited unexpectedly without sending a result',
          ),
        );
      }
    });

    // Listen for the result
    receivePort.listen((message) {
      if (completer.isCompleted) return;

      cleanup(isolate);

      if (message is _IsolateSuccess) {
        completer.complete(message.waveformData);
      } else if (message is _IsolateError) {
        completer.completeError(
          _ErrorReconstructor.reconstruct(message),
          message.stackTrace != null
              ? StackTrace.fromString(message.stackTrace!)
              : null,
        );
      } else {
        completer.completeError(
          IsolateProcessingException(
            'unknown',
            'Unexpected message type from isolate: ${message.runtimeType}',
          ),
        );
      }
    });

    return completer.future;
  }
}

/// Parameters passed to the isolate
class _IsolateParams {
  final String filePath;
  final WaveformConfig config;
  final SendPort sendPort;

  const _IsolateParams({
    required this.filePath,
    required this.config,
    required this.sendPort,
  });
}

/// Result types from isolate processing
sealed class _IsolateResult {}

class _IsolateSuccess extends _IsolateResult {
  final WaveformData waveformData;
  _IsolateSuccess(this.waveformData);
}

class _IsolateError extends _IsolateResult {
  final String errorType;
  final String message;
  final String? details;
  final String? stackTrace;

  _IsolateError({
    required this.errorType,
    required this.message,
    this.details,
    this.stackTrace,
  });
}

/// Entry point for the processing isolate
class _IsolateEntryPoint {
  _IsolateEntryPoint._();

  /// Main entry point called by Isolate.spawn
  static void process(_IsolateParams params) {
    _processAsync(params).then((result) {
      params.sendPort.send(result);
    });
  }

  /// Async processing logic
  static Future<_IsolateResult> _processAsync(_IsolateParams params) async {
    try {
      // Initialize native bindings in this isolate context
      NativeAudioBindings.initialize();

      if (!NativeAudioBindings.isFFMPEGAvailable) {
        return _IsolateError(
          errorType: 'FFIException',
          message: 'FFMPEG not available in isolate',
          details:
              'FFMPEG libraries are required but not available in this isolate context. '
              'Please install system FFmpeg (on macOS via Homebrew: brew install ffmpeg).',
        );
      }

      // Decode audio
      final processor = AudioFileProcessor();
      final AudioData audioData = await processor.process(params.filePath);

      // Generate waveform
      final waveformData = await WaveformGenerator.generateInMemory(
        audioData,
        config: params.config,
      );

      // Cleanup before returning
      NativeAudioBindings.cleanup();

      return _IsolateSuccess(waveformData);
    } catch (error, stackTrace) {
      // Attempt cleanup even on error
      try {
        NativeAudioBindings.cleanup();
      } catch (_) {}

      return _IsolateError(
        errorType: error.runtimeType.toString(),
        message: error is SonixException ? error.message : error.toString(),
        details: error is SonixException ? error.details : null,
        stackTrace: stackTrace.toString(),
      );
    }
  }
}

/// Reconstructs exceptions from isolate error data
class _ErrorReconstructor {
  _ErrorReconstructor._();

  static SonixException reconstruct(_IsolateError error) {
    return switch (error.errorType) {
      'UnsupportedFormatException' => UnsupportedFormatException(
          error.message,
          error.details,
        ),
      'DecodingException' => DecodingException(error.message, error.details),
      'MemoryException' => MemoryException(error.message, error.details),
      'FileAccessException' => FileAccessException(
          '',
          error.message,
          error.details,
        ),
      'FileNotFoundException' => FileNotFoundException('', error.details),
      'CorruptedFileException' => CorruptedFileException('', error.details),
      'FFIException' => FFIException(error.message, error.details),
      _ => IsolateProcessingException(
          'unknown',
          error.message,
          details: error.details,
        ),
    };
  }
}

/// Exception thrown when isolate spawning fails
class IsolateSpawnException extends SonixException {
  IsolateSpawnException(super.message, [super.details]);

  @override
  String toString() =>
      'IsolateSpawnException: $message${details != null ? ' ($details)' : ''}';
}
