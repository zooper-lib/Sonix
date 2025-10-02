# Sonix Development Tools

This directory contains tools for **Sonix package development only**. These tools are not intended for end users of the Sonix package.

## ⚠️ Important: Developer Tools Only

**These tools are for Sonix package developers, not for end users!**

If you're using Sonix in your Flutter app, these tools won't help you integrate FFMPEG. See the main Sonix documentation for proper FFMPEG integration in your application.

## Tools Overview

### For End Users: `setup_ffmpeg_for_app.dart`

**This tool is for end users of the Sonix package!**

A user-friendly tool that helps Flutter app developers integrate FFMPEG with their Sonix-powered applications.

**Purpose:**

- Downloads FFMPEG binaries for the user's platform
- Installs them to the app's build directories
- Validates the installation
- Enables Sonix to work with FFMPEG in the user's app

**Usage (for end users):**

```bash
# From your Flutter app's root directory
dart run sonix:setup_ffmpeg_for_app

# Verify installation
dart run sonix:setup_ffmpeg_for_app --verify

# Force reinstall
dart run sonix:setup_ffmpeg_for_app --force
```

**Requirements:**

- Must be run from a Flutter app's root directory
- Sonix must be added as a dependency in pubspec.yaml

### For Package Developers: `download_ffmpeg_binaries.dart`

Downloads and installs FFMPEG binaries required for Sonix package development and testing.

**Purpose:**

- Enables native library compilation (CMake builds)
- Provides FFMPEG libraries for unit tests
- Sets up the example app for local testing

**Installation Locations:**

1. `native/{platform}/` - Used by CMake to link against FFMPEG during native library builds
2. `test/fixtures/ffmpeg/` - Required for unit tests to load FFMPEG libraries via FFI
3. `example/build/{platform}/` - Enables the example app to run with FFMPEG support

**Usage:**

```bash
# Download and install for development
dart run tool/download_ffmpeg_binaries.dart

# Force reinstall
dart run tool/download_ffmpeg_binaries.dart --force

# Verify installation
dart run tool/download_ffmpeg_binaries.dart --verify

# See all options
dart run tool/download_ffmpeg_binaries.dart --help
```

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

Compiles the `sonix_native` library for all supported platforms and places them in the correct plugin directories for package distribution.

**Purpose:**

- Compiles sonix_native for Windows, Linux, macOS, iOS, and Android
- Places binaries in platform-specific plugin directories
- Prepares libraries for automatic bundling with the published package
- Eliminates the need for end users to compile native code

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
- iOS: `ios/libsonix_native.a`
- Android: `android/src/main/jniLibs/{arch}/libsonix_native.so`

### Supporting Files

- `ffmpeg_binary_downloader.dart` - Handles downloading FFMPEG archives from official sources
- `ffmpeg_binary_validator.dart` - Validates downloaded binaries for completeness and compatibility
- `ffmpeg_binary_installer.dart` - Manages installation to development directories

## Development Workflow

### Initial Setup

1. Clone the Sonix repository
2. Run `flutter pub get`
3. Run `dart run tool/download_ffmpeg_binaries.dart`
4. Build native libraries: `cd native && ./build.sh` (or `build.bat` on Windows)

### Testing

1. Ensure FFMPEG binaries are installed: `dart run tool/download_ffmpeg_binaries.dart --verify`
2. Run tests: `flutter test`
3. Run example app: `cd example && flutter run`

### Updating FFMPEG

1. Run `dart run tool/download_ffmpeg_binaries.dart --force` to get latest binaries
2. Rebuild native libraries if needed
3. Run tests to ensure compatibility

## Licensing Considerations

**Why we can't ship FFMPEG binaries:**

- FFMPEG is licensed under GPL (copyleft license)
- Sonix is licensed under MIT (permissive license)
- GPL and MIT are incompatible for binary distribution
- Shipping FFMPEG would force Sonix to become GPL-licensed

**Development vs. Distribution:**

- These tools enable development and testing with FFMPEG
- The published Sonix package does NOT include FFMPEG binaries
- End users must provide their own FFMPEG installation

## End User Integration

End users of the Sonix package have several options for FFMPEG integration:

1. **System Installation**: Install FFMPEG system-wide and let Sonix find it
2. **App Bundling**: Include FFMPEG binaries in their app's build process
3. **Runtime Loading**: Use Sonix's runtime binary loading features (if available)

See the main Sonix documentation for detailed end-user integration instructions.

## Platform Support

Currently supported platforms for development:

- **Windows**: x64 architecture
- **macOS**: x64 architecture (Intel and Apple Silicon via Rosetta)
- **Linux**: x64 architecture

## Troubleshooting

### Download Issues

- Check internet connection
- Verify platform is supported: `dart run tool/download_ffmpeg_binaries.dart --list-platforms`
- Try force reinstall: `dart run tool/download_ffmpeg_binaries.dart --force`

### Build Issues

- Ensure FFMPEG binaries are installed and validated
- Check that native build scripts have execute permissions (Unix systems)
- Verify CMake can find the FFMPEG libraries in `native/{platform}/`

### Test Issues

- Verify test fixtures are installed: check `test/fixtures/ffmpeg/` directory
- Run installation verification: `dart run tool/download_ffmpeg_binaries.dart --verify`
- Ensure FFI can load the libraries from the test fixtures directory

## Contributing

When modifying these tools:

1. Maintain clear separation between development and end-user concerns
2. Update documentation to reflect any changes in workflow
3. Test on all supported platforms
4. Ensure licensing compliance (no GPL code in MIT-licensed files)
