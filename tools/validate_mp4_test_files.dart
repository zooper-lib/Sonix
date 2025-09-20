// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

/// Validates MP4 test files to ensure they have proper structure
class MP4TestFileValidator {
  static const String generatedPath = 'test/assets/generated';

  /// Validates all MP4 test files
  static Future<void> validateAllMP4TestFiles() async {
    print('Validating MP4 test files...');

    final mp4Files = await _getMP4TestFiles();

    if (mp4Files.isEmpty) {
      print('No MP4 test files found!');
      return;
    }

    int validFiles = 0;
    int invalidFiles = 0;

    for (final file in mp4Files) {
      final isValid = await _validateMP4File(file);
      if (isValid) {
        validFiles++;
        print('✓ ${file.path.split(Platform.pathSeparator).last}');
      } else {
        invalidFiles++;
        print('✗ ${file.path.split(Platform.pathSeparator).last}');
      }
    }

    print('\nValidation Summary:');
    print('Valid MP4 files: $validFiles');
    print('Invalid MP4 files: $invalidFiles');
    print('Total MP4 files: ${mp4Files.length}');

    if (invalidFiles > 0) {
      print('\nNote: Some invalid files are expected (corrupted test files)');
    }
  }

  /// Gets all MP4 test files
  static Future<List<File>> _getMP4TestFiles() async {
    final directory = Directory(generatedPath);
    if (!await directory.exists()) {
      return [];
    }

    final mp4Files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.mp4')) {
        mp4Files.add(entity);
      }
    }

    return mp4Files;
  }

  /// Validates a single MP4 file
  static Future<bool> _validateMP4File(File file) async {
    try {
      final data = await file.readAsBytes();

      // Check minimum file size
      if (data.length < 8) {
        return false;
      }

      // Check for MP4 ftyp box signature
      return _hasValidMP4Signature(data);
    } catch (e) {
      return false;
    }
  }

  /// Checks if the file has a valid MP4 signature
  static bool _hasValidMP4Signature(Uint8List data) {
    if (data.length < 8) return false;

    // Check for ftyp box signature at the beginning
    // Format: [size:4][type:4] where type is 'ftyp'
    return data[4] == 0x66 && // 'f'
        data[5] == 0x74 && // 't'
        data[6] == 0x79 && // 'y'
        data[7] == 0x70; // 'p'
  }

  /// Analyzes MP4 file structure
  static Future<void> analyzeMP4File(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      print('File not found: $filePath');
      return;
    }

    final data = await file.readAsBytes();
    final filename = filePath.split(Platform.pathSeparator).last;

    print('\nAnalyzing: $filename');
    print('File size: ${_formatFileSize(data.length)}');

    if (data.isEmpty) {
      print('Status: Empty file');
      return;
    }

    if (_hasValidMP4Signature(data)) {
      print('Status: Valid MP4 signature');
      _analyzeMP4Boxes(data);
    } else {
      print('Status: Invalid MP4 signature');
      if (data.length >= 4) {
        final firstBytes = data.sublist(0, 4);
        print('First 4 bytes: ${firstBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      }
    }
  }

  /// Analyzes MP4 box structure
  static void _analyzeMP4Boxes(Uint8List data) {
    int offset = 0;
    final boxes = <String>[];

    while (offset + 8 <= data.length) {
      final boxSize = ByteData.view(data.buffer, offset, 4).getUint32(0, Endian.big);
      final boxType = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

      boxes.add(boxType);

      if (boxSize == 0 || boxSize > data.length - offset) {
        break;
      }

      offset += boxSize;
    }

    print('MP4 boxes found: ${boxes.join(', ')}');
  }

  /// Formats file size for human-readable output
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Main function to run MP4 test file validation
Future<void> main(List<String> args) async {
  try {
    if (args.isNotEmpty && args[0] == 'analyze') {
      // Analyze specific files
      if (args.length > 1) {
        for (int i = 1; i < args.length; i++) {
          await MP4TestFileValidator.analyzeMP4File(args[i]);
        }
      } else {
        print('Usage: dart validate_mp4_test_files.dart analyze <file1> [file2] ...');
      }
    } else {
      // Validate all MP4 test files
      await MP4TestFileValidator.validateAllMP4TestFiles();
    }
  } catch (e) {
    print('Error validating MP4 test files: $e');
    exit(1);
  }
}
