import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/mp4_models.dart';

void main() {
  group('MP4SampleInfo', () {
    test('should create MP4SampleInfo with all properties', () {
      const sampleInfo = MP4SampleInfo(offset: 1024, size: 768, timestamp: Duration(milliseconds: 23), isKeyframe: true);

      expect(sampleInfo.offset, equals(1024));
      expect(sampleInfo.size, equals(768));
      expect(sampleInfo.timestamp, equals(const Duration(milliseconds: 23)));
      expect(sampleInfo.isKeyframe, isTrue);
    });

    test('should calculate end offset correctly', () {
      const sampleInfo = MP4SampleInfo(offset: 1000, size: 500, timestamp: Duration(milliseconds: 10), isKeyframe: false);

      expect(sampleInfo.endOffset, equals(1500));
    });

    test('should check if timestamp is contained correctly', () {
      const sampleInfo = MP4SampleInfo(offset: 1000, size: 500, timestamp: Duration(milliseconds: 100), isKeyframe: true);

      const nextSampleTimestamp = Duration(milliseconds: 200);

      // Timestamp at start of sample
      expect(sampleInfo.containsTimestamp(const Duration(milliseconds: 100), nextSampleTimestamp), isTrue);

      // Timestamp in middle of sample
      expect(sampleInfo.containsTimestamp(const Duration(milliseconds: 150), nextSampleTimestamp), isTrue);

      // Timestamp at end of sample (should be false - exclusive end)
      expect(sampleInfo.containsTimestamp(const Duration(milliseconds: 200), nextSampleTimestamp), isFalse);

      // Timestamp before sample
      expect(sampleInfo.containsTimestamp(const Duration(milliseconds: 50), nextSampleTimestamp), isFalse);

      // Timestamp after sample
      expect(sampleInfo.containsTimestamp(const Duration(milliseconds: 250), nextSampleTimestamp), isFalse);
    });

    test('should calculate duration until next sample', () {
      const sampleInfo1 = MP4SampleInfo(offset: 1000, size: 500, timestamp: Duration(milliseconds: 100), isKeyframe: true);

      const sampleInfo2 = MP4SampleInfo(offset: 1500, size: 600, timestamp: Duration(milliseconds: 150), isKeyframe: false);

      final duration = sampleInfo1.durationUntil(sampleInfo2);
      expect(duration, equals(const Duration(milliseconds: 50)));
    });

    test('should create from map correctly', () {
      final map = {
        'offset': 2048,
        'size': 1024,
        'timestampMicros': 50000, // 50ms in microseconds
        'isKeyframe': true,
      };

      final sampleInfo = MP4SampleInfo.fromMap(map);

      expect(sampleInfo.offset, equals(2048));
      expect(sampleInfo.size, equals(1024));
      expect(sampleInfo.timestamp, equals(const Duration(milliseconds: 50)));
      expect(sampleInfo.isKeyframe, isTrue);
    });

    test('should create from map with missing values', () {
      final map = <String, dynamic>{};

      final sampleInfo = MP4SampleInfo.fromMap(map);

      expect(sampleInfo.offset, equals(0));
      expect(sampleInfo.size, equals(0));
      expect(sampleInfo.timestamp, equals(Duration.zero));
      expect(sampleInfo.isKeyframe, isFalse);
    });

    test('should convert to map correctly', () {
      const sampleInfo = MP4SampleInfo(offset: 3072, size: 512, timestamp: Duration(milliseconds: 75), isKeyframe: false);

      final map = sampleInfo.toMap();

      expect(map['offset'], equals(3072));
      expect(map['size'], equals(512));
      expect(map['timestampMicros'], equals(75000)); // 75ms in microseconds
      expect(map['isKeyframe'], isFalse);
    });

    test('should have correct string representation', () {
      const sampleInfo = MP4SampleInfo(offset: 1024, size: 768, timestamp: Duration(milliseconds: 23), isKeyframe: true);

      final str = sampleInfo.toString();
      expect(str, contains('MP4SampleInfo'));
      expect(str, contains('offset: 1024'));
      expect(str, contains('size: 768'));
      expect(str, contains('timestamp: 23ms'));
      expect(str, contains('keyframe: true'));
    });

    test('should implement equality correctly', () {
      const sampleInfo1 = MP4SampleInfo(offset: 1024, size: 768, timestamp: Duration(milliseconds: 23), isKeyframe: true);

      const sampleInfo2 = MP4SampleInfo(offset: 1024, size: 768, timestamp: Duration(milliseconds: 23), isKeyframe: true);

      const sampleInfo3 = MP4SampleInfo(offset: 2048, size: 768, timestamp: Duration(milliseconds: 23), isKeyframe: true);

      expect(sampleInfo1, equals(sampleInfo2));
      expect(sampleInfo1, isNot(equals(sampleInfo3)));
      expect(sampleInfo1.hashCode, equals(sampleInfo2.hashCode));
    });
  });

  group('MP4ContainerInfo', () {
    late List<MP4SampleInfo> sampleTable;

    setUp(() {
      sampleTable = [
        const MP4SampleInfo(offset: 1024, size: 768, timestamp: Duration(milliseconds: 0), isKeyframe: true),
        const MP4SampleInfo(offset: 1792, size: 800, timestamp: Duration(milliseconds: 23), isKeyframe: true),
        const MP4SampleInfo(offset: 2592, size: 750, timestamp: Duration(milliseconds: 46), isKeyframe: false),
      ];
    });

    test('should create MP4ContainerInfo with all properties', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(minutes: 3, seconds: 45),
        bitrate: 128000,
        maxBitrate: 160000,
        codecName: 'AAC-LC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      expect(containerInfo.duration, equals(const Duration(minutes: 3, seconds: 45)));
      expect(containerInfo.bitrate, equals(128000));
      expect(containerInfo.maxBitrate, equals(160000));
      expect(containerInfo.codecName, equals('AAC-LC'));
      expect(containerInfo.audioTrackId, equals(1));
      expect(containerInfo.sampleTable, equals(sampleTable));
    });

    test('should calculate total samples correctly', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 128000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      expect(containerInfo.totalSamples, equals(3));
    });

    test('should calculate estimated sample rate', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(milliseconds: 46), // Duration to last sample
        bitrate: 128000,
        maxBitrate: 128000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      // 3 samples over 46ms = ~65.2 samples per second
      final estimatedRate = containerInfo.estimatedSampleRate;
      expect(estimatedRate, closeTo(65.2, 0.1));
    });

    test('should handle zero duration for sample rate calculation', () {
      final containerInfo = MP4ContainerInfo(
        duration: Duration.zero,
        bitrate: 128000,
        maxBitrate: 128000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      expect(containerInfo.estimatedSampleRate, equals(0.0));
    });

    test('should handle empty sample table for sample rate calculation', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 128000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: [],
      );

      expect(containerInfo.estimatedSampleRate, equals(0.0));
    });

    test('should detect variable bitrate correctly', () {
      final vbrContainer = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 192000, // Higher than average
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      final cbrContainer = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 128000, // Same as average
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      expect(vbrContainer.isVariableBitrate, isTrue);
      expect(cbrContainer.isVariableBitrate, isFalse);
    });

    test('should calculate bitrate ratio correctly', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 192000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      expect(containerInfo.bitrateRatio, equals(1.5)); // 192000 / 128000
    });

    test('should handle zero bitrate for ratio calculation', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 0,
        maxBitrate: 192000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      expect(containerInfo.bitrateRatio, equals(1.0));
    });

    test('should create from native metadata correctly', () {
      final metadata = {
        'durationMicros': 225000000, // 3 minutes 45 seconds in microseconds
        'bitrate': 128000,
        'maxBitrate': 160000,
        'codecName': 'AAC-LC',
        'audioTrackId': 2,
        'sampleTable': [
          {'offset': 1024, 'size': 768, 'timestampMicros': 0, 'isKeyframe': true},
          {'offset': 1792, 'size': 800, 'timestampMicros': 23000, 'isKeyframe': true},
        ],
      };

      final containerInfo = MP4ContainerInfo.fromNativeMetadata(metadata);

      expect(containerInfo.duration, equals(const Duration(minutes: 3, seconds: 45)));
      expect(containerInfo.bitrate, equals(128000));
      expect(containerInfo.maxBitrate, equals(160000));
      expect(containerInfo.codecName, equals('AAC-LC'));
      expect(containerInfo.audioTrackId, equals(2));
      expect(containerInfo.sampleTable.length, equals(2));
      expect(containerInfo.sampleTable[0].offset, equals(1024));
      expect(containerInfo.sampleTable[1].timestamp, equals(const Duration(milliseconds: 23)));
    });

    test('should create from native metadata with missing values', () {
      final metadata = <String, dynamic>{};

      final containerInfo = MP4ContainerInfo.fromNativeMetadata(metadata);

      expect(containerInfo.duration, equals(Duration.zero));
      expect(containerInfo.bitrate, equals(0));
      expect(containerInfo.maxBitrate, equals(0));
      expect(containerInfo.codecName, equals('Unknown'));
      expect(containerInfo.audioTrackId, equals(1));
      expect(containerInfo.sampleTable, isEmpty);
    });

    test('should convert to map correctly', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(minutes: 2, seconds: 30),
        bitrate: 96000,
        maxBitrate: 128000,
        codecName: 'AAC-HE',
        audioTrackId: 3,
        sampleTable: sampleTable,
      );

      final map = containerInfo.toMap();

      expect(map['durationMicros'], equals(150000000)); // 2:30 in microseconds
      expect(map['bitrate'], equals(96000));
      expect(map['maxBitrate'], equals(128000));
      expect(map['codecName'], equals('AAC-HE'));
      expect(map['audioTrackId'], equals(3));
      expect(map['sampleTable'], isA<List>());
      expect((map['sampleTable'] as List).length, equals(3));
    });

    test('should have correct string representation', () {
      final containerInfo = MP4ContainerInfo(
        duration: const Duration(minutes: 3, seconds: 45),
        bitrate: 128000,
        maxBitrate: 160000,
        codecName: 'AAC-LC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      final str = containerInfo.toString();
      expect(str, contains('MP4ContainerInfo'));
      expect(str, contains('duration: 0:03:45.000000'));
      expect(str, contains('bitrate: 128kbps'));
      expect(str, contains('maxBitrate: 160kbps'));
      expect(str, contains('codec: AAC-LC'));
      expect(str, contains('trackId: 1'));
      expect(str, contains('samples: 3'));
    });

    test('should implement equality correctly', () {
      final containerInfo1 = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 160000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      final containerInfo2 = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 160000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      final containerInfo3 = MP4ContainerInfo(
        duration: const Duration(seconds: 20), // Different duration
        bitrate: 128000,
        maxBitrate: 160000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      expect(containerInfo1, equals(containerInfo2));
      expect(containerInfo1, isNot(equals(containerInfo3)));
      expect(containerInfo1.hashCode, equals(containerInfo2.hashCode));
    });

    test('should handle different sample tables in equality', () {
      final differentSampleTable = [const MP4SampleInfo(offset: 2048, size: 1024, timestamp: Duration(milliseconds: 0), isKeyframe: true)];

      final containerInfo1 = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 160000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: sampleTable,
      );

      final containerInfo2 = MP4ContainerInfo(
        duration: const Duration(seconds: 10),
        bitrate: 128000,
        maxBitrate: 160000,
        codecName: 'AAC',
        audioTrackId: 1,
        sampleTable: differentSampleTable,
      );

      expect(containerInfo1, isNot(equals(containerInfo2)));
    });
  });
}
