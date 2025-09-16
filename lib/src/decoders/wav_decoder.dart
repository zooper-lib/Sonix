import 'dart:io';
import 'dart:typed_data';

import '../models/audio_data.dart';
import '../models/file_chunk.dart';
import '../models/chunked_processing_models.dart';
import '../exceptions/sonix_exceptions.dart';
import '../native/native_audio_bindings.dart';
import 'audio_decoder.dart';
import 'chunked_audio_decoder.dart';

/// WAV audio decoder using dr_wav library with chunked processing support
class WAVDecoder implements ChunkedAudioDecoder {
  bool _disposed = false;
  bool _initialized = false;
  String? _currentFilePath;
  Duration _currentPosition = Duration.zero;
  int _sampleRate = 0;
  int _channels = 0;
  Duration? _totalDuration;

  // WAV-specific state for chunked processing
  int _dataChunkOffset = 0; // Offset to the start of audio data
  int _dataChunkSize = 0; // Size of the audio data chunk
  int _bytesPerSample = 0; // Bytes per sample (typically 2 for 16-bit)
  int _blockAlign = 0; // Bytes per sample frame (channels * bytesPerSample)
  int _totalSamples = 0; // Total number of sample frames

  @override
  Future<AudioData> decode(String filePath) async {
    _checkDisposed();

    try {
      // Read the entire file
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }

      final fileData = await file.readAsBytes();
      if (fileData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty WAV file: $filePath');
      }

      // Use native bindings to decode
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.wav);
      return audioData;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode WAV file', 'Error decoding $filePath: $e');
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      // Clean up any native resources if needed
      _disposed = true;
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('WAVDecoder has been disposed');
    }
  }

  // ChunkedAudioDecoder implementation

  @override
  Future<void> initializeChunkedDecoding(String filePath, {int chunkSize = 10 * 1024 * 1024, Duration? seekPosition}) async {
    _checkDisposed();

    try {
      _currentFilePath = filePath;

      // Verify file exists
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }

      // Read file to get metadata
      final fileData = await file.readAsBytes();
      if (fileData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty WAV file: $filePath');
      }

      // Parse WAV header to get format information
      await _parseWAVHeader(fileData);

      // Seek to initial position if specified
      if (seekPosition != null) {
        await seekToTime(seekPosition);
      }

      _initialized = true;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to initialize WAV chunked decoding', 'Error initializing $filePath: $e');
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // For WAV files, we can process raw PCM data directly
      final audioData = _processWAVChunk(fileChunk);

      if (audioData.isEmpty) {
        return [];
      }

      // Calculate start sample based on current position
      int startSample = (_currentPosition.inMilliseconds * _sampleRate / 1000).round();

      final audioChunk = AudioChunk(
        samples: audioData,
        startSample: startSample,
        isLast: false, // Will be set by the caller if this is the last chunk
      );

      // Update current position based on processed samples
      final sampleFrames = audioData.length ~/ _channels;
      final frameDuration = Duration(milliseconds: (sampleFrames * 1000 / _sampleRate).round());
      _currentPosition += frameDuration;

      return [audioChunk];
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to process WAV chunk', 'Error processing chunk: $e');
    }
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // WAV files support sample-accurate seeking
      final targetSampleFrame = (position.inMilliseconds * _sampleRate / 1000).round();

      // Clamp to valid range
      final clampedSampleFrame = targetSampleFrame.clamp(0, _totalSamples);

      // Calculate byte position in the data chunk
      final byteOffset = clampedSampleFrame * _blockAlign;
      final absoluteBytePosition = _dataChunkOffset + byteOffset;

      // Calculate actual position
      final actualPosition = Duration(milliseconds: (clampedSampleFrame * 1000 / _sampleRate).round());

      _currentPosition = actualPosition;

      // WAV seeking is always exact for uncompressed PCM
      return SeekResult(actualPosition: actualPosition, bytePosition: absoluteBytePosition, isExact: true, warning: null);
    } catch (e) {
      throw DecodingException('Failed to seek in WAV file', 'Error seeking to $position: $e');
    }
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    // WAV files are uncompressed, so we can use larger chunks efficiently
    final sampleRate = _sampleRate > 0 ? _sampleRate : 44100; // Default sample rate
    final channels = _channels > 0 ? _channels : 2; // Default to stereo
    final bytesPerSample = _bytesPerSample > 0 ? _bytesPerSample : 2; // Default to 16-bit
    final bytesPerSecond = sampleRate * channels * bytesPerSample;

    if (fileSize < 5 * 1024 * 1024) {
      // < 5MB
      return ChunkSizeRecommendation(
        recommendedSize: (fileSize * 0.5).clamp(bytesPerSecond, 2 * 1024 * 1024).round(),
        minSize: bytesPerSecond, // At least 1 second of audio
        maxSize: fileSize,
        reason: 'Small WAV file - using 50% of file size for efficient processing',
        metadata: {'format': 'WAV', 'bytesPerSecond': bytesPerSecond, 'blockAlign': _blockAlign, 'sampleAccurate': true},
      );
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      return ChunkSizeRecommendation(
        recommendedSize: 10 * 1024 * 1024, // 10MB
        minSize: 2 * 1024 * 1024, // 2MB
        maxSize: 25 * 1024 * 1024, // 25MB
        reason: 'Medium WAV file - using 10MB chunks for optimal memory usage',
        metadata: {'format': 'WAV', 'bytesPerSecond': bytesPerSecond, 'blockAlign': _blockAlign, 'sampleAccurate': true},
      );
    } else {
      // >= 100MB
      return ChunkSizeRecommendation(
        recommendedSize: 20 * 1024 * 1024, // 20MB
        minSize: 5 * 1024 * 1024, // 5MB
        maxSize: 50 * 1024 * 1024, // 50MB
        reason: 'Large WAV file - using 20MB chunks for memory efficiency',
        metadata: {'format': 'WAV', 'bytesPerSecond': bytesPerSecond, 'blockAlign': _blockAlign, 'sampleAccurate': true},
      );
    }
  }

  @override
  bool get supportsEfficientSeeking => true; // WAV supports sample-accurate seeking

  @override
  Duration get currentPosition {
    _checkDisposed();
    return _currentPosition;
  }

  @override
  Future<void> resetDecoderState() async {
    _checkDisposed();

    _currentPosition = Duration.zero;
    // No additional state to reset for WAV decoder
  }

  @override
  Map<String, dynamic> getFormatMetadata() {
    _checkDisposed();
    return {
      'format': 'WAV',
      'sampleRate': _sampleRate,
      'channels': _channels,
      'duration': _totalDuration?.inMilliseconds,
      'bytesPerSample': _bytesPerSample,
      'blockAlign': _blockAlign,
      'totalSamples': _totalSamples,
      'dataChunkSize': _dataChunkSize,
      'supportsSeekTable': false, // WAV doesn't need seek tables
      'seekingAccuracy': 'exact',
      'sampleAccurate': true,
    };
  }

  @override
  Future<Duration?> estimateDuration() async {
    if (_totalDuration != null) {
      return _totalDuration;
    }

    // If not initialized, try to get duration from file header
    if (_currentFilePath != null) {
      try {
        final file = File(_currentFilePath!);
        final fileData = await file.readAsBytes();
        await _parseWAVHeader(fileData);
        return _totalDuration;
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> cleanupChunkedProcessing() async {
    _initialized = false;
    _currentFilePath = null;
    _currentPosition = Duration.zero;
    _sampleRate = 0;
    _channels = 0;
    _totalDuration = null;
    _dataChunkOffset = 0;
    _dataChunkSize = 0;
    _bytesPerSample = 0;
    _blockAlign = 0;
    _totalSamples = 0;
  }

  // Helper methods for WAV-specific processing

  Future<void> _parseWAVHeader(Uint8List fileData) async {
    if (fileData.length < 44) {
      throw DecodingException('Invalid WAV file', 'File too small to contain WAV header');
    }

    // Check RIFF signature
    if (fileData[0] != 0x52 || fileData[1] != 0x49 || fileData[2] != 0x46 || fileData[3] != 0x46) {
      throw DecodingException('Invalid WAV file', 'RIFF signature not found');
    }

    // Check WAVE signature
    if (fileData[8] != 0x57 || fileData[9] != 0x41 || fileData[10] != 0x56 || fileData[11] != 0x45) {
      throw DecodingException('Invalid WAV file', 'WAVE signature not found');
    }

    // Find fmt chunk
    int offset = 12;
    while (offset < fileData.length - 8) {
      final chunkId = String.fromCharCodes(fileData.sublist(offset, offset + 4));
      final chunkSize = _readLittleEndian32(fileData, offset + 4);

      if (chunkId == 'fmt ') {
        // Parse format chunk
        if (chunkSize < 16) {
          throw DecodingException('Invalid WAV file', 'Format chunk too small');
        }

        final audioFormat = _readLittleEndian16(fileData, offset + 8);
        if (audioFormat != 1) {
          throw DecodingException('Unsupported WAV format', 'Only PCM format is supported');
        }

        _channels = _readLittleEndian16(fileData, offset + 10);
        _sampleRate = _readLittleEndian32(fileData, offset + 12);
        // byteRate = _readLittleEndian32(fileData, offset + 16); // Unused
        _blockAlign = _readLittleEndian16(fileData, offset + 20);
        final bitsPerSample = _readLittleEndian16(fileData, offset + 22);

        _bytesPerSample = bitsPerSample ~/ 8;

        // Validate format
        if (_channels == 0 || _sampleRate == 0 || _blockAlign == 0) {
          throw DecodingException('Invalid WAV format', 'Invalid format parameters');
        }

        if (_blockAlign != _channels * _bytesPerSample) {
          throw DecodingException('Invalid WAV format', 'Block align mismatch');
        }

        break;
      }

      offset += 8 + chunkSize;
      if (chunkSize % 2 == 1) offset++; // Pad to even boundary
    }

    // Find data chunk
    offset = 12;
    while (offset < fileData.length - 8) {
      final chunkId = String.fromCharCodes(fileData.sublist(offset, offset + 4));
      final chunkSize = _readLittleEndian32(fileData, offset + 4);

      if (chunkId == 'data') {
        _dataChunkOffset = offset + 8;
        _dataChunkSize = chunkSize;
        _totalSamples = _dataChunkSize ~/ _blockAlign;
        _totalDuration = Duration(milliseconds: (_totalSamples * 1000 / _sampleRate).round());
        break;
      }

      offset += 8 + chunkSize;
      if (chunkSize % 2 == 1) offset++; // Pad to even boundary
    }

    if (_dataChunkOffset == 0) {
      throw DecodingException('Invalid WAV file', 'Data chunk not found');
    }
  }

  List<double> _processWAVChunk(FileChunk fileChunk) {
    final samples = <double>[];

    // Determine which part of the chunk contains audio data
    int dataStart = 0;
    int dataEnd = fileChunk.data.length;

    // If this chunk starts before the data chunk, skip the header
    if (fileChunk.startPosition < _dataChunkOffset) {
      dataStart = (_dataChunkOffset - fileChunk.startPosition).clamp(0, fileChunk.data.length);
    }

    // If this chunk extends beyond the data chunk, truncate
    final dataChunkEnd = _dataChunkOffset + _dataChunkSize;
    if (fileChunk.endPosition > dataChunkEnd) {
      final excessBytes = fileChunk.endPosition - dataChunkEnd;
      dataEnd = (fileChunk.data.length - excessBytes).clamp(0, fileChunk.data.length);
    }

    // Process the audio data portion
    if (dataStart < dataEnd) {
      final audioData = fileChunk.data.sublist(dataStart, dataEnd);

      // Convert PCM data to floating point samples
      for (int i = 0; i < audioData.length - _bytesPerSample + 1; i += _bytesPerSample) {
        double sample;

        if (_bytesPerSample == 1) {
          // 8-bit unsigned PCM
          sample = (audioData[i] - 128) / 128.0;
        } else if (_bytesPerSample == 2) {
          // 16-bit signed PCM (little-endian)
          final value = _readLittleEndian16(audioData, i);
          final signedValue = value > 32767 ? value - 65536 : value;
          sample = signedValue / 32768.0;
        } else if (_bytesPerSample == 3) {
          // 24-bit signed PCM (little-endian)
          final value = audioData[i] | (audioData[i + 1] << 8) | (audioData[i + 2] << 16);
          final signedValue = value > 8388607 ? value - 16777216 : value;
          sample = signedValue / 8388608.0;
        } else {
          // Unsupported bit depth
          sample = 0.0;
        }

        samples.add(sample.clamp(-1.0, 1.0));
      }
    }

    return samples;
  }

  int _readLittleEndian16(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8);
  }

  int _readLittleEndian32(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);
  }
}
