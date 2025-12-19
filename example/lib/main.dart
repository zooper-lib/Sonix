import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sonix/sonix.dart';

// Import example screens
import 'examples/basic_usage_example.dart';
import 'examples/playback_position_example.dart';
import 'examples/style_customization_example.dart';
import 'examples/pre_generated_data_example.dart';
import 'examples/chunked_large_file_example.dart';
import 'examples/chunked_progress_example.dart';
import 'examples/seeking_partial_waveform_example.dart';
import 'examples/performance_comparison_example.dart';
import 'examples/concurrent_isolate_example.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonix Examples',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sonix Examples'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sonix Audio Waveform Package',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore different features and capabilities',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Basic Examples Section
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Basic Examples', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildExampleCard(
                          context,
                          'Basic Usage',
                          'Simple waveform generation and display',
                          Icons.graphic_eq,
                          Colors.blue,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BasicUsageExample())),
                        ),
                        _buildExampleCard(
                          context,
                          'Playback Position',
                          'Interactive waveform with playback visualization',
                          Icons.play_circle_outline,
                          Colors.green,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaybackPositionExample())),
                        ),
                        _buildExampleCard(
                          context,
                          'Style Customization',
                          'Explore different visual styles and options',
                          Icons.palette,
                          Colors.purple,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StyleCustomizationExample())),
                        ),
                        _buildExampleCard(
                          context,
                          'Pre-generated Data',
                          'Using pre-computed waveform data',
                          Icons.data_object,
                          Colors.teal,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PreGeneratedDataExample())),
                        ),
                      ],
                    ),

                    // Chunked Processing Examples Section
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Chunked Processing Examples', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildExampleCard(
                          context,
                          'Large File Processing',
                          'Chunked processing for large audio files',
                          Icons.storage,
                          Colors.deepPurple,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChunkedLargeFileExample())),
                        ),
                        _buildExampleCard(
                          context,
                          'Progress Reporting',
                          'Real-time progress updates and metrics',
                          Icons.analytics,
                          Colors.indigo,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChunkedProgressExample())),
                        ),
                        _buildExampleCard(
                          context,
                          'Seeking & Partial',
                          'Generate waveforms for specific sections',
                          Icons.fast_forward,
                          Colors.teal,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SeekingPartialWaveformExample())),
                        ),

                        _buildExampleCard(
                          context,
                          'Performance Comparison',
                          'Benchmark different processing methods',
                          Icons.speed,
                          Colors.deepOrange,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PerformanceComparisonExample())),
                        ),
                        _buildExampleCard(
                          context,
                          'Concurrent Isolates',
                          'Load up to 30 files with responsive UI',
                          Icons.hub,
                          Colors.cyan,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConcurrentIsolateExample())),
                        ),
                        _buildExampleCard(
                          context,
                          'Full Demo',
                          'Complete audio decoder demonstration',
                          Icons.audiotrack,
                          Colors.red,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AudioDecoderPage())),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('About Sonix', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sonix is a comprehensive Flutter package for generating and displaying '
                    'audio waveforms using FFmpeg. It supports multiple audio '
                    'formats using native C libraries for optimal performance.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [_buildFeatureChip('MP3'), _buildFeatureChip('WAV'), _buildFeatureChip('FLAC'), _buildFeatureChip('OGG')]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleCard(BuildContext context, String title, String description, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
      ),
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

  // Sonix instance for audio processing
  late final Sonix _sonix;

  // Pre-create waveform styles to ensure consistent references
  late final WaveformStyle _soundCloudStyle = WaveformStylePresets.soundCloud;
  late final WaveformStyle _spotifyStyle = WaveformStylePresets.spotify;
  late final WaveformStyle _minimalLineStyle = WaveformStylePresets.minimalLine;
  late final WaveformStyle _filledGradientStyle = WaveformStylePresets.filledGradient();
  late final WaveformStyle _professionalStyle = WaveformStylePresets.professional;
  late final WaveformStyle _neonGlowStyle = WaveformStylePresets.neonGlow();

  late WaveformStyle _selectedStyle = _soundCloudStyle;
  DownsamplingAlgorithm _selectedAlgorithm = DownsamplingAlgorithm.rms;

  @override
  void initState() {
    super.initState();
    // Initialize Sonix instance with desktop configuration for better performance
    _sonix = Sonix(SonixConfig.desktop());
  }

  @override
  void dispose() {
    // Clean up Sonix instance
    _sonix.dispose();
    super.dispose();
  }

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
      final config = WaveformConfig(
        resolution: 200, // Good resolution for UI display
        type: WaveformType.bars,
        normalize: true,
        algorithm: _selectedAlgorithm, // Use the selected algorithm
      );

      final waveformData = await _sonix.generateWaveform(_selectedFilePath!, config: config);

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
      body: SingleChildScrollView(
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
              Card(
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
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
                        ),
                        const SizedBox(height: 12),

                        // Algorithm selector
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
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
                        ),
                        const SizedBox(height: 16),

                        // Waveform widget with constrained height
                        SizedBox(
                          height: 200,
                          child: WaveformWidget(
                            waveformData: _waveformData!,
                            playbackPosition: _playbackPosition,
                            style: _selectedStyle,
                            onSeek: (position) {
                              setState(() {
                                _playbackPosition = position;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Playback controls
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
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
