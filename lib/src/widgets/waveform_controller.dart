import 'package:flutter/foundation.dart';
import 'package:sonix/sonix.dart';

/// Controller for programmatically controlling a [WaveformWidget].
///
/// This controller allows you to programmatically seek to positions in the waveform,
/// get the current playback position, and listen to position changes.
///
/// ## Basic Usage
///
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final WaveformController _waveformController = WaveformController();
///
///   @override
///   void dispose() {
///     _waveformController.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         WaveformWidget(
///           waveformData: waveformData,
///           controller: _waveformController,
///           onSeek: (position) {
///             // Handle seeking
///             audioPlayer.seek(waveformData.duration * position);
///           },
///         ),
///         ElevatedButton(
///           onPressed: () {
///             // Programmatically seek to middle
///             _waveformController.seekTo(0.5);
///           },
///           child: Text('Jump to Middle'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///
/// ## Listening to Changes
///
/// ```dart
/// _waveformController.addListener(() {
///   print('Position changed to: ${_waveformController.position}');
/// });
/// ```
///
/// ## Initial Position
///
/// ```dart
/// final controller = WaveformController(initialPosition: 0.25);
/// ```
class WaveformController extends ChangeNotifier {
  double _position;
  bool _shouldAnimate;

  /// Creates a [WaveformController] with an optional initial position.
  ///
  /// [initialPosition] must be between 0.0 and 1.0 (defaults to 0.0).
  /// [shouldAnimate] controls whether seeks should be animated (defaults to true).
  WaveformController({double initialPosition = 0.0, bool shouldAnimate = true}) : _position = initialPosition.clamp(0.0, 1.0), _shouldAnimate = shouldAnimate;

  /// The current playback position as a fraction from 0.0 to 1.0.
  ///
  /// - 0.0 = beginning of audio
  /// - 0.5 = middle of audio
  /// - 1.0 = end of audio
  double get position => _position;

  /// Whether position changes should be animated.
  ///
  /// When true, calling [seekTo] will smoothly animate to the new position.
  /// When false, position changes are instant.
  bool get shouldAnimate => _shouldAnimate;

  /// Seeks to a specific position in the waveform.
  ///
  /// [position] must be between 0.0 (start) and 1.0 (end).
  /// Values outside this range will be clamped.
  ///
  /// If [animate] is provided, it overrides the controller's [shouldAnimate] setting
  /// for this specific seek operation.
  ///
  /// ## Example
  /// ```dart
  /// // Seek to the middle
  /// controller.seekTo(0.5);
  ///
  /// // Seek to the start without animation
  /// controller.seekTo(0.0, animate: false);
  ///
  /// // Seek to 75% with animation
  /// controller.seekTo(0.75, animate: true);
  /// ```
  void seekTo(double position, {bool? animate}) {
    final clampedPosition = position.clamp(0.0, 1.0);
    if (_position != clampedPosition) {
      _position = clampedPosition;
      if (animate != null) {
        _shouldAnimate = animate;
      }
      notifyListeners();
    }
  }

  /// Updates the position without triggering a seek event.
  ///
  /// This is useful for updating the position based on audio playback progress
  /// without triggering the [onSeek] callback in the widget.
  ///
  /// [position] must be between 0.0 and 1.0. Values outside this range will be clamped.
  ///
  /// ## Example
  /// ```dart
  /// // Update position as audio plays
  /// audioPlayer.onPositionChanged.listen((duration) {
  ///   final position = duration.inMilliseconds / audioPlayer.duration!.inMilliseconds;
  ///   controller.updatePosition(position);
  /// });
  /// ```
  void updatePosition(double position) {
    final clampedPosition = position.clamp(0.0, 1.0);
    if (_position != clampedPosition) {
      _position = clampedPosition;
      notifyListeners();
    }
  }

  /// Resets the position to the beginning (0.0).
  void reset() {
    seekTo(0.0);
  }

  /// Sets whether position changes should be animated.
  ///
  /// This affects future calls to [seekTo] (unless they override with their own [animate] parameter).
  void setAnimationEnabled(bool enabled) {
    if (_shouldAnimate != enabled) {
      _shouldAnimate = enabled;
    }
  }
}
