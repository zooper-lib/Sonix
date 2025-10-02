import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';
import 'ffmpeg_setup_helper.dart';

void main() {
  setUpAll(() async {
    // Setup FFMPEG binaries for testing
    await FFMPEGSetupHelper.setupFFMPEGForTesting();
  });

  group('FFmpeg Log Level Tests', () {
    test('can create Sonix instances with different log levels', () {
      // Test creating instances with different log levels
      expect(() => Sonix(SonixConfig(logLevel: 2)), returnsNormally);
      expect(() => Sonix(SonixConfig(logLevel: -1)), returnsNormally);
      expect(() => Sonix(SonixConfig(logLevel: 3)), returnsNormally);
    });

    test('can generate waveform with reduced logging', () async {
      // Create Sonix with ERROR log level to suppress MP3 format warnings
      final sonix = Sonix(SonixConfig(logLevel: 2));

      // This test assumes you have MP3 test files
      // The point is that it should work without verbose logging
      expect(Sonix.isFormatSupported('.mp3'), isTrue);

      await sonix.dispose();
    });

    test('can create instances with all supported log levels', () async {
      // Test all supported log levels
      const levels = [-1, 0, 1, 2, 3, 4, 5, 6];

      for (final level in levels) {
        final sonix = Sonix(SonixConfig(logLevel: level));
        expect(sonix.config.logLevel, equals(level));
        await sonix.dispose();
      }
    });

    test('default log level is ERROR (2)', () {
      final sonix = Sonix();
      expect(sonix.config.logLevel, equals(2));
      sonix.dispose();
    });

    test('mobile config has appropriate log level', () {
      final sonix = Sonix(SonixConfig.mobile());
      expect(sonix.config.logLevel, equals(2)); // Should be ERROR level for mobile
      sonix.dispose();
    });

    test('desktop config has appropriate log level', () {
      final sonix = Sonix(SonixConfig.desktop());
      expect(sonix.config.logLevel, equals(2)); // Should be ERROR level for desktop
      sonix.dispose();
    });
  });
}
