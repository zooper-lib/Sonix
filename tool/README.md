# Sonix Development Tools

This directory contains tools for **Sonix package development only**. These tools are not intended for end users of the Sonix package.

## ⚠️ Important: Developer Tools Only

**These tools are for Sonix package developers, not for end users!**

If you're using Sonix in your Flutter app, these tools won't help you integrate FFMPEG. See the main Sonix documentation for proper FFMPEG integration in your application.

## Tools Overview

### FFmpeg requirement (system-installed)

Sonix now uses the system FFmpeg exclusively for development and distribution on desktop platforms.

Install FFmpeg on your system and CMake will find it automatically:

- macOS: Homebrew — `brew install ffmpeg`
- Linux: Use your distro’s package manager (for example: `sudo apt install ffmpeg`)
- Windows: Provide development libraries via vcpkg/conda/msys2 as appropriate (not bundled here)

### `build_native_for_development.dart`

**This tool is for Sonix package developers during development!**

Quick development build script that compiles the native library for local testing and development.

**Purpose:**

- Fast development builds for testing changes
- Builds to `build/development/` directory (not for distribution)
- Single platform (current platform only)
- Incremental builds supported

**Usage:**

```bash
# Quick development build
dart run tool/build_native_for_development.dart

# Debug build with verbose output
dart run tool/build_native_for_development.dart --build-type Debug --verbose

# Clean build directory
dart run tool/build_native_for_development.dart --clean
```

**Output Locations:**

- Windows: `build/development/Release/sonix_native.dll`
- Linux: `build/development/libsonix_native.so`
- macOS: `build/development/libsonix_native.dylib`

### `build_native_for_distribution.dart`

**This tool is for Sonix package developers preparing releases!**

Compiles the `sonix_native` library for supported platforms and places them in the correct plugin directories for package distribution.

**Purpose:**

- Compiles sonix_native for Windows, Linux, and macOS
- Places binaries in platform-specific plugin directories (desktop)
- Prepares libraries used by the plugin during local development and CI

**Usage:**

```bash
# Build for current platform
dart run tool/build_native_for_distribution.dart

# Build for all platforms
dart run tool/build_native_for_distribution.dart --platforms all

# Build for specific platforms
dart run tool/build_native_for_distribution.dart --platforms windows,linux

# Clean build artifacts
dart run tool/build_native_for_distribution.dart --clean
```

**Output Locations:**

- Windows: `windows/sonix_native.dll`
- Linux: `linux/libsonix_native.so`
- macOS: `macos/libsonix_native.dylib`

### Supporting Files

No binary download or installer tooling remains. The workflow depends on system FFmpeg.

## Development Workflow

### Initial Setup

1. Clone the Sonix repository
2. Run `flutter pub get`
3. Install system FFmpeg (macOS: `brew install ffmpeg`)
4. Build native libraries: `dart run tool/build_native_for_development.dart`

### Testing

1. Ensure system FFmpeg is installed and discoverable (for example, `brew --prefix ffmpeg` on macOS)
2. Run tests: `flutter test`
3. Run example app: `cd example && flutter run`

### Updating FFMPEG

Keep your system FFmpeg up-to-date using your package manager.

## Licensing Considerations

**Why we can't ship FFMPEG binaries:**

- FFMPEG is licensed under GPL (copyleft license)
- Sonix is licensed under MIT (permissive license)
- GPL and MIT are incompatible for binary distribution
- Shipping FFMPEG would force Sonix to become GPL-licensed

**Development vs. Distribution:**

- These tools enable development and testing with FFmpeg.
- The published Sonix package does NOT include FFmpeg binaries.
- End users must provide their own FFmpeg installation when required by their platform.

## End User Integration

See the main Sonix documentation for end-user FFmpeg setup instructions. Desktop platforms rely on system-installed FFmpeg.

## Platform Support

Currently supported platforms for development:

- **Windows**: x64 architecture
- **macOS**: Intel and Apple Silicon
- **Linux**: x64 architecture

## Troubleshooting

### Build Issues

- Ensure system FFmpeg is installed and provides shared libraries.
- Check that native build scripts have execute permissions (Unix systems).
- Verify CMake finds FFmpeg in common system locations (Homebrew on macOS).

### Test Issues

- Some tests preload FFmpeg from `test/fixtures/ffmpeg` when present; otherwise they rely on system FFmpeg.
- Ensure FFmpeg can be located system-wide or place symlinks in the fixtures directory for testing convenience.

## Contributing

When modifying these tools:

1. Maintain clear separation between development and end-user concerns
2. Update documentation to reflect any changes in workflow
3. Test on all supported platforms
4. Ensure licensing compliance (no GPL code in MIT-licensed files)
