/// Main API for the Sonix audio waveform library
///
/// This file provides the core Sonix class for
/// instance-based audio processing with isolate support.
library;

import 'dart:async';

import 'config/sonix_config.dart';
import 'isolate/isolate_runner.dart';
import 'models/waveform_data.dart';
import 'models/waveform_type.dart';
import 'processing/waveform_generator.dart';
import 'processing/waveform_config.dart';
import 'processing/waveform_use_case.dart';
import 'processing/audio_file_processor.dart';
import 'decoders/audio_format_service.dart';
import 'exceptions/sonix_exceptions.dart';
import 'native/native_audio_bindings.dart';
import 'utils/sonix_logger.dart';

/// Main API class for the Sonix package
///
/// This is an instance-based class that provides two methods for waveform generation:
///
/// - [generateWaveform]: Processes audio on the main thread. Simple and direct,
///   but blocks the calling thread. Best for small files or non-UI contexts.
///
/// - [generateWaveformInIsolate]: Processes audio in a background isolate to prevent
///   UI thread blocking. Best for large files or Flutter applications where
///   UI responsiveness is important.
class Sonix {
  /// Configuration for this Sonix instance
  final SonixConfig config;

  /// Whether this instance has been disposed
  bool _isDisposed = false;

  /// Create a new Sonix instance with the specified configuration
  ///
  /// [config] - Configuration options for this instance. If not provided,
  /// uses default configuration.
  ///
  /// Example:
  /// ```dart
  /// // Create with default configuration
  /// final sonix = Sonix();
  ///
  /// // Create with custom configuration
  /// final sonix = Sonix(SonixConfig.mobile());
  ///
  /// // Create with specific options
  /// final sonix = Sonix(SonixConfig(
  ///   maxMemoryUsage: 50 * 1024 * 1024, // 50MB
  /// ));
  /// ```
  Sonix([SonixConfig? config]) : config = config ?? SonixConfig.defaultConfig() {
    // Configure FFmpeg log level based on config
    _configureLogLevel(this.config.logLevel);
    // Configure Dart logger to use the same log level
    SonixLogger.setLogLevel(this.config.logLevel);
  }

