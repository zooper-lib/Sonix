import 'package:flutter/material.dart';
import '../models/waveform_data.dart';
import 'waveform_style.dart';
import 'waveform_painter.dart';

/// A widget that displays audio waveform with playback position visualization
class WaveformWidget extends StatefulWidget {
  /// Waveform data to display
  final WaveformData waveformData;

  /// Current playback position (0.0 to 1.0)
  final double? playbackPosition;

  /// Style configuration for the waveform
  final WaveformStyle style;

  /// Callback when the waveform is tapped
  final VoidCallback? onTap;

  /// Callback when user seeks to a position (0.0 to 1.0)
  final Function(double)? onSeek;

  /// Duration for smooth position transitions
  final Duration animationDuration;

  /// Animation curve for position transitions
  final Curve animationCurve;

  /// Whether to enable touch interaction for seeking
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

/// A simplified waveform widget for static display without playback features
class StaticWaveformWidget extends StatelessWidget {
  /// Waveform data to display
  final WaveformData waveformData;

  /// Style configuration for the waveform
  final WaveformStyle style;

  /// Callback when the waveform is tapped
  final VoidCallback? onTap;

  const StaticWaveformWidget({super.key, required this.waveformData, this.style = const WaveformStyle(), this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - style.margin.horizontal;
        final availableHeight = style.height;
        final size = Size(availableWidth, availableHeight);

        Widget waveformChild = GestureDetector(
          onTap: onTap,
          child: CustomPaint(
            size: size,
            painter: WaveformPainter(waveformData: waveformData, style: style, playbackPosition: null, animationValue: 1.0),
          ),
        );

        // Apply decorations (border, shadow, etc.)
        if (style.border != null || style.boxShadow != null) {
          waveformChild = Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(border: style.border, boxShadow: style.boxShadow, borderRadius: style.borderRadius),
            child: waveformChild,
          );
        }

        // Apply margin
        if (style.margin != EdgeInsets.zero) {
          waveformChild = Padding(padding: style.margin, child: waveformChild);
        }

        return SizedBox(width: constraints.maxWidth, height: style.height + style.margin.vertical, child: waveformChild);
      },
    );
  }
}
