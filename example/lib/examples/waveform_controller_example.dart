import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';

/// Example demonstrating the WaveformController for programmatic control
/// of waveform seeking and playback position.
class WaveformControllerExample extends StatefulWidget {
  const WaveformControllerExample({super.key});

  @override
  State<WaveformControllerExample> createState() => _WaveformControllerExampleState();
}

class _WaveformControllerExampleState extends State<WaveformControllerExample> {
  final WaveformController _waveformController = WaveformController();
  WaveformData? _waveformData;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _generateSampleWaveform();
    _setupControllerListener();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _waveformController.dispose();
    super.dispose();
  }

  void _setupControllerListener() {
    _waveformController.addListener(() {
      // Listen to position changes from the controller
      debugPrint('Waveform position: ${_waveformController.position}');
    });
  }

  Future<void> _generateSampleWaveform() async {
    // Generate sample waveform data for demonstration
    final amplitudes = List.generate(200, (i) => (i % 20) / 20.0 + 0.1);

    setState(() {
      _waveformData = WaveformData(
        amplitudes: amplitudes,
        duration: const Duration(seconds: 10),
        sampleRate: 44100,
        metadata: WaveformMetadata(resolution: 200, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
      );
    });
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _startPlayback();
    } else {
      _pausePlayback();
    }
  }

  void _startPlayback() {
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final currentPosition = _waveformController.position;
      final increment = (50 / 10000) * _playbackSpeed; // 50ms of 10s duration

      if (currentPosition >= 1.0) {
        // Reached the end
        _pausePlayback();
        setState(() {
          _isPlaying = false;
        });
        return;
      }

      // Update position programmatically
      _waveformController.updatePosition(currentPosition + increment);
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
  }

  void _seekToPosition(double position) {
    _waveformController.seekTo(position);
  }

  void _resetPosition() {
    _waveformController.reset();
    _pausePlayback();
    setState(() {
      _isPlaying = false;
    });
  }

  void _jumpToQuarter(int quarter) {
    final position = quarter * 0.25;
    _waveformController.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waveform Controller Example')),
      body: _waveformData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('WaveformController Demo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text(
                              'Use the WaveformController to programmatically control '
                              'the waveform position. The controller allows you to seek, '
                              'update position, and listen to changes.',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Current Position: ${(_waveformController.position * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Waveform widget with controller
                    WaveformWidget(
                      waveformData: _waveformData!,
                      controller: _waveformController,
                      style: WaveformStyle(
                        playedColor: Colors.blue,
                        unplayedColor: Colors.blue.withValues(alpha: 0.5),
                        backgroundColor: Colors.grey[200]!,
                        height: 100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSeek: (position) {
                        debugPrint('User seeked to: ${(position * 100).toStringAsFixed(1)}%');
                        // In a real app, you'd seek the audio player here
                      },
                    ),
                    const SizedBox(height: 24),

                    // Playback controls
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Playback Controls', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(onPressed: _resetPosition, icon: const Icon(Icons.skip_previous), label: const Text('Reset')),
                                ElevatedButton.icon(
                                  onPressed: _togglePlayback,
                                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                                  label: Text(_isPlaying ? 'Pause' : 'Play'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('Speed: '),
                                Expanded(
                                  child: Slider(
                                    value: _playbackSpeed,
                                    min: 0.5,
                                    max: 2.0,
                                    divisions: 6,
                                    label: '${_playbackSpeed.toStringAsFixed(1)}x',
                                    onChanged: (value) {
                                      setState(() {
                                        _playbackSpeed = value;
                                      });
                                    },
                                  ),
                                ),
                                Text('${_playbackSpeed.toStringAsFixed(1)}x'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick seek buttons
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Quick Seek (Programmatic)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(onPressed: () => _jumpToQuarter(0), child: const Text('0%')),
                                ElevatedButton(onPressed: () => _jumpToQuarter(1), child: const Text('25%')),
                                ElevatedButton(onPressed: () => _jumpToQuarter(2), child: const Text('50%')),
                                ElevatedButton(onPressed: () => _jumpToQuarter(3), child: const Text('75%')),
                                ElevatedButton(onPressed: () => _seekToPosition(1.0), child: const Text('100%')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Animation toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Animation Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Animate Seeks'),
                              subtitle: const Text('When enabled, programmatic seeks will animate smoothly'),
                              value: _waveformController.shouldAnimate,
                              onChanged: (value) {
                                setState(() {
                                  _waveformController.setAnimationEnabled(value);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Code example
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Code Example', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                              child: const SelectableText('''// Create controller
final controller = WaveformController();

// Use in widget
WaveformWidget(
  waveformData: data,
  controller: controller,
  onSeek: (position) {
    audioPlayer.seek(duration * position);
  },
)

// Programmatic seek
controller.seekTo(0.5); // Jump to middle

// Update position (no seek event)
controller.updatePosition(0.3);

// Listen to changes
controller.addListener(() {
  print(controller.position);
});''', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
