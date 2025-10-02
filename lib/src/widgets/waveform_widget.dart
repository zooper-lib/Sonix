import 'package:flutter/material.dart';
import '../models/waveform_data.dart';
import 'waveform_style.dart';
import 'waveform_painter.dart';

/// A Flutter widget for displaying interactive audio waveforms with playback visualization.
///
/// This widget renders waveform data as a visual representation and provides
/// interactive features like seeking, progress indication, and smooth animations.
/// It's designed to integrate seamlessly with audio players and provides a
/// professional-grade waveform visualization experience.
///
/// ## Key Features
///
/// - **Interactive Seeking**: Tap or drag to seek to specific positions
/// - **Playback Progress**: Visual indicator showing current playback position
/// - **Smooth Animations**: Customizable transitions for position changes
/// - **Flexible Styling**: Comprehensive appearance customization
/// - **Touch Support**: Full gesture support for mobile and desktop
/// - **Performance Optimized**: Efficient rendering for large waveforms
///
/// ## Basic Usage
///
/// ```dart
/// class AudioPlayerWidget extends StatefulWidget {
///   @override
///   _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
/// }
///
/// class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
///   WaveformData? waveformData;
///   double playbackPosition = 0.0;
///   AudioPlayer? audioPlayer;
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         if (waveformData != null)
///           WaveformWidget(
///             waveformData: waveformData!,
///             playbackPosition: playbackPosition,
///             onSeek: (position) {
///               final seekTime = waveformData!.duration * position;
///               audioPlayer?.seek(seekTime);
///             },
///           ),
///         // Audio controls here...
///       ],
///     );
///   }
/// }
/// ```
///
/// ## Advanced Styling
///
/// ```dart
/// WaveformWidget(
///   waveformData: waveformData,
///   playbackPosition: position,
///   style: WaveformStyle(
///     waveColor: Colors.blue.withOpacity(0.6),
///     progressColor: Colors.blue,
///     backgroundColor: Colors.grey[100],
///     borderRadius: BorderRadius.circular(8),
///     showBorder: true,
///   ),
///   animationDuration: Duration(milliseconds: 200),
///   onSeek: (position) => _handleSeek(position),
/// )
/// ```
///
/// ## Real-time Updates
///
/// ```dart
/// // Update playback position in real-time
/// Timer.periodic(Duration(milliseconds: 100), (timer) {
///   if (audioPlayer?.isPlaying == true) {
///     setState(() {
///       playbackPosition = audioPlayer!.position.inMilliseconds /
///                        audioPlayer!.duration!.inMilliseconds;
///     });
///   }
/// });
/// ```
///
/// ## Custom Interaction
///
/// ```dart
/// WaveformWidget(
///   waveformData: waveformData,
///   enableSeek: true,  // Allow touch seeking
///   onTap: () {
///     // Handle tap events
///     if (audioPlayer?.isPlaying == true) {
///       audioPlayer?.pause();
///     } else {
///       audioPlayer?.play();
///     }
///   },
///   onSeek: (position) {
///     // Handle seek events with validation
///     if (position >= 0.0 && position <= 1.0) {
///       final seekTime = waveformData.duration * position;
///       audioPlayer?.seek(seekTime);
///     }
///   },
/// )
/// ```
class WaveformWidget extends StatefulWidget {
  /// The waveform data to visualize.
  ///
  /// This should be a [WaveformData] instance generated using [Sonix.generateWaveform]
  /// or created from existing amplitude data. The widget will render all amplitude
  /// values in the data as a visual waveform.
  ///
  /// **Required:** Must not be null and should contain valid amplitude data.
  final WaveformData waveformData;

  /// Current playback position as a fraction from 0.0 to 1.0.
  ///
  /// - 0.0 = beginning of audio
  /// - 0.5 = middle of audio
  /// - 1.0 = end of audio
  /// - null = no position indicator shown
  ///
  /// The widget displays a vertical line or highlight at this position.
  /// Update this value as audio plays to show real-time progress.
  final double? playbackPosition;

  /// Visual styling configuration for the waveform.
  ///
  /// Controls colors, dimensions, borders, and other appearance aspects.
  /// Use [WaveformStyle] or predefined styles from [WaveformStylePresets].
  ///
  /// **Default:** Basic blue waveform with standard dimensions.
  final WaveformStyle style;

  /// Callback invoked when the user taps the waveform widget.
  ///
  /// Useful for implementing play/pause functionality or other general
  /// interactions. For position-based interactions, use [onSeek] instead.
  ///
  /// ## Example
  /// ```dart
  /// onTap: () {
  ///   if (audioPlayer.isPlaying) {
  ///     audioPlayer.pause();
  ///   } else {
  ///     audioPlayer.play();
  ///   }
  /// }
  /// ```
  final VoidCallback? onTap;

  /// Callback invoked when the user seeks to a specific position.
  ///
  /// The position parameter is a fraction from 0.0 to 1.0 representing
  /// the relative position in the audio. Convert this to actual time
  /// using the waveform's duration.
  ///
  /// **Parameters:**
  /// - position: Seek position from 0.0 (start) to 1.0 (end)
  ///
  /// ## Example
  /// ```dart
  /// onSeek: (position) {
  ///   final seekTime = waveformData.duration * position;
  ///   audioPlayer.seek(seekTime);
  ///   setState(() {
  ///     playbackPosition = position;
  ///   });
  /// }
  /// ```
  final Function(double)? onSeek;

