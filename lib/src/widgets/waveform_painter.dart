import 'package:flutter/material.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/display_sampler.dart';
import 'waveform_style.dart';

/// Custom painter for efficient waveform rendering
class WaveformPainter extends CustomPainter {
  /// Waveform data to render
  final WaveformData waveformData;

  /// Style configuration
  final WaveformStyle style;

  /// Current playback position (0.0 to 1.0)
  final double? playbackPosition;

  /// Animation value for smooth transitions
  final double animationValue;

  const WaveformPainter({required this.waveformData, required this.style, this.playbackPosition, this.animationValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final sourceAmplitudes = waveformData.amplitudes;
    if (sourceAmplitudes.isEmpty) return;

    // Apply anti-aliasing
    if (style.antiAlias) {
      canvas.clipRect(Offset.zero & size, doAntiAlias: true);
    }

    // Apply opacity
    if (style.opacity < 1.0) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: style.opacity));
    }

    // Calculate content area (accounting for padding)
    final contentRect = Rect.fromLTWH(style.padding.left, style.padding.top, size.width - style.padding.horizontal, size.height - style.padding.vertical);

    // Draw background
    if (style.backgroundColor != Colors.transparent) {
      final backgroundPaint = Paint()..color = style.backgroundColor;
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    }

    // Calculate display resolution based on style and available width
    final displayResolution = style.autoDisplayResolution 
      ? (style.fixedDisplayResolution ?? DisplaySampler.calculateDisplayResolution(
          availableWidth: contentRect.width,
          barWidth: style.barWidth,
          barSpacing: style.barSpacing,
          displayDensity: style.displayDensity,
          waveformType: style.type,
        ))
      : (style.fixedDisplayResolution ?? sourceAmplitudes.length);

    // Resample amplitudes to match display resolution
    final displayAmplitudes = DisplaySampler.resampleForDisplay(
      sourceAmplitudes: sourceAmplitudes,
      targetCount: displayResolution,
      downsampleMethod: style.downsampleMethod,
      upsampleMethod: style.upsampleMethod,
    );

    // Calculate dimensions
    final centerY = contentRect.center.dy;
    final playedWidth = playbackPosition != null ? contentRect.width * playbackPosition! * animationValue : 0.0;

    // Draw center line if enabled
    if (style.showCenterLine) {
      final centerLinePaint = Paint()
        ..color = style.centerLineColor
        ..strokeWidth = style.centerLineWidth;
      canvas.drawLine(Offset(contentRect.left, centerY), Offset(contentRect.right, centerY), centerLinePaint);
    }

    // Render based on waveform type using display-sampled amplitudes
    switch (style.type) {
      case WaveformType.bars:
        _paintBars(canvas, contentRect, displayAmplitudes, centerY, playedWidth);
        break;
      case WaveformType.line:
        _paintLine(canvas, contentRect, displayAmplitudes, centerY, playedWidth);
        break;
      case WaveformType.filled:
        _paintFilled(canvas, contentRect, displayAmplitudes, centerY, playedWidth);
        break;
    }

    // Apply gradient overlay if specified
    if (style.gradient != null) {
      final gradientPaint = Paint()
        ..shader = style.gradient!.createShader(contentRect)
        ..blendMode = style.gradientBlendMode;
      canvas.drawRect(contentRect, gradientPaint);
    }

    // Restore opacity layer
    if (style.opacity < 1.0) {
      canvas.restore();
    }
  }

  /// Paint waveform as bars
  void _paintBars(Canvas canvas, Rect contentRect, List<double> amplitudes, double centerY, double playedWidth) {
    final barCount = amplitudes.length;
    if (barCount == 0) return;

    // Use exact user-specified bar width and spacing
    // The display sampling already calculated the optimal number of bars
    final barUnit = style.barWidth + style.barSpacing;
    
    for (int i = 0; i < barCount; i++) {
      final x = contentRect.left + i * barUnit;
      final amplitude = (amplitudes[i] * style.amplitudeScale).clamp(0.0, 1.0);

      // Apply min/max height constraints
      var barHeight = amplitude * (contentRect.height / 2);
      barHeight = barHeight.clamp(style.minBarHeight, style.maxBarHeight ?? double.infinity);

      // Determine color/gradient based on playback position
      final isPlayed = (x - contentRect.left) < playedWidth;

      Paint paint;
      if (isPlayed && style.playedGradient != null) {
        paint = Paint()
          ..shader = style.playedGradient!.createShader(contentRect)
          ..style = PaintingStyle.fill;
      } else if (!isPlayed && style.unplayedGradient != null) {
        paint = Paint()
          ..shader = style.unplayedGradient!.createShader(contentRect)
          ..style = PaintingStyle.fill;
      } else {
        final color = isPlayed ? style.playedColor : style.unplayedColor;
        paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
      }

      // Draw bar (centered around centerY) using exact user-specified width
      final rect = Rect.fromLTWH(x, centerY - barHeight / 2, style.barWidth, barHeight);

      if (style.borderRadius != null) {
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: style.borderRadius!.topLeft,
          topRight: style.borderRadius!.topRight,
          bottomLeft: style.borderRadius!.bottomLeft,
          bottomRight: style.borderRadius!.bottomRight,
        );
        canvas.drawRRect(rrect, paint);
      } else {
        canvas.drawRect(rect, paint);
      }
    }
  }

  /// Paint waveform as a continuous line
  void _paintLine(Canvas canvas, Rect contentRect, List<double> amplitudes, double centerY, double playedWidth) {
    if (amplitudes.length < 2) return;

    final path = Path();
    final playedPath = Path();

    // Calculate points
    final points = <Offset>[];
    for (int i = 0; i < amplitudes.length; i++) {
      final x = contentRect.left + (i / (amplitudes.length - 1)) * contentRect.width;
      final amplitude = (amplitudes[i] * style.amplitudeScale).clamp(0.0, 1.0);
      final y = centerY - (amplitude * (contentRect.height / 2));
      points.add(Offset(x, y));
    }

    // Create main path
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Create played portion path
    if (playedWidth > 0) {
      playedPath.moveTo(points[0].dx, points[0].dy);
      final playedEndX = contentRect.left + playedWidth;

      for (int i = 1; i < points.length; i++) {
        if (points[i].dx <= playedEndX) {
          playedPath.lineTo(points[i].dx, points[i].dy);
        } else {
          // Interpolate the exact position at playedWidth
          final prevPoint = points[i - 1];
          final currentPoint = points[i];
          final t = (playedEndX - prevPoint.dx) / (currentPoint.dx - prevPoint.dx);
          final interpolatedY = prevPoint.dy + (currentPoint.dy - prevPoint.dy) * t;
          playedPath.lineTo(playedEndX, interpolatedY);
          break;
        }
      }
    }

    // Draw unplayed portion
    Paint unplayedPaint;
    if (style.unplayedGradient != null) {
      unplayedPaint = Paint()
        ..shader = style.unplayedGradient!.createShader(contentRect)
        ..strokeWidth = style.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
    } else {
      unplayedPaint = Paint()
        ..color = style.unplayedColor
        ..strokeWidth = style.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
    }
    canvas.drawPath(path, unplayedPaint);

    // Draw played portion
    if (playedWidth > 0) {
      Paint playedPaint;
      if (style.playedGradient != null) {
        playedPaint = Paint()
          ..shader = style.playedGradient!.createShader(contentRect)
          ..strokeWidth = style.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
      } else {
        playedPaint = Paint()
          ..color = style.playedColor
          ..strokeWidth = style.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
      }
      canvas.drawPath(playedPath, playedPaint);
    }
  }

  /// Paint waveform as filled area
  void _paintFilled(Canvas canvas, Rect contentRect, List<double> amplitudes, double centerY, double playedWidth) {
    if (amplitudes.isEmpty) return;

    final unplayedPath = Path();
    final playedPath = Path();

    // Start from bottom left
    unplayedPath.moveTo(contentRect.left, contentRect.bottom);
    playedPath.moveTo(contentRect.left, contentRect.bottom);

    // Create waveform outline
    for (int i = 0; i < amplitudes.length; i++) {
      final x = contentRect.left + (i / (amplitudes.length - 1)) * contentRect.width;
      final amplitude = (amplitudes[i] * style.amplitudeScale).clamp(0.0, 1.0);
      final y = centerY - (amplitude * (contentRect.height / 2));

      unplayedPath.lineTo(x, y);
      if ((x - contentRect.left) <= playedWidth) {
        playedPath.lineTo(x, y);
      }
    }

    // Close paths
    unplayedPath.lineTo(contentRect.right, contentRect.bottom);
    unplayedPath.close();

    if (playedWidth > 0) {
      playedPath.lineTo(contentRect.left + playedWidth, contentRect.bottom);
      playedPath.close();
    }

    // Draw unplayed area
    Paint unplayedPaint;
    if (style.unplayedGradient != null) {
      unplayedPaint = Paint()
        ..shader = style.unplayedGradient!.createShader(contentRect)
        ..style = PaintingStyle.fill;
    } else {
      unplayedPaint = Paint()
        ..color = style.unplayedColor
        ..style = PaintingStyle.fill;
    }
    canvas.drawPath(unplayedPath, unplayedPaint);

    // Draw played area
    if (playedWidth > 0) {
      Paint playedPaint;
      if (style.playedGradient != null) {
        playedPaint = Paint()
          ..shader = style.playedGradient!.createShader(contentRect)
          ..style = PaintingStyle.fill;
      } else {
        playedPaint = Paint()
          ..color = style.playedColor
          ..style = PaintingStyle.fill;
      }
      canvas.drawPath(playedPath, playedPaint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.style != style ||
        oldDelegate.playbackPosition != playbackPosition ||
        oldDelegate.animationValue != animationValue;
  }
}
