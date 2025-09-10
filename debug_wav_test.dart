import 'package:sonix/src/decoders/wav_decoder.dart';

void main() async {
  print('Testing WAV decoder with debug output...');

  final decoder = WAVDecoder();

  // Test with our small file first
  try {
    print('Testing small WAV file...');
    final result = await decoder.decode('test/assets/small.wav');
    print('Small file success: ${result.samples.length} samples, ${result.sampleRate}Hz, ${result.channels} channels');
  } catch (e) {
    print('Small file failed: $e');
  }

  // Test with large file
  try {
    print('\nTesting large WAV file...');
    final result = await decoder.decode('test/assets/Double-F the King - Your Blessing.wav');
    print('Large file success: ${result.samples.length} samples, ${result.sampleRate}Hz, ${result.channels} channels');
  } catch (e) {
    print('Large file failed: $e');
  }

  decoder.dispose();
}