  /// Generate waveform data from an audio file on the main thread
  ///
  /// This method processes audio directly on the calling thread. It's suitable for
  /// small files or when you need synchronous-like behavior. For large files or
  /// UI applications, consider using [generateWaveformInIsolate] to prevent blocking.
  ///
  /// **Note**: Large files are automatically handled using memory-efficient
  /// chunked processing to avoid memory issues.
  ///
  /// **Warning**: This method will block the calling thread during processing.
  /// For Flutter apps, use [generateWaveformInIsolate] to keep the UI responsive.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced configuration options (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Throws [StateError] if this instance has been disposed
  /// Throws [UnsupportedFormatException] if the audio format is not supported
  /// Throws [DecodingException] if audio decoding fails
  /// Throws [FileSystemException] if the file cannot be accessed
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// final waveformData = await sonix.generateWaveform('audio.mp3');
  /// ```
  Future<WaveformData> generateWaveform(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
  }) async {
    _ensureNotDisposed();

    // Validate file format
    if (!AudioFormatService.isFileSupported(filePath)) {
      final extension = _getFileExtension(filePath);
      throw UnsupportedFormatException(
        extension,
        'Unsupported audio format: $extension. Supported formats: ${AudioFormatService.getSupportedFormatNames().join(', ')}',
      );
    }

    // Create waveform configuration
    final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

    // Use AudioFileProcessor to handle decoding (automatically handles large files)
    final processor = AudioFileProcessor();
    final audioData = await processor.process(filePath);
    final waveformData = await WaveformGenerator.generateInMemory(audioData, config: waveformConfig);
    return waveformData;
  }

  /// Generate waveform data from an audio file in a background isolate
  ///
  /// This method processes audio in a background isolate to prevent UI thread blocking.
  /// It automatically handles file format detection and optimal processing strategies.
  /// Use this method for large files or in UI applications to keep the interface responsive.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced configuration options (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Throws [StateError] if this instance has been disposed
  /// Throws [UnsupportedFormatException] if the audio format is not supported
  /// Throws [DecodingException] if audio decoding fails
  /// Throws [FileSystemException] if the file cannot be accessed
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// final waveformData = await sonix.generateWaveformInIsolate('audio.mp3');
  /// ```
  Future<WaveformData> generateWaveformInIsolate(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
  }) async {
    _ensureNotDisposed();

    // Validate file format
    if (!AudioFormatService.isFileSupported(filePath)) {
      final extension = _getFileExtension(filePath);
      throw UnsupportedFormatException(
        extension,
        'Unsupported audio format: $extension. Supported formats: ${AudioFormatService.getSupportedFormatNames().join(', ')}',
      );
    }

    // Create waveform configuration
    final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

    // Run in a background isolate
    const runner = IsolateRunner();
    return runner.run(filePath, waveformConfig);
  }

  /// Dispose of this Sonix instance
  ///
  /// After calling dispose, this instance cannot be used for any operations.
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// // ... use sonix for operations
  /// sonix.dispose(); // Clean up when done
  /// ```
  void dispose() {
    _isDisposed = true;
  }

  /// Check if this instance has been disposed
  bool get isDisposed => _isDisposed;

  /// Ensure this instance has not been disposed
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('This Sonix instance has been disposed and cannot be used');
    }
  }

  /// Extract file extension from a file path
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1);
  }

  // Static utility methods that don't require an instance

  /// Checks if a specific audio format is supported by the library.
  ///
  /// This utility method determines format support based on file extension
  /// or MIME type. It doesn't require initialization and can be called
  /// independently of any Sonix instance.
  ///
  /// **Parameters:**
  /// - [filePath]: Path to audio file or just the filename with extension
  ///
  /// **Returns:** `true` if the format is supported, `false` otherwise
  ///
  /// **Supported Formats:** MP3, OGG, WAV, FLAC, Opus
  ///
  /// ## Example
  /// ```dart
  /// // Check before processing
  /// if (Sonix.isFormatSupported('audio.mp3')) {
  ///   print('MP3 is supported!');
  ///   // Proceed with processing
  /// } else {
  ///   print('Unsupported format');
  /// }
  ///
  /// // Works with full paths too
  /// final isSupported = Sonix.isFormatSupported('/path/to/song.flac');
  /// ```
  ///
  /// **Use Case:** Validation before file processing, UI filter setup,
  /// or batch operation planning.
  static bool isFormatSupported(String filePath) {
    return AudioFormatService.isFileSupported(filePath);
  }

  /// Configure FFmpeg log level based on the current config
  ///
  /// This is called automatically during Sonix initialization to set up
  /// FFmpeg logging according to the logLevel specified in SonixConfig.
  ///
  /// **Available log levels:**
  /// * `-1` = `QUIET` - No output at all
  /// * `0` = `PANIC` - Only critical errors
  /// * `1` = `FATAL` - Fatal errors
  /// * `2` = `ERROR` - Error conditions (recommended - suppresses MP3 warnings)
  /// * `3` = `WARNING` - Warning messages including MP3 format detection
  /// * `4` = `INFO` - Informational messages
  /// * `5` = `VERBOSE` - Verbose informational messages
  /// * `6` = `DEBUG` - Debug messages with maximum verbosity
  void _configureLogLevel(int level) {
    try {
      NativeAudioBindings.setLogLevel(level);
    } catch (e) {
      throw ConfigurationException('Failed to configure FFmpeg log level: $e');
    }
  }

  /// Returns a list of human-readable audio format names supported by the library.
  ///
  /// This utility method provides format names suitable for display in user
  /// interfaces, error messages, or documentation. The names are capitalized
  /// and standardized (e.g., 'MP3', 'FLAC', 'OGG').
  ///
  /// **Returns:** List of format names like `['MP3', 'WAV', 'FLAC', 'OGG', 'Opus']`
  ///
  /// ## Example
  /// ```dart
  /// // Display supported formats to user
  /// final formats = Sonix.getSupportedFormats();
  /// final formatText = 'Supported formats: ${formats.join(', ')}';
  /// print(formatText); // "Supported formats: MP3, WAV, FLAC, OGG, Opus"
  ///
  /// // Use in file picker dialog
  /// showDialog(
  ///   context: context,
  ///   builder: (context) => AlertDialog(
  ///     title: Text('Select Audio File'),
  ///     content: Text('Supported: ${formats.join(', ')}'),
  ///   ),
  /// );
  /// ```
  ///
  /// **See also:** [getSupportedExtensions] for file extensions
  static List<String> getSupportedFormats() {
    return AudioFormatService.getSupportedFormatNames();
  }

  /// Returns a list of supported file extensions (without dots).
  ///
  /// This utility method provides file extensions that can be used for
  /// file filtering, validation, or building file picker dialogs. All
  /// extensions are lowercase and don't include the leading dot.
  ///
  /// **Returns:** List of extensions like `['mp3', 'wav', 'flac', 'ogg', 'opus']`
  ///
  /// ## Example
  /// ```dart
  /// // Build file picker filter
  /// final extensions = Sonix.getSupportedExtensions();
  /// final filter = extensions.map((ext) => '*.$ext').join(';');
  ///
  /// // Use in file picker
  /// final result = await FilePicker.platform.pickFiles(
  ///   type: FileType.custom,
  ///   allowedExtensions: extensions,
  /// );
  ///
  /// // Validate file extension
  /// bool isValidFile(String filename) {
  ///   final ext = filename.split('.').last.toLowerCase();
  ///   return extensions.contains(ext);
  /// }
  /// ```
  ///
  /// **See also:** [getSupportedFormats] for display names
  static List<String> getSupportedExtensions() {
    return AudioFormatService.getSupportedExtensions();
  }

  /// Checks if a specific file extension is supported by the library.
  ///
  /// This utility method provides flexible extension checking with automatic
  /// normalization. It accepts extensions with or without leading dots and
  /// is case-insensitive for user convenience.
  ///
  /// **Parameters:**
  /// - [extension]: File extension to check (e.g., 'mp3', '.MP3', 'Flac')
  ///
  /// **Returns:** `true` if supported, `false` otherwise
  ///
  /// ## Example
  /// ```dart
  /// // All of these work
  /// print(Sonix.isExtensionSupported('mp3'));    // true
  /// print(Sonix.isExtensionSupported('.MP3'));   // true
  /// print(Sonix.isExtensionSupported('FLAC'));   // true
  /// print(Sonix.isExtensionSupported('.xyz'));   // false
  ///
  /// // Use for file validation
  /// bool validateAudioFile(File file) {
  ///   final extension = file.path.split('.').last;
  ///   if (!Sonix.isExtensionSupported(extension)) {
  ///     throw UnsupportedError('File type not supported: $extension');
  ///   }
  ///   return true;
  /// }
  /// ```
  ///
  /// **See also:** [isFormatSupported] for full file path checking
  static bool isExtensionSupported(String extension) {
    // Normalize the extension
    String normalizedExt = extension.toLowerCase();
    if (normalizedExt.startsWith('.')) {
      normalizedExt = normalizedExt.substring(1);
    }

    return AudioFormatService.getSupportedExtensions().contains(normalizedExt);
  }

  /// Checks whether the FFmpeg backend is available.
  ///
  /// This is a safe helper intended for apps to show setup instructions
  /// (for example, prompting the user to install FFmpeg) without throwing.
  ///
  /// Returns `true` if the native library can be loaded and FFmpeg is
  /// initialized/available, otherwise returns `false`.
  static bool isFFmpegAvailable() {
    return NativeAudioBindings.checkFFMPEGAvailable();
  }

  /// Returns optimized waveform configuration for a specific use case.
  ///
  /// Convenience helper for common UI scenarios. You can always construct a
  /// [WaveformConfig] directly for full control.
  static WaveformConfig getOptimalConfig({required WaveformUseCase useCase, int? customResolution}) {
    return WaveformGenerator.getOptimalConfig(useCase: useCase, customResolution: customResolution);
  }
}
