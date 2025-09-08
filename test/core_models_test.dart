import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('Core Data Models', () {
    test('AudioData creation and disposal', () {
      final audioData = AudioData(samples: [0.1, 0.2, -0.1, -0.2], sampleRate: 44100, channels: 2, duration: const Duration(milliseconds: 100));

      expect(audioData.samples.length, 4);
      expect(audioData.sampleRate, 44100);
      expect(audioData.channels, 2);
      expect(audioData.duration.inMilliseconds, 100);

      // Test disposal
      audioData.dispose();
      expect(audioData.samples.isEmpty, true);
    });

    test('AudioChunk creation', () {
      final chunk = AudioChunk(samples: [0.1, 0.2], startSample: 1000, isLast: false);

      expect(chunk.samples.length, 2);
      expect(chunk.startSample, 1000);
      expect(chunk.isLast, false);
    });

    test('AudioMetadata creation', () {
      final metadata = AudioMetadata(format: 'mp3', bitrate: 320, fileSize: 1024000, title: 'Test Song', artist: 'Test Artist', album: 'Test Album');

      expect(metadata.format, 'mp3');
      expect(metadata.bitrate, 320);
      expect(metadata.fileSize, 1024000);
      expect(metadata.title, 'Test Song');
      expect(metadata.artist, 'Test Artist');
      expect(metadata.album, 'Test Album');
    });
  });

  group('Waveform Data Models', () {
    test('WaveformMetadata serialization', () {
      final now = DateTime.now();
      final metadata = WaveformMetadata(resolution: 1000, type: WaveformType.bars, normalized: true, generatedAt: now);

      final json = metadata.toJson();
      expect(json['resolution'], 1000);
      expect(json['type'], 'bars');
      expect(json['normalized'], true);
      expect(json['generatedAt'], now.toIso8601String());

      final restored = WaveformMetadata.fromJson(json);
      expect(restored.resolution, metadata.resolution);
      expect(restored.type, metadata.type);
      expect(restored.normalized, metadata.normalized);
      expect(restored.generatedAt, metadata.generatedAt);
    });

    test('WaveformData serialization', () {
      final metadata = WaveformMetadata(resolution: 5, type: WaveformType.line, normalized: false, generatedAt: DateTime.now());

      final waveformData = WaveformData(amplitudes: [0.1, 0.5, 0.8, 0.3, 0.0], duration: const Duration(seconds: 5), sampleRate: 44100, metadata: metadata);

      final json = waveformData.toJson();
      expect(json['amplitudes'], [0.1, 0.5, 0.8, 0.3, 0.0]);
      expect(json['duration'], 5000000); // microseconds
      expect(json['sampleRate'], 44100);

      final restored = WaveformData.fromJson(json);
      expect(restored.amplitudes, waveformData.amplitudes);
      expect(restored.duration, waveformData.duration);
      expect(restored.sampleRate, waveformData.sampleRate);
      expect(restored.metadata.resolution, metadata.resolution);

      // Test JSON string conversion
      final jsonString = waveformData.toJsonString();
      final restoredFromString = WaveformData.fromJsonString(jsonString);
      expect(restoredFromString.amplitudes, waveformData.amplitudes);

      // Test disposal
      waveformData.dispose();
      expect(waveformData.amplitudes.isEmpty, true);
    });

    test('WaveformChunk creation', () {
      final chunk = WaveformChunk(amplitudes: [0.1, 0.2, 0.3], startTime: const Duration(seconds: 1), isLast: true);

      expect(chunk.amplitudes.length, 3);
      expect(chunk.startTime.inSeconds, 1);
      expect(chunk.isLast, true);
    });
  });

  group('Audio Decoder Factory', () {
    test('Format detection by extension', () {
      expect(AudioDecoderFactory.detectFormat('test.mp3'), AudioFormat.mp3);
      expect(AudioDecoderFactory.detectFormat('test.wav'), AudioFormat.wav);
      expect(AudioDecoderFactory.detectFormat('test.flac'), AudioFormat.flac);
      expect(AudioDecoderFactory.detectFormat('test.ogg'), AudioFormat.ogg);
      expect(AudioDecoderFactory.detectFormat('test.opus'), AudioFormat.opus);
      expect(AudioDecoderFactory.detectFormat('test.xyz'), AudioFormat.unknown);
    });

    test('Format support checking', () {
      expect(AudioDecoderFactory.isFormatSupported('test.mp3'), true);
      expect(AudioDecoderFactory.isFormatSupported('test.wav'), true);
      expect(AudioDecoderFactory.isFormatSupported('test.xyz'), false);
    });

    test('Supported formats listing', () {
      final extensions = AudioDecoderFactory.getSupportedExtensions();
      expect(extensions.contains('mp3'), true);
      expect(extensions.contains('wav'), true);
      expect(extensions.contains('flac'), true);
      expect(extensions.contains('ogg'), true);
      expect(extensions.contains('opus'), true);

      final formats = AudioDecoderFactory.getSupportedFormats();
      expect(formats.length, 5);
      expect(formats.contains(AudioFormat.mp3), true);

      final formatNames = AudioDecoderFactory.getSupportedFormatNames();
      expect(formatNames.contains('MP3'), true);
      expect(formatNames.contains('WAV'), true);
    });

    test('Decoder creation', () {
      expect(() => AudioDecoderFactory.createDecoder('test.mp3'), returnsNormally);
      expect(() => AudioDecoderFactory.createDecoder('test.wav'), returnsNormally);
      expect(() => AudioDecoderFactory.createDecoder('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
    });
  });

  group('Audio Format Extensions', () {
    test('Format extensions', () {
      expect(AudioFormat.mp3.extensions, ['mp3']);
      expect(AudioFormat.wav.extensions, ['wav']);
      expect(AudioFormat.flac.extensions, ['flac']);
      expect(AudioFormat.ogg.extensions, ['ogg']);
      expect(AudioFormat.opus.extensions, ['opus']);
      expect(AudioFormat.unknown.extensions, []);
    });

    test('Format names', () {
      expect(AudioFormat.mp3.name, 'MP3');
      expect(AudioFormat.wav.name, 'WAV');
      expect(AudioFormat.flac.name, 'FLAC');
      expect(AudioFormat.ogg.name, 'OGG Vorbis');
      expect(AudioFormat.opus.name, 'Opus');
      expect(AudioFormat.unknown.name, 'Unknown');
    });
  });

  group('Exceptions', () {
    test('UnsupportedFormatException', () {
      final exception = UnsupportedFormatException('xyz', 'Test details');
      expect(exception.format, 'xyz');
      expect(exception.message, 'Unsupported audio format: xyz');
      expect(exception.details, 'Test details');
      expect(exception.toString().contains('xyz'), true);
    });

    test('DecodingException', () {
      final exception = DecodingException('Decode failed', 'Test details');
      expect(exception.message, 'Decode failed');
      expect(exception.details, 'Test details');
      expect(exception.toString().contains('Decode failed'), true);
    });

    test('MemoryException', () {
      final exception = MemoryException('Out of memory');
      expect(exception.message, 'Out of memory');
      expect(exception.toString().contains('Out of memory'), true);
    });

    test('FileAccessException', () {
      final exception = FileAccessException('/path/to/file', 'Access denied');
      expect(exception.filePath, '/path/to/file');
      expect(exception.message, 'Access denied');
      expect(exception.toString().contains('/path/to/file'), true);
    });

    test('FFIException', () {
      final exception = FFIException('FFI call failed');
      expect(exception.message, 'FFI call failed');
      expect(exception.toString().contains('FFI call failed'), true);
    });
  });
}
