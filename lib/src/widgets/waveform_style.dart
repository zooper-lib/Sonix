import 'package:flutter/material.dart';
import 'package:sonix/src/models/waveform_type.dart';
import 'package:sonix/src/processing/downsample_method.dart';
import 'package:sonix/src/processing/upsample_method.dart';

/// Comprehensive styling configuration for waveform visualization widgets.
///
/// This class provides extensive customization options for visual appearance,
/// performance optimization, and interactive behavior of waveform displays.
/// It supports multiple visualization types, color schemes, gradients, and
/// advanced rendering options.
///
/// ## Key Features
///
/// - **Multiple Visual Types**: Bars, lines, and filled area rendering
/// - **Flexible Coloring**: Solid colors, gradients, and blend modes
/// - **Performance Controls**: Automatic resolution scaling and sampling methods
/// - **Layout Options**: Padding, margins, borders, and shadows
/// - **Interactive Elements**: Progress indication and center line markers
///
/// ## Basic Usage
///
/// ```dart
/// // Simple blue waveform
/// WaveformWidget(
///   waveformData: data,
///   style: WaveformStyle(
///     playedColor: Colors.blue,
///     unplayedColor: Colors.grey[300]!,
///     height: 80,
///   ),
/// )
/// ```
///
/// ## Advanced Styling
///
/// ```dart
/// // Gradient waveform with custom appearance
/// WaveformWidget(
///   waveformData: data,
///   style: WaveformStyle(
///     type: WaveformType.filled,
///     playedGradient: LinearGradient(
///       colors: [Colors.purple, Colors.blue],
///       begin: Alignment.topCenter,
///       end: Alignment.bottomCenter,
///     ),
///     unplayedGradient: LinearGradient(
///       colors: [Colors.grey[300]!, Colors.grey[100]!],
///       begin: Alignment.topCenter,
///       end: Alignment.bottomCenter,
///     ),
///     height: 120,
///     borderRadius: BorderRadius.circular(12),
///     padding: EdgeInsets.all(8),
///     showCenterLine: true,
///     centerLineColor: Colors.white.withOpacity(0.5),
///   ),
/// )
/// ```
///
/// ## Performance Optimization
///
/// ```dart
/// // Optimized for large waveforms
/// WaveformStyle(
///   autoDisplayResolution: true,    // Scale to widget size
///   downsampleMethod: DownsampleMethod.rms,  // Quality downsampling
///   antiAlias: true,                 // Smooth rendering
///   amplitudeScale: 0.9,            // Prevent clipping
/// )
/// ```
///
/// ## Preset Styles
///
/// For common use cases, consider using [WaveformStylePresets]:
/// ```dart
/// WaveformWidget(
///   waveformData: data,
///   style: WaveformStylePresets.soundcloud(),
/// )
/// ```
class WaveformStyle {
  /// Color for the played portion of the waveform
  final Color playedColor;

  /// Color for the unplayed portion of the waveform
  final Color unplayedColor;

  /// Background color of the waveform widget
  final Color backgroundColor;

  /// Height of the waveform widget
  final double height;

  /// Width of individual bars (for bar type waveforms)
  final double barWidth;

  /// Spacing between bars (for bar type waveforms)
  final double barSpacing;

  /// Border radius for rounded corners
  final BorderRadius? borderRadius;

  /// Gradient overlay for the waveform
  final Gradient? gradient;

  /// Gradient for the played portion (overrides playedColor if set)
  final Gradient? playedGradient;

  /// Gradient for the unplayed portion (overrides unplayedColor if set)
  final Gradient? unplayedGradient;

  /// Type of waveform visualization
  final WaveformType type;

  /// Stroke width for line type waveforms
  final double strokeWidth;

  /// Whether to show a center line
  final bool showCenterLine;

  /// Color of the center line
  final Color centerLineColor;

  /// Width of the center line
  final double centerLineWidth;

  /// Padding around the waveform content
  final EdgeInsets padding;

  /// Margin around the entire widget
  final EdgeInsets margin;

  /// Border around the waveform widget
  final Border? border;

  /// Shadow for the waveform widget
  final List<BoxShadow>? boxShadow;

  /// Opacity for the entire waveform (0.0 to 1.0)
  final double opacity;

  /// Scale factor for amplitude values (affects visual height)
  final double amplitudeScale;

  /// Minimum bar height (prevents invisible bars for very low amplitudes)
  final double minBarHeight;

  /// Maximum bar height (caps very high amplitudes)
  final double? maxBarHeight;

  /// Whether to apply anti-aliasing to the waveform rendering
  final bool antiAlias;

  /// Blend mode for gradient overlays
  final BlendMode gradientBlendMode;

  /// Method for downsampling when data points exceed display resolution
  final DownsampleMethod downsampleMethod;

  /// Method for upsampling when data points are fewer than display resolution
  final UpsampleMethod upsampleMethod;

  /// Whether to automatically calculate display resolution based on widget width
  final bool autoDisplayResolution;

  /// Manual override for display resolution (null = automatic calculation)
  final int? fixedDisplayResolution;

  /// Target density for automatic display resolution calculation (points per 100px)
  /// Only used when autoDisplayResolution is true and fixedDisplayResolution is null
  final double? displayDensity;

