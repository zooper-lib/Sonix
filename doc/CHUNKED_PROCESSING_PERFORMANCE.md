# Chunked Processing Performance Optimization Guide

Comprehensive guide for optimizing performance when using Sonix's chunked audio processing capabilities.

## Table of Contents

1. [Performance Overview](#performance-overview)
2. [Benchmarking and Profiling](#benchmarking-and-profiling)
3. [Memory Optimization](#memory-optimization)
4. [CPU Optimization](#cpu-optimization)
5. [I/O Optimization](#i-o-optimization)
6. [Platform-Specific Optimizations](#platform-specific-optimizations)
7. [Performance Monitoring](#performance-monitoring)
8. [Common Performance Issues](#common-performance-issues)

## Performance Overview

Chunked processing performance depends on several key factors:

- **Chunk Size**: Larger chunks = fewer I/O operations but more memory usage
- **Concurrency**: More concurrent chunks = better CPU utilization but higher memory usage
- **Memory Management**: Efficient memory allocation and cleanup
- **Format Optimization**: Format-specific optimizations for better performance
- **Platform Characteristics**: Device capabilities and limitations

### Performance Metrics

Key metrics to monitor:

```dart
class PerformanceMetrics {
  final Duration totalProcessingTime;      // Total time to process file
  final Duration averageChunkTime;         // Average time per chunk
  final int peakMemoryUsage;              // Peak memory usage in bytes
  final double throughputMBps;            // Processing throughput in MB/s
  final double cpuUtilization;            // CPU utilization percentage
  final int ioOperations;                 // Number of I/O operations
  final double errorRate;                 // Percentage of failed chunks
}
```

## Benchmarking and Profiling

### Setting Up Benchmarks

Create comprehensive benchmarks to measure performance:

```dart
class ChunkedProcessingBenchmark {
  static Future<BenchmarkResult> runBenchmark({
    required String filePath,
    required ChunkedProcessingConfig config,
    int iterations = 5,
  }) async {
    final results = <PerformanceMetrics>[];
    
    for (int i = 0; i < iterations; i++) {
      // Clear caches between runs
      await Sonix.clearAllCaches();
      
      final stopwatch = Stopwatch()..start();
      final memoryBefore = await Sonix.getCurrentMemoryUsage();
      
      try {
        final waveform = await Sonix.generateWaveformChunked(
          filePath,
          config: config.copyWith(enableProfiling: true),
        );
        
        stopwatch.stop();
        final memoryAfter = await Sonix.getCurrentMemoryUsage();
        final profile = Sonix.getLastProfilingResult();
        
        results.add(PerformanceMetrics(
          totalProcessingTime: stopwatch.elapsed,
          averageChunkTime: profile.averageChunkTime,
          peakMemoryUsage: profile.peakMemoryUsage,
          throughputMBps: _calculateThroughput(filePath, stopwatch.elapsed),
          cpuUtilization: profile.averageCpuUtilization,
          ioOperations: profile.totalIoOperations,
          errorRate: profile.errorRate,
        ));
      } catch (e) {
        print('Benchmark iteration $i failed: $e');
      }
    }
    
    return BenchmarkResult.fromMetrics(results);
  }
  
  static double _calculateThroughput(String filePath, Duration processingTime) {
    final fileSize = File(filePath).lengthSync();
    final fileSizeMB = fileSize / (1024 * 1024);
    final processingTimeSeconds = processingTime.inMilliseconds / 1000.0;
    return fileSizeMB / processingTimeSeconds;
  }
}

// Usage example
final benchmarkResult = await ChunkedProcessingBenchmark.runBenchmark(
  filePath: 'test_audio.mp3',
  config: ChunkedProcessingConfig(
    fileChunkSize: 10 * 1024 * 1024,
    maxConcurrentChunks: 3,
  ),
);

print('Average processing time: ${benchmarkResult.averageProcessingTime}');
print('Peak memory usage: ${benchmarkResult.peakMemoryUsage} bytes');
print('Throughput: ${benchmarkResult.averageThroughput} MB/s');
```

### Profiling Configuration

Enable detailed profiling for performance analysis:

```dart
final profilingConfig = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,
  maxConcurrentChunks: 3,
  
  // Enable comprehensive profiling
  enableProfiling: true,
  enableMemoryTracking: true,
  enableCpuProfiling: true,
  enableIoProfiling: true,
  
  // Detailed callbacks for analysis
  onChunkProcessed: (chunkIndex, metrics) {
    print('Chunk $chunkIndex: ${metrics.processingTime}ms, '
          '${metrics.memoryUsed} bytes, ${metrics.cpuTime}ms CPU');
  },
  
  onMemoryAllocation: (size, type) {
    print('Memory allocated: $size bytes for $type');
  },
  
  onIoOperation: (operation, duration, bytesTransferred) {
    print('I/O $operation: ${duration}ms, $bytesTransferred bytes');
  },
);
```

### Performance Comparison

Compare different configurations to find optimal settings:

```dart
class ConfigurationComparison {
  static Future<ComparisonResult> compareConfigurations(
    String filePath,
    List<ChunkedProcessingConfig> configs,
  ) async {
    final results = <String, BenchmarkResult>{};
    
    for (int i = 0; i < configs.length; i++) {
      final config = configs[i];
      final configName = 'Config_$i';
      
      print('Testing $configName...');
      final result = await ChunkedProcessingBenchmark.runBenchmark(
        filePath: filePath,
        config: config,
      );
      
      results[configName] = result;
    }
    
    return ComparisonResult(results);
  }
}

// Compare different chunk sizes
final configs = [
  ChunkedProcessingConfig(fileChunkSize: 5 * 1024 * 1024),   // 5MB
  ChunkedProcessingConfig(fileChunkSize: 10 * 1024 * 1024),  // 10MB
  ChunkedProcessingConfig(fileChunkSize: 20 * 1024 * 1024),  // 20MB
];

final comparison = await ConfigurationComparison.compareConfigurations(
  'large_audio_file.mp3',
  configs,
);

print('Best configuration: ${comparison.bestConfiguration}');
print('Performance improvement: ${comparison.performanceImprovement}%');
```

## Memory Optimization

### Memory Pool Management

Implement memory pools to reduce allocation overhead:

```dart
final memoryOptimizedConfig = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,
  maxMemoryUsage: 100 * 1024 * 1024,
  
  // Memory pool configuration
  enableMemoryPool: true,
  memoryPoolSize: 5,                    // Pool 5 chunks worth of memory
  memoryPoolPreallocation: true,        // Pre-allocate pool memory
  memoryPoolAlignment: 64,              // 64-byte alignment for SIMD
  
  // Memory reuse strategies
  enableMemoryReuse: true,
  memoryReuseThreshold: 0.8,            // Reuse if 80% similar size
  
  // Garbage collection optimization
  enableGCOptimization: true,
  gcStrategy: GCStrategy.generational,   // Use generational GC
  forceGCInterval: 10,                  // Force GC every 10 chunks
);
```

### Memory Pressure Handling

Implement adaptive memory management:

```dart
class AdaptiveMemoryManager {
  static ChunkedProcessingConfig createAdaptiveConfig() {
    return ChunkedProcessingConfig(
      fileChunkSize: 10 * 1024 * 1024,
      maxMemoryUsage: 100 * 1024 * 1024,
      
      enableAdaptiveMemoryManagement: true,
      memoryPressureThresholds: [0.6, 0.8, 0.9],  // Warning, high, critical
      
      onMemoryPressure: (level, currentUsage, maxUsage) {
        switch (level) {
          case MemoryPressureLevel.warning:
            // Reduce chunk size by 25%
            return _reduceChunkSize(0.75);
          case MemoryPressureLevel.high:
            // Reduce chunk size by 50%, disable concurrency
            return _reduceChunkSize(0.5).copyWith(maxConcurrentChunks: 1);
          case MemoryPressureLevel.critical:
            // Minimum chunk size, sequential processing
            return ChunkedProcessingConfig(
              fileChunkSize: 1 * 1024 * 1024,
              maxMemoryUsage: 25 * 1024 * 1024,
              maxConcurrentChunks: 1,
            );
        }
      },
    );
  }
  
  static ChunkedProcessingConfig _reduceChunkSize(double factor) {
    return ChunkedProcessingConfig(
      fileChunkSize: (10 * 1024 * 1024 * factor).round(),
      maxMemoryUsage: (100 * 1024 * 1024 * factor).round(),
    );
  }
}
```

### Memory Leak Detection

Monitor for memory leaks during processing:

```dart
class MemoryLeakDetector {
  static void enableLeakDetection(ChunkedProcessingConfig config) {
    final baselineMemory = <int>[];
    
    config.copyWith(
      enableMemoryLeakDetection: true,
      memoryLeakCheckInterval: 5,        // Check every 5 chunks
      
      onMemorySnapshot: (chunkIndex, memoryUsage) {
        baselineMemory.add(memoryUsage);
        
        if (baselineMemory.length > 10) {
          // Check for consistent memory growth
          final recentGrowth = _calculateMemoryGrowth(baselineMemory.takeLast(10));
          
          if (recentGrowth > 5 * 1024 * 1024) { // 5MB growth
            print('Potential memory leak detected: ${recentGrowth} bytes growth');
            
            // Force garbage collection
            Sonix.forceGarbageCollection();
            
            // Re-check after GC
            final postGCMemory = Sonix.getCurrentMemoryUsage();
            if (postGCMemory > memoryUsage * 0.9) {
              print('Memory leak confirmed after GC');
            }
          }
        }
      },
    );
  }
  
  static int _calculateMemoryGrowth(Iterable<int> memorySnapshots) {
    final list = memorySnapshots.toList();
    return list.last - list.first;
  }
}
```

## CPU Optimization

### Multi-Threading Configuration

Optimize CPU utilization with proper threading:

```dart
class CPUOptimizedConfig {
  static ChunkedProcessingConfig forCPUCores(int coreCount) {
    return ChunkedProcessingConfig(
      fileChunkSize: 8 * 1024 * 1024,
      maxConcurrentChunks: coreCount,
      
      // CPU optimization settings
      enableCPUAffinity: true,           // Pin threads to specific cores
      cpuAffinityStrategy: CPUAffinityStrategy.roundRobin,
      
      // Thread pool configuration
      enableCustomThreadPool: true,
      threadPoolSize: coreCount * 2,     // 2x threads per core
      threadPriority: ThreadPriority.high,
      
      // SIMD optimization
      enableSIMDOptimization: true,
      simdInstructionSet: SIMDInstructionSet.auto, // Auto-detect best SIMD
      
      // CPU-intensive processing mode
      cpuIntensiveMode: true,
      enableHyperthreading: true,        // Use hyperthreading if available
    );
  }
  
  // Configuration for different CPU architectures
  static ChunkedProcessingConfig forArchitecture(CPUArchitecture arch) {
    switch (arch) {
      case CPUArchitecture.arm64:
        return ChunkedProcessingConfig(
          fileChunkSize: 6 * 1024 * 1024,  // ARM64 optimized chunk size
          enableNEONOptimization: true,     // ARM NEON SIMD
          memoryAlignment: 16,              // ARM64 cache line alignment
        );
        
      case CPUArchitecture.x86_64:
        return ChunkedProcessingConfig(
          fileChunkSize: 12 * 1024 * 1024, // x86_64 optimized chunk size
          enableAVXOptimization: true,      // Intel AVX SIMD
          memoryAlignment: 64,              // x86_64 cache line alignment
        );
        
      case CPUArchitecture.arm32:
        return ChunkedProcessingConfig(
          fileChunkSize: 4 * 1024 * 1024,  // Smaller chunks for ARM32
          maxConcurrentChunks: 2,           // Conservative concurrency
          enableNEONOptimization: false,    // May not be available
        );
    }
  }
}
```

### CPU Load Balancing

Implement dynamic load balancing:

```dart
class CPULoadBalancer {
  static ChunkedProcessingConfig createLoadBalancedConfig() {
    return ChunkedProcessingConfig(
      fileChunkSize: 10 * 1024 * 1024,
      
      enableDynamicLoadBalancing: true,
      loadBalancingStrategy: LoadBalancingStrategy.adaptive,
      
      onCPUUtilization: (utilization) {
        if (utilization < 0.5) {
          // CPU underutilized - increase concurrency
          return _increaseConcurrency();
        } else if (utilization > 0.9) {
          // CPU overutilized - decrease concurrency
          return _decreaseConcurrency();
        }
        return null; // No change needed
      },
      
      cpuUtilizationTarget: 0.8,         // Target 80% CPU utilization
      loadBalancingInterval: Duration(seconds: 1),
    );
  }
  
  static ChunkedProcessingConfig _increaseConcurrency() {
    return ChunkedProcessingConfig(
      maxConcurrentChunks: min(Platform.numberOfProcessors * 2, 8),
    );
  }
  
  static ChunkedProcessingConfig _decreaseConcurrency() {
    return ChunkedProcessingConfig(
      maxConcurrentChunks: max(1, Platform.numberOfProcessors ~/ 2),
    );
  }
}
```

## I/O Optimization

### Storage Type Optimization

Optimize for different storage types:

```dart
class StorageOptimizedConfig {
  static Future<ChunkedProcessingConfig> forStorageType(String filePath) async {
    final storageType = await _detectStorageType(filePath);
    
    switch (storageType) {
      case StorageType.ssd:
        return ChunkedProcessingConfig(
          fileChunkSize: 20 * 1024 * 1024,  // Large chunks for SSD
          maxConcurrentChunks: 4,            // High concurrency
          enableReadAhead: true,
          readAheadSize: 64 * 1024 * 1024,   // 64MB read-ahead
          ioStrategy: IOStrategy.sequential,
        );
        
      case StorageType.hdd:
        return ChunkedProcessingConfig(
          fileChunkSize: 8 * 1024 * 1024,   // Smaller chunks for HDD
          maxConcurrentChunks: 2,            // Lower concurrency
          enableReadAhead: true,
          readAheadSize: 32 * 1024 * 1024,   // 32MB read-ahead
          ioStrategy: IOStrategy.sequential,  // Sequential for HDD
        );
        
      case StorageType.network:
        return ChunkedProcessingConfig(
          fileChunkSize: 5 * 1024 * 1024,   // Network-optimized chunks
          maxConcurrentChunks: 2,
          enableProgressiveDownload: true,
          networkBufferSize: 2 * 1024 * 1024, // 2MB network buffer
          ioStrategy: IOStrategy.adaptive,
        );
        
      case StorageType.cloud:
        return ChunkedProcessingConfig(
          fileChunkSize: 10 * 1024 * 1024,  // Cloud-optimized chunks
          maxConcurrentChunks: 3,
          enableCloudOptimization: true,
          cloudProvider: CloudProvider.auto,
          ioStrategy: IOStrategy.parallel,
        );
    }
  }
  
  static Future<StorageType> _detectStorageType(String filePath) async {
    // Implementation to detect storage type
    // This would use platform-specific APIs
    return StorageType.ssd; // Placeholder
  }
}
```

### Buffer Management

Optimize I/O buffers for better performance:

```dart
final ioOptimizedConfig = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,
  
  // I/O buffer configuration
  ioBufferSize: 64 * 1024,              // 64KB I/O buffer
  enableDoubleBuffering: true,           // Use double buffering
  bufferAlignment: 4096,                 // 4KB page alignment
  
  // Read-ahead optimization
  enableReadAhead: true,
  readAheadSize: 32 * 1024 * 1024,       // 32MB read-ahead
  readAheadStrategy: ReadAheadStrategy.adaptive,
  
  // Write optimization (for temporary files)
  enableWriteOptimization: true,
  writeBufferSize: 128 * 1024,           // 128KB write buffer
  enableWriteBatching: true,
  
  // Memory-mapped I/O for large files
  enableMemoryMappedIO: true,
  memoryMapThreshold: 100 * 1024 * 1024, // Use mmap for files > 100MB
);
```

## Platform-Specific Optimizations

### Android Optimizations

```dart
class AndroidPerformanceOptimizer {
  static ChunkedProcessingConfig optimizeForAndroid(AndroidDeviceInfo deviceInfo) {
    final config = ChunkedProcessingConfig(
      fileChunkSize: 8 * 1024 * 1024,
      maxMemoryUsage: 64 * 1024 * 1024,
      
      // Android-specific optimizations
      enableAndroidOptimizations: true,
      respectAndroidMemoryLimits: true,
      
      // Battery optimization
      enableBatteryOptimization: true,
      batteryOptimizationLevel: BatteryOptimizationLevel.balanced,
      
      // Thermal throttling awareness
      enableThermalThrottling: true,
      thermalThrottlingThreshold: 80, // 80°C
      
      onThermalThrottling: (temperature) {
        if (temperature > 85) {
          // Reduce processing intensity
          return ChunkedProcessingConfig(
            fileChunkSize: 4 * 1024 * 1024,
            maxConcurrentChunks: 1,
          );
        }
        return null;
      },
    );
    
    // Adjust based on device capabilities
    if (deviceInfo.totalMemory < 3 * 1024 * 1024 * 1024) { // < 3GB RAM
      return config.copyWith(
        fileChunkSize: 4 * 1024 * 1024,
        maxMemoryUsage: 32 * 1024 * 1024,
        maxConcurrentChunks: 1,
      );
    }
    
    return config;
  }
}
```

### iOS Optimizations

```dart
class IOSPerformanceOptimizer {
  static ChunkedProcessingConfig optimizeForIOS(IosDeviceInfo deviceInfo) {
    return ChunkedProcessingConfig(
      fileChunkSize: 10 * 1024 * 1024,
      maxMemoryUsage: 100 * 1024 * 1024,
      
      // iOS-specific optimizations
      enableIOSOptimizations: true,
      respectIOSMemoryWarnings: true,
      
      // Metal Performance Shaders optimization
      enableMetalOptimization: true,
      metalComputeShaders: true,
      
      // Background processing optimization
      enableBackgroundProcessing: true,
      backgroundProcessingPriority: BackgroundPriority.utility,
      
      onMemoryWarning: (warningLevel) {
        switch (warningLevel) {
          case MemoryWarningLevel.low:
            return ChunkedProcessingConfig(
              fileChunkSize: 5 * 1024 * 1024,
              maxMemoryUsage: 50 * 1024 * 1024,
            );
          case MemoryWarningLevel.critical:
            return ChunkedProcessingConfig(
              fileChunkSize: 2 * 1024 * 1024,
              maxMemoryUsage: 25 * 1024 * 1024,
              maxConcurrentChunks: 1,
            );
        }
      },
    );
  }
}
```

### Desktop Optimizations

```dart
class DesktopPerformanceOptimizer {
  static ChunkedProcessingConfig optimizeForDesktop() {
    return ChunkedProcessingConfig(
      fileChunkSize: 25 * 1024 * 1024,      // Large chunks for desktop
      maxMemoryUsage: 500 * 1024 * 1024,    // 500MB memory limit
      maxConcurrentChunks: Platform.numberOfProcessors,
      
      // Desktop-specific optimizations
      enableDesktopOptimizations: true,
      enableLargePageSupport: true,          // Use large memory pages
      enableNUMAOptimization: true,          // NUMA-aware processing
      
      // High-performance processing
      cpuIntensiveMode: true,
      enableAllCores: true,
      threadAffinityStrategy: ThreadAffinityStrategy.spread,
      
      // Advanced memory management
      enableHugePages: true,                 // Use huge pages if available
      memoryPrefetchStrategy: PrefetchStrategy.aggressive,
    );
  }
}
```

## Performance Monitoring

### Real-Time Monitoring

Implement real-time performance monitoring:

```dart
class PerformanceMonitor {
  static void startMonitoring(ChunkedProcessingConfig config) {
    final monitor = PerformanceMonitor._();
    
    config.copyWith(
      enableRealTimeMonitoring: true,
      monitoringInterval: Duration(milliseconds: 100),
      
      onPerformanceUpdate: (metrics) {
        monitor._updateMetrics(metrics);
        
        // Check for performance issues
        if (metrics.throughputMBps < 5.0) {
          print('Warning: Low throughput detected: ${metrics.throughputMBps} MB/s');
        }
        
        if (metrics.memoryUsagePercentage > 0.9) {
          print('Warning: High memory usage: ${(metrics.memoryUsagePercentage * 100).toStringAsFixed(1)}%');
        }
        
        if (metrics.cpuUtilization > 0.95) {
          print('Warning: High CPU usage: ${(metrics.cpuUtilization * 100).toStringAsFixed(1)}%');
        }
      },
    );
  }
  
  void _updateMetrics(PerformanceMetrics metrics) {
    // Update internal metrics tracking
    // Could send to analytics service, update UI, etc.
  }
}
```

### Performance Alerts

Set up automated performance alerts:

```dart
class PerformanceAlerts {
  static ChunkedProcessingConfig withAlerts(ChunkedProcessingConfig baseConfig) {
    return baseConfig.copyWith(
      enablePerformanceAlerts: true,
      
      performanceThresholds: PerformanceThresholds(
        minThroughputMBps: 10.0,
        maxMemoryUsagePercentage: 0.85,
        maxCpuUtilization: 0.9,
        maxProcessingTimePerMB: Duration(seconds: 2),
      ),
      
      onPerformanceAlert: (alert) {
        switch (alert.type) {
          case AlertType.lowThroughput:
            print('ALERT: Low throughput - ${alert.value} MB/s');
            _suggestThroughputOptimization();
            break;
            
          case AlertType.highMemoryUsage:
            print('ALERT: High memory usage - ${alert.value}%');
            _suggestMemoryOptimization();
            break;
            
          case AlertType.highCpuUsage:
            print('ALERT: High CPU usage - ${alert.value}%');
            _suggestCpuOptimization();
            break;
        }
      },
    );
  }
  
  static void _suggestThroughputOptimization() {
    print('Suggestions:');
    print('- Increase chunk size');
    print('- Enable more concurrent processing');
    print('- Check I/O bottlenecks');
  }
  
  static void _suggestMemoryOptimization() {
    print('Suggestions:');
    print('- Reduce chunk size');
    print('- Decrease concurrent chunks');
    print('- Enable memory pressure handling');
  }
  
  static void _suggestCpuOptimization() {
    print('Suggestions:');
    print('- Reduce concurrent chunks');
    print('- Lower processing priority');
    print('- Enable CPU throttling');
  }
}
```

## Common Performance Issues

### Issue 1: Slow Processing Speed

**Symptoms:**
- Low throughput (< 5 MB/s)
- High processing time per chunk
- CPU underutilization

**Solutions:**

```dart
// Increase chunk size and concurrency
final optimizedConfig = ChunkedProcessingConfig(
  fileChunkSize: 20 * 1024 * 1024,      // Increase from 10MB to 20MB
  maxConcurrentChunks: Platform.numberOfProcessors, // Use all CPU cores
  enableCPUOptimization: true,
  cpuIntensiveMode: true,
);

// Enable I/O optimization
final ioOptimizedConfig = optimizedConfig.copyWith(
  enableReadAhead: true,
  readAheadSize: 64 * 1024 * 1024,      // 64MB read-ahead
  ioBufferSize: 128 * 1024,             // 128KB I/O buffer
);
```

### Issue 2: High Memory Usage

**Symptoms:**
- Memory usage exceeding limits
- Out of memory errors
- Memory pressure warnings

**Solutions:**

```dart
// Reduce memory footprint
final memoryOptimizedConfig = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,       // Reduce chunk size
  maxMemoryUsage: 50 * 1024 * 1024,     // Lower memory limit
  maxConcurrentChunks: 1,                // Sequential processing
  enableMemoryPool: true,                // Reuse memory
  forceGCInterval: 5,                    // Frequent garbage collection
);
```

### Issue 3: Inconsistent Performance

**Symptoms:**
- Variable processing times
- Sporadic slowdowns
- Unpredictable memory usage

**Solutions:**

```dart
// Enable adaptive configuration
final adaptiveConfig = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,
  enableAdaptiveProcessing: true,
  
  // Monitor and adjust automatically
  onPerformanceRegression: (currentMetrics, baselineMetrics) {
    if (currentMetrics.throughputMBps < baselineMetrics.throughputMBps * 0.8) {
      // Performance dropped by 20% - adjust configuration
      return ChunkedProcessingConfig(
        fileChunkSize: 15 * 1024 * 1024,  // Increase chunk size
        maxConcurrentChunks: 2,            // Reduce concurrency
      );
    }
    return null;
  },
);
```

### Issue 4: Battery Drain (Mobile)

**Symptoms:**
- High battery consumption during processing
- Device heating up
- Thermal throttling

**Solutions:**

```dart
// Battery-optimized configuration
final batteryOptimizedConfig = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,
  maxConcurrentChunks: 1,                // Sequential processing
  
  // Battery optimization
  enableBatteryOptimization: true,
  batteryOptimizationLevel: BatteryOptimizationLevel.aggressive,
  
  // Thermal management
  enableThermalThrottling: true,
  thermalThrottlingThreshold: 75,        // 75°C threshold
  
  // Processing intervals to allow cooling
  processingInterval: Duration(milliseconds: 100),
  coolingInterval: Duration(milliseconds: 50),
);
```

### Performance Optimization Checklist

Use this checklist to optimize chunked processing performance:

#### Memory Optimization
- [ ] Set appropriate chunk size for available memory
- [ ] Enable memory pooling for frequent allocations
- [ ] Configure garbage collection optimization
- [ ] Monitor memory pressure and adjust dynamically
- [ ] Use memory-mapped I/O for large files

#### CPU Optimization
- [ ] Match concurrent chunks to CPU cores
- [ ] Enable SIMD optimizations for your platform
- [ ] Use CPU affinity for consistent performance
- [ ] Monitor CPU utilization and adjust load
- [ ] Enable platform-specific optimizations

#### I/O Optimization
- [ ] Configure appropriate I/O buffer sizes
- [ ] Enable read-ahead for sequential access
- [ ] Use double buffering for better throughput
- [ ] Optimize for storage type (SSD/HDD/Network)
- [ ] Align memory access to cache boundaries

#### Platform Optimization
- [ ] Use platform-specific configurations
- [ ] Respect platform memory limits
- [ ] Enable battery optimization on mobile
- [ ] Handle thermal throttling appropriately
- [ ] Use platform-specific acceleration (Metal, CUDA, etc.)

#### Monitoring and Debugging
- [ ] Enable performance profiling
- [ ] Set up real-time monitoring
- [ ] Configure performance alerts
- [ ] Benchmark different configurations
- [ ] Monitor for memory leaks and performance regressions

This performance optimization guide provides comprehensive strategies for maximizing Sonix chunked processing performance across different platforms and use cases.