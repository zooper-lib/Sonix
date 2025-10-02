import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';
import 'dart:convert';

/// Example showing how to use pre-generated waveform data
class PreGeneratedDataExample extends StatefulWidget {
  const PreGeneratedDataExample({super.key});

  @override
  State<PreGeneratedDataExample> createState() => _PreGeneratedDataExampleState();
}

class _PreGeneratedDataExampleState extends State<PreGeneratedDataExample> {
  WaveformData? _waveformFromJson;
  WaveformData? _waveformFromAmplitudes;
  WaveformData? _waveformFromString;
  double _playbackPosition = 0.4;

  @override
  void initState() {
    super.initState();
    _loadPreGeneratedData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-generated Data')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Using Pre-generated Waveform Data', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates how to use pre-computed waveform data '
              'instead of generating it from audio files. This is useful for '
              'displaying waveforms when you already have the data or want to '
              'avoid processing time.',
            ),
            const SizedBox(height: 24),

            // From JSON object
            _buildWaveformSection('From JSON Object', 'Create waveform from a complete JSON object with metadata', _waveformFromJson, _buildJsonCode()),

            const SizedBox(height: 24),

            // From amplitude array
            _buildWaveformSection(
              'From Amplitude Array',
              'Create waveform from just amplitude values (simplified)',
              _waveformFromAmplitudes,
              _buildAmplitudeCode(),
            ),

            const SizedBox(height: 24),

            // From JSON string
            _buildWaveformSection(
              'From JSON String',
              'Create waveform from a JSON string (e.g., from API or file)',
              _waveformFromString,
              _buildJsonStringCode(),
            ),

            const SizedBox(height: 24),

            // Playback position control
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Playback Position Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('All waveforms above use the same playback position:'),
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
                    Text('Position: ${(_playbackPosition * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Usage tips
            _buildUsageTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformSection(String title, String description, WaveformData? waveformData, Widget codeExample) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),

            if (waveformData != null) ...[
              WaveformWidget(waveformData: waveformData, playbackPosition: _playbackPosition, style: WaveformStylePresets.soundCloud),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Waveform Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Data Points: ${waveformData.amplitudes.length}'),
                    Text('Duration: ${waveformData.duration.inSeconds}s'),
                    Text('Sample Rate: ${waveformData.sampleRate} Hz'),
                    Text('Type: ${waveformData.metadata.type.name}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ExpansionTile(
              title: const Text('Code Example'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: codeExample,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJsonCode() {
    return const SelectableText('''// Create from complete JSON object
final jsonData = {
  'amplitudes': [0.1, 0.5, 0.8, 0.3, 0.7, 0.2, 0.9, 0.4],
  'duration': 5000000, // microseconds
  'sampleRate': 44100,
  'metadata': {
    'resolution': 8,
    'type': 'bars',
    'normalized': true,
    'generatedAt': '2024-01-01T12:00:00.000Z'
  }
};

final waveformData = WaveformData.fromJson(jsonData);

// Use in widget
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.soundCloud,
)''', style: TextStyle(fontFamily: 'monospace', fontSize: 12));
  }

  Widget _buildAmplitudeCode() {
    return const SelectableText('''// Create from amplitude array (simplified)
final amplitudes = [
  0.1, 0.5, 0.8, 0.3, 0.7, 0.2, 0.9, 0.4,
  0.6, 0.3, 0.8, 0.1, 0.9, 0.5, 0.2, 0.7
];

final waveformData = WaveformData.fromAmplitudes(amplitudes);

// Use in widget
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.spotify,
)''', style: TextStyle(fontFamily: 'monospace', fontSize: 12));
  }

  Widget _buildJsonStringCode() {
    return const SelectableText(r'''// Create from JSON string (e.g., from API or file)
final jsonString = """{
  "amplitudes": [0.2, 0.6, 0.9, 0.4, 0.8, 0.1, 0.7, 0.3],
  "duration": 8000000,
  "sampleRate": 44100,
  "metadata": {
    "resolution": 8,
    "type": "bars",
    "normalized": true,
    "generatedAt": "2024-01-01T12:00:00.000Z"
  }
}""";

final waveformData = WaveformData.fromJsonString(jsonString);

// Or from amplitude string
final amplitudeString = '[0.2, 0.6, 0.9, 0.4, 0.8]';
final waveformFromAmps = WaveformData.fromAmplitudeString(amplitudeString);''', style: TextStyle(fontFamily: 'monospace', fontSize: 12));
  }

  Widget _buildUsageTips() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Usage Tips',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              '• Use pre-generated data when you want to avoid processing time\n'
              '• Store waveform data in your database or cache for quick access\n'
              '• fromAmplitudes() is perfect for simple use cases\n'
              '• fromJson() preserves all metadata and is recommended for full features\n'
              '• fromJsonString() is useful when loading from files or APIs\n'
              '• All pre-generated waveforms support the same features as generated ones\n'
              '• Amplitude values should be between 0.0 and 1.0 for best results',
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Common Use Cases:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Displaying waveforms from server-generated data\n'
                    '• Caching waveforms to avoid regeneration\n'
                    '• Testing UI components with known data\n'
                    '• Offline applications with pre-computed waveforms\n'
                    '• Quick prototyping without audio files',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadPreGeneratedData() {
    // Example 1: From JSON object
    final jsonData = {
      'amplitudes': [0.1, 0.5, 0.8, 0.3, 0.7, 0.2, 0.9, 0.4, 0.6, 0.3, 0.8, 0.1, 0.9, 0.5, 0.2, 0.7],
      'duration': 5000000, // 5 seconds in microseconds
      'sampleRate': 44100,
      'metadata': {'resolution': 16, 'type': 'bars', 'normalized': true, 'generatedAt': DateTime.now().toIso8601String()},
    };
    _waveformFromJson = WaveformData.fromJson(jsonData);

    // Example 2: From amplitude array
    final amplitudes = [0.2, 0.6, 0.9, 0.4, 0.8, 0.1, 0.7, 0.3, 0.5, 0.9, 0.2, 0.8, 0.4, 0.6, 0.1, 0.7, 0.3, 0.8, 0.5, 0.9, 0.2, 0.6, 0.4, 0.7];
    _waveformFromAmplitudes = WaveformData.fromAmplitudes(amplitudes);

    // Example 3: From JSON string
    final jsonString = jsonEncode({
      'amplitudes': [0.3, 0.7, 0.1, 0.9, 0.5, 0.2, 0.8, 0.4, 0.6, 0.9, 0.1, 0.7, 0.3, 0.8, 0.5, 0.2],
      'duration': 8000000, // 8 seconds in microseconds
      'sampleRate': 44100,
      'metadata': {'resolution': 16, 'type': 'bars', 'normalized': true, 'generatedAt': DateTime.now().toIso8601String()},
    });
    _waveformFromString = WaveformData.fromJsonString(jsonString);

    setState(() {
      // Data loaded
    });
  }
}
