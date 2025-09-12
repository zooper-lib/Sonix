#!/usr/bin/env dart
// Test cache management script
// Usage: dart scripts/manage_test_cache.dart <command>

import 'dart:io';

void main(List<String> args) async {
  // Forward to the actual cache manager
  final result = await Process.run('dart', ['test/utils/test_file_cache_manager.dart', ...args], workingDirectory: Directory.current.path);

  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print(result.stderr);
  }

  exit(result.exitCode);
}
