import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';

/// Advanced performance profiling utilities for chunked audio processing
class PerformanceProfiler {
  final Map<String, ProfileSession> _sessions = {};
  final List<PerformanceMetric> _metrics = [];

  /// Starts a new profiling session
  ProfileSession startSession(String sessionName) {
    final session = ProfileSession(sessionName);
    _sessions[sessionName] = session;
    return session;
  }

  /// Ends a profiling session and returns results
  ProfileResults endSession(String sessionName) {
    final session = _sessions.remove(sessionName);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionName');
    }

    return session.getResults();
  }

  /// Records a performance metric
  void recordMetric(PerformanceMetric metric) {
    _metrics.add(metric);
  }

  /// Generates a comprehensive performance report
  Future<PerformanceReport> generateReport() async {
    final systemInfo = await _collectSystemInfo();
    final memoryProfile = await _generateMemoryProfile();
    final cpuProfile = await _generateCpuProfile();

    return PerformanceReport(
      systemInfo: systemInfo,
      memoryProfile: memoryProfile,
      cpuProfile: cpuProfile,
      metrics: List.from(_metrics),
      sessions: Map.from(_sessions),
    );
  }

  /// Exports performance data to JSON
  Future<void> exportToJson(String filePath) async {
    final report = await generateReport();
    final json = jsonEncode(report.toJson());
    await File(filePath).writeAsString(json);
  }

  Future<SystemInfo> _collectSystemInfo() async {
    return SystemInfo(
      platform: Platform.operatingSystem,
      version: Platform.operatingSystemVersion,
      numberOfProcessors: Platform.numberOfProcessors,
      memoryMB: await _getTotalSystemMemory(),
      dartVersion: Platform.version,
    );
  }

  Future<MemoryProfile> _generateMemoryProfile() async {
    final currentRss = await _getCurrentRss();
    final heapSize = await _getHeapSize();

    return MemoryProfile(currentRssMB: currentRss / (1024 * 1024), heapSizeMB: heapSize / (1024 * 1024), peakRssMB: await _getPeakRss() / (1024 * 1024));
  }

  Future<CpuProfile> _generateCpuProfile() async {
    return CpuProfile(userTimeMs: await _getUserTime(), systemTimeMs: await _getSystemTime(), cpuUsagePercent: await _getCpuUsage());
  }

  Future<int> _getTotalSystemMemory() async {
    // Platform-specific implementation would be needed
    return 8 * 1024; // 8GB default
  }

  Future<int> _getCurrentRss() async {
    // Platform-specific implementation would be needed
    return 100 * 1024 * 1024; // 100MB default
  }

  Future<int> _getHeapSize() async {
    // Platform-specific implementation would be needed
    return 50 * 1024 * 1024; // 50MB default
  }

  Future<int> _getPeakRss() async {
    // Platform-specific implementation would be needed
    return 150 * 1024 * 1024; // 150MB default
  }

  Future<int> _getUserTime() async {
    // Platform-specific implementation would be needed
    return 1000; // 1 second default
  }

  Future<int> _getSystemTime() async {
    // Platform-specific implementation would be needed
    return 500; // 0.5 seconds default
  }

  Future<double> _getCpuUsage() async {
    // Platform-specific implementation would be needed
    return 25.0; // 25% default
  }
}

/// Profiling session for tracking performance over time
class ProfileSession {
  final String name;
  final DateTime startTime;
  final List<ProfileEvent> _events = [];
  final Map<String, dynamic> _counters = {};

  ProfileSession(this.name) : startTime = DateTime.now();

  /// Records an event in the session
  void recordEvent(String eventName, {Map<String, dynamic>? data}) {
    _events.add(ProfileEvent(name: eventName, timestamp: DateTime.now(), data: data ?? {}));
  }

  /// Increments a counter
  void incrementCounter(String counterName, [int amount = 1]) {
    _counters[counterName] = (_counters[counterName] ?? 0) + amount;
  }

  /// Sets a counter value
  void setCounter(String counterName, dynamic value) {
    _counters[counterName] = value;
  }

  /// Gets current counter value
  dynamic getCounter(String counterName) {
    return _counters[counterName];
  }

  /// Gets session results
  ProfileResults getResults() {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    return ProfileResults(
      sessionName: name,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      events: List.from(_events),
      counters: Map.from(_counters),
    );
  }
}

/// Performance metric data
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PerformanceMetric({required this.name, required this.value, required this.unit, DateTime? timestamp, this.metadata = const {}})
    : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {'name': name, 'value': value, 'unit': unit, 'timestamp': timestamp.toIso8601String(), 'metadata': metadata};
}

/// Profile event data
class ProfileEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  ProfileEvent({required this.name, required this.timestamp, required this.data});

  Map<String, dynamic> toJson() => {'name': name, 'timestamp': timestamp.toIso8601String(), 'data': data};
}

/// Profile session results
class ProfileResults {
  final String sessionName;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final List<ProfileEvent> events;
  final Map<String, dynamic> counters;

