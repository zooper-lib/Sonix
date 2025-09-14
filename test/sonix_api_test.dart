import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('Sonix API Tests', () {
    test('getSupportedFormats returns expected formats', () {
      final formats = Sonix.getSupportedFormats();

      expect(formats, isNotEmpty);
      expect(formats, contains('MP3'));
      expect(formats, contains('WAV'));
      expect(formats, contains('FLAC'));
      expect(formats, contains('OGG Vorbis'));
      expect(formats, contains('Opus'));
    });

    test('getSupportedExtensions returns expected extensions', () {
      final extensions = Sonix.getSupportedExtensions();

      expect(extensions, isNotEmpty);
      expect(extensions, contains('mp3'));
      expect(extensions, contains('wav'));
      expect(extensions, contains('flac'));
      expect(extensions, contains('ogg'));
      expect(extensions, contains('opus'));
    });

    test('isFormatSupported correctly identifies supported formats', () {
      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
      expect(Sonix.isFormatSupported('test.wav'), isTrue);
      expect(Sonix.isFormatSupported('test.flac'), isTrue);
      expect(Sonix.isFormatSupported('test.ogg'), isTrue);
      expect(Sonix.isFormatSupported('test.opus'), isTrue);

      expect(Sonix.isFormatSupported('test.xyz'), isFalse);
      expect(Sonix.isFormatSupported('test.txt'), isFalse);
    });

    test('isExtensionSupported correctly identifies supported extensions', () {
      expect(Sonix.isExtensionSupported('mp3'), isTrue);
      expect(Sonix.isExtensionSupported('.mp3'), isTrue);
      expect(Sonix.isExtensionSupported('MP3'), isTrue);
      expect(Sonix.isExtensionSupported('.WAV'), isTrue);

      expect(Sonix.isExtensionSupported('xyz'), isFalse);
      expect(Sonix.isExtensionSupported('.txt'), isFalse);
    });

    test('getOptimalConfig returns valid configurations', () {
      final musicConfig = Sonix.getOptimalConfig(useCase: WaveformUseCase.musicVisualization);
      expect(musicConfig.resolution, equals(1000));
      expect(musicConfig.normalize, isTrue);

      final speechConfig = Sonix.getOptimalConfig(useCase: WaveformUseCase.speechAnalysis, customResolution: 1500);
      expect(speechConfig.resolution, equals(1500));
      expect(speechConfig.normalize, isTrue);
    });

    test('generateWaveform throws UnsupportedFormatException for invalid format', () async {
      expect(() async => await Sonix.generateWaveform('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
    });

    test('generateWaveformStream throws UnsupportedFormatException for invalid format', () async {
      expect(() async {
        await for (final _ in Sonix.generateWaveformStream('test.xyz')) {
          // This should not execute
        }
      }, throwsA(isA<UnsupportedFormatException>()));
    });

    test('generateWaveform throws UnsupportedFormatException for invalid format', () async {
      expect(() async => await Sonix.generateWaveform('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
    });
  });
}
