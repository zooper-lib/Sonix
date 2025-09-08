import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';

/// Example showing memory-efficient processing for large audio files
class MemoryEfficientExample extends StatefulWidget {
  const MemoryEfficientExample({super.key});

  @override
  State<MemoryEfficientExample> createState() => _MemoryEfficientExampleState();
}

class _MemoryEfficientExampleState extends State<MemoryEfficientExample> {
  WaveformData? _waveformData;
  bool _isLoading = false;
  String? _error;
  ResourceStatistics? _resourceStats;

  // Processing options
  ProcessingMethod _selectedMethod = ProcessingMethod.adaptive;
  int _memoryLimit = 25; // MB
  bool _useCache = true;

  @override
  void initState() {
    super.initState();
    _initializeSonix();
    _updateResourceStats();
  }

  void _initializeSonix() {
    // Initialize Sonix with memory management
    Sonix.initialize(
      memoryLimit: _memoryLimit * 1024 * 1024, // Convert MB to bytes
      maxWaveformCacheSize: 20,
      maxAudioDataCacheSize: 10,
    );
  }

  void _updateResourceStats() {
    setState(() {
      _resourceStats = Sonix.getResourceStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Efficient Processing'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _updateResourceStats, tooltip: 'Refresh Stats')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Memory-Efficient Waveform Processing', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates different memory-efficient processing '
              'methods for handling large audio files without running out of memory.',
            ),
            const SizedBox(height: 24),

            // Resource statistics
            if (_resourceStats != null) _buildResourceStatsCard(),

            const SizedBox(height: 16),

            // Processing options
            _buildProcessingOptionsCard(),

            const SizedBox(height: 16),

            // Generate button
            ElevatedButton(
              onPressed: _isLoading ? null : _generateWaveform,
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Processing...'),
                      ],
                    )
                  : const Text('Generate Waveform'),
            ),

            const SizedBox(height: 16),

            // Error display
            if (_error != null) _buildErrorCard(),

            // Waveform display
            if (_waveformData != null) _buildWaveformCard(),

            const SizedBox(height: 24),

