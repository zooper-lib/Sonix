/// Configuration interface for isolate management
abstract class IsolateConfig {
  int get maxConcurrentOperations;
  int get isolatePoolSize;
  Duration get isolateIdleTimeout;
  int get maxMemoryUsage;
}
