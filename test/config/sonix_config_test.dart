import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/config/sonix_config.dart';

void main() {
  group('SonixConfig', () {
    test('should create with default values', () {
      const config = SonixConfig();

      expect(config.maxMemoryUsage, equals(100 * 1024 * 1024)); // 100MB
      expect(config.logLevel, equals(2)); // ERROR level
    });

    test('should create with custom values', () {
      const config = SonixConfig(maxMemoryUsage: 200 * 1024 * 1024, logLevel: 3);

      expect(config.maxMemoryUsage, equals(200 * 1024 * 1024));
      expect(config.logLevel, equals(3));
    });

    test('should create factory configurations', () {
      // Test default config
      final defaultConfig = SonixConfig.defaultConfig();
      expect(defaultConfig.maxMemoryUsage, equals(100 * 1024 * 1024));

      // Test mobile config
      final mobileConfig = SonixConfig.mobile();
      expect(mobileConfig.maxMemoryUsage, equals(50 * 1024 * 1024));

      // Test desktop config
      final desktopConfig = SonixConfig.desktop();
      expect(desktopConfig.maxMemoryUsage, equals(200 * 1024 * 1024));
    });

    test('should provide string representation', () {
      const config = SonixConfig();
      final stringRep = config.toString();

      expect(stringRep, contains('SonixConfig'));
      expect(stringRep, contains('100.0MB')); // Memory usage in MB
      expect(stringRep, contains('logLevel'));
    });

    test('should handle different memory configurations', () {
      const lowMemoryConfig = SonixConfig(maxMemoryUsage: 25 * 1024 * 1024);
      const highMemoryConfig = SonixConfig(maxMemoryUsage: 500 * 1024 * 1024);

      expect(lowMemoryConfig.maxMemoryUsage, equals(25 * 1024 * 1024));
      expect(highMemoryConfig.maxMemoryUsage, equals(500 * 1024 * 1024));

      // String representation should show memory in MB
      expect(lowMemoryConfig.toString(), contains('25.0MB'));
      expect(highMemoryConfig.toString(), contains('500.0MB'));
    });

    test('should handle debug logging flags', () {
      expect(SonixConfig.enableDebugLogging, isFalse);

      SonixConfig.enableDebugLogs();
      expect(SonixConfig.enableDebugLogging, isTrue);

      SonixConfig.disableDebugLogs();
      expect(SonixConfig.enableDebugLogging, isFalse);
    });
  });
}
