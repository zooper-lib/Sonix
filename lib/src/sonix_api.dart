/// Main API for the Sonix audio waveform library
///
/// This file provides the core Sonix class for
/// instance-based audio processing with isolate support.
library;

import 'dart:async';
import 'dart:io';

import 'config/sonix_config.dart';
import 'isolate/isolate_manager.dart';
import 'models/waveform_data.dart';
import 'models/waveform_type.dart';
import 'processing/waveform_generator.dart';
import 'processing/waveform_config.dart';
import 'processing/waveform_use_case.dart';
import 'decoders/audio_decoder_factory.dart';
import 'exceptions/sonix_exceptions.dart';
import 'native/native_audio_bindings.dart';

/// Main API class for the Sonix package
///
/// This is an instance-based class that ensures all audio processing happens
/// in background isolates, preventing UI thread blocking. Each instance manages
/// its own isolate pool and configuration.
class Sonix {
  /// Configuration for this Sonix instance
  final SonixConfig config;

  /// Isolate manager for background processing
  late final IsolateManager _isolateManager;

  /// Whether this instance has been disposed
  bool _isDisposed = false;

  /// Whether this instance has been initialized
  bool _isInitialized = false;

  /// Map of active tasks for cancellation support
  final Map<String, ProcessingTask> _activeTasks = {};

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
    _isolateManager = createIsolateManager();
  }

  /// Create the isolate manager - can be overridden for testing
  IsolateManager createIsolateManager() {
    return IsolateManager(config);
  }

  /// Initialize this Sonix instance
  ///
  /// This method sets up the isolate manager and prepares the instance for use.
  /// It's automatically called when needed, but can be called explicitly for
  /// better control over initialization timing.
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed Sonix instance');
    }

    if (_isInitialized) {
      return; // Already initialized
    }

    await _isolateManager.initialize();
    _isInitialized = true;
  }

  /// Generate waveform data from an audio file
  ///
  /// This method processes audio in background isolates to prevent UI thread blocking.
  /// It automatically handles file format detection and optimal processing strategies.
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
    await _ensureInitialized();

    // Validate file format
    if (!AudioDecoderFactory.isFormatSupported(filePath)) {
      final extension = _getFileExtension(filePath);
      throw UnsupportedFormatException(
        extension,
        'Unsupported audio format: $extension. Supported formats: ${AudioDecoderFactory.getSupportedFormatNames().join(', ')}',
      );
    }

    // Create waveform configuration
    final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

    // Create processing task
    final task = ProcessingTask(id: _generateTaskId(), filePath: filePath, config: waveformConfig);

    // Track the task for cancellation support
    _activeTasks[task.id] = task;

    try {
      // Execute task in background isolate
      final result = await _isolateManager.executeTask(task);
      return result;
    } finally {
      // Remove task from active tasks when complete
      _activeTasks.remove(task.id);
    }
  }

  /// Get resource statistics for this Sonix instance
  ///
  /// Returns detailed information about current memory usage, isolate statistics,
  /// active operations, and other resource metrics for this specific instance.
  ///
  /// Throws [StateError] if this instance has been disposed.
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// final stats = sonix.getResourceStatistics();
  /// print('Active isolates: ${stats.activeIsolates}');
  /// print('Completed tasks: ${stats.completedTasks}');
  /// ```
  IsolateStatistics getResourceStatistics() {
    _ensureNotDisposed();
    return _isolateManager.getStatistics();
  }

  /// Optimize resource usage for this instance
  ///
  /// This method performs cleanup of idle isolates and optimizes memory usage.
  /// It's automatically called periodically, but can be called manually when needed.
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// sonix.optimizeResources(); // Clean up idle resources
  /// ```
  void optimizeResources() {
    if (!_isDisposed && _isInitialized) {
      _isolateManager.optimizeResources();
    }
  }

  /// Cancel a specific operation by task ID
  ///
  /// This method cancels a specific waveform generation operation that is
  /// currently in progress. The operation will be stopped and resources cleaned up.
  ///
  /// [taskId] - The ID of the task to cancel
  ///
  /// Returns true if the task was found and cancelled, false if the task
  /// was not found (already completed or never existed).
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// final taskId = 'my_task_id';
  /// final cancelled = sonix.cancelOperation(taskId);
  /// if (cancelled) {
  ///   print('Operation cancelled successfully');
  /// }
  /// ```
  bool cancelOperation(String taskId) {
    _ensureNotDisposed();

    final task = _activeTasks[taskId];
    if (task != null) {
      task.cancel();
      _activeTasks.remove(taskId);
      return true;
    }
    return false;
  }

  /// Cancel all active operations
  ///
  /// This method cancels all currently running waveform generation operations
  /// for this instance. All operations will be stopped and resources cleaned up.
  ///
  /// Returns the number of operations that were cancelled.
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// final cancelledCount = sonix.cancelAllOperations();
  /// print('Cancelled $cancelledCount operations');
  /// ```
  int cancelAllOperations() {
    _ensureNotDisposed();

    final taskIds = _activeTasks.keys.toList();
    for (final taskId in taskIds) {
      final task = _activeTasks[taskId];
      if (task != null) {
        task.cancel();
      }
    }

    final cancelledCount = _activeTasks.length;
    _activeTasks.clear();
    return cancelledCount;
  }

  /// Get a list of active operation IDs
  ///
  /// Returns a list of task IDs for operations that are currently in progress.
  /// This can be useful for tracking and managing active operations.
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// final activeOperations = sonix.getActiveOperations();
  /// print('Active operations: ${activeOperations.length}');
  /// ```
  List<String> getActiveOperations() {
    _ensureNotDisposed();
    return _activeTasks.keys.toList();
  }

  /// Dispose of this Sonix instance and clean up all associated resources
  ///
  /// This method cleans up all resources associated with this specific instance,
  /// including background isolates, active tasks, and memory allocations.
  /// After calling dispose, this instance cannot be used for any operations.
  ///
  /// Example:
  /// ```dart
  /// final sonix = Sonix();
  /// // ... use sonix for operations
  /// await sonix.dispose(); // Clean up when done
  /// ```
  Future<void> dispose() async {
    if (_isDisposed) {
      return; // Already disposed
    }

    // Cancel all active operations before setting disposed flag
    final taskIds = _activeTasks.keys.toList();
    for (final taskId in taskIds) {
      final task = _activeTasks[taskId];
      if (task != null) {
        task.cancel();
      }
    }
    _activeTasks.clear();

    _isDisposed = true;

    if (_isInitialized) {
      await _isolateManager.dispose();
    }
  }

  /// Check if this instance has been disposed
  bool get isDisposed => _isDisposed;

  /// Ensure this instance is initialized
  Future<void> _ensureInitialized() async {
    _ensureNotDisposed();
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Ensure this instance has not been disposed
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('This Sonix instance has been disposed and cannot be used');
    }
  }

  /// Generate a unique task ID
  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}_$hashCode';
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
    return AudioDecoderFactory.isFormatSupported(filePath);
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
    return AudioDecoderFactory.getSupportedFormatNames();
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
    return AudioDecoderFactory.getSupportedExtensions();
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

    return AudioDecoderFactory.getSupportedExtensions().contains(normalizedExt);
  }

  /// Returns optimized waveform configuration for specific use cases.
  ///
  /// This utility method provides pre-tuned configurations that work well
  /// for common waveform visualization scenarios. Each use case has been
  /// optimized for the best balance of quality, performance, and visual appeal.
  ///
  /// **Parameters:**
  /// - [useCase]: The intended use case (see [WaveformUseCase] for options)
  /// - [customResolution]: Optional override for the resolution parameter
  ///
  /// **Returns:** [WaveformConfig] optimized for the specified use case
  ///
  /// ## Available Use Cases
  ///
  /// - `WaveformUseCase.musicVisualization`: For music players and visualizers
  /// - `WaveformUseCase.podcastPlayer`: Optimized for speech content
  /// - `WaveformUseCase.audioEditor`: High detail for editing applications
  /// - `WaveformUseCase.thumbnail`: Low resolution for preview/thumbnail
  /// - `WaveformUseCase.streaming`: Balanced for real-time streaming
  ///
  /// ## Example
  /// ```dart
  /// // Get config for music player
  /// final musicConfig = Sonix.getOptimalConfig(
  ///   useCase: WaveformUseCase.musicVisualization,
  /// );
  ///
  /// // Override resolution for specific needs
  /// final customConfig = Sonix.getOptimalConfig(
  ///   useCase: WaveformUseCase.audioEditor,
  ///   customResolution: 5000, // High detail
  /// );
  ///
  /// // Use with instance API
  /// final sonix = Sonix();
  /// final waveform = await sonix.generateWaveform(
  ///   'audio.mp3',
  ///   config: musicConfig,
  /// );
  /// ```
  ///
  /// **Benefits:** Saves time on configuration tuning and ensures optimal
  /// settings for common scenarios.
  static WaveformConfig getOptimalConfig({required WaveformUseCase useCase, int? customResolution}) {
    return WaveformGenerator.getOptimalConfig(useCase: useCase, customResolution: customResolution);
  }
}
