import 'package:flutter/material.dart';
import '../models/waveform_data.dart';
import 'waveform_style.dart';

/// Predefined waveform style presets for common use cases
class WaveformStylePresets {
  WaveformStylePresets._();

  /// SoundCloud-like waveform style
  static const WaveformStyle soundCloud = WaveformStyle(
    playedColor: Color(0xFFFF5500),
    unplayedColor: Color(0xFFCCCCCC),
    height: 60.0,
    barWidth: 2.0,
    barSpacing: 1.0,
    type: WaveformType.bars,
    borderRadius: BorderRadius.all(Radius.circular(1.0)),
  );

  /// Spotify-like waveform style
  static const WaveformStyle spotify = WaveformStyle(
    playedColor: Color(0xFF1DB954),
    unplayedColor: Color(0xFF535353),
    height: 80.0,
    barWidth: 3.0,
    barSpacing: 1.5,
    type: WaveformType.bars,
    borderRadius: BorderRadius.all(Radius.circular(1.5)),
  );

  /// Minimal line waveform
  static const WaveformStyle minimalLine = WaveformStyle(
    playedColor: Colors.blue,
    unplayedColor: Colors.grey,
    height: 50.0,
    strokeWidth: 2.0,
    type: WaveformType.line,
    showCenterLine: true,
    centerLineColor: Color(0xFFE0E0E0),
    centerLineWidth: 0.5,
  );

  /// Filled area waveform with gradient
  static WaveformStyle filledGradient({Color startColor = Colors.blue, Color endColor = Colors.purple, double height = 100.0}) {
    return WaveformStyle(
      playedGradient: LinearGradient(colors: [startColor, endColor], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      unplayedColor: Colors.grey.shade300,
      height: height,
      type: WaveformType.filled,
      opacity: 0.8,
    );
  }

  /// Retro/vintage style with rounded bars
  static const WaveformStyle retro = WaveformStyle(
    playedColor: Color(0xFFFFD700),
    unplayedColor: Color(0xFF8B4513),
    backgroundColor: Color(0xFF2F1B14),
    height: 70.0,
    barWidth: 4.0,
    barSpacing: 2.0,
    type: WaveformType.bars,
    borderRadius: BorderRadius.all(Radius.circular(2.0)),
    padding: EdgeInsets.all(8.0),
    border: Border.fromBorderSide(BorderSide(color: Color(0xFF8B4513), width: 1.0)),
  );

  /// Modern glass-like effect
  static WaveformStyle glassEffect({Color accentColor = Colors.cyan, double height = 90.0}) {
    return WaveformStyle(
      playedGradient: LinearGradient(
        colors: [accentColor.withValues(alpha: 0.8), accentColor.withValues(alpha: 0.4)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      unplayedGradient: LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      height: height,
      barWidth: 3.0,
      barSpacing: 1.0,
      type: WaveformType.bars,
      borderRadius: const BorderRadius.all(Radius.circular(1.5)),
      backgroundColor: Colors.black.withValues(alpha: 0.1),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8.0, offset: const Offset(0, 2))],
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
    );
  }

  /// Neon glow effect
  static WaveformStyle neonGlow({Color glowColor = Colors.cyan, double height = 80.0}) {
    return WaveformStyle(
      playedColor: glowColor,
      unplayedColor: glowColor.withValues(alpha: 0.3),
      backgroundColor: Colors.black,
      height: height,
      barWidth: 2.0,
      barSpacing: 1.0,
      type: WaveformType.bars,
      boxShadow: [
        BoxShadow(color: glowColor.withValues(alpha: 0.5), blurRadius: 10.0, spreadRadius: 2.0),
        BoxShadow(color: glowColor.withValues(alpha: 0.3), blurRadius: 20.0, spreadRadius: 4.0),
      ],
    );
  }

  /// Professional audio editor style
  static const WaveformStyle professional = WaveformStyle(
    playedColor: Color(0xFF4CAF50),
    unplayedColor: Color(0xFF757575),
    backgroundColor: Color(0xFF1E1E1E),
    height: 120.0,
    barWidth: 1.5,
    barSpacing: 0.5,
    type: WaveformType.bars,
    showCenterLine: true,
    centerLineColor: Color(0xFF424242),
    centerLineWidth: 1.0,
    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
    amplitudeScale: 0.9,
    minBarHeight: 2.0,
  );

  /// Compact mobile style
  static const WaveformStyle compact = WaveformStyle(
    playedColor: Colors.blue,
    unplayedColor: Colors.grey,
    height: 40.0,
    barWidth: 2.0,
    barSpacing: 1.0,
    type: WaveformType.bars,
    borderRadius: BorderRadius.all(Radius.circular(1.0)),
    amplitudeScale: 0.8,
  );

  /// Podcast player style
  static const WaveformStyle podcast = WaveformStyle(
    playedColor: Color(0xFF6200EA),
    unplayedColor: Color(0xFFE1BEE7),
    height: 60.0,
    strokeWidth: 3.0,
    type: WaveformType.line,
    showCenterLine: false,
    padding: EdgeInsets.symmetric(horizontal: 8.0),
  );
}
