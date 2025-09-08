import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';

/// Example demonstrating Sonix performance optimization features
class PerformanceOptimizationExample extends StatefulWidget {
  const PerformanceOptimizationExample({super.key});

  @override
  State<PerformanceOptimizationExample> createState() => _PerformanceOptimizationExampleState();
}

class _PerformanceOptimizationExampleState extends State<PerformanceOptimizationExample> {
  PerformanceOptimizer? _optimizer;
  PerformanceProfiler? _profiler;
  PlatformValidator? _platformValidator;

  PerformanceMetrics? _currentMetrics;
  List<OptimizationSuggestion> _suggestions = [];
  PlatformValidationResult? _platformValidation;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializePerformanceTools();
  }

  Future<void> _initializePerformanceTools() async {
    try {
      // Initialize performance optimizer
      _optimizer = PerformanceOptimizer();
      await _optimizer!.initialize(
        settings: const OptimizationSettings(
          enableProfiling: true,
          memoryLimit: 150 * 1024 * 1024, // 150MB
          maxCacheSize: 30,
          enableAutoOptimization: true,
        ),
      );

      // Initialize profiler
      _profiler = PerformanceProfiler();
      _profiler!.enable();

      // Initialize platform validator
      _platformValidator = PlatformValidator();
      _platformValidation = await _platformValidator!.validatePlatform();

      // Update UI
      await _updateMetrics();

      setState(() {
        _statusMessage = 'Performance tools initialized successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing performance tools: $e';
      });
    }
  }

  Future<void> _updateMetrics() async {
    if (_optimizer == null) return;

    final metrics = _optimizer!.getCurrentMetrics();
    final suggestions = _optimizer!.getOptimizationSuggestions();

    setState(() {
      _currentMetrics = metrics;
      _suggestions = suggestions;
    });
  }

  Future<void> _runPerformanceBenchmark() async {
    if (_profiler == null) return;

    setState(() {
      _statusMessage = 'Running performance benchmark...';
    });

    try {
      // Run waveform generation benchmark
      final waveformBenchmark = await _profiler!.benchmarkWaveformGeneration(resolutions: [500, 1000, 2000], durations: [5.0, 10.0, 30.0], iterations: 3);

      // Run widget rendering benchmark
      final renderingBenchmark = await _profiler!.benchmarkWidgetRendering(amplitudeCounts: [500, 1000, 2000, 5000], iterations: 5);

      setState(() {
        _statusMessage =
            'Benchmark completed!\n'
            'Waveform tests: ${waveformBenchmark.results.length}\n'
            'Rendering tests: ${renderingBenchmark.results.length}';
      });

      await _updateMetrics();
    } catch (e) {
      setState(() {
        _statusMessage = 'Benchmark failed: $e';
      });
    }
  }

  Future<void> _forceOptimization() async {
    if (_optimizer == null) return;

    setState(() {
      _statusMessage = 'Applying optimizations...';
    });

    try {
      final result = await _optimizer!.forceOptimization();

      setState(() {
        _statusMessage =
            'Optimization completed!\n'
            'Memory freed: ${(result.memoryFreed / 1024 / 1024).toStringAsFixed(1)}MB\n'
            'Duration: ${result.duration.inMilliseconds}ms\n'
            'Applied: ${result.optimizationsApplied.join(', ')}';
      });

      await _updateMetrics();
    } catch (e) {
      setState(() {
        _statusMessage = 'Optimization failed: $e';
      });
    }
  }

  Future<void> _validatePlatform() async {
    if (_platformValidator == null) return;

    setState(() {
      _statusMessage = 'Validating platform...';
    });

    try {
      _platformValidation = await _platformValidator!.validatePlatform(forceRevalidation: true);

      setState(() {
        _statusMessage =
            'Platform validation completed!\n'
            'Supported: ${_platformValidation!.isSupported ? 'Yes' : 'No'}\n'
            'Issues: ${_platformValidation!.issues.length}\n'
            'Warnings: ${_platformValidation!.warnings.length}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Platform validation failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Optimization'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Performance Metrics Card
            if (_currentMetrics != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Performance Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        'Memory Usage',
                        '${(_currentMetrics!.memoryUsage / 1024 / 1024).toStringAsFixed(1)}MB / '
                            '${(_currentMetrics!.memoryLimit / 1024 / 1024).toStringAsFixed(1)}MB '
                            '(${(_currentMetrics!.memoryUsagePercentage * 100).toStringAsFixed(1)}%)',
                      ),
                      _buildMetricRow('Cache Hit Rate', '${(_currentMetrics!.cacheHitRate * 100).toStringAsFixed(1)}%'),
                      _buildMetricRow('Active Resources', '${_currentMetrics!.activeResourceCount}'),
                      _buildMetricRow('Avg Operation Time', '${_currentMetrics!.averageOperationTime.toStringAsFixed(1)}ms'),
                      _buildMetricRow(
                        'Memory Pressure',
                        _currentMetrics!.isMemoryPressureCritical
                            ? 'CRITICAL'
                            : _currentMetrics!.isMemoryPressureHigh
                            ? 'HIGH'
                            : 'NORMAL',
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Optimization Suggestions Card
            if (_suggestions.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Optimization Suggestions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._suggestions.map(
                        (suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_getPriorityIcon(suggestion.priority), color: _getPriorityColor(suggestion.priority), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(suggestion.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(suggestion.description, style: const TextStyle(fontSize: 12)),
                                    Text('Action: ${suggestion.action}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Platform Information Card
            if (_platformValidation != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platform Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildMetricRow('Operating System', _platformValidation!.platformInfo.operatingSystem),
                      _buildMetricRow('Architecture', _platformValidation!.platformInfo.architecture),
                      _buildMetricRow('Supported', _platformValidation!.isSupported ? 'Yes' : 'No'),
                      _buildMetricRow('Issues', '${_platformValidation!.issues.length}'),
                      _buildMetricRow('Warnings', '${_platformValidation!.warnings.length}'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(onPressed: _runPerformanceBenchmark, icon: const Icon(Icons.speed), label: const Text('Run Benchmark')),
                ElevatedButton.icon(onPressed: _forceOptimization, icon: const Icon(Icons.tune), label: const Text('Force Optimization')),
                ElevatedButton.icon(onPressed: _validatePlatform, icon: const Icon(Icons.computer), label: const Text('Validate Platform')),
                ElevatedButton.icon(onPressed: _updateMetrics, icon: const Icon(Icons.refresh), label: const Text('Refresh Metrics')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  IconData _getPriorityIcon(SuggestionPriority priority) {
    switch (priority) {
      case SuggestionPriority.critical:
        return Icons.error;
      case SuggestionPriority.high:
        return Icons.warning;
      case SuggestionPriority.medium:
        return Icons.info;
      case SuggestionPriority.low:
        return Icons.info_outline;
    }
  }

  Color _getPriorityColor(SuggestionPriority priority) {
    switch (priority) {
      case SuggestionPriority.critical:
        return Colors.red;
      case SuggestionPriority.high:
        return Colors.orange;
      case SuggestionPriority.medium:
        return Colors.blue;
      case SuggestionPriority.low:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _optimizer?.dispose();
    _profiler?.clear();
    super.dispose();
  }
}