  ProfileResults({
    required this.sessionName,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.events,
    required this.counters,
  });

  Map<String, dynamic> toJson() => {
    'sessionName': sessionName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'events': events.map((e) => e.toJson()).toList(),
    'counters': counters,
  };
}

/// System information
class SystemInfo {
  final String platform;
  final String version;
  final int numberOfProcessors;
  final int memoryMB;
  final String dartVersion;

  SystemInfo({required this.platform, required this.version, required this.numberOfProcessors, required this.memoryMB, required this.dartVersion});

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'version': version,
    'numberOfProcessors': numberOfProcessors,
    'memoryMB': memoryMB,
    'dartVersion': dartVersion,
  };
}

/// Memory profiling data
class MemoryProfile {
  final double currentRssMB;
  final double heapSizeMB;
  final double peakRssMB;

  MemoryProfile({required this.currentRssMB, required this.heapSizeMB, required this.peakRssMB});

  Map<String, dynamic> toJson() => {'currentRssMB': currentRssMB, 'heapSizeMB': heapSizeMB, 'peakRssMB': peakRssMB};
}

/// CPU profiling data
class CpuProfile {
  final int userTimeMs;
  final int systemTimeMs;
  final double cpuUsagePercent;

  CpuProfile({required this.userTimeMs, required this.systemTimeMs, required this.cpuUsagePercent});

  Map<String, dynamic> toJson() => {'userTimeMs': userTimeMs, 'systemTimeMs': systemTimeMs, 'cpuUsagePercent': cpuUsagePercent};
}

/// Comprehensive performance report
class PerformanceReport {
  final SystemInfo systemInfo;
  final MemoryProfile memoryProfile;
  final CpuProfile cpuProfile;
  final List<PerformanceMetric> metrics;
  final Map<String, ProfileSession> sessions;

  PerformanceReport({required this.systemInfo, required this.memoryProfile, required this.cpuProfile, required this.metrics, required this.sessions});

  Map<String, dynamic> toJson() => {
    'systemInfo': systemInfo.toJson(),
    'memoryProfile': memoryProfile.toJson(),
    'cpuProfile': cpuProfile.toJson(),
    'metrics': metrics.map((m) => m.toJson()).toList(),
    'sessions': sessions.map((k, v) => MapEntry(k, v.getResults().toJson())),
  };
}

/// Memory leak detector
class MemoryLeakDetector {
  final List<MemorySnapshot> _snapshots = [];
  final Duration _snapshotInterval;

  MemoryLeakDetector({Duration? snapshotInterval}) : _snapshotInterval = snapshotInterval ?? Duration(seconds: 1);

  /// Starts memory leak detection
  void startDetection() {
    _snapshots.clear();
    _scheduleSnapshot();
  }

  /// Stops detection and analyzes for leaks
  MemoryLeakReport stopDetection() {
    final report = _analyzeSnapshots();
    _snapshots.clear();
    return report;
  }

  void _scheduleSnapshot() {
    Future.delayed(_snapshotInterval, () async {
      final snapshot = await _takeSnapshot();
      _snapshots.add(snapshot);

      // Continue taking snapshots (in real implementation, this would be controlled)
      if (_snapshots.length < 100) {
        // Limit snapshots for testing
        _scheduleSnapshot();
      }
    });
  }

  Future<MemorySnapshot> _takeSnapshot() async {
    return MemorySnapshot(timestamp: DateTime.now(), rssMB: await _getCurrentRss() / (1024 * 1024), heapMB: await _getHeapSize() / (1024 * 1024));
  }

  MemoryLeakReport _analyzeSnapshots() {
    if (_snapshots.length < 3) {
      return MemoryLeakReport(hasLeak: false, leakRateMBPerSecond: 0.0, confidence: 0.0, snapshots: List.from(_snapshots));
    }

    // Calculate memory growth trend
    final rssValues = _snapshots.map((s) => s.rssMB).toList();
    final heapValues = _snapshots.map((s) => s.heapMB).toList();

    final rssGrowthRate = _calculateGrowthRate(rssValues);
    final heapGrowthRate = _calculateGrowthRate(heapValues);

    // Determine if there's a leak
    final leakThreshold = 0.1; // 0.1 MB/second
    final hasRssLeak = rssGrowthRate > leakThreshold;
    final hasHeapLeak = heapGrowthRate > leakThreshold;

    return MemoryLeakReport(
      hasLeak: hasRssLeak || hasHeapLeak,
      leakRateMBPerSecond: math.max(rssGrowthRate, heapGrowthRate),
      confidence: _calculateConfidence(rssValues, heapValues),
      snapshots: List.from(_snapshots),
    );
  }

  double _calculateGrowthRate(List<double> values) {
    if (values.length < 2) return 0.0;

    // Simple linear regression to find growth rate
    final n = values.length;
    final sumX = (n * (n - 1)) / 2;
    final sumY = values.reduce((a, b) => a + b);
    final sumXY = values.asMap().entries.map((e) => e.key * e.value).reduce((a, b) => a + b);
    final sumX2 = (n * (n - 1) * (2 * n - 1)) / 6;

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    // Convert to MB per second (assuming 1 second intervals)
    return slope / _snapshotInterval.inSeconds;
  }

