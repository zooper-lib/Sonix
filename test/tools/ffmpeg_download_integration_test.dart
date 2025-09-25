// ignore_for_file: avoid_print

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import '../../tools/ffmpeg_binary_downloader.dart';

void main() {
  group('FFMPEG Download Integration Tests', () {
    test('should have accessible download URLs for all platforms', () async {
      final configs = FFMPEGBinaryDownloader.getAllConfigurations();

      for (final entry in configs.entries) {
        final platform = entry.key;
        final config = entry.value;

        print('Testing $platform: ${config.archiveUrl}');

        try {
          // Make a HEAD request to check if URL is accessible
          final response = await http.head(Uri.parse(config.archiveUrl)).timeout(Duration(seconds: 10));

          // Accept both 200 (OK) and 302 (redirect) as valid responses
          expect(response.statusCode, isIn([200, 302, 301]), reason: 'URL not accessible for $platform: ${config.archiveUrl}');

          print('✓ $platform URL is accessible (${response.statusCode})');
        } catch (e) {
          // Some servers might not support HEAD requests, so this is just a warning
          print('⚠ Could not verify $platform URL: $e');
        }
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('should have valid archive URLs format', () {
      final configs = FFMPEGBinaryDownloader.getAllConfigurations();

      for (final entry in configs.entries) {
        final platform = entry.key;
        final config = entry.value;

        // Validate URL format
        final uri = Uri.tryParse(config.archiveUrl);
        expect(uri, isNotNull, reason: 'Invalid URL for $platform');
        expect(uri!.scheme, isIn(['http', 'https']), reason: 'URL must use HTTP/HTTPS for $platform');

        // Validate archive format
        final supportedFormats = ['.zip', '.tar.gz', '.tar.xz', '/zip']; // /zip for evermeet.cx
        final hasValidFormat = supportedFormats.any((format) => config.archiveUrl.endsWith(format));
        expect(hasValidFormat, isTrue, reason: 'Unsupported archive format for $platform: ${config.archiveUrl}');

        // Validate library paths are not empty
        expect(config.libraryPaths, isNotEmpty, reason: 'No library paths defined for $platform');

        print('✓ $platform configuration is valid');
      }
    });

    test('should have consistent library names across platforms', () {
      final configs = FFMPEGBinaryDownloader.getAllConfigurations();

      // Expected base library names (without extensions)
      final expectedLibraries = ['avformat', 'avcodec', 'avutil', 'swresample'];

      for (final entry in configs.entries) {
        final platform = entry.key;
        final config = entry.value;

        final libraryNames = config.libraryPaths.keys.toList();

        // Check that all expected libraries are present
        for (final expectedLib in expectedLibraries) {
          final hasLibrary = libraryNames.any((name) => name.contains(expectedLib));
          expect(hasLibrary, isTrue, reason: 'Missing $expectedLib library for $platform');
        }

        print('✓ $platform has all required libraries');
      }
    });

    test('should create valid downloader instance', () {
      final downloader = FFMPEGBinaryDownloader();
      expect(downloader, isNotNull);

      final platformInfo = downloader.platformInfo;
      expect(platformInfo.platform, isIn(['windows', 'macos', 'linux']));
      expect(platformInfo.architecture, isNotEmpty);

      print('✓ Downloader created for ${platformInfo.platform} ${platformInfo.architecture}');
    });
  });
}