  /// Duration for animating playback position changes.
  ///
  /// When [playbackPosition] changes, the position indicator will smoothly
  /// animate to the new location over this duration. Shorter durations
  /// provide more responsive feedback, longer durations create smoother motion.
  ///
  /// **Typical values:**
  /// - 50-100ms: Very responsive, minimal animation
  /// - 150-200ms: Balanced smooth motion (default)
  /// - 300-500ms: Slow, emphasizes position changes
  final Duration animationDuration;

  /// Animation curve for position transitions.
  ///
  /// Defines the easing function used when animating position changes.
  /// Common options include [Curves.easeInOut], [Curves.linear],
  /// [Curves.bounceOut], etc.
  final Curve animationCurve;

  /// Whether to enable touch interaction for seeking.
  ///
  /// When true, users can tap or drag on the waveform to seek to specific
  /// positions. When false, the widget is display-only and [onSeek] will
  /// never be called.
  ///
  /// **Use cases for disabling:**
  /// - Read-only waveform displays
  /// - During loading states
  /// - When seeking is handled elsewhere in the UI
  final bool enableSeek;

  const WaveformWidget({
    super.key,
    required this.waveformData,
    this.playbackPosition,
    this.style = const WaveformStyle(),
    this.onTap,
    this.onSeek,
    this.animationDuration = const Duration(milliseconds: 150),
    this.animationCurve = Curves.easeInOut,
    this.enableSeek = true,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  double? _previousPosition;
  bool _isDragging = false;
  double? _dragPosition;
  bool _shouldAnimate = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: widget.animationDuration, vsync: this);

    // Initialize with current position if available, otherwise start at 0
    final initialPosition = widget.playbackPosition ?? 0.0;
    _positionAnimation = Tween<double>(
      begin: initialPosition,
      end: initialPosition,
    ).animate(CurvedAnimation(parent: _animationController, curve: widget.animationCurve));
    _previousPosition = initialPosition;
    _animationController.value = 1.0; // Start in completed state
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle playback position changes with smooth transitions
    if (widget.playbackPosition != oldWidget.playbackPosition) {
      _handlePositionChange();
    }

    // Update animation duration if changed
    if (widget.animationDuration != oldWidget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }
  }

  void _handlePositionChange() {
    if (widget.playbackPosition != _previousPosition && !_isDragging) {
      final currentPosition = _previousPosition ?? 0.0;
      final newPosition = widget.playbackPosition ?? 0.0;

      // Only animate if we should animate and the change is significant
      if (_shouldAnimate && (newPosition - currentPosition).abs() > 0.001) {
        // Create new animation from current position to new position
        _positionAnimation = Tween<double>(
          begin: currentPosition,
          end: newPosition,
        ).animate(CurvedAnimation(parent: _animationController, curve: widget.animationCurve));

        _animationController.reset();
        _animationController.forward();
      } else {
        // No animation needed, just update directly
        _positionAnimation = Tween<double>(
          begin: newPosition,
          end: newPosition,
        ).animate(CurvedAnimation(parent: _animationController, curve: widget.animationCurve));
        _animationController.value = 1.0;
      }

      _previousPosition = widget.playbackPosition;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.enableSeek) return;

    setState(() {
      _isDragging = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    if (!widget.enableSeek) return;

    final position = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
    setState(() {
      _dragPosition = position;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enableSeek) return;

    if (_dragPosition != null && widget.onSeek != null) {
      // Disable animation for the next position change since it's from drag
      _shouldAnimate = false;
      widget.onSeek!(_dragPosition!);
      // Re-enable animation after a brief delay
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _shouldAnimate = true;
        }
      });
    }

    setState(() {
      _isDragging = false;
      _dragPosition = null;
    });
  }

  void _handleTap(TapUpDetails details, Size size) {
    if (widget.onTap != null) {
      widget.onTap!();
    }

    if (widget.enableSeek && widget.onSeek != null) {
      final position = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
      // Disable animation for tap-to-seek to make it immediate
      _shouldAnimate = false;
      widget.onSeek!(position);
      // Re-enable animation after a brief delay
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _shouldAnimate = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - widget.style.margin.horizontal;
        final availableHeight = widget.style.height;
        final size = Size(availableWidth, availableHeight);

        Widget waveformChild = GestureDetector(
          onTapUp: (details) => _handleTap(details, size),
          onPanStart: _handlePanStart,
          onPanUpdate: (details) => _handlePanUpdate(details, size),
          onPanEnd: _handlePanEnd,
          child: AnimatedBuilder(
            animation: _positionAnimation,
            builder: (context, child) {
              // Use drag position if dragging, otherwise use animated position
              final currentPosition = _isDragging ? _dragPosition : _positionAnimation.value;

              return CustomPaint(
                size: size,
                painter: WaveformPainter(
                  waveformData: widget.waveformData,
                  style: widget.style,
                  playbackPosition: currentPosition,
                  animationValue: 1.0, // Always 1.0 since we're animating the position directly
                ),
              );
            },
          ),
        );

        // Apply decorations (border, shadow, etc.)
        if (widget.style.border != null || widget.style.boxShadow != null) {
          waveformChild = Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(border: widget.style.border, boxShadow: widget.style.boxShadow, borderRadius: widget.style.borderRadius),
            child: waveformChild,
          );
        }

        // Apply margin
        if (widget.style.margin != EdgeInsets.zero) {
          waveformChild = Padding(padding: widget.style.margin, child: waveformChild);
        }

        return SizedBox(width: constraints.maxWidth, height: widget.style.height + widget.style.margin.vertical, child: waveformChild);
      },
    );
  }
}