  double _calculateConfidence(List<double> rssValues, List<double> heapValues) {
    // Calculate R-squared for confidence measure
    if (rssValues.length < 3) return 0.0;

    final rssR2 = _calculateRSquared(rssValues);
    final heapR2 = _calculateRSquared(heapValues);

    return math.max(rssR2, heapR2);
  }

  double _calculateRSquared(List<double> values) {
    if (values.length < 2) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final totalSumSquares = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b);

    // Calculate predicted values using linear regression
    final n = values.length;
    final sumX = (n * (n - 1)) / 2;
    final sumY = values.reduce((a, b) => a + b);
    final sumXY = values.asMap().entries.map((e) => e.key * e.value).reduce((a, b) => a + b);
    final sumX2 = (n * (n - 1) * (2 * n - 1)) / 6;

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    final residualSumSquares = values.asMap().entries.map((e) => math.pow(e.value - (slope * e.key + intercept), 2)).reduce((a, b) => a + b);

    return 1 - (residualSumSquares / totalSumSquares);
  }

  Future<int> _getCurrentRss() async {
    // Platform-specific implementation would be needed
    return 100 * 1024 * 1024; // 100MB default
  }

  Future<int> _getHeapSize() async {
    // Platform-specific implementation would be needed
    return 50 * 1024 * 1024; // 50MB default
  }
}

/// Memory snapshot data
class MemorySnapshot {
  final DateTime timestamp;
  final double rssMB;
  final double heapMB;

  MemorySnapshot({required this.timestamp, required this.rssMB, required this.heapMB});

  Map<String, dynamic> toJson() => {'timestamp': timestamp.toIso8601String(), 'rssMB': rssMB, 'heapMB': heapMB};
}

/// Memory leak detection report
class MemoryLeakReport {
  final bool hasLeak;
  final double leakRateMBPerSecond;
  final double confidence;
  final List<MemorySnapshot> snapshots;

  MemoryLeakReport({required this.hasLeak, required this.leakRateMBPerSecond, required this.confidence, required this.snapshots});

  Map<String, dynamic> toJson() => {
    'hasLeak': hasLeak,
    'leakRateMBPerSecond': leakRateMBPerSecond,
    'confidence': confidence,
    'snapshots': snapshots.map((s) => s.toJson()).toList(),
  };
}

/// Performance regression detector
class RegressionDetector {
  final Map<String, List<double>> _historicalData = {};

  /// Records a performance measurement
  void recordMeasurement(String metricName, double value) {
    _historicalData.putIfAbsent(metricName, () => []).add(value);
  }

  /// Detects regressions in performance metrics
  List<RegressionResult> detectRegressions() {
    final results = <RegressionResult>[];

    for (final entry in _historicalData.entries) {
      final metricName = entry.key;
      final values = entry.value;

      if (values.length < 5) continue; // Need at least 5 data points

      final regression = _analyzeRegression(metricName, values);
      if (regression != null) {
        results.add(regression);
      }
    }

    return results;
  }

  RegressionResult? _analyzeRegression(String metricName, List<double> values) {
    // Use last 5 values as baseline and current value for comparison
    final baseline = values.take(values.length - 1).toList();
    final current = values.last;

    final baselineMean = baseline.reduce((a, b) => a + b) / baseline.length;
    final baselineStdDev = _calculateStandardDeviation(baseline, baselineMean);

    // Check if current value is significantly worse than baseline
    final threshold = baselineMean + (2 * baselineStdDev); // 2 standard deviations

    if (current > threshold) {
      return RegressionResult(
        metricName: metricName,
        baselineValue: baselineMean,
        currentValue: current,
        regressionPercent: ((current - baselineMean) / baselineMean) * 100,
        confidence: _calculateRegressionConfidence(baseline, current),
      );
    }

    return null;
  }

  double _calculateStandardDeviation(List<double> values, double mean) {
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }

  double _calculateRegressionConfidence(List<double> baseline, double current) {
    final mean = baseline.reduce((a, b) => a + b) / baseline.length;
    final stdDev = _calculateStandardDeviation(baseline, mean);

    // Calculate z-score
    final zScore = (current - mean) / stdDev;

    // Convert to confidence (simplified)
    return math.min(zScore.abs() / 3.0, 1.0); // Max confidence of 1.0
  }
}

/// Regression analysis result
class RegressionResult {
  final String metricName;
  final double baselineValue;
  final double currentValue;
  final double regressionPercent;
  final double confidence;

  RegressionResult({
    required this.metricName,
    required this.baselineValue,
    required this.currentValue,
    required this.regressionPercent,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'metricName': metricName,
    'baselineValue': baselineValue,
    'currentValue': currentValue,
    'regressionPercent': regressionPercent,
    'confidence': confidence,
  };
}
