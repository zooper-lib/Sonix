import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sonix/sonix.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonix Audio Decoder',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const AudioDecoderPage(),
    );
  }
}

class AudioDecoderPage extends StatefulWidget {
  const AudioDecoderPage({super.key});

  @override
  State<AudioDecoderPage> createState() => _AudioDecoderPageState();
}

class _AudioDecoderPageState extends State<AudioDecoderPage> {
  String? _selectedFilePath;
  String? _fileName;
  WaveformData? _waveformData;
  bool _isDecoding = false;
  bool _isGeneratingWaveform = false;
  String? _errorMessage;
  String? _detectedFormat;
  double _playbackPosition = 0.0;

  // Pre-create waveform styles to ensure consistent references
  late final WaveformStyle _soundCloudStyle = WaveformStylePresets.soundCloud;
  late final WaveformStyle _spotifyStyle = WaveformStylePresets.spotify;
  late final WaveformStyle _minimalLineStyle = WaveformStylePresets.minimalLine;
  late final WaveformStyle _filledGradientStyle = WaveformStylePresets.filledGradient();
  late final WaveformStyle _professionalStyle = WaveformStylePresets.professional;
  late final WaveformStyle _neonGlowStyle = WaveformStylePresets.neonGlow();

  late WaveformStyle _selectedStyle = _soundCloudStyle;
  DownsamplingAlgorithm _selectedAlgorithm = DownsamplingAlgorithm.rms;
  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _fileName = result.files.single.name;
          _waveformData = null;
          _errorMessage = null;
          _detectedFormat = null;
          _playbackPosition = 0.0;
          _selectedAlgorithm = DownsamplingAlgorithm.rms;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _decodeAudioFile() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isDecoding = true;
      _isGeneratingWaveform = true;
      _errorMessage = null;
    });

    try {
      // Generate waveform with optimal settings for visualization
      final config =
          Sonix.getOptimalConfig(
            useCase: WaveformUseCase.musicVisualization,
            customResolution: 200, // Good resolution for UI display
          ).copyWith(
            algorithm: _selectedAlgorithm, // Use the selected algorithm
          );

      final waveformData = await Sonix.generateWaveform(_selectedFilePath!, config: config);

      setState(() {
        _waveformData = waveformData;
        _isDecoding = false;
        _isGeneratingWaveform = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating waveform: $e';
        _isDecoding = false;
        _isGeneratingWaveform = false;
      });
    }
  }

  Future<void> _regenerateWaveform() async {
    if (_selectedFilePath == null) return;
    await _decodeAudioFile(); // Just regenerate with current settings
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: const Text('Sonix Audio Decoder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Audio File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Supported formats: WAV, MP3, FLAC, OGG'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _pickAudioFile, icon: const Icon(Icons.folder_open), label: const Text('Pick Audio File')),
                    if (_fileName != null) ...[const SizedBox(height: 8), Text('Selected: $_fileName', style: const TextStyle(fontWeight: FontWeight.w500))],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedFilePath != null)
              ElevatedButton.icon(
                onPressed: _isDecoding ? null : _decodeAudioFile,
                icon: _isDecoding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                label: Text(_isDecoding ? 'Decoding...' : 'Decode Audio'),
              ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
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
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            if (_waveformData != null)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Decoded Audio Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (_detectedFormat != null) _buildInfoRow('Detected Format', _detectedFormat!),
                        const Text('Sample Preview (first 10 values):', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),

                        // Waveform Visualization Section
                        const Text('Waveform Visualization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        if (_isGeneratingWaveform)
                          const Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Generating waveform...')]))
                        else if (_waveformData != null) ...[
                          // Style selector
                          Row(
                            children: [
                              const Text('Style: ', style: TextStyle(fontWeight: FontWeight.w500)),
                              DropdownButton<WaveformStyle>(
                                value: _selectedStyle,
                                onChanged: (style) {
                                  if (style != null) {
                                    setState(() {
                                      _selectedStyle = style;
                                    });
                                  }
                                },
                                items: [
                                  DropdownMenuItem(value: _soundCloudStyle, child: const Text('SoundCloud')),
                                  DropdownMenuItem(value: _spotifyStyle, child: const Text('Spotify')),
                                  DropdownMenuItem(value: _minimalLineStyle, child: const Text('Minimal Line')),
                                  DropdownMenuItem(value: _filledGradientStyle, child: const Text('Filled Gradient')),
                                  DropdownMenuItem(value: _professionalStyle, child: const Text('Professional')),
                                  DropdownMenuItem(value: _neonGlowStyle, child: const Text('Neon Glow')),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Algorithm selector
                          Row(
                            children: [
                              const Text('Algorithm: ', style: TextStyle(fontWeight: FontWeight.w500)),
                              DropdownButton<DownsamplingAlgorithm>(
                                value: _selectedAlgorithm,
                                onChanged: (algorithm) {
                                  if (algorithm != null) {
                                    setState(() {
                                      _selectedAlgorithm = algorithm;
                                    });
                                    _regenerateWaveform();
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(value: DownsamplingAlgorithm.rms, child: Text('RMS (Loudness)')),
                                  DropdownMenuItem(value: DownsamplingAlgorithm.peak, child: Text('Peak (Maximum)')),
                                  DropdownMenuItem(value: DownsamplingAlgorithm.average, child: Text('Average')),
                                  DropdownMenuItem(value: DownsamplingAlgorithm.median, child: Text('Median')),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Waveform widget
                          WaveformWidget(
                            waveformData: _waveformData!,
                            playbackPosition: _playbackPosition,
                            style: _selectedStyle,
                            onSeek: (position) {
                              setState(() {
                                _playbackPosition = position;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Playback controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _playbackPosition = 0.0;
                                  });
                                },
                                icon: const Icon(Icons.skip_previous),
                                label: const Text('Reset'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _playbackPosition = (_playbackPosition + 0.1).clamp(0.0, 1.0);
                                  });
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Simulate Play'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Waveform info
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
                                const Text('Waveform Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Resolution: ${_waveformData!.amplitudes.length} points'),
                                Text('Algorithm: ${_selectedAlgorithm.name.toUpperCase()}'),
                                Text('Type: ${_waveformData!.metadata.type.name}'),
                                Text('Normalized: ${_waveformData!.metadata.normalized}'),
                                Text('Generated: ${_waveformData!.metadata.generatedAt.toString().split('.')[0]}'),
                                Text('Playback Position: ${(_playbackPosition * 100).toStringAsFixed(1)}%'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: SelectableText('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
