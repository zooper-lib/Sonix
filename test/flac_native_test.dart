// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('FLAC Native Binding Tests', () {
    test('should initialize native bindings', () {
      try {
        NativeAudioBindings.initialize();
        print('Native bindings initialized successfully');
      } catch (e) {
        print('Failed to initialize native bindings: $e');
        rethrow;
      }
    });

    test('should detect FLAC format from file header', () async {
      final testFile = File('test/assets/test_sample.flac');
      if (!testFile.existsSync()) {
        markTestSkipped('Test FLAC file not found');
        return;
      }

      NativeAudioBindings.initialize();

      final bytes = await testFile.readAsBytes();
      final first4Bytes = bytes.take(4).toList();
      print('First 4 bytes: ${first4Bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');

      // Check if it's FLAC signature: fLaC (0x66, 0x4C, 0x61, 0x43)
      expect(first4Bytes[0], equals(0x66)); // 'f'
      expect(first4Bytes[1], equals(0x4C)); // 'L'
      expect(first4Bytes[2], equals(0x61)); // 'a'
      expect(first4Bytes[3], equals(0x43)); // 'C'

      final format = NativeAudioBindings.detectFormat(Uint8List.fromList(bytes));
      print('Detected format: $format');
      expect(format, equals(AudioFormat.flac));
    });

    test('should try to decode small FLAC data', () async {
      final testFile = File('test/assets/test_sample.flac');
      if (!testFile.existsSync()) {
        markTestSkipped('Test FLAC file not found');
        return;
      }

      NativeAudioBindings.initialize();

      final bytes = await testFile.readAsBytes();
      print('FLAC file size: ${bytes.length} bytes');

      try {
        final audioData = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.flac);
        print('FLAC decoding successful!');
        print('  Sample count: ${audioData.samples.length}');
        print('  Sample rate: ${audioData.sampleRate} Hz');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds} ms');
      } catch (e) {
        print('FLAC decoding failed: $e');
        if (e is DecodingException) {
          print('Details: ${e.details}');
        }
        rethrow;
      }
    });
  });
}
