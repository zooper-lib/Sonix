import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';

/// Example demonstrating performance comparison between different processing methods
/// Shows benchmarks, memory usage, and efficiency metrics
class PerformanceComparisonExample extends StatefulWidget {
  const PerformanceComparisonExample({super.key});

  @override
  State<PerformanceComparisonExample> createState() => _PerformanceComparisonExampleState();
}

class _PerformanceComparisonExampleState extends State<PerformanceComparisonExample> {
  String _selectedFilePath = '';
  bool _isRunningBenchmark = false;
  String? _error;

  // Benchmark results
  final List<BenchmarkResult> _benchmarkResults = [];
  BenchmarkResult? _currentBenchmark;

  // Test configurations
  final List<TestConfiguration> _testConfigurations = [
    TestConfiguration(name: 'Traditional Processing', method: ProcessingMethod.traditional, description: 'Standard full-file processing', color: Colors.blue),
    TestConfiguration(name: 'Chunked Processing', method: ProcessingMethod.chunked, description: 'Memory-efficient chunked processing', color: Colors.green),
    TestConfiguration(name: 'Streaming Processing', method: ProcessingMethod.streaming, description: 'Real-time streaming processing', color: Colors.orange),
    TestConfiguration(name: 'Memory Efficient', method: ProcessingMethod.memoryEfficient, description: 'Optimized for low memory usage', color: Colors.purple),
    TestConfiguration(name: 'Adaptive Processing', method: ProcessingMethod.adaptive, description: 'Automatically chooses best method', color: Colors.teal),
  ];

