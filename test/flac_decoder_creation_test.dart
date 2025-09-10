// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';

void main() {
  test('FLAC decoder creation test', () {
    try {
      print('Testing FLAC decoder creation...');

      // Test if we can create a FLAC decoder
      final decoder = AudioDecoderFactory.createDecoder('test.flac');
      print('FLAC decoder created successfully: ${decoder.runtimeType}');

      // Test format detection
      final format = AudioDecoderFactory.detectFormat('test.flac');
      print('Detected format: $format');

      decoder.dispose();
      print('Test completed successfully');
    } catch (e, stackTrace) {
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  });
}
