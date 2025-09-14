/// Health monitoring and crash detection for isolates
///
/// This module provides functionality to monitor isolate health,
/// detect crashes, and implement recovery mechanisms.
library;

import 'dart:async';
import 'dart:isolate';

import 'isolate_messages.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

/// Health status of an isolate
enum IsolateHealthStatus {
  /// Isolate is healthy and responsive
  healthy,

  /// Isolate is unresponsive but may recover
  unresponsive,

  /// Isolate has crashed and needs to be restarted
  crashed,

  /// Isolate is being terminated
  terminating,
}

/// Health information for an isolate
class IsolateHealth {
  /// Current health status
  final IsolateHealthStatus status;

  /// Last time the isolate responded to a health check
  final DateTime lastHealthCheck;

  /// Number of consecutive failed health checks
  final int failedHealthChecks;

  /// Last error encountered (if any)
  final Object? lastError;

  /// Time when the isolate was created
  final DateTime createdAt;

  /// Number of tasks successfully completed
  final int completedTasks;

  /// Number of tasks that failed
  final int failedTasks;

  const IsolateHealth({
    required this.status,
    required this.lastHealthCheck,
    required this.failedHealthChecks,
    this.lastError,
    required this.createdAt,
    required this.completedTasks,
    required this.failedTasks,
  });

  /// Create initial health state for a new isolate
  factory IsolateHealth.initial() {
    final now = DateTime.now();
    return IsolateHealth(status: IsolateHealthStatus.healthy, lastHealthCheck: now, failedHealthChecks: 0, createdAt: now, completedTasks: 0, failedTasks: 0);
  }

  /// Update health after a successful operation
  IsolateHealth markHealthy() {
    return IsolateHealth(
      status: IsolateHealthStatus.healthy,
      lastHealthCheck: DateTime.now(),
      failedHealthChecks: 0,
      lastError: null,
      createdAt: createdAt,
      completedTasks: completedTasks + 1,
      failedTasks: failedTasks,
    );
  }

  /// Update health after a failed operation
  IsolateHealth markUnhealthy(Object error) {
    final newFailedChecks = failedHealthChecks + 1;
    final newStatus = newFailedChecks >= 3 ? IsolateHealthStatus.crashed : IsolateHealthStatus.unresponsive;

    return IsolateHealth(
      status: newStatus,
      lastHealthCheck: DateTime.now(),
      failedHealthChecks: newFailedChecks,
      lastError: error,
      createdAt: createdAt,
      completedTasks: completedTasks,
      failedTasks: failedTasks + 1,
    );
  }

  /// Mark isolate as terminating
  IsolateHealth markTerminating() {
    return IsolateHealth(
      status: IsolateHealthStatus.terminating,
      lastHealthCheck: lastHealthCheck,
      failedHealthChecks: failedHealthChecks,
      lastError: lastError,
      createdAt: createdAt,
      completedTasks: completedTasks,
      failedTasks: failedTasks,
    );
  }

  /// Check if the isolate needs to be restarted
  bool get needsRestart => status == IsolateHealthStatus.crashed;

  /// Check if the isolate is responsive
  bool get isResponsive => status == IsolateHealthStatus.healthy;

  /// Get uptime of the isolate
  Duration get uptime => DateTime.now().difference(createdAt);
}

/// Health check message for testing isolate responsiveness
class HealthCheckRequest extends IsolateMessage {
  @override
  String get messageType => 'HealthCheckRequest';

  const HealthCheckRequest({required super.id, required super.timestamp});

  @override
  Map<String, dynamic> toJson() {
    return {'messageType': messageType, 'id': id, 'timestamp': timestamp.toIso8601String()};
  }

  factory HealthCheckRequest.fromJson(Map<String, dynamic> json) {
    return HealthCheckRequest(id: json['id'] as String, timestamp: DateTime.parse(json['timestamp'] as String));
  }
}

/// Health check response from isolate
class HealthCheckResponse extends IsolateMessage {
  /// Memory usage in bytes (if available)
  final int? memoryUsage;

  /// Number of active tasks
  final int activeTasks;

  /// Isolate status information
  final Map<String, dynamic> statusInfo;

  @override
  String get messageType => 'HealthCheckResponse';

  const HealthCheckResponse({required super.id, required super.timestamp, this.memoryUsage, required this.activeTasks, required this.statusInfo});

