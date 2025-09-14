import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

/// Example showing waveform with playback position visualization and seeking
class PlaybackPositionExample extends StatefulWidget {
  const PlaybackPositionExample({super.key});

  @override
  State<PlaybackPositionExample> createState() => _PlaybackPositionExampleState();
}

class _PlaybackPositionExampleState extends State<PlaybackPositionExample> {
  WaveformData? _waveformData;
  double _playbackPosition = 0.0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  bool _isLoading = false;
  String _selectedFilePath = '';
  String? _error;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playback Position Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Interactive Waveform with Playback', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates real-time playback position updates '
              'and interactive seeking by tapping on the waveform.',
            ),
            const SizedBox(height: 24),

            // File selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Audio File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedFilePath.isEmpty ? 'No file selected' : 'Selected: ${_selectedFilePath.split('/').last}',
                            style: TextStyle(color: _selectedFilePath.isEmpty ? Colors.grey : Colors.black87),
                          ),
                        ),
                        ElevatedButton.icon(onPressed: _selectFile, icon: const Icon(Icons.folder_open), label: const Text('Select File')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Error display
            if (_error != null)
              Card(
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
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
                    ],
                  ),
                ),
              ),

            if (_error != null) const SizedBox(height: 16),

            if (_waveformData == null && _selectedFilePath.isNotEmpty)
              ElevatedButton(
                onPressed: _isLoading ? null : _loadWaveform,
                child: _isLoading
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Loading...'),
                        ],
                      )
                    : const Text('Load Waveform'),
              ),

            if (_waveformData != null) ...[
              // Waveform with playback position
              WaveformWidget(
                waveformData: _waveformData!,
                playbackPosition: _playbackPosition,
                style: WaveformStylePresets.soundCloud,
                onSeek: (position) {
                  setState(() {
                    _playbackPosition = position;
                  });
                  // In a real app, you would seek your audio player here
                  debugPrint('Seeking to position: ${(position * 100).toStringAsFixed(1)}%');
                },
                enableSeek: true,
                animationDuration: const Duration(milliseconds: 200),
              ),

              const SizedBox(height: 24),

              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(onPressed: _resetPlayback, icon: const Icon(Icons.skip_previous), label: const Text('Reset')),
                  ElevatedButton.icon(
                    onPressed: _togglePlayback,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_isPlaying ? 'Pause' : 'Play'),
                  ),
                  ElevatedButton.icon(onPressed: _skipToEnd, icon: const Icon(Icons.skip_next), label: const Text('End')),
                ],
              ),

              const SizedBox(height: 24),

              // Position slider for fine control
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manual Position Control:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Slider(
                    value: _playbackPosition,
                    onChanged: (value) {
                      setState(() {
                        _playbackPosition = value;
                      });
                    },
                    divisions: 100,
                    label: '${(_playbackPosition * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Position information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Playback Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Position: ${(_playbackPosition * 100).toStringAsFixed(1)}%'),
                    Text('Time: ${_formatTime(_playbackPosition * _waveformData!.duration.inMilliseconds)}'),
                    Text('Status: ${_isPlaying ? "Playing" : "Paused"}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Tip: Tap anywhere on the waveform to seek to that position!',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
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
          _playbackPosition = 0.0;
          _isPlaying = false;
        });
        _playbackTimer?.cancel();
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _loadWaveform() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create a Sonix instance for processing
      final sonix = SonixInstance();

      // Generate waveform optimized for music visualization
      final config = Sonix.getOptimalConfig(useCase: WaveformUseCase.musicVisualization, customResolution: 300);

      final waveformData = await sonix.generateWaveform(_selectedFilePath, config: config);

      setState(() {
        _waveformData = waveformData;
        _isLoading = false;
      });

      // Clean up the instance
      await sonix.dispose();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading waveform: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      // Simulate playback with a timer
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() {
          _playbackPosition += 0.01; // Advance by 1% every 100ms
          if (_playbackPosition >= 1.0) {
            _playbackPosition = 1.0;
            _isPlaying = false;
            timer.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _resetPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _playbackPosition = 0.0;
      _isPlaying = false;
    });
  }

  void _skipToEnd() {
    _playbackTimer?.cancel();
    setState(() {
      _playbackPosition = 1.0;
      _isPlaying = false;
    });
  }

  String _formatTime(double milliseconds) {
    final duration = Duration(milliseconds: milliseconds.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
