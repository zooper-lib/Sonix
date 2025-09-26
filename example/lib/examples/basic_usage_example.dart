import 'package:flutter/material.dart';
import 'package:sonix/sonix.dart';
import 'package:file_picker/file_picker.dart';

/// Basic usage example showing simple waveform generation and display
class BasicUsageExample extends StatefulWidget {
  const BasicUsageExample({super.key});

  @override
  State<BasicUsageExample> createState() => _BasicUsageExampleState();
}

class _BasicUsageExampleState extends State<BasicUsageExample> {
  WaveformData? _waveformData;
  bool _isLoading = false;
  String? _error;
  String _selectedFilePath = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic Usage Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Basic Waveform Generation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('This example shows the simplest way to generate and display a waveform.'),
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

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: (_isLoading || _selectedFilePath.isEmpty) ? null : _generateWaveform,
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Generating...'),
                      ],
                    )
                  : const Text('Generate Waveform'),
            ),

            const SizedBox(height: 24),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
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
                    SelectableText(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),

            if (_waveformData != null) ...[
              const Text('Generated Waveform:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),

              // Basic waveform display with auto display resolution
              WaveformWidget(
                waveformData: _waveformData!,
                style: const WaveformStyle(
                  playedColor: Colors.blue,
                  unplayedColor: Colors.grey,
                  height: 80,
                  barWidth: 3.0,
                  barSpacing: 1.0,
                  autoDisplayResolution: true, // Automatically calculate optimal bars
                ),
              ),

              const SizedBox(height: 24),

              const Text('Different Display Resolutions:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),

              // Wide bars example
              const Text('Wide bars (6px width, 2px spacing):', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              WaveformWidget(
                waveformData: _waveformData!,
                style: const WaveformStyle(
                  playedColor: Colors.green,
                  unplayedColor: Colors.grey,
                  height: 60,
                  barWidth: 6.0,
                  barSpacing: 2.0,
                  autoDisplayResolution: true,
                ),
              ),

              const SizedBox(height: 16),

              // Thin bars example
              const Text('Thin bars (1px width, 0.5px spacing):', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              WaveformWidget(
                waveformData: _waveformData!,
                style: const WaveformStyle(
                  playedColor: Colors.orange,
                  unplayedColor: Colors.grey,
                  height: 60,
                  barWidth: 1.0,
                  barSpacing: 0.5,
                  autoDisplayResolution: true,
                ),
              ),

              const SizedBox(height: 16),

              // Fixed resolution example
              const Text('Fixed resolution (100 bars):', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              WaveformWidget(
                waveformData: _waveformData!,
                style: const WaveformStyle(
                  playedColor: Colors.purple,
                  unplayedColor: Colors.grey,
                  height: 60,
                  barWidth: 2.0,
                  barSpacing: 1.0,
                  autoDisplayResolution: false,
                  fixedDisplayResolution: 100, // Always show exactly 100 bars
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
                    const Text('Waveform Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Data Points: ${_waveformData!.amplitudes.length}'),
                    Text('Duration: ${_waveformData!.duration.inSeconds}s'),
                    Text('Sample Rate: ${_waveformData!.sampleRate} Hz'),
                    Text('Type: ${_waveformData!.metadata.type.name}'),
                    Text('Normalized: ${_waveformData!.metadata.normalized}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Display Resolution Features:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const Text('✓ Auto-calculated display resolution', style: TextStyle(color: Colors.green)),
                    const Text('✓ Exact bar width & spacing control', style: TextStyle(color: Colors.green)),
                    const Text('✓ Smart data sampling', style: TextStyle(color: Colors.green)),
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
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg', 'opus', 'mp4'],
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

  Future<void> _generateWaveform() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Create a Sonix instance for processing
      final sonix = Sonix();

      // Basic waveform generation with default settings
      final waveformData = await sonix.generateWaveform(
        _selectedFilePath,
        resolution: 1000, // Number of data points
        normalize: true, // Normalize amplitude values
      );

      setState(() {
        _waveformData = waveformData;
        _isLoading = false;
      });

      // Clean up the instance
      await sonix.dispose();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}
