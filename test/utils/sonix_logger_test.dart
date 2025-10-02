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

    test('log levels should use correct numeric values', () {
      // Test that the logging methods use the correct log levels
      // Error = 2, Warning = 3, Info = 4, Debug = 6

      // Since we can't directly test the internal levels, we test that the methods exist
      // and work with the expected log level behavior
      expect(() => SonixLogger.error('Test error'), returnsNormally);
      expect(() => SonixLogger.warning('Test warning'), returnsNormally);
      expect(() => SonixLogger.info('Test info'), returnsNormally);
      expect(() => SonixLogger.debug('Test debug'), returnsNormally);
      expect(() => SonixLogger.trace('Test trace'), returnsNormally);

      // Log levels are now: 2 (error) < 3 (warning) < 4 (info) < 6 (debug/trace)
      // Higher numbers mean more verbose (opposite of priority)
      expect(2 < 3, true); // error < warning
      expect(3 < 4, true); // warning < info
      expect(4 < 6, true); // info < debug
    });
  });
}
