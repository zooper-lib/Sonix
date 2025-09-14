/// Main API for the Sonix audio waveform library
///
/// This file provides the core SonixInstance class and SonixConfig for
/// instance-based audio processing with isolate support.
library;

import 'dart:async';
import 'dart:io';

import 'isolate/isolate_manager.dart';
import 'models/waveform_data.dart';
import 'processing/waveform_generator.dart';
import 'decoders/audio_decoder_factory.dart';
import 'exceptions/sonix_exceptions.dart';

/// Configuration class for Sonix instances
///
/// Provides configuration options for isolate management and memory usage.
class SonixConfig implements IsolateConfig {
  /// Maximum number of concurrent operations
  @override
  final int maxConcurrentOperations;

  /// Size of the isolate pool for background processing
  @override
  final int isolatePoolSize;

  /// Timeout for idle isolates before cleanup
  @override
  final Duration isolateIdleTimeout;

  /// Maximum memory usage in bytes
  @override
  final int maxMemoryUsage;

  /// Whether to enable caching (for future use)
  final bool enableCaching;

  /// Maximum cache size (for future use)
  final int maxCacheSize;

  /// Whether to enable progress reporting
  final bool enableProgressReporting;

  const SonixConfig({
    this.maxConcurrentOperations = 3,
    this.isolatePoolSize = 2,
    this.isolateIdleTimeout = const Duration(minutes: 5),
    this.maxMemoryUsage = 100 * 1024 * 1024, // 100MB
    this.enableCaching = true,
    this.maxCacheSize = 50,
    this.enableProgressReporting = true,
  });

  /// Create a default configuration
  factory SonixConfig.defaultConfig() => const SonixConfig();

  /// Create a configuration optimized for mobile devices
  factory SonixConfig.mobile() => const SonixConfig(
    maxConcurrentOperations: 2,
    isolatePoolSize: 1,
    maxMemoryUsage: 50 * 1024 * 1024, // 50MB
  );

  /// Create a configuration optimized for desktop devices
  factory SonixConfig.desktop() => const SonixConfig(
    maxConcurrentOperations: 4,
    isolatePoolSize: 3,
    maxMemoryUsage: 200 * 1024 * 1024, // 200MB
  );

  @override
  String toString() {
    return 'SonixConfig('
        'maxConcurrentOperations: $maxConcurrentOperations, '
        'isolatePoolSize: $isolatePoolSize, '
        'isolateIdleTimeout: $isolateIdleTimeout, '
        'maxMemoryUsage: ${(maxMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB'
        ')';
  }
}

/// Progress information for waveform generation
class WaveformProgress {
  /// Progress percentage (0.0 to 1.0)
  final double progress;

  /// Optional status message describing current operation
  final String? statusMessage;

  /// Partial waveform data for streaming (optional)
  final WaveformData? partialData;

  /// Whether this is the final progress update
  final bool isComplete;

  /// Error message if processing failed
  final String? error;

  const WaveformProgress({required this.progress, this.statusMessage, this.partialData, this.isComplete = false, this.error});
}

/// Main API class for the Sonix package
///
/// This is an instance-based class that ensures all audio processing happens
/// in background isolates, preventing UI thread blocking. Each instance manages
/// its own isolate pool and configuration.
class SonixInstance {
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
  /// final sonix = SonixInstance();
  ///
  /// // Create with custom configuration
  /// final sonix = SonixInstance(SonixConfig.mobile());
  ///
  /// // Create with specific options
  /// final sonix = SonixInstance(SonixConfig(
  ///   maxMemoryUsage: 50 * 1024 * 1024, // 50MB
  /// ));
  /// ```
  SonixInstance([SonixConfig? config]) : config = config ?? SonixConfig.defaultConfig() {
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
  /// final sonix = SonixInstance();
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

  /// Generate waveform data with streaming progress updates
  ///
  /// This method provides real-time progress updates during waveform generation,
  /// which is useful for large files or when you need to show progress to users.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced configuration options (optional)
  ///
  /// Returns a [Stream<WaveformProgress>] that emits progress updates
  ///
  /// Example:
  /// ```dart
  /// final sonix = SonixInstance();
  /// await for (final progress in sonix.generateWaveformStream('large_audio.mp3')) {
  ///   print('Progress: ${(progress.progress * 100).toStringAsFixed(1)}%');
  ///   if (progress.isComplete && progress.partialData != null) {
  ///     // Use the final waveform data
  ///     final waveformData = progress.partialData!;
  ///   }
  /// }
  /// ```
  Stream<WaveformProgress> generateWaveformStream(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
  }) async* {
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

    // Create streaming processing task
    final task = ProcessingTask(id: _generateTaskId(), filePath: filePath, config: waveformConfig, streamResults: true);

    // Track the task for cancellation support
    _activeTasks[task.id] = task;

    // Set up a stream controller to manage the complete streaming flow
    final streamController = StreamController<WaveformProgress>();

    // Handle the task execution and progress updates
    _handleStreamingTask(task, streamController);

    // Return the stream
    yield* streamController.stream;
  }

