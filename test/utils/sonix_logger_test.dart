import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/config/sonix_config.dart';
import 'package:sonix/src/utils/sonix_logger.dart';

void main() {
  group('SonixLogger Tests', () {
    setUp(() {
      // Reset debug logging state before each test
      SonixConfig.disableDebugLogs();
    });

    test('should respect debug logging flag', () {
      // Initially disabled
      expect(SonixConfig.enableDebugLogging, false);

      // Enable debug logging
      SonixConfig.enableDebugLogs();
      expect(SonixConfig.enableDebugLogging, true);

      // Disable debug logging
      SonixConfig.disableDebugLogs();
      expect(SonixConfig.enableDebugLogging, false);
    });

    test('logger methods should not throw exceptions', () {
      // Test all logging methods don't throw
      expect(() => SonixLogger.error('Test error'), returnsNormally);
      expect(() => SonixLogger.warning('Test warning'), returnsNormally);
      expect(() => SonixLogger.info('Test info'), returnsNormally);
      expect(() => SonixLogger.debug('Test debug'), returnsNormally);
      expect(() => SonixLogger.trace('Test trace'), returnsNormally);
    });

    test('error logging with exception should not throw', () {
      final testError = Exception('Test exception');
      final testStackTrace = StackTrace.current;

      expect(() => SonixLogger.error('Test error with exception', testError, testStackTrace), returnsNormally);
    });

    test('specialized logging methods should not throw', () {
      expect(() => SonixLogger.isolate('isolate-1', 'Test isolate message'), returnsNormally);
      expect(() => SonixLogger.native('decode', 'Test native message'), returnsNormally);
    });

    test('log levels should have correct values', () {
      expect(SonixLogLevel.error, 1000);
      expect(SonixLogLevel.warning, 800);
      expect(SonixLogLevel.info, 500);
      expect(SonixLogLevel.debug, 300);
      expect(SonixLogLevel.trace, 100);

      // Error should be highest priority
      expect(SonixLogLevel.error > SonixLogLevel.warning, true);
      expect(SonixLogLevel.warning > SonixLogLevel.info, true);
      expect(SonixLogLevel.info > SonixLogLevel.debug, true);
      expect(SonixLogLevel.debug > SonixLogLevel.trace, true);
    });
  });
}
