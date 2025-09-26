#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

/// Simple utility to copy existing native binaries to plugin directories
///
/// This is a temporary helper for testing the plugin structure before
/// the full build system is implemented.
///
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart run tools/copy_native_binary.dart <source_binary>');
    print('Example: dart run tools/copy_native_binary.dart sonix_native.dll');
    exit(1);
  }

  final sourcePath = arguments[0];
  final sourceFile = File(sourcePath);

  if (!await sourceFile.exists()) {
    print('❌ Source file not found: $sourcePath');
    exit(1);
  }

  print('Copying $sourcePath to plugin directories...');

  // Determine platform and copy to appropriate location
  if (sourcePath.endsWith('.dll')) {
    // Windows
    final targetFile = File('windows/sonix_native.dll');
    await sourceFile.copy(targetFile.path);
    print('✅ Copied to: ${targetFile.path}');
  } else if (sourcePath.endsWith('.so')) {
    // Linux
    final targetFile = File('linux/libsonix_native.so');
    await sourceFile.copy(targetFile.path);
    print('✅ Copied to: ${targetFile.path}');
  } else if (sourcePath.endsWith('.dylib')) {
    // macOS
    final targetFile = File('macos/libsonix_native.dylib');
    await sourceFile.copy(targetFile.path);
    print('✅ Copied to: ${targetFile.path}');
  } else if (sourcePath.endsWith('.a')) {
    // iOS
    final targetFile = File('ios/libsonix_native.a');
    await sourceFile.copy(targetFile.path);
    print('✅ Copied to: ${targetFile.path}');
  } else {
    print('❌ Unknown binary type: $sourcePath');
    print('   Supported extensions: .dll, .so, .dylib, .a');
    exit(1);
  }

  print('');
  print('🎉 Binary copied successfully!');
  print('The native library is now ready for plugin bundling.');
}