  /// Handle streaming task execution with proper error handling and progress updates
  Future<void> _handleStreamingTask(ProcessingTask task, StreamController<WaveformProgress> streamController) async {
    try {
      // Listen to progress updates from the task
      final progressSubscription = task.progressStream?.listen(
        (update) {
          if (!streamController.isClosed) {
            streamController.add(
              WaveformProgress(progress: update.progress, statusMessage: update.statusMessage, partialData: update.partialData, isComplete: false),
            );
          }
        },
        onError: (error) {
          if (!streamController.isClosed) {
            streamController.add(WaveformProgress(progress: task.progressStream?.isBroadcast == true ? 1.0 : 0.0, error: error.toString(), isComplete: true));
            streamController.close();
          }
        },
      );

      // Execute the task
      final result = await _isolateManager.executeTask(task);

      // Send final result
      if (!streamController.isClosed) {
        streamController.add(WaveformProgress(progress: 1.0, partialData: result, isComplete: true, statusMessage: 'Waveform generation complete'));
        streamController.close();
      }

      // Clean up subscription
      await progressSubscription?.cancel();
    } catch (error) {
      // Handle execution errors
      if (!streamController.isClosed) {
        streamController.add(WaveformProgress(progress: 1.0, error: error.toString(), isComplete: true));
        streamController.close();
      }
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
  /// final sonix = SonixInstance();
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
  /// final sonix = SonixInstance();
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
  /// final sonix = SonixInstance();
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
  /// final sonix = SonixInstance();
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
  /// final sonix = SonixInstance();
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
  /// final sonix = SonixInstance();
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
}

/// Backward compatibility wrapper for the Sonix package
///
/// This class provides static methods that maintain backward compatibility
/// with existing code while internally using SonixInstance for processing.
///
/// For new code, prefer using SonixInstance directly for better control
/// and configuration options.
class Sonix {
  static SonixInstance? _defaultInstance;

  /// Initialize Sonix with optional configuration
  ///
  /// This method initializes the default static Sonix instance for backward compatibility.
  /// For new code, consider using `SonixInstance()` constructor to create instance-based objects.
  ///
  /// [config] - Configuration for the default instance
  ///
  /// This should be called once at the start of your application.
  ///
  /// Example:
  /// ```dart
  /// Sonix.initialize(); // Uses default configuration
  /// // Or set a custom configuration:
  /// // Sonix.initialize(SonixConfig.mobile());
  /// ```
  static Future<void> initialize([SonixConfig? config]) async {
    if (_defaultInstance != null) {
      return; // Already initialized
    }

    _defaultInstance = SonixInstance(config);
    await _defaultInstance!.initialize();
  }

  /// Check if a specific audio format is supported
  ///
  /// This is a utility method that doesn't require a SonixInstance.
  /// It checks format support based on file extension or content.
  ///
  /// Example:
  /// ```dart
  /// if (Sonix.isFormatSupported('audio.mp3')) {
  ///   // Process the file
  /// }
  /// ```
  static bool isFormatSupported(String filePath) {
    return AudioDecoderFactory.isFormatSupported(filePath);
  }

  /// Get a list of supported audio format names
  ///
  /// This is a utility method that doesn't require a SonixInstance.
  /// Returns human-readable format names like ['MP3', 'WAV', 'FLAC'].
  ///
  /// Example:
  /// ```dart
  /// final formats = Sonix.getSupportedFormats();
  /// print('Supported: ${formats.join(', ')}');
  /// ```
  static List<String> getSupportedFormats() {
    return AudioDecoderFactory.getSupportedFormatNames();
  }

  /// Get a list of supported file extensions
  ///
  /// This is a utility method that doesn't require a SonixInstance.
  /// Returns file extensions like ['mp3', 'wav', 'flac'].
  ///
  /// Example:
  /// ```dart
  /// final extensions = Sonix.getSupportedExtensions();
  /// print('Extensions: ${extensions.join(', ')}');
  /// ```
  static List<String> getSupportedExtensions() {
    return AudioDecoderFactory.getSupportedExtensions();
  }

  /// Check if a specific file extension is supported
  ///
  /// This is a utility method that doesn't require a SonixInstance.
  /// Accepts extensions with or without leading dot, case-insensitive.
  ///
  /// Example:
  /// ```dart
  /// if (Sonix.isExtensionSupported('mp3')) {
  ///   // Extension is supported
  /// }
  /// ```
  static bool isExtensionSupported(String extension) {
    // Normalize the extension
    String normalizedExt = extension.toLowerCase();
    if (normalizedExt.startsWith('.')) {
      normalizedExt = normalizedExt.substring(1);
    }

    return AudioDecoderFactory.getSupportedExtensions().contains(normalizedExt);
  }

  /// Get optimal configuration for different use cases
  ///
  /// This is a utility method that doesn't require a SonixInstance.
  /// Returns optimized WaveformConfig for specific use cases.
  ///
  /// Example:
  /// ```dart
  /// final config = Sonix.getOptimalConfig(
  ///   useCase: WaveformUseCase.musicVisualization,
  ///   customResolution: 2000
  /// );
  /// ```
  static WaveformConfig getOptimalConfig({required WaveformUseCase useCase, int? customResolution}) {
    return WaveformGenerator.getOptimalConfig(useCase: useCase, customResolution: customResolution);
  }

  /// Dispose of all Sonix resources
  static Future<void> dispose() async {
    if (_defaultInstance != null) {
      await _defaultInstance!.dispose();
      _defaultInstance = null;
    }
  }
}
