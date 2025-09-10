// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FLAC file analysis', () async {
    const testFile = 'test/assets/test_sample.flac';
    final file = File(testFile);

    if (!file.existsSync()) {
      print('File does not exist: $testFile');
      return;
    }

    final bytes = await file.readAsBytes();
    print('File size: ${bytes.length} bytes');

    // Check first 50 bytes
    final first50 = bytes.take(50).toList();
    print('First 50 bytes:');
    for (int i = 0; i < first50.length; i += 16) {
      final chunk = first50.skip(i).take(16).toList();
      final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final ascii = chunk.map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.').join('');
      print('${i.toString().padLeft(3, '0')}: $hex | $ascii');
    }

    // Check FLAC signature
    if (bytes.length >= 4) {
      final sig = bytes.take(4).toList();
      final isFlac = sig[0] == 0x66 && sig[1] == 0x4C && sig[2] == 0x61 && sig[3] == 0x43;
      print('FLAC signature valid: $isFlac');

      if (isFlac && bytes.length >= 8) {
        // Check metadata block header
        final isLastBlock = (bytes[4] & 0x80) != 0;
        final blockType = bytes[4] & 0x7F;
        final blockLength = (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];

        print('First metadata block:');
        print('  Is last block: $isLastBlock');
        print('  Block type: $blockType (${_getBlockTypeName(blockType)})');
        print('  Block length: $blockLength bytes');

        if (blockType == 0 && blockLength >= 34) {
          // STREAMINFO block
          print('STREAMINFO block found - this should be a valid FLAC file');

          // Extract STREAMINFO details
          final streamInfo = bytes.skip(8).take(34).toList();
          final minBlockSize = (streamInfo[0] << 8) | streamInfo[1];
          final maxBlockSize = (streamInfo[2] << 8) | streamInfo[3];
          print('  Min block size: $minBlockSize');
          print('  Max block size: $maxBlockSize');
        }
      }
    }
  });
}

String _getBlockTypeName(int type) {
  switch (type) {
    case 0:
      return 'STREAMINFO';
    case 1:
      return 'PADDING';
    case 2:
      return 'APPLICATION';
    case 3:
      return 'SEEKTABLE';
    case 4:
      return 'VORBIS_COMMENT';
    case 5:
      return 'CUESHEET';
    case 6:
      return 'PICTURE';
    default:
      return 'UNKNOWN($type)';
  }
}
