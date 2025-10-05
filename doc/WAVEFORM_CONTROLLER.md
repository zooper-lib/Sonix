# WaveformController

The `WaveformController` provides programmatic control over waveform playback position and seeking. This allows you to control the waveform widget from code, not just through user interactions.

## Basic Usage

```dart
class _MyWidgetState extends State<MyWidget> {
  final WaveformController _controller = WaveformController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WaveformWidget(
      waveformData: waveformData,
      controller: _controller,
      onSeek: (position) {
        // Handle seeking
        audioPlayer.seek(waveformData.duration * position);
      },
    );
  }
}
```

## Key Features

### 1. Programmatic Seeking

```dart
// Seek to specific position (0.0 to 1.0)
_controller.seekTo(0.5); // Jump to middle

// Seek without animation
_controller.seekTo(0.75, animate: false);

// Reset to beginning
_controller.reset();
```

### 2. Position Updates

```dart
// Update position without triggering onSeek callback
// Useful for syncing with audio player
_controller.updatePosition(0.3);

// Example: Sync with audio player
audioPlayer.onPositionChanged.listen((duration) {
  final position = duration.inMilliseconds / 
                   audioPlayer.duration!.inMilliseconds;
  _controller.updatePosition(position);
});
```

### 3. Listen to Changes

```dart
_controller.addListener(() {
  print('Position changed to: ${_controller.position}');
});
```

### 4. Animation Control

```dart
// Enable/disable animations globally
_controller.setAnimationEnabled(false);

// Check current animation state
if (_controller.shouldAnimate) {
  // Animation is enabled
}
```

## API Reference

### Properties

- **`position`** (`double`): Current position from 0.0 to 1.0
- **`shouldAnimate`** (`bool`): Whether seeks should be animated

### Methods

#### `seekTo(double position, {bool? animate})`
Seeks to a specific position with optional animation override.

**Parameters:**
- `position`: Target position (0.0 to 1.0)
- `animate`: Optional override for animation (null uses controller's setting)

**Example:**
```dart
_controller.seekTo(0.5); // Animated seek to middle
_controller.seekTo(0.0, animate: false); // Instant seek to start
```

#### `updatePosition(double position)`
Updates the position without triggering the `onSeek` callback.

**Use case:** Syncing the waveform with audio playback progress

**Example:**
```dart
_controller.updatePosition(0.3); // No onSeek callback fired
```

#### `reset()`
Resets the position to the beginning (0.0).

#### `setAnimationEnabled(bool enabled)`
Enables or disables animation for all future seeks.

## Backward Compatibility

The controller is **optional**. Existing code using `playbackPosition` parameter continues to work:

```dart
// Old way (still works)
WaveformWidget(
  waveformData: data,
  playbackPosition: 0.5,
  onSeek: (pos) { },
)

// New way with controller
WaveformWidget(
  waveformData: data,
  controller: controller,
  onSeek: (pos) { },
)
```

**Note:** If both `controller` and `playbackPosition` are provided, the controller takes precedence.

## Best Practices

1. **Always dispose**: Call `controller.dispose()` in your widget's `dispose()` method
2. **Use updatePosition for playback sync**: Don't use `seekTo` when just updating the position from audio playback
3. **Disable animation for rapid updates**: When updating position frequently (e.g., every 50ms), consider disabling animation
4. **Use seekTo for user actions**: When user clicks buttons or interacts, use `seekTo` for smooth animated feedback

## Complete Example

See `example/lib/examples/waveform_controller_example.dart` for a complete working example with:
- Play/pause controls
- Quick seek buttons
- Playback speed control
- Animation toggling
- Real-time position updates
