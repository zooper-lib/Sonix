# Sonix Examples

This directory contains comprehensive examples demonstrating the chunked audio processing capabilities of the Sonix package. These examples showcase how to efficiently process large audio files using memory-aware chunked processing.

## Example Applications

### Basic Examples

#### 1. Basic Usage Example (`basic_usage_example.dart`)
- Simple waveform generation and display
- Demonstrates the core API usage
- Shows basic error handling

#### 2. Playback Position Example (`playback_position_example.dart`)
- Interactive waveform with playback visualization
- Demonstrates seeking and position tracking
- Shows how to implement playback controls

#### 3. Style Customization Example (`style_customization_example.dart`)
- Explore different visual styles and options
- Demonstrates waveform styling capabilities
- Shows preset styles and custom styling

#### 4. Pre-generated Data Example (`pre_generated_data_example.dart`)
- Using pre-computed waveform data
- Demonstrates data serialization and caching
- Shows performance optimization techniques

### Chunked Processing Examples

#### 5. Large File Processing Example (`chunked_large_file_example.dart`)
**Demonstrates:** Chunked processing for large audio files (100MB+)

**Key Features:**
- Automatic chunked processing for large files
- Memory usage monitoring and reporting
- Performance comparison with traditional processing
- Real-time progress tracking
- Error recovery and continuation
- Configurable chunk sizes and memory limits

**Requirements Addressed:** 1.1, 1.2, 1.3, 4.1, 4.2

#### 6. Progress Reporting Example (`chunked_progress_example.dart`)
**Demonstrates:** Comprehensive progress reporting during chunked processing

**Key Features:**
- Real-time progress percentage and chunk counting
- Time estimation and throughput calculation
- Memory usage monitoring
- Error tracking and recovery
- Animated progress indicators
- Performance metrics display

**Requirements Addressed:** 10.1, 10.2, 10.4, 10.5, 10.6

#### 7. Seeking & Partial Waveform Example (`seeking_partial_waveform_example.dart`)
**Demonstrates:** Efficient seeking and partial waveform generation

**Key Features:**
- Generate waveforms for specific audio sections
- Efficient seeking within large files
- Section presets and bookmarking
- Performance comparison between full and partial processing
- Interactive time range selection
- Multiple section management

**Requirements Addressed:** 10.1, 10.2, 10.4, 10.5, 10.6

#### 8. Memory Efficient Example (`memory_efficient_example.dart`)
**Demonstrates:** Memory-efficient processing for resource-constrained devices

**Key Features:**
- Multiple processing methods (standard, chunked, streaming, adaptive)
- Memory usage monitoring and optimization
- Configurable memory limits
- Cache management and cleanup
- Platform-specific optimizations
- Resource statistics tracking

**Requirements Addressed:** 10.1, 10.2, 10.4, 10.5, 10.6

#### 9. Performance Comparison Example (`performance_comparison_example.dart`)
**Demonstrates:** Benchmarking different processing methods

**Key Features:**
- Comprehensive performance benchmarks
- Memory usage comparison
- Accuracy testing between methods
- Scalability analysis with different file sizes
- Throughput and efficiency metrics
- Automated test suite with configurable parameters

**Requirements Addressed:** 10.1, 10.2, 10.4, 10.5, 10.6

## Running the Examples

1. **Setup:**
   ```bash
   cd example
   flutter pub get
   ```

2. **Run the example app:**
   ```bash
   flutter run
   ```

3. **Select an example** from the main menu to explore specific functionality.

## Key Concepts Demonstrated

### Chunked Processing Benefits

1. **Memory Efficiency:**
   - Consistent memory usage regardless of file size
   - Process files larger than available RAM
   - Automatic memory pressure detection and response

2. **Performance:**
   - Real-time progress reporting
   - Concurrent chunk processing
   - Optimized for different file sizes and platforms

3. **Reliability:**
   - Error recovery for corrupted chunks
   - Graceful degradation under memory pressure
   - Robust error handling and reporting

