import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/wav_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'dart:io';

void main() {
  test('WAV decoder should successfully decode small test file', () async {
    final decoder = WAVDecoder();
    final filePath = 'test/assets/small.wav';
    final file = File(filePath);

    if (!file.existsSync()) {
      fail('Test WAV file does not exist: $filePath');
    }

    print('Small test file size: ${file.lengthSync()} bytes');

    try {
      // This small file should decode successfully
      final audioData = await decoder.decode(filePath);
      print('Success! Sample rate: ${audioData.sampleRate}, Channels: ${audioData.channels}, Samples: ${audioData.samples.length}');

      expect(audioData.sampleRate, greaterThan(0));
      expect(audioData.channels, greaterThan(0));
      expect(audioData.samples, isNotEmpty);
      expect(audioData.duration.inMilliseconds, greaterThan(0));
    } catch (e) {
      print('Unexpected error with small file: $e');
      rethrow;
    } finally {
      decoder.dispose();
    }
  });

  test('WAV decoder should fail gracefully with corrupted file', () async {
    final decoder = WAVDecoder();
    final filePath = 'test/assets/corrupted_data.wav';
    final file = File(filePath);

    if (!file.existsSync()) {
      return; // Skip if corrupted file doesn't exist
    }

    print('Corrupted file size: ${file.lengthSync()} bytes');

    try {
      await decoder.decode(filePath);
      fail('Should have thrown an exception for corrupted file');
    } catch (e) {
      print('Expected error for corrupted file: $e');
      expect(e, isA<DecodingException>());
    } finally {
      decoder.dispose();
    }
  });

  test('WAV decoder should suggest streaming for large file', () async {
    final decoder = WAVDecoder();
    final filePath = 'test/assets/Double-F the King - Your Blessing.wav';
    final file = File(filePath);

    if (!file.existsSync()) {
      return; // Skip if large file doesn't exist
    }

    print('Large file size: ${file.lengthSync()} bytes');

    try {
      await decoder.decode(filePath);
      fail('Should have thrown an exception for large file');
    } catch (e) {
      print('Expected error for large file: $e');
      expect(e.toString(), contains('too large'));
      expect(e.toString(), contains('streaming'));
    } finally {
      decoder.dispose();
    }
  });
}
