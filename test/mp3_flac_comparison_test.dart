// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';

void main() {
  group('MP3 vs FLAC Comparison Tests', () {
    test('should decode MP3 file successfully for reference', () async {
      final testFile = File('test/assets/test_short.mp3');
      if (!testFile.existsSync()) {
        markTestSkipped('Test MP3 file not found');
        return;
      }

      NativeAudioBindings.initialize();

      final bytes = await testFile.readAsBytes();
      print('MP3 file size: ${bytes.length} bytes');

      final format = NativeAudioBindings.detectFormat(Uint8List.fromList(bytes));
      print('Detected format: $format');
      expect(format, equals(AudioFormat.mp3));

      final audioData = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3);
      print('MP3 decoding successful!');
      print('  Sample count: ${audioData.samples.length}');
      print('  Sample rate: ${audioData.sampleRate} Hz');
      print('  Channels: ${audioData.channels}');
      print('  Duration: ${audioData.duration.inMilliseconds} ms');
    });

    test('should compare FLAC file header with known good file', () async {
      final flacFile = File('test/assets/test_sample.flac');
      final truncatedFile = File('test/assets/truncated.flac');

      if (!flacFile.existsSync()) {
        markTestSkipped('Test FLAC file not found');
        return;
      }

      NativeAudioBindings.initialize();

      final flacBytes = await flacFile.readAsBytes();
      final flacFirst16 = flacBytes.take(16).toList();
      print('test_sample.flac first 16 bytes: ${flacFirst16.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');

      if (truncatedFile.existsSync()) {
        final truncatedBytes = await truncatedFile.readAsBytes();
        final truncatedFirst16 = truncatedBytes.take(16).toList();
        print('truncated.flac first 16 bytes: ${truncatedFirst16.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      }

      // Check FLAC signature
      expect(flacFirst16[0], equals(0x66)); // 'f'
      expect(flacFirst16[1], equals(0x4C)); // 'L'
      expect(flacFirst16[2], equals(0x61)); // 'a'
      expect(flacFirst16[3], equals(0x43)); // 'C'
    });
  });
}