  @override
  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'memoryUsage': memoryUsage,
      'activeTasks': activeTasks,
      'statusInfo': statusInfo,
    };
  }

  factory HealthCheckResponse.fromJson(Map<String, dynamic> json) {
    return HealthCheckResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      memoryUsage: json['memoryUsage'] as int?,
      activeTasks: json['activeTasks'] as int? ?? 0,
      statusInfo: json['statusInfo'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Monitors the health of isolates and implements recovery mechanisms
class IsolateHealthMonitor {
  /// Health information for each monitored isolate
  final Map<String, IsolateHealth> _isolateHealth = {};

  /// Timers for periodic health checks
  final Map<String, Timer> _healthCheckTimers = {};

  /// Callbacks for health status changes
  final List<void Function(String isolateId, IsolateHealth health)> _healthCallbacks = [];

  /// Callbacks for isolate crash events
  final List<void Function(String isolateId, Object error)> _crashCallbacks = [];

  /// Configuration
  final Duration healthCheckInterval;
  final Duration responseTimeout;
  final int maxFailedChecks;

  IsolateHealthMonitor({this.healthCheckInterval = const Duration(seconds: 30), this.responseTimeout = const Duration(seconds: 5), this.maxFailedChecks = 3});

  /// Start monitoring an isolate
  void startMonitoring(String isolateId, SendPort sendPort) {
    _isolateHealth[isolateId] = IsolateHealth.initial();

    // Start periodic health checks
    _healthCheckTimers[isolateId] = Timer.periodic(healthCheckInterval, (timer) {
      _performHealthCheck(isolateId, sendPort);
    });
  }

  /// Stop monitoring an isolate
  void stopMonitoring(String isolateId) {
    _healthCheckTimers[isolateId]?.cancel();
    _healthCheckTimers.remove(isolateId);

    final health = _isolateHealth[isolateId];
    if (health != null) {
      _isolateHealth[isolateId] = health.markTerminating();
    }
  }

  /// Remove an isolate from monitoring completely
  void removeIsolate(String isolateId) {
    stopMonitoring(isolateId);
    _isolateHealth.remove(isolateId);
  }

  /// Get health information for an isolate
  IsolateHealth? getHealth(String isolateId) {
    return _isolateHealth[isolateId];
  }

  /// Get health information for all monitored isolates
  Map<String, IsolateHealth> getAllHealth() {
    return Map.unmodifiable(_isolateHealth);
  }

  /// Register a callback for health status changes
  void onHealthChanged(void Function(String isolateId, IsolateHealth health) callback) {
    _healthCallbacks.add(callback);
  }

  /// Register a callback for isolate crashes
  void onIsolateCrashed(void Function(String isolateId, Object error) callback) {
    _crashCallbacks.add(callback);
  }

  /// Report a successful operation for an isolate
  void reportSuccess(String isolateId) {
    final currentHealth = _isolateHealth[isolateId];
    if (currentHealth != null) {
      final newHealth = currentHealth.markHealthy();
      _isolateHealth[isolateId] = newHealth;
      _notifyHealthChanged(isolateId, newHealth);
    }
  }

  /// Report a failed operation for an isolate
  void reportFailure(String isolateId, Object error) {
    final currentHealth = _isolateHealth[isolateId];
    if (currentHealth != null) {
      final newHealth = currentHealth.markUnhealthy(error);
      _isolateHealth[isolateId] = newHealth;
      _notifyHealthChanged(isolateId, newHealth);

      if (newHealth.needsRestart) {
        _notifyIsolateCrashed(isolateId, error);
      }
    }
  }

  /// Handle a health check response
  void handleHealthCheckResponse(String isolateId, HealthCheckResponse response) {
    reportSuccess(isolateId);
  }

  /// Perform a health check on an isolate
  void _performHealthCheck(String isolateId, SendPort sendPort) {
    final healthCheck = HealthCheckRequest(id: 'health_${DateTime.now().millisecondsSinceEpoch}', timestamp: DateTime.now());

    try {
      sendPort.send(healthCheck.toJson());

      // Set up timeout for response
      Timer(responseTimeout, () {
        final currentHealth = _isolateHealth[isolateId];
        if (currentHealth != null && DateTime.now().difference(currentHealth.lastHealthCheck) >= responseTimeout) {
          reportFailure(isolateId, TimeoutException('Health check timeout for isolate $isolateId', responseTimeout));
        }
      });
    } catch (error) {
      reportFailure(isolateId, IsolateCommunicationException.sendFailure('HealthCheckRequest', isolateId: isolateId, cause: error));
    }
  }

  /// Notify health change callbacks
  void _notifyHealthChanged(String isolateId, IsolateHealth health) {
    for (final callback in _healthCallbacks) {
      try {
        callback(isolateId, health);
      } catch (e) {
        // Ignore callback errors
      }
    }
  }

  /// Notify crash callbacks
  void _notifyIsolateCrashed(String isolateId, Object error) {
    for (final callback in _crashCallbacks) {
      try {
        callback(isolateId, error);
      } catch (e) {
        // Ignore callback errors
      }
    }
  }

  /// Get statistics about monitored isolates
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{
      'totalIsolates': _isolateHealth.length,
      'healthyIsolates': 0,
      'unresponsiveIsolates': 0,
      'crashedIsolates': 0,
      'terminatingIsolates': 0,
      'totalCompletedTasks': 0,
      'totalFailedTasks': 0,
    };

    for (final health in _isolateHealth.values) {
      switch (health.status) {
        case IsolateHealthStatus.healthy:
          stats['healthyIsolates']++;
          break;
        case IsolateHealthStatus.unresponsive:
          stats['unresponsiveIsolates']++;
          break;
        case IsolateHealthStatus.crashed:
          stats['crashedIsolates']++;
          break;
        case IsolateHealthStatus.terminating:
          stats['terminatingIsolates']++;
          break;
      }

      stats['totalCompletedTasks'] += health.completedTasks;
      stats['totalFailedTasks'] += health.failedTasks;
    }

    return stats;
  }

  /// Dispose of the health monitor
  void dispose() {
    for (final timer in _healthCheckTimers.values) {
      timer.cancel();
    }
    _healthCheckTimers.clear();
    _isolateHealth.clear();
    _healthCallbacks.clear();
    _crashCallbacks.clear();
  }
}
