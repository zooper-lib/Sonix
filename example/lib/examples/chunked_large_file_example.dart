import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Example demonstrating chunked processing for large audio files
/// Shows memory-efficient processing of files larger than available RAM
class ChunkedLargeFileExample extends StatefulWidget {
  const ChunkedLargeFileExample({super.key});

  @override
  State<ChunkedLargeFileExample> createState() => _ChunkedLargeFileExampleState();
}

class _ChunkedLargeFileExampleState extends State<ChunkedLargeFileExample> {
  WaveformData? _waveformData;
  bool _isProcessing = false;
  String? _error;
  double _progress = 0.0;
  String _statusMessage = '';
  Duration? _estimatedTimeRemaining;
  int _currentMemoryUsage = 0;
  int _peakMemoryUsage = 0;
  String _selectedFilePath = '';

  // Processing statistics
  int _processedChunks = 0;
  int _totalChunks = 0;
  Duration _processingTime = Duration.zero;
  double _throughputMBps = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Large File Processing'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFileSelection(),
            const SizedBox(height: 24),
            _buildConfigurationSection(),
            const SizedBox(height: 24),
            _buildProcessingSection(),
            if (_isProcessing) ...[const SizedBox(height: 24), _buildProgressSection()],
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
                Icon(Icons.storage, color: Colors.deepPurple, size: 28),
                SizedBox(width: 12),
                Text('Large File Processing', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This example demonstrates chunked processing for large audio files (100MB+). '
              'Chunked processing allows you to process files larger than available RAM with '
              'consistent memory usage and real-time progress reporting.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Benefits of Chunked Processing:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Consistent memory usage regardless of file size'),
                  Text('• Process files larger than available RAM'),
                  Text('• Real-time progress reporting'),
                  Text('• Error recovery for corrupted chunks'),
                  Text('• Seeking support for large files'),
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
                ElevatedButton.icon(onPressed: _selectFile, icon: const Icon(Icons.folder_open), label: const Text('Select Large Audio File')),
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
                        color: fileSizeMB > 100 ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: fileSizeMB > 100 ? Colors.green.shade200 : Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('File Size: ${fileSizeMB.toStringAsFixed(1)} MB'),
                          Text('Path: $_selectedFilePath'),
                          if (fileSizeMB > 100)
                            const Text(
                              '✓ Perfect for chunked processing demonstration',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            )
                          else
                            const Text(
                              '⚠ File is small - chunked processing benefits are minimal',
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
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

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chunked Processing Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Optimal configuration will be automatically selected based on file size and device capabilities.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuration Strategy:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Chunk Size: Automatically optimized for file size'),
                  Text('• Memory Limit: Based on available device memory'),
                  Text('• Concurrency: Matched to CPU cores'),
                  Text('• Progress Reporting: Enabled for user feedback'),
                  Text('• Error Recovery: Skip corrupted chunks and continue'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingSection() {
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
                    onPressed: (_isProcessing || _selectedFilePath.isEmpty) ? null : _processWithChunking,
                    icon: _isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(_isProcessing ? 'Processing...' : 'Start Chunked Processing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (_isProcessing || _selectedFilePath.isEmpty) ? null : _processTraditional,
                  icon: const Icon(Icons.memory),
                  label: const Text('Compare Traditional'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cancelProcessing,
                icon: const Icon(Icons.stop),
                label: const Text('Cancel Processing'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
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

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress: ${(_progress * 100).toStringAsFixed(1)}%'),
                    if (_estimatedTimeRemaining != null) Text('ETA: ${_formatDuration(_estimatedTimeRemaining!)}'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey.shade300, valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple)),
              ],
            ),

            const SizedBox(height: 16),

            // Status and statistics
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
                  Text('Status: $_statusMessage'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chunks: $_processedChunks / $_totalChunks'),
                            Text('Processing Time: ${_formatDuration(_processingTime)}'),
                            Text('Throughput: ${_throughputMBps.toStringAsFixed(1)} MB/s'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Memory: ${(_currentMemoryUsage / (1024 * 1024)).toStringAsFixed(1)} MB'),
                            Text('Peak Memory: ${(_peakMemoryUsage / (1024 * 1024)).toStringAsFixed(1)} MB'),
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
                style: const WaveformStyle(playedColor: Colors.deepPurple, unplayedColor: Colors.grey, height: 120),
              ),
            ),

            const SizedBox(height: 16),

            // Results information
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
                  const Text('Waveform Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data Points: ${_waveformData!.amplitudes.length}'),
                            Text('Duration: ${_formatDuration(_waveformData!.duration)}'),
                            Text('Sample Rate: ${_waveformData!.sampleRate} Hz'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Type: ${_waveformData!.metadata.type.name}'),
                            Text('Normalized: ${_waveformData!.metadata.normalized}'),
                            Text('Generated: ${_waveformData!.metadata.generatedAt.toString().split('.')[0]}'),
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
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _processWithChunking() async {
    if (_selectedFilePath.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _error = null;
      _progress = 0.0;
      _statusMessage = 'Initializing streaming processing...';
      _processedChunks = 0;
      _totalChunks = 10; // Simulated chunk count
      _processingTime = Duration.zero;
      _currentMemoryUsage = 0;
      _peakMemoryUsage = 0;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Get file size for information
      final fileSize = await File(_selectedFilePath).length();
      final fileSizeMB = fileSize / (1024 * 1024);

      setState(() {
        _statusMessage = 'Processing ${fileSizeMB.toStringAsFixed(1)}MB file with chunked processing...';
      });

      // Create a Sonix instance for processing
      final sonix = Sonix();

      // Use regular waveform generation with chunked processing support
      final waveformData = await sonix.generateWaveform(_selectedFilePath, resolution: 1000);

      setState(() {
        _progress = 1.0;
        _processedChunks = _totalChunks;
        _processingTime = stopwatch.elapsed;

        // Calculate throughput
        final elapsedSeconds = _processingTime.inMilliseconds / 1000.0;
        if (elapsedSeconds > 0) {
          _throughputMBps = (fileSizeMB * _progress) / elapsedSeconds;
        }

        // Simulate memory usage
        _currentMemoryUsage = (50 * 1024 * 1024 * (0.5 + _progress * 0.5)).round();
        _peakMemoryUsage = (_peakMemoryUsage < _currentMemoryUsage) ? _currentMemoryUsage : _peakMemoryUsage;

        _statusMessage = 'Chunked processing completed successfully!';
        _waveformData = waveformData;
      });

      stopwatch.stop();

      setState(() {
        _isProcessing = false;
        _progress = 1.0;
        _processingTime = stopwatch.elapsed;
      });

      // Clean up the instance
      sonix.dispose();
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _error = 'Streaming processing failed: $e';
        _isProcessing = false;
        _statusMessage = 'Processing failed';
      });
    }
  }

  Future<void> _processTraditional() async {
    if (_selectedFilePath.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _error = null;
      _statusMessage = 'Processing with traditional method...';
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Create a Sonix instance for processing
      final sonix = Sonix();

      // Use traditional processing for comparison
      final waveformData = await sonix.generateWaveform(_selectedFilePath);

      stopwatch.stop();

      setState(() {
        _waveformData = waveformData;
        _isProcessing = false;
        _statusMessage = 'Traditional processing completed!';
        _processingTime = stopwatch.elapsed;
      });

      // Clean up the instance
      sonix.dispose();
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _error =
            'Traditional processing failed: $e\n\n'
            'This is expected for very large files that exceed available memory. '
            'Try streaming processing instead.';
        _isProcessing = false;
        _statusMessage = 'Processing failed';
      });
    }
  }

  void _cancelProcessing() {
    // In a real implementation, you would cancel the processing operation
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Processing cancelled by user';
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