            // Memory management actions
            _buildMemoryActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.memory, color: Colors.blue),
                SizedBox(width: 8),
                Text('Resource Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Memory usage bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text('Memory Usage:'), Text('${(_resourceStats!.memoryUsagePercentage * 100).toStringAsFixed(1)}%')],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _resourceStats!.memoryUsagePercentage,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _resourceStats!.memoryUsagePercentage > 0.8
                        ? Colors.red
                        : _resourceStats!.memoryUsagePercentage > 0.6
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Detailed stats
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Waveform Cache: ${_resourceStats!.waveformCacheStats.size}/${_resourceStats!.waveformCacheStats.maxSize}'),
                      Text('Audio Data Cache: ${_resourceStats!.audioDataCacheStats.size}/${_resourceStats!.audioDataCacheStats.maxSize}'),
                      Text('Active Decoders: ${_resourceStats!.activeDecoderCount}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Memory Limit: ${_memoryLimit}MB'),
                      Text('Cache Utilization: ${(_resourceStats!.waveformCacheStats.utilization * 100).toStringAsFixed(1)}%'),
                      Text('Managed Resources: ${_resourceStats!.managedResourceCount}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Processing Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Processing method
            const Text('Processing Method:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButton<ProcessingMethod>(
              value: _selectedMethod,
              isExpanded: true,
              onChanged: (method) {
                if (method != null) {
                  setState(() {
                    _selectedMethod = method;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: ProcessingMethod.standard, child: Text('Standard - Fast, uses more memory')),
                DropdownMenuItem(value: ProcessingMethod.memoryEfficient, child: Text('Memory Efficient - Slower, uses less memory')),
                DropdownMenuItem(value: ProcessingMethod.streaming, child: Text('Streaming - Best for very large files')),
                DropdownMenuItem(value: ProcessingMethod.adaptive, child: Text('Adaptive - Automatically chooses best method')),
                DropdownMenuItem(value: ProcessingMethod.cached, child: Text('Cached - Uses intelligent caching')),
              ],
            ),

            const SizedBox(height: 16),

            // Memory limit
            Row(
              children: [
                const Text('Memory Limit: '),
                Expanded(
                  child: Slider(
                    value: _memoryLimit.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '${_memoryLimit}MB',
                    onChanged: (value) {
                      setState(() {
                        _memoryLimit = value.round();
                      });
                      _initializeSonix(); // Reinitialize with new limit
                    },
                  ),
                ),
              ],
            ),

            // Cache option
            Row(
              children: [
                Checkbox(
                  value: _useCache,
                  onChanged: (value) {
                    setState(() {
                      _useCache = value ?? true;
                    });
                  },
                ),
                const Text('Use Caching'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Error',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Generated Waveform', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            WaveformWidget(waveformData: _waveformData!, style: WaveformStylePresets.professional),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Processing Results:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Method Used: ${_selectedMethod.displayName}'),
                  Text('Data Points: ${_waveformData!.amplitudes.length}'),
                  Text('Duration: ${_waveformData!.duration.inSeconds}s'),
                  Text('Memory Efficient: ${_selectedMethod != ProcessingMethod.standard ? "Yes" : "No"}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Memory Management Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(onPressed: _forceCleanup, icon: const Icon(Icons.cleaning_services), label: const Text('Force Cleanup')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(onPressed: _clearCaches, icon: const Icon(Icons.clear_all), label: const Text('Clear Caches')),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(onPressed: _preloadAudioData, icon: const Icon(Icons.download), label: const Text('Preload Audio Data')),

            const SizedBox(height: 16),

            const Text('Tips for Memory Efficiency:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '• Use Adaptive processing for automatic optimization\n'
              '• Enable caching for frequently accessed files\n'
              '• Use Streaming for files larger than 50MB\n'
              '• Monitor memory usage regularly\n'
              '• Call forceCleanup() when memory is low',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateWaveform() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      WaveformData waveformData;

      switch (_selectedMethod) {
        case ProcessingMethod.standard:
          waveformData = await Sonix.generateWaveform(
            'assets/sample_audio.mp3', // Replace with your audio file
            resolution: 200,
          );
          break;

        case ProcessingMethod.memoryEfficient:
          waveformData = await Sonix.generateWaveformMemoryEfficient('assets/sample_audio.mp3', maxMemoryUsage: _memoryLimit * 1024 * 1024);
          break;

        case ProcessingMethod.streaming:
          // For demonstration, we'll collect the stream into a single waveform
          final chunks = <WaveformChunk>[];
          await for (final chunk in Sonix.generateWaveformStream('assets/sample_audio.mp3')) {
            chunks.add(chunk);
          }
          // Combine chunks (simplified for demo)
          final allAmplitudes = chunks.expand((c) => c.amplitudes).toList();
          waveformData = WaveformData.fromAmplitudes(allAmplitudes);
          break;

        case ProcessingMethod.adaptive:
          waveformData = await Sonix.generateWaveformAdaptive('assets/sample_audio.mp3', resolution: 200);
          break;

        case ProcessingMethod.cached:
          waveformData = await Sonix.generateWaveformCached('assets/sample_audio.mp3', useCache: _useCache);
          break;
      }

      setState(() {
        _waveformData = waveformData;
        _isLoading = false;
      });

      _updateResourceStats();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _forceCleanup() async {
    await Sonix.forceCleanup();
    _updateResourceStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memory cleanup completed'), backgroundColor: Colors.green));
    }
  }

  void _clearCaches() {
    // Clear specific file from caches (example)
    Sonix.clearFileFromCaches('assets/sample_audio.mp3');
    _updateResourceStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caches cleared'), backgroundColor: Colors.blue));
    }
  }

  Future<void> _preloadAudioData() async {
    try {
      await Sonix.preloadAudioData('assets/sample_audio.mp3');
      _updateResourceStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio data preloaded'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preload failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

enum ProcessingMethod {
  standard('Standard'),
  memoryEfficient('Memory Efficient'),
  streaming('Streaming'),
  adaptive('Adaptive'),
  cached('Cached');

  const ProcessingMethod(this.displayName);
  final String displayName;
}
