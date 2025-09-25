# FFMPEG Binary Download and Management Tools

This directory contains tools for downloading, validating, and installing FFMPEG binaries for the Sonix Flutter package.

## Overview

The FFMPEG binary management system consists of three main components:

1. **FFMPEGBinaryDownloader** - Downloads pre-built FFMPEG binaries from reliable sources
2. **FFMPEGBinaryValidator** - Validates downloaded binaries for compatibility and completeness
3. **FFMPEGBinaryInstaller** - Installs binaries to Flutter build directories and test locations

## Quick Start

### Download and Install FFMPEG Binaries

```bash
# Download and install for current platform
dart run tools/download_ffmpeg_binaries.dart

# Force reinstall even if binaries exist
dart run tools/download_ffmpeg_binaries.dart --force

# Verify current installation
dart run tools/download_ffmpeg_binaries.dart --verify
```

### Command Line Options

```bash
# Show help
dart run tools/download_ffmpeg_binaries.dart --help

# Download to custom directory without installing
dart run tools/download_ffmpeg_binaries.dart --output ./custom --skip-install

# List supported platforms
dart run tools/download_ffmpeg_binaries.dart --list-platforms

# Remove installed binaries
dart run tools/download_ffmpeg_binaries.dart --uninstall
```

## File Structure

```
tools/
├── download_ffmpeg_binaries.dart    # Main command-line tool
├── ffmpeg_binary_downloader.dart    # Binary download functionality
├── ffmpeg_binary_validator.dart     # Binary validation and symbol checking
├── ffmpeg_binary_installer.dart     # Flutter build directory integration
├── ffmpeg_binary_sources.json       # Configuration for binary sources
└── README.md                        # This file
```

## Binary Installation Locations

The tool automatically installs FFMPEG binaries to the following locations:

### Windows
- `build/windows/x64/runner/Debug/`
- `build/windows/x64/runner/Release/`
- `test/assets/ffmpeg/` (for unit tests)

### macOS
- `build/macos/Build/Products/Debug/`
- `build/macos/Build/Products/Release/`
- `test/assets/ffmpeg/` (for unit tests)

### Linux
- `build/linux/x64/debug/bundle/lib/`
- `build/linux/x64/release/bundle/lib/`
- `test/assets/ffmpeg/` (for unit tests)

## Binary Sources

The tool downloads FFMPEG binaries from trusted sources:

- **Windows**: BtbN/FFmpeg-Builds (GitHub releases)
- **macOS**: evermeet.cx (official builds)
- **Linux**: johnvansickle.com (static builds)

## Validation Process

Each downloaded binary is validated for:

1. **File integrity** - SHA-256 checksum verification
2. **Symbol presence** - Required FFMPEG symbols are checked
3. **Architecture compatibility** - Platform and architecture validation
4. **Version compatibility** - FFMPEG version checking

## Required FFMPEG Libraries

The following libraries are required for each platform:

### Windows
- `avformat-60.dll` - Container format handling
- `avcodec-60.dll` - Audio/video codecs
- `avutil-58.dll` - Utility functions
- `swresample-4.dll` - Audio resampling

### macOS
- `libavformat.dylib` - Container format handling
- `libavcodec.dylib` - Audio/video codecs
- `libavutil.dylib` - Utility functions
- `libswresample.dylib` - Audio resampling

### Linux
- `libavformat.so` - Container format handling
- `libavcodec.so` - Audio/video codecs
- `libavutil.so` - Utility functions
- `libswresample.so` - Audio resampling

## Troubleshooting

### Download Issues

If downloads fail:

1. Check internet connectivity
2. Verify the binary sources are accessible
3. Check if antivirus software is blocking downloads
4. Try using a different network or VPN

### Validation Issues

If binary validation fails:

1. Re-download the binaries with `--force`
2. Check if the binaries are corrupted
3. Verify platform compatibility
4. Check if required tools are installed (nm, objdump, readelf)

### Installation Issues

If installation to Flutter directories fails:

1. Ensure Flutter project structure exists
2. Check write permissions to build directories
3. Run `flutter clean` and try again
4. Manually create build directories if needed

### Platform-Specific Issues

#### Windows
- Ensure PowerShell execution policy allows script execution
- Install Visual Studio Build Tools if needed
- Check Windows Defender exclusions

#### macOS
- Install Xcode command line tools: `xcode-select --install`
- Check Gatekeeper settings for downloaded binaries
- Verify code signing if required

#### Linux
- Install required tools: `sudo apt-get install binutils`
- Check library dependencies with `ldd`
- Verify executable permissions

## Development

### Running Tests

```bash
# Run binary download system tests
dart test test/tools/ffmpeg_binary_download_test.dart

# Run all tests
dart test
```

### Updating Binary Sources

To update binary sources, modify `ffmpeg_binary_sources.json`:

1. Update URLs to new binary releases
2. Update checksums for new binaries
3. Test downloads on all platforms
4. Update version numbers

### Adding New Platforms

To add support for new platforms:

1. Add platform configuration to `PlatformInfo.detect()`
2. Add binary sources to `ffmpeg_binary_sources.json`
3. Update validation logic in `FFMPEGBinaryValidator`
4. Add installation paths in `FFMPEGBinaryInstaller`
5. Test thoroughly on the new platform

## Security Considerations

- All downloads use HTTPS
- Binary integrity is verified with SHA-256 checksums
- Binaries are sourced from trusted, well-known providers
- Symbol validation ensures binaries contain expected functions
- Architecture validation prevents incompatible binaries

## Performance

- Downloads are performed with progress reporting
- Checksums are calculated efficiently using streaming
- Binary validation uses platform-native tools
- Installation uses file copying for reliability

## License

This tool downloads FFMPEG binaries which are licensed under LGPL/GPL. Please ensure compliance with FFMPEG licensing requirements in your application.