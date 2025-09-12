import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:io';

/// Example demonstrating comprehensive progress reporting during chunked processing
/// Shows real-time progress updates, time estimation, and error handling
class ChunkedProgressExample extends StatefulWidget {
  const ChunkedProgressExample({super.key});

  @override
  State<ChunkedProgressExample> createState() => _ChunkedProgressExampleState();
}

class _ChunkedProgressExampleState extends State<ChunkedProgressExample> with TickerProviderStateMixin {
  WaveformData? _waveformData;
  bool _isProcessing = false;
  String? _error;
  String _selectedFilePath = '';

  // Progress tracking
  double _progress = 0.0;
  int _processedChunks = 0;
  int _totalChunks = 0;
  Duration? _estimatedTimeRemaining;
  Duration _elapsedTime = Duration.zero;
  String _statusMessage = '';

  // Performance metrics
  double _throughputMBps = 0.0;
  int _currentMemoryUsage = 0;
  int _peakMemoryUsage = 0;
  List<String> _errorLog = [];

  // Animation controllers
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  // Timer for elapsed time tracking
  Timer? _elapsedTimer;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _progressAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    _pulseAnimationController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut));

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut));

    _pulseAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress Reporting'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFileSelection(),
            const SizedBox(height: 24),
            _buildProcessingControls(),
            if (_isProcessing) ...[const SizedBox(height: 24), _buildProgressSection()],
            if (_errorLog.isNotEmpty) ...[const SizedBox(height: 24), _buildErrorLog()],
            if (_error != null) ...[const SizedBox(height: 24), _buildErrorSection()],
            if (_waveformData != null) ...[const SizedBox(height: 24), _buildResultsSection()],
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
                Icon(Icons.analytics, color: Colors.indigo, size: 28),
                SizedBox(width: 12),
                Text('Progress Reporting Demo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This example demonstrates comprehensive progress reporting during chunked '
              'audio processing. You can monitor real-time progress, performance metrics, '
              'error handling, and time estimation.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progress Features:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Real-time progress percentage and chunk counting'),
                  Text('• Time estimation and throughput calculation'),
                  Text('• Memory usage monitoring'),
                  Text('• Error tracking and recovery'),
                  Text('• Animated progress indicators'),
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
            const Text('File Selection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedFilePath.isEmpty ? 'No file selected' : 'Selected: ${_selectedFilePath.split('/').last}',
                    style: TextStyle(color: _selectedFilePath.isEmpty ? Colors.grey : Colors.black87),
                  ),
                ),
                ElevatedButton.icon(onPressed: _selectFile, icon: const Icon(Icons.folder_open), label: const Text('Select Audio File')),
              ],
            ),
            if (_selectedFilePath.isNotEmpty) ...[
              const SizedBox(height: 12),
              FutureBuilder<FileStat>(
                future: FileStat.stat(_selectedFilePath),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final fileSizeMB = snapshot.data!.size / (1024 * 1024);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('File Size: ${fileSizeMB.toStringAsFixed(1)} MB'),
                          Text('Path: $_selectedFilePath'),
                          Text('Estimated Chunks: ${_estimateChunkCount(snapshot.data!.size)}'),
                        ],
                      ),
                    );
                  }
                  return const CircularProgressIndicator();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Processing Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isProcessing || _selectedFilePath.isEmpty) ? null : _startProcessing,
                    icon: _isProcessing
                        ? AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                ),
                              );
                            },
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isProcessing ? 'Processing...' : 'Start Processing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_isProcessing) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _cancelProcessing,
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Processing Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Main progress bar with animation
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress: ${(_progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (_estimatedTimeRemaining != null) Text('ETA: ${_formatDuration(_estimatedTimeRemaining!)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _progressAnimation.value * _progress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                      minHeight: 8,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Status message
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
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value * 0.5 + 0.5,
                            child: Icon(Icons.info, color: Colors.blue, size: 16),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Detailed metrics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Performance Metrics:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chunks: $_processedChunks / $_totalChunks'),
                            Text('Elapsed: ${_formatDuration(_elapsedTime)}'),
                            Text('Throughput: ${_throughputMBps.toStringAsFixed(1)} MB/s'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Memory: ${(_currentMemoryUsage / (1024 * 1024)).toStringAsFixed(1)} MB'),
                            Text('Peak: ${(_peakMemoryUsage / (1024 * 1024)).toStringAsFixed(1)} MB'),
                            Text('Errors: ${_errorLog.length}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorLog() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Error Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: () => setState(() => _errorLog.clear()), child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: ListView.builder(
                itemCount: _errorLog.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text('${index + 1}. ${_errorLog[index]}', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
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
                  'Processing Error',
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
            const Text('Processing Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Waveform display
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: WaveformWidget(
                waveformData: _waveformData!,
                style: const WaveformStyle(playedColor: Colors.indigo, unplayedColor: Colors.grey, height: 120),
              ),
            ),

            const SizedBox(height: 16),

            // Success metrics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Processing Completed Successfully!',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data Points: ${_waveformData!.amplitudes.length}'),
                            Text('Duration: ${_formatDuration(_waveformData!.duration)}'),
                            Text('Total Time: ${_formatDuration(_elapsedTime)}'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sample Rate: ${_waveformData!.sampleRate} Hz'),
                            Text('Chunks Processed: $_processedChunks'),
                            Text('Avg Throughput: ${_throughputMBps.toStringAsFixed(1)} MB/s'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          _waveformData = null;
          _errorLog.clear();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting file: $e';
      });
    }
  }

  int _estimateChunkCount(int fileSize) {
    const defaultChunkSize = 10 * 1024 * 1024; // 10MB
    return (fileSize / defaultChunkSize).ceil();
  }

  Future<void> _startProcessing() async {
    if (_selectedFilePath.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _error = null;
      _progress = 0.0;
      _processedChunks = 0;
      _totalChunks = 0;
      _elapsedTime = Duration.zero;
      _statusMessage = 'Initializing chunked processing...';
      _currentMemoryUsage = 0;
      _peakMemoryUsage = 0;
      _errorLog.clear();
    });

    _startTime = DateTime.now();
    _startElapsedTimer();
    _progressAnimationController.forward();

    try {
      // Get file size for configuration
      final fileSize = await File(_selectedFilePath).length();

      // Create chunked processing configuration
      final config = ChunkedProcessingConfig.forFileSize(
        fileSize,
      ).copyWith(enableProgressReporting: true, progressUpdateInterval: const Duration(milliseconds: 50));

      setState(() {
        _statusMessage = 'Starting chunked processing...';
        _totalChunks = _estimateChunkCount(fileSize);
      });

      // Generate waveform with progress reporting
      final waveformData = await Sonix.generateWaveformChunked(_selectedFilePath, chunkedConfig: config, onProgress: _handleProgress);

      setState(() {
        _waveformData = waveformData;
        _isProcessing = false;
        _progress = 1.0;
        _statusMessage = 'Processing completed successfully!';
      });
    } catch (e) {
      setState(() {
        _error = 'Processing failed: $e';
        _isProcessing = false;
        _statusMessage = 'Processing failed';
      });
      _errorLog.add('Fatal error: $e');
    } finally {
      _stopElapsedTimer();
    }
  }

  void _handleProgress(ProgressInfo progress) {
    setState(() {
      _progress = progress.progressPercentage;
      _processedChunks = progress.processedChunks;
      _totalChunks = progress.totalChunks;
      _estimatedTimeRemaining = progress.estimatedTimeRemaining;

      // Update status message
      if (progress.hasErrors) {
        _statusMessage = 'Processing with errors - chunk ${progress.processedChunks}';
        if (progress.lastError != null) {
          _errorLog.add('Chunk ${progress.processedChunks}: ${progress.lastError}');
        }
      } else {
        _statusMessage = 'Processing chunk ${progress.processedChunks} of ${progress.totalChunks}';
      }

      // Simulate memory usage (in a real app, this would come from the progress info)
      _currentMemoryUsage = (50 * 1024 * 1024 * (0.5 + _progress * 0.5)).round();
      _peakMemoryUsage = (_peakMemoryUsage < _currentMemoryUsage) ? _currentMemoryUsage : _peakMemoryUsage;

      // Calculate throughput
      if (_elapsedTime.inMilliseconds > 0) {
        final fileSizeMB = 100; // Simulated file size
        final elapsedSeconds = _elapsedTime.inMilliseconds / 1000.0;
        _throughputMBps = (fileSizeMB * _progress) / elapsedSeconds;
      }
    });
  }

  void _cancelProcessing() {
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Processing cancelled by user';
    });
    _stopElapsedTimer();
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
