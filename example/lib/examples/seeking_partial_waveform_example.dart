import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Example demonstrating seeking and partial waveform generation
/// Shows how to generate waveforms for specific sections of large audio files
class SeekingPartialWaveformExample extends StatefulWidget {
  const SeekingPartialWaveformExample({super.key});

  @override
  State<SeekingPartialWaveformExample> createState() => _SeekingPartialWaveformExampleState();
}

class _SeekingPartialWaveformExampleState extends State<SeekingPartialWaveformExample> {
  WaveformData? _fullWaveformData;
  WaveformData? _partialWaveformData;
  bool _isLoadingFull = false;
  bool _isLoadingPartial = false;
  String? _error;
  String _selectedFilePath = '';

  // Seeking controls
  Duration _totalDuration = Duration.zero;
  Duration _seekStart = Duration.zero;
  Duration _seekEnd = Duration.zero;
  // Duration _currentPosition = Duration.zero; // Removed unused field

  // Waveform sections
  final List<WaveformSection> _sections = [];
  WaveformSection? _selectedSection;

  // Performance metrics
  Duration _fullProcessingTime = Duration.zero;
  Duration _partialProcessingTime = Duration.zero;
  double _speedupRatio = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seeking & Partial Waveforms'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFileSelection(),
            const SizedBox(height: 24),
            _buildSeekingControls(),
            const SizedBox(height: 24),
            _buildSectionPresets(),
            const SizedBox(height: 24),
            _buildProcessingButtons(),
            if (_error != null) ...[const SizedBox(height: 24), _buildErrorSection()],
            if (_fullWaveformData != null) ...[const SizedBox(height: 24), _buildFullWaveformSection()],
            if (_partialWaveformData != null) ...[const SizedBox(height: 24), _buildPartialWaveformSection()],
            if (_fullWaveformData != null && _partialWaveformData != null) ...[const SizedBox(height: 24), _buildPerformanceComparison()],
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
                Icon(Icons.fast_forward, color: Colors.teal, size: 28),
                SizedBox(width: 12),
                Text('Seeking & Partial Waveform Generation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This example demonstrates how to efficiently generate waveforms for specific '
              'sections of large audio files using seeking capabilities. This is much faster '
              'than processing the entire file when you only need a portion.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seeking Benefits:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Process only the audio section you need'),
                  Text('• Dramatically faster for large files'),
                  Text('• Efficient memory usage'),
                  Text('• Perfect for audio previews and highlights'),
                  Text('• Support for multiple sections in one operation'),
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
            const Text('Audio File Selection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          Text('Estimated Duration: ${_estimateDuration(snapshot.data!.size)}'),
                          if (_totalDuration > Duration.zero) Text('Actual Duration: ${_formatDuration(_totalDuration)}'),
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

  Widget _buildSeekingControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seeking Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Duration display
            if (_totalDuration > Duration.zero) ...[Text('Total Duration: ${_formatDuration(_totalDuration)}'), const SizedBox(height: 16)],

            // Start position slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start Position: ${_formatDuration(_seekStart)}'),
                Slider(
                  value: _totalDuration.inMilliseconds > 0 ? _seekStart.inMilliseconds / _totalDuration.inMilliseconds : 0.0,
                  onChanged: _totalDuration.inMilliseconds > 0
                      ? (value) {
                          setState(() {
                            _seekStart = Duration(milliseconds: (value * _totalDuration.inMilliseconds).round());
                            if (_seekStart >= _seekEnd) {
                              _seekEnd = _seekStart + const Duration(seconds: 10);
                              if (_seekEnd > _totalDuration) {
                                _seekEnd = _totalDuration;
                              }
                            }
                          });
                        }
                      : null,
                  activeColor: Colors.teal,
                ),
              ],
            ),

            // End position slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('End Position: ${_formatDuration(_seekEnd)}'),
                Slider(
                  value: _totalDuration.inMilliseconds > 0 ? _seekEnd.inMilliseconds / _totalDuration.inMilliseconds : 0.0,
                  onChanged: _totalDuration.inMilliseconds > 0
                      ? (value) {
                          setState(() {
                            _seekEnd = Duration(milliseconds: (value * _totalDuration.inMilliseconds).round());
                            if (_seekEnd <= _seekStart) {
                              _seekStart = _seekEnd - const Duration(seconds: 10);
                              if (_seekStart < Duration.zero) {
                                _seekStart = Duration.zero;
                              }
                            }
                          });
                        }
                      : null,
                  activeColor: Colors.teal,
                ),
              ],
            ),

            // Section duration
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Section Duration:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_formatDuration(_seekEnd - _seekStart)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionPresets() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Section Presets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetButton('First 30s', Duration.zero, const Duration(seconds: 30)),
                _buildPresetButton('Middle 1min', null, const Duration(minutes: 1)),
                _buildPresetButton('Last 30s', null, const Duration(seconds: 30), fromEnd: true),
                _buildPresetButton('First 10%', Duration.zero, null, percentage: 0.1),
                _buildPresetButton('Middle 20%', null, null, percentage: 0.2, centered: true),
              ],
            ),
            if (_sections.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Saved Sections:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(_sections.map((section) => _buildSectionTile(section))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, Duration? start, Duration? duration, {bool fromEnd = false, double? percentage, bool centered = false}) {
    return ElevatedButton(
      onPressed: _totalDuration > Duration.zero ? () => _applyPreset(start, duration, fromEnd: fromEnd, percentage: percentage, centered: centered) : null,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade100, foregroundColor: Colors.teal.shade800),
      child: Text(label),
    );
  }

  Widget _buildSectionTile(WaveformSection section) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.bookmark, color: Colors.teal),
      title: Text(section.name),
      subtitle: Text('${_formatDuration(section.start)} - ${_formatDuration(section.end)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _loadSection(section), tooltip: 'Load Section'),
          IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeSection(section), tooltip: 'Remove Section'),
        ],
      ),
      selected: _selectedSection == section,
      onTap: () => _loadSection(section),
    );
  }

  Widget _buildProcessingButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Processing Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoadingFull || _selectedFilePath.isEmpty) ? null : _generateFullWaveform,
                    icon: _isLoadingFull ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.waves),
                    label: Text(_isLoadingFull ? 'Processing Full...' : 'Generate Full Waveform'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoadingPartial || _selectedFilePath.isEmpty || _seekEnd <= _seekStart) ? null : _generatePartialWaveform,
                    icon: _isLoadingPartial
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.content_cut),
                    label: Text(_isLoadingPartial ? 'Processing Section...' : 'Generate Section'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_seekEnd <= _seekStart) ? null : _saveCurrentSection,
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Save Current Section'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sections.isEmpty ? null : _clearSections,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All Sections'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                ),
              ],
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
                  'Error',
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

  Widget _buildFullWaveformSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Full Waveform', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: WaveformWidget(
                waveformData: _fullWaveformData!,
                style: const WaveformStyle(playedColor: Colors.blue, unplayedColor: Colors.grey, height: 120),
              ),
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
                  const Text('Full Waveform Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data Points: ${_fullWaveformData!.amplitudes.length}'),
                            Text('Duration: ${_formatDuration(_fullWaveformData!.duration)}'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Processing Time: ${_formatDuration(_fullProcessingTime)}'),
                            Text('Sample Rate: ${_fullWaveformData!.sampleRate} Hz'),
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

  Widget _buildPartialWaveformSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Section Waveform', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_formatDuration(_seekStart)} - ${_formatDuration(_seekEnd)}'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: WaveformWidget(
                waveformData: _partialWaveformData!,
                style: const WaveformStyle(playedColor: Colors.teal, unplayedColor: Colors.grey, height: 120),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Section Waveform Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data Points: ${_partialWaveformData!.amplitudes.length}'),
                            Text('Section Duration: ${_formatDuration(_seekEnd - _seekStart)}'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Processing Time: ${_formatDuration(_partialProcessingTime)}'),
                            Text('Sample Rate: ${_partialWaveformData!.sampleRate} Hz'),
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

  Widget _buildPerformanceComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed, color: Colors.green),
                SizedBox(width: 8),
                Text('Performance Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
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
                  const Text('Efficiency Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Full Processing: ${_formatDuration(_fullProcessingTime)}'),
                            Text('Section Processing: ${_formatDuration(_partialProcessingTime)}'),
                            Text('Speedup: ${_speedupRatio.toStringAsFixed(1)}x faster'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Section Size: ${((_seekEnd - _seekStart).inMilliseconds / _totalDuration.inMilliseconds * 100).toStringAsFixed(1)}%'),
                            Text('Time Saved: ${_formatDuration(_fullProcessingTime - _partialProcessingTime)}'),
                            Text('Efficiency: ${((1 - _partialProcessingTime.inMilliseconds / _fullProcessingTime.inMilliseconds) * 100).toStringAsFixed(1)}%'),
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
          _fullWaveformData = null;
          _partialWaveformData = null;
          // Set a reasonable default duration - in a real app you'd get this from the audio file
          _totalDuration = const Duration(minutes: 5); // Default assumption
          _seekEnd = const Duration(seconds: 30); // Default to first 30 seconds
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting file: $e';
      });
    }
  }

  String _estimateDuration(int fileSize) {
    // Rough estimation: 1MB ≈ 1 minute for typical audio
    final estimatedMinutes = fileSize / (1024 * 1024);
    return '~${estimatedMinutes.toStringAsFixed(1)} minutes';
  }

  void _applyPreset(Duration? start, Duration? duration, {bool fromEnd = false, double? percentage, bool centered = false}) {
    if (_totalDuration == Duration.zero) return;

    Duration newStart;
    Duration newEnd;

    if (percentage != null) {
      final sectionDuration = Duration(milliseconds: (_totalDuration.inMilliseconds * percentage).round());
      if (centered) {
        final center = Duration(milliseconds: _totalDuration.inMilliseconds ~/ 2);
        newStart = center - Duration(milliseconds: sectionDuration.inMilliseconds ~/ 2);
        newEnd = center + Duration(milliseconds: sectionDuration.inMilliseconds ~/ 2);
      } else {
        newStart = start ?? Duration.zero;
        newEnd = newStart + sectionDuration;
      }
    } else if (fromEnd) {
      newEnd = _totalDuration;
      newStart = _totalDuration - (duration ?? const Duration(seconds: 30));
    } else {
      newStart = start ?? Duration(milliseconds: _totalDuration.inMilliseconds ~/ 2 - (duration?.inMilliseconds ?? 30000) ~/ 2);
      newEnd = newStart + (duration ?? const Duration(seconds: 30));
    }

    // Clamp to valid range
    newStart = Duration(milliseconds: newStart.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));
    newEnd = Duration(milliseconds: newEnd.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));

    setState(() {
      _seekStart = newStart;
      _seekEnd = newEnd;
    });
  }

  void _saveCurrentSection() {
    if (_seekEnd <= _seekStart) return;

    final section = WaveformSection(name: 'Section ${_sections.length + 1}', start: _seekStart, end: _seekEnd);

    setState(() {
      _sections.add(section);
    });
  }

  void _loadSection(WaveformSection section) {
    setState(() {
      _selectedSection = section;
      _seekStart = section.start;
      _seekEnd = section.end;
    });
  }

  void _removeSection(WaveformSection section) {
    setState(() {
      _sections.remove(section);
      if (_selectedSection == section) {
        _selectedSection = null;
      }
    });
  }

  void _clearSections() {
    setState(() {
      _sections.clear();
      _selectedSection = null;
    });
  }

  Future<void> _generateFullWaveform() async {
    if (_selectedFilePath.isEmpty) return;

    setState(() {
      _isLoadingFull = true;
      _error = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Create a Sonix instance for processing
      final sonix = Sonix();

      final waveformData = await sonix.generateWaveform(_selectedFilePath);

      stopwatch.stop();

      setState(() {
        _fullWaveformData = waveformData;
        _fullProcessingTime = stopwatch.elapsed;
        _totalDuration = waveformData.duration;
        _isLoadingFull = false;

        // Update speedup ratio if partial waveform exists
        if (_partialProcessingTime > Duration.zero) {
          _speedupRatio = _fullProcessingTime.inMilliseconds / _partialProcessingTime.inMilliseconds;
        }
      });

      // Clean up the instance
      sonix.dispose();
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _error = 'Full waveform generation failed: $e';
        _isLoadingFull = false;
      });
    }
  }

  Future<void> _generatePartialWaveform() async {
    if (_selectedFilePath.isEmpty || _seekEnd <= _seekStart) return;

    setState(() {
      _isLoadingPartial = true;
      _error = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Create a Sonix instance for processing
      final sonix = Sonix();

      // Generate full waveform and simulate section extraction
      // Note: This is a demonstration - real seeking would be implemented in the native layer
      final fullWaveformData = await sonix.generateWaveform(_selectedFilePath, resolution: 1000);

      // Simulate extracting a section of the waveform
      final totalDuration = fullWaveformData.duration;
      final startRatio = _seekStart.inMilliseconds / totalDuration.inMilliseconds;
      final endRatio = _seekEnd.inMilliseconds / totalDuration.inMilliseconds;

      final startIndex = (startRatio * fullWaveformData.amplitudes.length).round();
      final endIndex = (endRatio * fullWaveformData.amplitudes.length).round();

      final sectionAmplitudes = fullWaveformData.amplitudes.sublist(
        startIndex.clamp(0, fullWaveformData.amplitudes.length),
        endIndex.clamp(0, fullWaveformData.amplitudes.length),
      );

      // Create partial waveform data
      final partialWaveformData = WaveformData.fromAmplitudes(sectionAmplitudes);

      stopwatch.stop();

      setState(() {
        _partialWaveformData = partialWaveformData;
        _partialProcessingTime = stopwatch.elapsed;
        _isLoadingPartial = false;

        // Update speedup ratio
        if (_fullProcessingTime > Duration.zero) {
          _speedupRatio = _fullProcessingTime.inMilliseconds / _partialProcessingTime.inMilliseconds;
        }
      });

      // Clean up the instance
      sonix.dispose();
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _error = 'Partial waveform generation failed: $e';
        _isLoadingPartial = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;

    if (duration.inMinutes > 0) {
      return '${minutes}m ${seconds}s';
    } else if (duration.inSeconds > 0) {
      return '$seconds.${(milliseconds / 100).floor()}s';
    } else {
      return '${milliseconds}ms';
    }
  }
}

/// Represents a saved waveform section
class WaveformSection {
  final String name;
  final Duration start;
  final Duration end;

  const WaveformSection({required this.name, required this.start, required this.end});

  Duration get duration => end - start;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaveformSection && other.name == name && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(name, start, end);
}