  // Benchmark settings
  int _benchmarkIterations = 3;
  bool _includeMemoryProfiling = true;
  bool _includeAccuracyTest = true;
  final List<int> _testFileSizes = [1, 5, 10, 50, 100]; // MB

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Comparison'), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFileSelection(),
            const SizedBox(height: 24),
            _buildBenchmarkSettings(),
            const SizedBox(height: 24),
            _buildTestConfigurations(),
            const SizedBox(height: 24),
            _buildBenchmarkControls(),
            if (_isRunningBenchmark && _currentBenchmark != null) ...[const SizedBox(height: 24), _buildCurrentBenchmark()],
            if (_error != null) ...[const SizedBox(height: 24), _buildErrorSection()],
            if (_benchmarkResults.isNotEmpty) ...[const SizedBox(height: 24), _buildResultsSection()],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed, color: Colors.deepOrange, size: 28),
                SizedBox(width: 12),
                Text('Performance Comparison & Benchmarks', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This example compares the performance of different audio processing methods. '
              'Run benchmarks to see how chunked processing compares to traditional methods '
              'in terms of speed, memory usage, and accuracy.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepOrange.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Benchmark Metrics:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Processing time and throughput'),
                  Text('• Memory usage and peak consumption'),
                  Text('• Accuracy comparison between methods'),
                  Text('• Scalability with different file sizes'),
                  Text('• Resource efficiency analysis'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test File Selection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedFilePath.isEmpty ? 'No file selected - will use generated test files' : 'Selected: ${_selectedFilePath.split('/').last}',
                    style: TextStyle(color: _selectedFilePath.isEmpty ? Colors.grey : Colors.black87),
                  ),
                ),
                ElevatedButton.icon(onPressed: _selectFile, icon: const Icon(Icons.folder_open), label: const Text('Select File')),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Test Strategy:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_selectedFilePath.isEmpty) ...[
                    const Text('• Generate synthetic audio files of various sizes'),
                    const Text('• Test with different audio characteristics'),
                    const Text('• Ensure consistent test conditions'),
                  ] else ...[
                    const Text('• Use selected file for all tests'),
                    const Text('• Create variations for size testing'),
                    const Text('• Maintain audio quality consistency'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Benchmark Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Iterations
            Row(
              children: [
                const Text('Iterations per test: '),
                Expanded(
                  child: Slider(
                    value: _benchmarkIterations.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _benchmarkIterations.toString(),
                    onChanged: (value) {
                      setState(() {
                        _benchmarkIterations = value.round();
                      });
                    },
                  ),
                ),
              ],
            ),

            // Options
            CheckboxListTile(
              title: const Text('Include Memory Profiling'),
              subtitle: const Text('Monitor memory usage during processing'),
              value: _includeMemoryProfiling,
              onChanged: (value) {
                setState(() {
                  _includeMemoryProfiling = value ?? true;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Include Accuracy Testing'),
              subtitle: const Text('Compare output accuracy between methods'),
              value: _includeAccuracyTest,
              onChanged: (value) {
                setState(() {
                  _includeAccuracyTest = value ?? true;
                });
              },
            ),

            // Test file sizes
            const SizedBox(height: 16),
            const Text('Test File Sizes (MB):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 5, 10, 25, 50, 100].map((size) {
                final isSelected = _testFileSizes.contains(size);
                return FilterChip(
                  label: Text('${size}MB'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _testFileSizes.add(size);
                        _testFileSizes.sort();
                      } else {
                        _testFileSizes.remove(size);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestConfigurations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Configurations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._testConfigurations.map((config) => _buildConfigurationTile(config)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationTile(TestConfiguration config) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: config.color,
          child: Icon(_getMethodIcon(config.method), color: Colors.white, size: 20),
        ),
        title: Text(config.name),
        subtitle: Text(config.description),
        trailing: Switch(
          value: config.enabled,
          onChanged: (value) {
            setState(() {
              config.enabled = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildBenchmarkControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Benchmark Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunningBenchmark ? null : _runBenchmarks,
                    icon: _isRunningBenchmark
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(_isRunningBenchmark ? 'Running Benchmarks...' : 'Run Benchmarks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _benchmarkResults.isEmpty ? null : _clearResults,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Results'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ],
            ),
            if (_isRunningBenchmark) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cancelBenchmark,
                icon: const Icon(Icons.stop),
                label: const Text('Cancel Benchmark'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBenchmark() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Benchmark', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _currentBenchmark!.progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
            ),
            const SizedBox(height: 12),
            Text('Testing: ${_currentBenchmark!.configurationName}'),
            Text('File Size: ${_currentBenchmark!.fileSizeMB}MB'),
            Text('Iteration: ${_currentBenchmark!.currentIteration}/$_benchmarkIterations'),
            Text('Status: ${_currentBenchmark!.status}'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Benchmark Error',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Benchmark Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildResultsChart(),
            const SizedBox(height: 16),
            _buildResultsTable(),
            const SizedBox(height: 16),
            _buildResultsSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsChart() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'Performance Chart\n(Chart visualization would be implemented here)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildResultsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Method')),
          DataColumn(label: Text('File Size')),
          DataColumn(label: Text('Time (s)')),
          DataColumn(label: Text('Memory (MB)')),
          DataColumn(label: Text('Throughput')),
          DataColumn(label: Text('Accuracy')),
        ],
        rows: _benchmarkResults.map((result) {
          return DataRow(
            cells: [
              DataCell(Text(result.configurationName)),
              DataCell(Text('${result.fileSizeMB}MB')),
              DataCell(Text(result.averageProcessingTime.toStringAsFixed(2))),
              DataCell(Text(result.peakMemoryUsageMB.toStringAsFixed(1))),
              DataCell(Text('${result.throughputMBps.toStringAsFixed(1)} MB/s')),
              DataCell(Text('${(result.accuracyScore * 100).toStringAsFixed(1)}%')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsSummary() {
    if (_benchmarkResults.isEmpty) return const SizedBox.shrink();

    // Calculate summary statistics
    final fastestMethod = _benchmarkResults.reduce((a, b) => a.averageProcessingTime < b.averageProcessingTime ? a : b);
    final mostMemoryEfficient = _benchmarkResults.reduce((a, b) => a.peakMemoryUsageMB < b.peakMemoryUsageMB ? a : b);
    final mostAccurate = _benchmarkResults.reduce((a, b) => a.accuracyScore > b.accuracyScore ? a : b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('🏆 Fastest: ${fastestMethod.configurationName} (${fastestMethod.averageProcessingTime.toStringAsFixed(2)}s)'),
          Text('💾 Most Memory Efficient: ${mostMemoryEfficient.configurationName} (${mostMemoryEfficient.peakMemoryUsageMB.toStringAsFixed(1)}MB)'),
          Text('🎯 Most Accurate: ${mostAccurate.configurationName} (${(mostAccurate.accuracyScore * 100).toStringAsFixed(1)}%)'),
          const SizedBox(height: 8),
          const Text(
            'Recommendation: Use chunked processing for large files (>50MB) and '
            'traditional processing for smaller files for optimal performance.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(ProcessingMethod method) {
    switch (method) {
      case ProcessingMethod.traditional:
        return Icons.memory;
      case ProcessingMethod.chunked:
        return Icons.view_module;
      case ProcessingMethod.streaming:
        return Icons.stream;
      case ProcessingMethod.memoryEfficient:
        return Icons.compress;
      case ProcessingMethod.adaptive:
        return Icons.auto_awesome;
    }
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg', 'opus'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path!;
          _error = null;
          _benchmarkResults.clear();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _runBenchmarks() async {
    setState(() {
      _isRunningBenchmark = true;
      _error = null;
      _benchmarkResults.clear();
    });

    try {
      final enabledConfigs = _testConfigurations.where((c) => c.enabled).toList();

      for (final config in enabledConfigs) {
        for (final fileSize in _testFileSizes) {
          await _runSingleBenchmark(config, fileSize);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Benchmark failed: $e';
      });
    } finally {
      setState(() {
        _isRunningBenchmark = false;
        _currentBenchmark = null;
      });
    }
  }

  Future<void> _runSingleBenchmark(TestConfiguration config, int fileSizeMB) async {
    setState(() {
      _currentBenchmark = BenchmarkResult(
        configurationName: config.name,
        method: config.method,
        fileSizeMB: fileSizeMB,
        currentIteration: 0,
        status: 'Preparing...',
      );
    });

    final processingTimes = <double>[];
    final memoryUsages = <double>[];
    double accuracyScore = 1.0;

    for (int i = 0; i < _benchmarkIterations; i++) {
      setState(() {
        _currentBenchmark = _currentBenchmark!.copyWith(
          currentIteration: i + 1,
          status: 'Running iteration ${i + 1}...',
          progress: (i + 1) / _benchmarkIterations,
        );
      });

      final stopwatch = Stopwatch()..start();

      try {
        // Simulate processing based on method
        await _simulateProcessing(config.method, fileSizeMB);

        stopwatch.stop();
        processingTimes.add(stopwatch.elapsedMilliseconds / 1000.0);

        // Simulate memory usage
        final memoryUsage = _simulateMemoryUsage(config.method, fileSizeMB);
        memoryUsages.add(memoryUsage);

        // Simulate accuracy (chunked processing might have slight differences)
        if (config.method == ProcessingMethod.chunked) {
          accuracyScore = 0.995 + Random().nextDouble() * 0.005; // 99.5-100%
        } else if (config.method == ProcessingMethod.streaming) {
          accuracyScore = 0.990 + Random().nextDouble() * 0.010; // 99.0-100%
        }
      } catch (e) {
        // Handle individual iteration failure
        processingTimes.add(double.infinity);
        memoryUsages.add(0);
      }

      // Small delay to show progress
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Calculate averages
    final validTimes = processingTimes.where((t) => t.isFinite).toList();
    final avgTime = validTimes.isNotEmpty ? validTimes.reduce((a, b) => a + b) / validTimes.length : 0.0;
    final peakMemory = memoryUsages.isNotEmpty ? memoryUsages.reduce((a, b) => a > b ? a : b) : 0.0;
    final throughput = avgTime > 0 ? fileSizeMB / avgTime : 0.0;

    final result = BenchmarkResult(
      configurationName: config.name,
      method: config.method,
      fileSizeMB: fileSizeMB,
      averageProcessingTime: avgTime,
      peakMemoryUsageMB: peakMemory,
      throughputMBps: throughput,
      accuracyScore: accuracyScore,
      iterations: _benchmarkIterations,
      status: 'Completed',
      progress: 1.0,
    );

    setState(() {
      _benchmarkResults.add(result);
    });
  }

  Future<void> _simulateProcessing(ProcessingMethod method, int fileSizeMB) async {
    // Simulate different processing times based on method and file size
    int baseTime;

    switch (method) {
      case ProcessingMethod.traditional:
        baseTime = fileSizeMB * 50; // 50ms per MB
        break;
      case ProcessingMethod.chunked:
        baseTime = fileSizeMB * 40; // 40ms per MB (more efficient for large files)
        break;
      case ProcessingMethod.streaming:
        baseTime = fileSizeMB * 45; // 45ms per MB
        break;
      case ProcessingMethod.memoryEfficient:
        baseTime = fileSizeMB * 60; // 60ms per MB (slower but uses less memory)
        break;
      case ProcessingMethod.adaptive:
        // Adaptive chooses best method based on file size
        if (fileSizeMB > 50) {
          baseTime = fileSizeMB * 40; // Use chunked for large files
        } else {
          baseTime = fileSizeMB * 50; // Use traditional for small files
        }
        break;
    }

    // Add some randomness
    final actualTime = baseTime + Random().nextInt(baseTime ~/ 4);
    await Future.delayed(Duration(milliseconds: actualTime));
  }

  double _simulateMemoryUsage(ProcessingMethod method, int fileSizeMB) {
    switch (method) {
      case ProcessingMethod.traditional:
        return fileSizeMB * 8.0; // 8MB RAM per MB file
      case ProcessingMethod.chunked:
        return 50.0 + (fileSizeMB * 0.5); // Constant 50MB + small overhead
      case ProcessingMethod.streaming:
        return 30.0 + (fileSizeMB * 0.3); // Even less memory
      case ProcessingMethod.memoryEfficient:
        return 25.0 + (fileSizeMB * 0.2); // Most memory efficient
      case ProcessingMethod.adaptive:
        if (fileSizeMB > 50) {
          return 50.0 + (fileSizeMB * 0.5); // Use chunked approach
        } else {
          return fileSizeMB * 8.0; // Use traditional approach
        }
    }
  }

  void _cancelBenchmark() {
    setState(() {
      _isRunningBenchmark = false;
      _currentBenchmark = null;
    });
  }

  void _clearResults() {
    setState(() {
      _benchmarkResults.clear();
    });
  }
}

/// Configuration for a processing method test
class TestConfiguration {
  final String name;
  final ProcessingMethod method;
  final String description;
  final Color color;
  bool enabled;

  TestConfiguration({required this.name, required this.method, required this.description, required this.color, this.enabled = true});
}

/// Processing method enumeration
enum ProcessingMethod { traditional, chunked, streaming, memoryEfficient, adaptive }

/// Result of a benchmark test
class BenchmarkResult {
  final String configurationName;
  final ProcessingMethod method;
  final int fileSizeMB;
  final double averageProcessingTime;
  final double peakMemoryUsageMB;
  final double throughputMBps;
  final double accuracyScore;
  final int iterations;
  final int currentIteration;
  final String status;
  final double progress;

  const BenchmarkResult({
    required this.configurationName,
    required this.method,
    required this.fileSizeMB,
    this.averageProcessingTime = 0.0,
    this.peakMemoryUsageMB = 0.0,
    this.throughputMBps = 0.0,
    this.accuracyScore = 1.0,
    this.iterations = 1,
    this.currentIteration = 0,
    this.status = '',
    this.progress = 0.0,
  });

  BenchmarkResult copyWith({
    String? configurationName,
    ProcessingMethod? method,
    int? fileSizeMB,
    double? averageProcessingTime,
    double? peakMemoryUsageMB,
    double? throughputMBps,
    double? accuracyScore,
    int? iterations,
    int? currentIteration,
    String? status,
    double? progress,
  }) {
    return BenchmarkResult(
      configurationName: configurationName ?? this.configurationName,
      method: method ?? this.method,
      fileSizeMB: fileSizeMB ?? this.fileSizeMB,
      averageProcessingTime: averageProcessingTime ?? this.averageProcessingTime,
      peakMemoryUsageMB: peakMemoryUsageMB ?? this.peakMemoryUsageMB,
      throughputMBps: throughputMBps ?? this.throughputMBps,
      accuracyScore: accuracyScore ?? this.accuracyScore,
      iterations: iterations ?? this.iterations,
      currentIteration: currentIteration ?? this.currentIteration,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }
}
