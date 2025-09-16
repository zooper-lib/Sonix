import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/config/sonix_config.dart';

void main() {
  group('SonixConfig', () {
    test('should create with default values', () {
      const config = SonixConfig();

      expect(config.isolatePoolSize, equals(2));
      expect(config.maxConcurrentOperations, equals(3));
      expect(config.maxMemoryUsage, equals(100 * 1024 * 1024)); // 100MB
      expect(config.enableProgressReporting, isTrue);
      expect(config.enableCaching, isTrue);
      expect(config.maxCacheSize, equals(50));
      expect(config.isolateIdleTimeout, equals(const Duration(minutes: 5)));
    });

    test('should create with custom values', () {
      const config = SonixConfig(
        isolatePoolSize: 5,
        maxConcurrentOperations: 10,
        maxMemoryUsage: 200 * 1024 * 1024,
        enableProgressReporting: false,
        enableCaching: false,
        maxCacheSize: 100,
        isolateIdleTimeout: Duration(minutes: 10),
      );

      expect(config.isolatePoolSize, equals(5));
      expect(config.maxConcurrentOperations, equals(10));
      expect(config.maxMemoryUsage, equals(200 * 1024 * 1024));
      expect(config.enableProgressReporting, isFalse);
      expect(config.enableCaching, isFalse);
      expect(config.maxCacheSize, equals(100));
      expect(config.isolateIdleTimeout, equals(const Duration(minutes: 10)));
    });

    test('should create factory configurations', () {
      // Test default config
      final defaultConfig = SonixConfig.defaultConfig();
      expect(defaultConfig.maxConcurrentOperations, equals(3));
      expect(defaultConfig.isolatePoolSize, equals(2));

      // Test mobile config
      final mobileConfig = SonixConfig.mobile();
      expect(mobileConfig.maxConcurrentOperations, equals(2));
      expect(mobileConfig.isolatePoolSize, equals(1));
      expect(mobileConfig.maxMemoryUsage, equals(50 * 1024 * 1024));

      // Test desktop config
      final desktopConfig = SonixConfig.desktop();
      expect(desktopConfig.maxConcurrentOperations, equals(4));
      expect(desktopConfig.isolatePoolSize, equals(3));
      expect(desktopConfig.maxMemoryUsage, equals(200 * 1024 * 1024));
    });

    test('should provide string representation', () {
      const config = SonixConfig(isolatePoolSize: 2, enableCaching: false);
      final stringRep = config.toString();

      expect(stringRep, contains('SonixConfig'));
      expect(stringRep, contains('isolatePoolSize: 2'));
      expect(stringRep, contains('100.0MB')); // Memory usage in MB
    });

    test('should implement IsolateConfig interface', () {
      const config = SonixConfig();

      // Should have all IsolateConfig properties
      expect(config.maxConcurrentOperations, isA<int>());
      expect(config.isolatePoolSize, isA<int>());
      expect(config.isolateIdleTimeout, isA<Duration>());
      expect(config.maxMemoryUsage, isA<int>());
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
  });
}
