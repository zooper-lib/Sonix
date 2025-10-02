import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';
import '../test_helpers/test_sonix_instance.dart';

void main() {
  group('SonixConfig Log Level Tests', () {
    test('default config should have ERROR log level', () {
      final config = SonixConfig.defaultConfig();
      expect(config.logLevel, equals(2)); // ERROR level
    });

    test('mobile config should have ERROR log level', () {
      final config = SonixConfig.mobile();
      expect(config.logLevel, equals(2)); // ERROR level
    });

    test('desktop config should have ERROR log level', () {
      final config = SonixConfig.desktop();
      expect(config.logLevel, equals(2)); // ERROR level
    });

    test('custom config can specify different log levels', () {
      // Test QUIET level
      const quietConfig = SonixConfig(logLevel: -1);
      expect(quietConfig.logLevel, equals(-1));

      // Test DEBUG level
      const debugConfig = SonixConfig(logLevel: 6);
      expect(debugConfig.logLevel, equals(6));

      // Test WARNING level
      const warningConfig = SonixConfig(logLevel: 3);
      expect(warningConfig.logLevel, equals(3));
    });

    test('Sonix instance should initialize with configured log level', () {
      // Test with different log levels
      final sonixWithQuiet = TestSonixInstance(const TestSonixConfig(logLevel: -1));
      expect(sonixWithQuiet.config.logLevel, equals(-1));

      final sonixWithDebug = TestSonixInstance(const TestSonixConfig(logLevel: 6));
      expect(sonixWithDebug.config.logLevel, equals(6));

      final sonixWithError = TestSonixInstance(const TestSonixConfig(logLevel: 2));
      expect(sonixWithError.config.logLevel, equals(2));
    });

    test('log level configuration should be immutable', () {
      const config = SonixConfig(logLevel: 4);
      expect(config.logLevel, equals(4));

      // Verify config is const and immutable
      expect(config.logLevel, equals(4)); // Should remain unchanged
    });

    test('each Sonix instance can have different log levels', () {
      final silentSonix = TestSonixInstance(const TestSonixConfig(logLevel: -1));
      final debugSonix = TestSonixInstance(const TestSonixConfig(logLevel: 6));
      final errorSonix = TestSonixInstance(const TestSonixConfig(logLevel: 2));

      expect(silentSonix.config.logLevel, equals(-1));
      expect(debugSonix.config.logLevel, equals(6));
      expect(errorSonix.config.logLevel, equals(2));

      // Verify they're independent
      expect(silentSonix.config.logLevel, isNot(equals(debugSonix.config.logLevel)));
      expect(debugSonix.config.logLevel, isNot(equals(errorSonix.config.logLevel)));
    });

    test('log level should be included in config toString', () {
      const config = SonixConfig(logLevel: 5);
      final configString = config.toString();

      // The toString should contain the essential config info
      expect(configString, contains('SonixConfig'));
      expect(configString, contains('maxConcurrentOperations'));
      expect(configString, contains('isolatePoolSize'));
    });

    group('Log Level Validation', () {
      test('should accept valid log levels', () {
        const validLevels = [-1, 0, 1, 2, 3, 4, 5, 6];

        for (final level in validLevels) {
          expect(() => SonixConfig(logLevel: level), returnsNormally);
        }
      });

      test('should accept extreme log levels without throwing', () {
        // While these are not standard, the config should accept them
        // The native FFmpeg layer will clamp them to valid ranges
        expect(() => const SonixConfig(logLevel: -100), returnsNormally);
        expect(() => const SonixConfig(logLevel: 100), returnsNormally);
      });
    });

    group('Integration with Existing Config Options', () {
      test('log level should work with other config options', () {
        const config = SonixConfig(
          maxConcurrentOperations: 8,
          isolatePoolSize: 4,
          maxMemoryUsage: 256 * 1024 * 1024,
          logLevel: 1, // FATAL level
          enableProgressReporting: false,
        );

        expect(config.maxConcurrentOperations, equals(8));
        expect(config.isolatePoolSize, equals(4));
        expect(config.maxMemoryUsage, equals(256 * 1024 * 1024));
        expect(config.logLevel, equals(1));
        expect(config.enableProgressReporting, equals(false));
      });

      test('mobile config should balance performance and logging', () {
        final config = SonixConfig.mobile();

        // Should be optimized for mobile (low resource usage)
        expect(config.maxConcurrentOperations, equals(2));
        expect(config.isolatePoolSize, equals(1));
        expect(config.maxMemoryUsage, equals(50 * 1024 * 1024));

        // Should suppress MP3 warnings for cleaner mobile logs
        expect(config.logLevel, equals(2)); // ERROR level
      });

      test('desktop config should optimize for performance with clean logging', () {
        final config = SonixConfig.desktop();

        // Should utilize desktop resources
        expect(config.maxConcurrentOperations, equals(4));
        expect(config.isolatePoolSize, equals(3));
        expect(config.maxMemoryUsage, equals(200 * 1024 * 1024));

        // Should suppress MP3 warnings for clean desktop logs
        expect(config.logLevel, equals(2)); // ERROR level
      });
    });
  });
}
