import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sonix/sonix.dart';
import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:sonix/src/native/sonix_bindings.dart';

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
  AudioData? _decodedAudio;
  bool _isDecoding = false;
  String? _errorMessage;
  String? _detectedFormat;

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
          _decodedAudio = null;
          _errorMessage = null;
          _detectedFormat = null;
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
      _errorMessage = null;
    });

    try {
      // Detect the format first
      final format = AudioDecoderFactory.detectFormat(_selectedFilePath!);

      // Use the factory to create the appropriate decoder for the file
      final decoder = AudioDecoderFactory.createDecoder(_selectedFilePath!);
      final audioData = await decoder.decode(_selectedFilePath!);

      setState(() {
        _decodedAudio = audioData;
        _detectedFormat = format.name;
        _isDecoding = false;
      });

      decoder.dispose();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error decoding audio: $e';
        _isDecoding = false;
      });
    }
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
            if (_decodedAudio != null)
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
                        _buildInfoRow('Sample Rate', '${_decodedAudio!.sampleRate} Hz'),
                        _buildInfoRow('Channels', '${_decodedAudio!.channels}'),
                        _buildInfoRow('Duration', '${_decodedAudio!.duration.inMilliseconds} ms'),
                        if (kDebugMode) ...[
                          // Recompute expected duration from raw sample buffer
                          Builder(builder: (context) {
                            final samples = _decodedAudio!.samples.length;
                            final ch = _decodedAudio!.channels;
                            final sr = _decodedAudio!.sampleRate;
                            final recomputedMs = ((samples / ch) / sr * 1000).round();
                            if (recomputedMs != _decodedAudio!.duration.inMilliseconds) {
                              // Print detailed diagnostics once per build frame
                              debugPrint('[DURATION_MISMATCH] native=${_decodedAudio!.duration.inMilliseconds}ms recomputed=$recomputedMs samples=$samples ch=$ch sr=$sr perCh=${samples ~/ ch}');
                            }
                            return _buildInfoRow('Debug Recomputed Duration', '$recomputedMs ms');
                          }),
                        ],
                        _buildInfoRow('Total Samples', '${_decodedAudio!.samples.length}'),
                        _buildInfoRow('Samples per Channel', '${_decodedAudio!.samples.length ~/ _decodedAudio!.channels}'),
                        if (kDebugMode) _buildMp3Stats(),
                        const SizedBox(height: 16),
                        const Text('Sample Preview (first 10 values):', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: SelectableText(
                            _decodedAudio!.samples.take(10).map((s) => s.toStringAsFixed(4)).join(', '),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
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

  Widget _buildMp3Stats() {
    try {
      final ptr = SonixNativeBindings.getLastMp3DebugStats();
      if (ptr == ffi.nullptr) return const SizedBox.shrink();
  final stats = ptr.ref;
      if (stats.frame_count == 0) return const SizedBox.shrink();
      final estDurationMs = ((stats.total_samples / stats.channels) / stats.sample_rate * 1000).round();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        const Text('MP3 Debug Stats', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildInfoRow('Frames', '${stats.frame_count}'),
        _buildInfoRow('Total Samples(native)', '${stats.total_samples}'),
        _buildInfoRow('Channels(native)', '${stats.channels}'),
        _buildInfoRow('Sample Rate(native)', '${stats.sample_rate}'),
        _buildInfoRow('Processed Bytes', '${stats.processed_bytes}/${stats.file_size}'),
        _buildInfoRow('Est Duration (recalc)', '$estDurationMs ms'),
      ]);
    } catch (_) {
      return const SizedBox.shrink();
    }
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
