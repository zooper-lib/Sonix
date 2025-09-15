/// Test helper for creating Sonix with mock isolate manager
///
/// This provides a way to test Sonix functionality without
/// requiring real audio files or native decoders.
library;

import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/config/sonix_config.dart';
import 'package:sonix/src/isolate/isolate_manager.dart';
import 'mock_isolate_manager.dart';

/// Test configuration that uses mock isolates
class TestSonixConfig extends SonixConfig {
  const TestSonixConfig({
    super.maxConcurrentOperations = 2,
    super.isolatePoolSize = 1,
    super.isolateIdleTimeout = const Duration(seconds: 5),
    super.maxMemoryUsage = 50 * 1024 * 1024,
    super.enableCaching = false,
    super.maxCacheSize = 10,
    super.enableProgressReporting = true,
  });
}

/// Test isolate manager that uses mock processing (no real isolates)
class TestIsolateManager extends MockIsolateManager {
  TestIsolateManager(super.config);

  // No need to override spawnProcessingIsolate since we're using synchronous mocking
}

/// Test Sonix that uses mock isolate manager
class TestSonixInstance extends Sonix {
  late final TestIsolateManager _testIsolateManager;

  TestSonixInstance([SonixConfig? config]) : super(config ?? const TestSonixConfig());

  @override
  IsolateManager createIsolateManager() {
    _testIsolateManager = TestIsolateManager(config);
    return _testIsolateManager;
  }

  /// Get the mock isolate manager for testing
  TestIsolateManager get mockIsolateManager => _testIsolateManager;
}
