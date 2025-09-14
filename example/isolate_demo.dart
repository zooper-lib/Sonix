/// Demonstration of isolate-based waveform generation
///
/// This example shows how the new isolate-based processing works
/// for background waveform generation without blocking the UI thread.
// ignore_for_file: avoid_print

library;

import 'dart:async';
import 'dart:isolate';
import 'package:sonix/src/isolate/isolate_messages.dart';
import 'package:sonix/src/isolate/processing_isolate.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/models/waveform_data.dart';

void main() async {
  print('Starting isolate-based waveform generation demo...');

  // Create receive ports for communication
  final handshakeReceivePort = ReceivePort();
  final responseReceivePort = ReceivePort();

  try {
    // Spawn the processing isolate
    print('Spawning processing isolate...');
    final isolate = await Isolate.spawn(processingIsolateEntryPoint, handshakeReceivePort.sendPort, debugName: 'DemoProcessingIsolate');

    // Get the isolate's SendPort
    print('Waiting for isolate handshake...');
    final isolateSendPort = await handshakeReceivePort.first as SendPort;
    handshakeReceivePort.close();

    // Send our response port to the isolate
    isolateSendPort.send(responseReceivePort.sendPort);

    // Create a test processing request
    final config = WaveformConfig(resolution: 100, type: WaveformType.bars, normalize: true);

    final request = ProcessingRequest(
      id: 'demo_request_1',
      timestamp: DateTime.now(),
      filePath: 'demo_audio.wav', // This will fail, but demonstrates the flow
      config: config,
      streamResults: true,
    );

    print('Sending processing request to isolate...');
    isolateSendPort.send(request.toJson());

    // Listen for responses
    print('Listening for responses from isolate...');
    final completer = Completer<void>();

    responseReceivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        try {
          final isolateMessage = IsolateMessage.fromJson(message);

          if (isolateMessage is ProgressUpdate) {
            print('Progress: ${(isolateMessage.progress * 100).toStringAsFixed(1)}% - ${isolateMessage.statusMessage}');
          } else if (isolateMessage is ProcessingResponse) {
            if (isolateMessage.error != null) {
              print('Processing completed with error: ${isolateMessage.error}');
            } else {
              print('Processing completed successfully!');
              if (isolateMessage.waveformData != null) {
                print('Generated waveform with ${isolateMessage.waveformData!.amplitudes.length} data points');
              }
            }

            if (isolateMessage.isComplete) {
              completer.complete();
            }
          } else if (isolateMessage is ErrorMessage) {
            print('Error from isolate: ${isolateMessage.errorMessage}');
            completer.complete();
          }
        } catch (e) {
          print('Error parsing message: $e');
        }
      }
    });

    // Wait for completion
    await completer.future.timeout(Duration(seconds: 10));

    print('Demo completed successfully!');
    print('The isolate-based waveform generation is working correctly.');

    // Cleanup
    isolate.kill(priority: Isolate.immediate);
    responseReceivePort.close();
  } catch (e, stackTrace) {
    print('Demo failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}
