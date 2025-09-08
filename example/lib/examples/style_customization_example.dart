import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';

/// Example showing different waveform styles and customization options
class StyleCustomizationExample extends StatefulWidget {
  const StyleCustomizationExample({super.key});

  @override
  State<StyleCustomizationExample> createState() => _StyleCustomizationExampleState();
}

class _StyleCustomizationExampleState extends State<StyleCustomizationExample> {
  WaveformData? _waveformData;
  bool _isLoading = false;
  double _playbackPosition = 0.3; // 30% for demonstration

  // Style options
  WaveformType _selectedType = WaveformType.bars;
  Color _playedColor = Colors.blue;
  Color _unplayedColor = Colors.grey;
  double _height = 80;
  double _barWidth = 2.0;
  double _barSpacing = 1.0;
  bool _useGradient = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Style Customization')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Waveform Style Customization', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Explore different visual styles and customization options for waveforms.'),
            const SizedBox(height: 24),

            if (_waveformData == null)
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
              // Current waveform display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Style:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    WaveformWidget(waveformData: _waveformData!, playbackPosition: _playbackPosition, style: _buildCurrentStyle()),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Style controls
              const Text('Customization Options:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Waveform type
              _buildOptionCard(
                'Waveform Type',
                DropdownButton<WaveformType>(
                  value: _selectedType,
                  isExpanded: true,
                  onChanged: (type) {
                    if (type != null) {
                      setState(() {
                        _selectedType = type;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: WaveformType.bars, child: Text('Bars (Classic)')),
                    DropdownMenuItem(value: WaveformType.line, child: Text('Line (Continuous)')),
                    DropdownMenuItem(value: WaveformType.filled, child: Text('Filled (Solid)')),
                  ],
                ),
              ),

              // Colors
              _buildOptionCard(
                'Colors',
                Column(
                  children: [
                    Row(
                      children: [
                        const Text('Played: '),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showColorPicker(true),
                          child: Container(
                            width: 40,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _playedColor,
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text('Unplayed: '),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showColorPicker(false),
                          child: Container(
                            width: 40,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _unplayedColor,
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _useGradient,
                          onChanged: (value) {
                            setState(() {
                              _useGradient = value ?? false;
                            });
                          },
                        ),
                        const Text('Use Gradient Effect'),
                      ],
                    ),
                  ],
                ),
              ),

              // Dimensions
              _buildOptionCard(
                'Dimensions',
                Column(
                  children: [
                    Row(
                      children: [
                        const Text('Height: '),
                        Expanded(
                          child: Slider(
                            value: _height,
                            min: 40,
                            max: 200,
                            divisions: 16,
                            label: '${_height.round()}px',
                            onChanged: (value) {
                              setState(() {
                                _height = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedType == WaveformType.bars) ...[
                      Row(
                        children: [
                          const Text('Bar Width: '),
                          Expanded(
                            child: Slider(
                              value: _barWidth,
                              min: 1,
                              max: 8,
                              divisions: 7,
                              label: '${_barWidth.toStringAsFixed(1)}px',
                              onChanged: (value) {
                                setState(() {
                                  _barWidth = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Bar Spacing: '),
                          Expanded(
                            child: Slider(
                              value: _barSpacing,
                              min: 0,
                              max: 4,
                              divisions: 8,
                              label: '${_barSpacing.toStringAsFixed(1)}px',
                              onChanged: (value) {
                                setState(() {
                                  _barSpacing = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Playback position control
              _buildOptionCard(
                'Playback Position',
                Column(
                  children: [
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
                    Text('Position: ${(_playbackPosition * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Preset styles
              const Text('Preset Styles:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _buildPresetGrid(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPresetGrid() {
    final presets = [
      ('SoundCloud', WaveformStylePresets.soundCloud),
      ('Spotify', WaveformStylePresets.spotify),
      ('Professional', WaveformStylePresets.professional),
      ('Minimal Line', WaveformStylePresets.minimalLine),
      ('Filled Gradient', WaveformStylePresets.filledGradient()),
      ('Neon Glow', WaveformStylePresets.neonGlow()),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final (name, style) = presets[index];
        return GestureDetector(
          onTap: () => _applyPresetStyle(style),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Expanded(
                  child: WaveformWidget(waveformData: _waveformData!, playbackPosition: _playbackPosition, style: style.copyWith(height: 40)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  WaveformStyle _buildCurrentStyle() {
    return WaveformStyle(
      playedColor: _playedColor,
      unplayedColor: _unplayedColor,
      height: _height,
      type: _selectedType,
      barWidth: _barWidth,
      barSpacing: _barSpacing,
      gradient: _useGradient
          ? LinearGradient(colors: [_playedColor, _playedColor.withValues(alpha: 0.3)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
          : null,
    );
  }

  void _applyPresetStyle(WaveformStyle style) {
    setState(() {
      _selectedType = style.type;
      _playedColor = style.playedColor;
      _unplayedColor = style.unplayedColor;
      _height = style.height;
      _barWidth = style.barWidth;
      _barSpacing = style.barSpacing;
      _useGradient = style.gradient != null;
    });
  }

  Future<void> _loadWaveform() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final waveformData = await Sonix.generateWaveform(
        'assets/sample_audio.mp3', // Replace with your audio file
        resolution: 150,
        normalize: true,
      );

      setState(() {
        _waveformData = waveformData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading waveform: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showColorPicker(bool isPlayedColor) {
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose ${isPlayedColor ? 'Played' : 'Unplayed'} Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isPlayedColor) {
                    _playedColor = color;
                  } else {
                    _unplayedColor = color;
                  }
                });
                Navigator.of(context).pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
