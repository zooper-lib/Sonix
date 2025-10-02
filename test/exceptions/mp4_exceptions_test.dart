import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('MP4ContainerException', () {
    test('should create basic MP4ContainerException', () {
      const exception = MP4ContainerException('Invalid container structure');

      expect(exception.message, equals('MP4 container error: Invalid container structure'));
      expect(exception.details, isNull);
      expect(exception.operation, isNull);
      expect(exception.boxType, isNull);
      expect(exception.fileOffset, isNull);
    });

    test('should create MP4ContainerException with all properties', () {
      const exception = MP4ContainerException(
        'Box parsing failed',
        details: 'Unexpected end of file',
        operation: 'box_parsing',
        boxType: 'moov',
        fileOffset: 1024,
      );

      expect(exception.message, equals('MP4 container error: Box parsing failed'));
      expect(exception.details, equals('Unexpected end of file'));
      expect(exception.operation, equals('box_parsing'));
      expect(exception.boxType, equals('moov'));
      expect(exception.fileOffset, equals(1024));
    });

    test('should create invalid box exception', () {
      final exception = MP4ContainerException.invalidBox('ftyp', details: 'Invalid box size', fileOffset: 512);

      expect(exception.message, equals('MP4 container error: Invalid or corrupted ftyp box'));
      expect(exception.details, equals('Invalid box size'));
      expect(exception.operation, equals('box_parsing'));
      expect(exception.boxType, equals('ftyp'));
      expect(exception.fileOffset, equals(512));
    });

    test('should create missing box exception', () {
      final exception = MP4ContainerException.missingBox('moov', details: 'Required for metadata extraction');

      expect(exception.message, equals('MP4 container error: Required moov box not found in MP4 container'));
      expect(exception.details, equals('Required for metadata extraction'));
      expect(exception.operation, equals('box_validation'));
      expect(exception.boxType, equals('moov'));
    });

    test('should create truncated file exception', () {
      final exception = MP4ContainerException.truncatedFile(details: 'File size mismatch', fileOffset: 2048);

      expect(exception.message, equals('MP4 container error: MP4 file appears to be truncated or incomplete'));
      expect(exception.details, equals('File size mismatch'));
      expect(exception.operation, equals('file_reading'));
      expect(exception.fileOffset, equals(2048));
    });

    test('should create encrypted content exception', () {
      final exception = MP4ContainerException.encryptedContent(details: 'DRM protection detected');

      expect(exception.message, equals('MP4 container error: MP4 file is encrypted or DRM-protected'));
      expect(exception.details, equals('DRM protection detected'));
      expect(exception.operation, equals('content_validation'));
    });

    test('should inherit from DecodingException', () {
      const exception = MP4ContainerException('Test error');
      expect(exception, isA<DecodingException>());
      expect(exception, isA<SonixException>());
    });

    test('should have correct string representation', () {
      const exception = MP4ContainerException('Box parsing failed', details: 'Unexpected data', operation: 'box_parsing', boxType: 'mdat', fileOffset: 1024);

      final str = exception.toString();
      expect(str, contains('MP4ContainerException'));
      expect(str, contains('MP4 container error: Box parsing failed'));
      expect(str, contains('Operation: box_parsing'));
      expect(str, contains('Box Type: mdat'));
      expect(str, contains('File Offset: 1024'));
      expect(str, contains('Details: Unexpected data'));
    });

    test('should have minimal string representation without optional fields', () {
      const exception = MP4ContainerException('Simple error');

      final str = exception.toString();
      expect(str, equals('MP4ContainerException: MP4 container error: Simple error'));
    });
  });

  group('MP4CodecException', () {
    test('should create basic MP4CodecException', () {
      const exception = MP4CodecException('DTS');

      expect(exception.codecName, equals('DTS'));
      expect(exception.format, equals('DTS'));
      expect(exception.message, contains('Unsupported MP4 audio codec: DTS'));
      expect(exception.codecProfile, isNull);
      expect(exception.codecConfig, isNull);
      expect(exception.initializationFailure, isFalse);
    });

    test('should create MP4CodecException with all properties', () {
      const exception = MP4CodecException(
        'AAC',
        details: 'Profile not supported',
        codecProfile: 'AAC-SSR',
        codecConfig: 'Profile=2, Level=4',
        initializationFailure: true,
      );

      expect(exception.codecName, equals('AAC'));
      expect(exception.codecProfile, equals('AAC-SSR'));
      expect(exception.codecConfig, equals('Profile=2, Level=4'));
      expect(exception.initializationFailure, isTrue);
      expect(exception.message, contains('AAC (AAC-SSR)'));
      expect(exception.details, contains('Profile not supported'));
    });

    test('should create unsupported codec exception', () {
      final exception = MP4CodecException.unsupportedCodec('AC-3', codecProfile: 'Dolby Digital', details: 'Requires license');

      expect(exception.codecName, equals('AC-3'));
      expect(exception.codecProfile, equals('Dolby Digital'));
      expect(exception.details, contains('Requires license'));
      expect(exception.initializationFailure, isFalse);
    });

    test('should create initialization failed exception', () {
      final exception = MP4CodecException.initializationFailed(
        'AAC',
        codecProfile: 'AAC-LC',
        codecConfig: 'SampleRate=48000',
        details: 'Decoder library error',
      );

      expect(exception.codecName, equals('AAC'));
      expect(exception.codecProfile, equals('AAC-LC'));
      expect(exception.codecConfig, equals('SampleRate=48000'));
      expect(exception.initializationFailure, isTrue);
      expect(exception.details, contains('Decoder library error'));
    });

    test('should create unsupported AAC profile exception', () {
      final exception = MP4CodecException.unsupportedAACProfile('AAC-SSR', details: 'Legacy profile');

      expect(exception.codecName, equals('AAC'));
      expect(exception.codecProfile, equals('AAC-SSR'));
      expect(exception.details, contains('Legacy profile'));
      expect(exception.details, contains('Supported: LC, HE, HEv2'));
      expect(exception.initializationFailure, isFalse);
    });

    test('should provide user-friendly messages for different codecs', () {
      final aacException = MP4CodecException.unsupportedAACProfile('AAC-SSR');
      expect(aacException.userFriendlyMessage, contains('AAC variant (AAC-SSR) is not supported'));

      final ac3Exception = MP4CodecException.unsupportedCodec('AC-3');
      expect(ac3Exception.userFriendlyMessage, contains('AC-3 audio is not supported'));

      final dtsException = MP4CodecException.unsupportedCodec('DTS');
      expect(dtsException.userFriendlyMessage, contains('DTS audio is not supported'));

      final unknownException = MP4CodecException.unsupportedCodec('UNKNOWN');
      expect(unknownException.userFriendlyMessage, contains('Audio codec "UNKNOWN" is not supported'));
    });

    test('should provide suggested alternatives', () {
      const exception = MP4CodecException('AC-3');
      final alternatives = exception.suggestedAlternatives;

      expect(alternatives, contains('AAC-LC'));
      expect(alternatives, contains('AAC-HE'));
      expect(alternatives, contains('MP3'));
      expect(alternatives, contains('FLAC'));
      expect(alternatives, contains('WAV'));
    });

    test('should inherit from UnsupportedFormatException', () {
      const exception = MP4CodecException('DTS');
      expect(exception, isA<UnsupportedFormatException>());
      expect(exception, isA<SonixException>());
    });

    test('should have correct string representation', () {
      const exception = MP4CodecException('AAC', details: 'Profile error', codecProfile: 'AAC-SSR', codecConfig: 'Config data', initializationFailure: true);

      final str = exception.toString();
      expect(str, contains('MP4CodecException'));
      expect(str, contains('Unsupported MP4 audio codec: AAC (AAC-SSR)'));
      expect(str, contains('[Initialization Failed]'));
      expect(str, contains('Codec Config: Config data'));
      expect(str, contains('Details: Profile error'));
    });

    test('should have minimal string representation', () {
      const exception = MP4CodecException('DTS');

      final str = exception.toString();
      expect(str, equals('MP4CodecException: Unsupported MP4 audio codec: DTS'));
    });
  });

  group('MP4TrackException', () {
    test('should create basic MP4TrackException', () {
      const exception = MP4TrackException('Track not found');

      expect(exception.message, equals('MP4 track error: Track not found'));
      expect(exception.details, isNull);
      expect(exception.trackId, isNull);
      expect(exception.operation, isNull);
      expect(exception.audioTrackCount, isNull);
      expect(exception.isCorrupted, isFalse);
    });

    test('should create MP4TrackException with all properties', () {
      const exception = MP4TrackException(
        'Invalid track data',
        details: 'Corrupted sample table',
        trackId: 2,
        operation: 'track_parsing',
        audioTrackCount: 1,
        isCorrupted: true,
      );

      expect(exception.message, equals('MP4 track error: Invalid track data'));
      expect(exception.details, equals('Corrupted sample table'));
      expect(exception.trackId, equals(2));
      expect(exception.operation, equals('track_parsing'));
      expect(exception.audioTrackCount, equals(1));
      expect(exception.isCorrupted, isTrue);
    });

    test('should create no audio tracks exception', () {
      final exception = MP4TrackException.noAudioTracks(details: 'Only video tracks found');

      expect(exception.message, equals('MP4 track error: No audio tracks found in MP4 file'));
      expect(exception.details, equals('Only video tracks found'));
      expect(exception.operation, equals('track_discovery'));
      expect(exception.audioTrackCount, equals(0));
    });

    test('should create corrupted track exception', () {
      final exception = MP4TrackException.corruptedTrack(3, details: 'Invalid chunk offsets', operation: 'chunk_parsing');

      expect(exception.message, equals('MP4 track error: Audio track 3 is corrupted or invalid'));
      expect(exception.details, equals('Invalid chunk offsets'));
      expect(exception.trackId, equals(3));
      expect(exception.operation, equals('chunk_parsing'));
      expect(exception.isCorrupted, isTrue);
    });

    test('should create invalid sample table exception', () {
      final exception = MP4TrackException.invalidSampleTable(1, details: 'Sample count mismatch');

      expect(exception.message, equals('MP4 track error: Invalid or corrupted sample table for track 1'));
      expect(exception.details, equals('Sample count mismatch'));
      expect(exception.trackId, equals(1));
      expect(exception.operation, equals('sample_table_parsing'));
      expect(exception.isCorrupted, isTrue);
    });

    test('should create encrypted track exception', () {
      final exception = MP4TrackException.encryptedTrack(2, details: 'CENC encryption detected');

      expect(exception.message, equals('MP4 track error: Audio track 2 is encrypted or protected'));
      expect(exception.details, equals('CENC encryption detected'));
      expect(exception.trackId, equals(2));
      expect(exception.operation, equals('track_access'));
    });

    test('should create unsupported configuration exception', () {
      final exception = MP4TrackException.unsupportedConfiguration(1, 'Multi-channel surround', details: 'Only stereo supported');

      expect(exception.message, equals('MP4 track error: Unsupported track configuration for track 1: Multi-channel surround'));
      expect(exception.details, equals('Only stereo supported'));
      expect(exception.trackId, equals(1));
      expect(exception.operation, equals('track_validation'));
    });

    test('should provide user-friendly messages for different scenarios', () {
      final noTracksException = MP4TrackException.noAudioTracks();
      expect(noTracksException.userFriendlyMessage, contains('no audio'));
      expect(noTracksException.userFriendlyMessage, contains('video-only'));

      final corruptedException = MP4TrackException.corruptedTrack(1);
      expect(corruptedException.userFriendlyMessage, contains('corrupted'));

      final encryptedException = MP4TrackException.encryptedTrack(1);
      expect(encryptedException.userFriendlyMessage, contains('protected'));

      const genericException = MP4TrackException('Generic error');
      expect(genericException.userFriendlyMessage, contains('problem with the audio track'));
    });

    test('should inherit from DecodingException', () {
      const exception = MP4TrackException('Test error');
      expect(exception, isA<DecodingException>());
      expect(exception, isA<SonixException>());
    });

    test('should have correct string representation', () {
      const exception = MP4TrackException('Track error', details: 'Error details', trackId: 2, operation: 'parsing', audioTrackCount: 1, isCorrupted: true);

      final str = exception.toString();
      expect(str, contains('MP4TrackException'));
      expect(str, contains('MP4 track error: Track error'));
      expect(str, contains('Track ID: 2'));
      expect(str, contains('Operation: parsing'));
      expect(str, contains('Audio Tracks Found: 1'));
      expect(str, contains('Track Status: Corrupted'));
      expect(str, contains('Details: Error details'));
    });

    test('should have minimal string representation', () {
      const exception = MP4TrackException('Simple error');

      final str = exception.toString();
      expect(str, equals('MP4TrackException: MP4 track error: Simple error'));
    });
  });

  group('Exception inheritance and polymorphism', () {
    test('should be catchable as base exception types', () {
      const containerException = MP4ContainerException('Container error');
      const codecException = MP4CodecException('AAC');
      const trackException = MP4TrackException('Track error');

      // Should be catchable as SonixException
      expect(containerException, isA<SonixException>());
      expect(codecException, isA<SonixException>());
      expect(trackException, isA<SonixException>());

      // Should be catchable as more specific types
      expect(containerException, isA<DecodingException>());
      expect(codecException, isA<UnsupportedFormatException>());
      expect(trackException, isA<DecodingException>());
    });

    test('should work with exception handling patterns', () {
      final exceptions = <SonixException>[
        const MP4ContainerException('Container error'),
        const MP4CodecException('AAC'),
        const MP4TrackException('Track error'),
      ];

      for (final exception in exceptions) {
        expect(exception.message, isNotEmpty);
        expect(exception.toString(), contains(exception.runtimeType.toString()));
      }
    });
  });
}