4. **Flexibility:**
   - Configurable chunk sizes and processing parameters
   - Multiple processing strategies (adaptive, streaming, etc.)
   - Platform-specific optimizations

### Configuration Examples

#### Automatic Configuration
```dart
// Automatically optimized for file size
final config = ChunkedProcessingConfig.forFileSize(fileSize);
```

#### Custom Configuration
```dart
final config = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024, // 10MB chunks
  maxMemoryUsage: 100 * 1024 * 1024, // 100MB limit
  maxConcurrentChunks: 3,
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 100),
);
```

#### Low Memory Device Configuration
```dart
final config = ChunkedProcessingConfig.forLowMemoryDevice(
  fileSize: fileSize,
);
```

### Progress Monitoring

```dart
final waveformData = await Sonix.generateWaveformChunked(
  filePath,
  chunkedConfig: config,
  onProgress: (progress) {
    print('Progress: ${progress.progressPercentage * 100}%');
    print('Chunks: ${progress.processedChunks}/${progress.totalChunks}');
    print('ETA: ${progress.estimatedTimeRemaining}');
    
    if (progress.hasErrors) {
      print('Error in chunk: ${progress.lastError}');
    }
  },
);
```

### Memory Management

```dart
// Monitor resource usage
final stats = Sonix.getResourceStatistics();
print('Memory usage: ${stats.memoryUsagePercentage * 100}%');

// Force cleanup when needed
await Sonix.forceCleanup();

// Clear specific files from cache
Sonix.clearFileFromCaches(filePath);
```

## Testing Large Files

The examples include functionality to test with various file sizes:

- **Small files (1-10MB):** Basic functionality testing
- **Medium files (10-100MB):** Performance comparison
- **Large files (100MB-1GB):** Memory efficiency validation
- **Very large files (1GB+):** Scalability testing

## Platform Considerations

The examples demonstrate platform-specific optimizations:

- **Mobile devices:** Conservative memory usage, smaller chunk sizes
- **Desktop platforms:** Larger chunks, more concurrent processing
- **Low-memory devices:** Adaptive chunk sizing, memory pressure handling

## Error Handling Strategies

The examples showcase different error recovery approaches:

1. **Skip and Continue:** Process remaining chunks despite errors
2. **Retry with Smaller Chunks:** Reduce chunk size for problematic sections
3. **Seek to Next Boundary:** Skip corrupted sections and continue
4. **Fail Fast:** Stop processing on first error

## Performance Optimization Tips

Based on the examples, here are key optimization strategies:

1. **File Size Based Configuration:**
   - Use `ChunkedProcessingConfig.forFileSize()` for automatic optimization
   - Adjust chunk sizes based on available memory

2. **Memory Management:**
   - Monitor memory usage with `getResourceStatistics()`
   - Use `forceCleanup()` when memory is constrained
   - Enable memory pressure detection for automatic adjustment

3. **Progress Reporting:**
   - Use appropriate update intervals (50-200ms)
   - Batch progress updates to avoid UI flooding

4. **Error Recovery:**
   - Enable error recovery for better user experience
   - Log errors for debugging while continuing processing

5. **Platform Adaptation:**
   - Use platform-specific configurations
   - Adjust concurrency based on device capabilities

## Contributing

When adding new examples:

1. Follow the existing naming convention
2. Include comprehensive documentation
3. Demonstrate specific chunked processing features
4. Add appropriate error handling
5. Update this README with the new example

## Requirements Mapping

Each example addresses specific requirements from the chunked processing specification:

- **Requirement 10.1:** Clear documentation and guidance
- **Requirement 10.2:** Code examples for common scenarios
- **Requirement 10.3:** Troubleshooting and debugging guidance
- **Requirement 10.4:** Platform-specific recommendations
- **Requirement 10.5:** Migration guides and compatibility information
- **Requirement 10.6:** Best practices and configuration examples