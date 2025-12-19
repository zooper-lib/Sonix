/// Test helper for creating Sonix test instances
///
/// This provides a way to test Sonix functionality with
/// specific configurations.
library;

import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/config/sonix_config.dart';

/// Test configuration with smaller memory limits
class TestSonixConfig extends SonixConfig {
  const TestSonixConfig({
    super.maxMemoryUsage = 50 * 1024 * 1024,
    super.logLevel = 2, // ERROR level for testing
  });
}

/// Test Sonix instance for testing
class TestSonixInstance extends Sonix {
  TestSonixInstance([SonixConfig? config]) : super(config ?? const TestSonixConfig());
}