  const WaveformStyle({
    this.playedColor = Colors.blue,
    this.unplayedColor = Colors.grey,
    this.backgroundColor = Colors.transparent,
    this.height = 100.0,
    this.barWidth = 2.0,
    this.barSpacing = 1.0,
    this.borderRadius,
    this.gradient,
    this.playedGradient,
    this.unplayedGradient,
    this.type = WaveformType.bars,
    this.strokeWidth = 2.0,
    this.showCenterLine = false,
    this.centerLineColor = Colors.grey,
    this.centerLineWidth = 1.0,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.border,
    this.boxShadow,
    this.opacity = 1.0,
    this.amplitudeScale = 1.0,
    this.minBarHeight = 1.0,
    this.maxBarHeight,
    this.antiAlias = true,
    this.gradientBlendMode = BlendMode.overlay,
    this.downsampleMethod = DownsampleMethod.max,
    this.upsampleMethod = UpsampleMethod.linear,
    this.autoDisplayResolution = true,
    this.fixedDisplayResolution,
    this.displayDensity,
  });

  /// Create a copy with modified properties
  WaveformStyle copyWith({
    Color? playedColor,
    Color? unplayedColor,
    Color? backgroundColor,
    double? height,
    double? barWidth,
    double? barSpacing,
    BorderRadius? borderRadius,
    Gradient? gradient,
    Gradient? playedGradient,
    Gradient? unplayedGradient,
    WaveformType? type,
    double? strokeWidth,
    bool? showCenterLine,
    Color? centerLineColor,
    double? centerLineWidth,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Border? border,
    List<BoxShadow>? boxShadow,
    double? opacity,
    double? amplitudeScale,
    double? minBarHeight,
    double? maxBarHeight,
    bool? antiAlias,
    BlendMode? gradientBlendMode,
    DownsampleMethod? downsampleMethod,
    UpsampleMethod? upsampleMethod,
    bool? autoDisplayResolution,
    int? fixedDisplayResolution,
    double? displayDensity,
  }) {
    return WaveformStyle(
      playedColor: playedColor ?? this.playedColor,
      unplayedColor: unplayedColor ?? this.unplayedColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      height: height ?? this.height,
      barWidth: barWidth ?? this.barWidth,
      barSpacing: barSpacing ?? this.barSpacing,
      borderRadius: borderRadius ?? this.borderRadius,
      gradient: gradient ?? this.gradient,
      playedGradient: playedGradient ?? this.playedGradient,
      unplayedGradient: unplayedGradient ?? this.unplayedGradient,
      type: type ?? this.type,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      showCenterLine: showCenterLine ?? this.showCenterLine,
      centerLineColor: centerLineColor ?? this.centerLineColor,
      centerLineWidth: centerLineWidth ?? this.centerLineWidth,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      border: border ?? this.border,
      boxShadow: boxShadow ?? this.boxShadow,
      opacity: opacity ?? this.opacity,
      amplitudeScale: amplitudeScale ?? this.amplitudeScale,
      minBarHeight: minBarHeight ?? this.minBarHeight,
      maxBarHeight: maxBarHeight ?? this.maxBarHeight,
      antiAlias: antiAlias ?? this.antiAlias,
      gradientBlendMode: gradientBlendMode ?? this.gradientBlendMode,
      downsampleMethod: downsampleMethod ?? this.downsampleMethod,
      upsampleMethod: upsampleMethod ?? this.upsampleMethod,
      autoDisplayResolution: autoDisplayResolution ?? this.autoDisplayResolution,
      fixedDisplayResolution: fixedDisplayResolution ?? this.fixedDisplayResolution,
      displayDensity: displayDensity ?? this.displayDensity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaveformStyle &&
        other.playedColor == playedColor &&
        other.unplayedColor == unplayedColor &&
        other.backgroundColor == backgroundColor &&
        other.height == height &&
        other.barWidth == barWidth &&
        other.barSpacing == barSpacing &&
        other.borderRadius == borderRadius &&
        other.gradient == gradient &&
        other.playedGradient == playedGradient &&
        other.unplayedGradient == unplayedGradient &&
        other.type == type &&
        other.strokeWidth == strokeWidth &&
        other.showCenterLine == showCenterLine &&
        other.centerLineColor == centerLineColor &&
        other.centerLineWidth == centerLineWidth &&
        other.padding == padding &&
        other.margin == margin &&
        other.border == border &&
        other.boxShadow == boxShadow &&
        other.opacity == opacity &&
        other.amplitudeScale == amplitudeScale &&
        other.minBarHeight == minBarHeight &&
        other.maxBarHeight == maxBarHeight &&
        other.antiAlias == antiAlias &&
        other.gradientBlendMode == gradientBlendMode &&
        other.downsampleMethod == downsampleMethod &&
        other.upsampleMethod == upsampleMethod &&
        other.autoDisplayResolution == autoDisplayResolution &&
        other.fixedDisplayResolution == fixedDisplayResolution &&
        other.displayDensity == displayDensity;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      playedColor,
      unplayedColor,
      backgroundColor,
      height,
      barWidth,
      barSpacing,
      borderRadius,
      gradient,
      playedGradient,
      unplayedGradient,
      type,
      strokeWidth,
      showCenterLine,
      centerLineColor,
      centerLineWidth,
      padding,
      margin,
      border,
      boxShadow,
      opacity,
      amplitudeScale,
      minBarHeight,
      maxBarHeight,
      antiAlias,
      gradientBlendMode,
      downsampleMethod,
      upsampleMethod,
      autoDisplayResolution,
      fixedDisplayResolution,
      displayDensity,
    ]);
  }
}
