import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';
import 'package:file_picker/file_picker.dart';

/// Example demonstrating concurrent isolate processing with up to 30 audio files.
///
/// This example showcases how the simplified single-isolate-per-request model
/// keeps the UI responsive even when processing many files simultaneously.
/// Each file spawns its own isolate, processes independently, and terminates
/// when complete.
class ConcurrentIsolateExample extends StatefulWidget {
  const ConcurrentIsolateExample({super.key});

  @override
  State<ConcurrentIsolateExample> createState() => _ConcurrentIsolateExampleState();
}

class _ConcurrentIsolateExampleState extends State<ConcurrentIsolateExample> with SingleTickerProviderStateMixin {
  static const int maxFiles = 50;
  static const int maxConcurrentIsolates = 8; // Limit concurrent processing

  final List<_AudioFileTask> _tasks = [];
  bool _isProcessing = false;
  int _completedCount = 0;
  int _errorCount = 0;
  int _activeIsolates = 0;

  // Animation to prove UI responsiveness
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Dispose any Sonix instances that might still be around
    for (final task in _tasks) {
      task.sonix?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concurrent Isolate Processing'),
        actions: [
          // Spinning icon to demonstrate UI responsiveness
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(angle: _rotationAnimation.value, child: const Icon(Icons.settings, size: 28));
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with controls
          _buildHeader(),

          // Progress summary
          if (_tasks.isNotEmpty) _buildProgressSummary(),

          // Task list
          Expanded(child: _tasks.isEmpty ? _buildEmptyState() : _buildTaskList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Load Multiple Audio Files', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Select up to $maxFiles files. Processes $maxConcurrentIsolates at a time. '
                      'Watch the spinning gear to verify UI stays responsive!',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _selectFiles,
                  icon: const Icon(Icons.add),
                  label: Text('Select Files (${_tasks.length}/$maxFiles)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_isProcessing || _tasks.isEmpty) ? null : _processAllFiles,
                  icon: _isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow),
                  label: Text(_isProcessing ? 'Processing...' : 'Process All'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(onPressed: _tasks.isEmpty ? null : _clearAll, icon: const Icon(Icons.delete_outline), tooltip: 'Clear All'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    final pendingCount = _tasks.where((t) => t.status == _TaskStatus.pending).length;
    final processingCount = _tasks.where((t) => t.status == _TaskStatus.processing).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusChip(Icons.hourglass_empty, 'Pending', pendingCount, Colors.grey),
          _buildStatusChip(Icons.sync, 'Processing', processingCount, Colors.blue),
          _buildStatusChip(Icons.check_circle, 'Completed', _completedCount, Colors.green),
          _buildStatusChip(Icons.error, 'Errors', _errorCount, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: TextStyle(fontWeight: FontWeight.w500, color: color),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No files selected', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(
            'Select audio files to see concurrent isolate processing in action',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskCard(_tasks[index], index);
      },
    );
  }

  Widget _buildTaskCard(_AudioFileTask task, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildStatusIcon(task.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(_getStatusText(task), style: TextStyle(fontSize: 12, color: _getStatusColor(task.status))),
                    ],
                  ),
                ),
                if (task.processingTime != null)
                  Chip(
                    label: Text('${task.processingTime!.inMilliseconds}ms'),
                    backgroundColor: Colors.green.shade100,
                    labelStyle: TextStyle(fontSize: 12, color: Colors.green.shade800),
                  ),
              ],
            ),
          ),

          // Waveform display (when completed)
          if (task.status == _TaskStatus.completed && task.waveformData != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: WaveformWidget(
                waveformData: task.waveformData!,
                style: WaveformStyle(
                  playedColor: Colors.primaries[index % Colors.primaries.length],
                  unplayedColor: Colors.grey.shade300,
                  height: 50,
                  barWidth: 2.0,
                  barSpacing: 1.0,
                  autoDisplayResolution: true,
                ),
              ),
            ),

          // Error display
          if (task.status == _TaskStatus.error && task.error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
              child: Text(
                task.error!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Processing indicator
          if (task.status == _TaskStatus.processing) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(_TaskStatus status) {
    switch (status) {
      case _TaskStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
      case _TaskStatus.processing:
        return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
      case _TaskStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case _TaskStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }

  String _getStatusText(_AudioFileTask task) {
    switch (task.status) {
      case _TaskStatus.pending:
        return 'Waiting to process...';
      case _TaskStatus.processing:
        return 'Processing in background isolate...';
      case _TaskStatus.completed:
        return 'Completed • ${task.waveformData?.amplitudes.length ?? 0} samples';
      case _TaskStatus.error:
        return 'Failed';
    }
  }

  Color _getStatusColor(_TaskStatus status) {
    switch (status) {
      case _TaskStatus.pending:
        return Colors.grey;
      case _TaskStatus.processing:
        return Colors.blue;
      case _TaskStatus.completed:
        return Colors.green;
      case _TaskStatus.error:
        return Colors.red;
    }
  }

  Future<void> _selectFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg', 'opus', 'mp4', 'm4a'],
        allowMultiple: true,
      );

      if (result != null) {
        final remainingSlots = maxFiles - _tasks.length;
        final filesToAdd = result.files.take(remainingSlots);

        setState(() {
          for (final file in filesToAdd) {
            if (file.path != null) {
              _tasks.add(_AudioFileTask(filePath: file.path!, fileName: file.name));
            }
          }
        });

        if (result.files.length > remainingSlots) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only added $remainingSlots files. Maximum is $maxFiles.')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting files: $e')));
      }
    }
  }

  Future<void> _processAllFiles() async {
    setState(() {
      _isProcessing = true;
      _completedCount = 0;
      _errorCount = 0;
      _activeIsolates = 0;
      // Reset all tasks to pending
      for (final task in _tasks) {
        task.status = _TaskStatus.pending;
        task.waveformData = null;
        task.error = null;
        task.processingTime = null;
        task.sonix?.dispose();
        task.sonix = null;
      }
    });

    // Use a queue-based approach with limited concurrency
    // This prevents spawning too many isolates at once which would block the UI
    final queue = List<_AudioFileTask>.from(_tasks);
    final activeFutures = <Future<void>>[];

    Future<void> processNext() async {
      while (queue.isNotEmpty && _activeIsolates < maxConcurrentIsolates) {
        final task = queue.removeAt(0);
        _activeIsolates++;

        // Process task and then try to start another
        final future = _processTask(task).then((_) {
          _activeIsolates--;
          // Start next task if any remain
          if (queue.isNotEmpty && mounted) {
            processNext();
          }
        });
        activeFutures.add(future);
      }
    }

    // Start initial batch of concurrent tasks
    await processNext();

    // Wait for all to complete
    await Future.wait(activeFutures);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processTask(_AudioFileTask task) async {
    setState(() {
      task.status = _TaskStatus.processing;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Each task gets its own Sonix instance
      // generateWaveformInIsolate spawns a dedicated isolate for this file
      task.sonix = Sonix();

      final waveformData = await task.sonix!.generateWaveformInIsolate(task.filePath, resolution: 500, normalize: true);

      stopwatch.stop();

      setState(() {
        task.status = _TaskStatus.completed;
        task.waveformData = waveformData;
        task.processingTime = stopwatch.elapsed;
        _completedCount++;
      });
    } catch (e) {
      stopwatch.stop();

      setState(() {
        task.status = _TaskStatus.error;
        task.error = e.toString();
        task.processingTime = stopwatch.elapsed;
        _errorCount++;
      });
    } finally {
      // Clean up the Sonix instance
      task.sonix?.dispose();
      task.sonix = null;
    }
  }

  void _clearAll() {
    setState(() {
      for (final task in _tasks) {
        task.sonix?.dispose();
      }
      _tasks.clear();
      _completedCount = 0;
      _errorCount = 0;
    });
  }
}

/// Represents a single audio file processing task
class _AudioFileTask {
  final String filePath;
  final String fileName;

  _TaskStatus status = _TaskStatus.pending;
  WaveformData? waveformData;
  String? error;
  Duration? processingTime;
  Sonix? sonix;

  _AudioFileTask({required this.filePath, required this.fileName});
}

enum _TaskStatus { pending, processing, completed, error }
