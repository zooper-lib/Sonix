# Sonix Tools

This directory contains development and build tools for the Sonix Flutter package.

## Available Tools

### FFMPEG Setup (`setup_ffmpeg.dart`)

Automated FFMPEG build and integration tool for cross-platform audio processing.

#### Quick Start

```bash
# Basic setup with auto-detection
dart run tools/setup_ffmpeg.dart --verbose --install-deps

# macOS specific (recommended for macOS users)
dart run tools/setup_ffmpeg.dart --platform macos --architecture arm64 --verbose --install-deps
```

#### What It Does

1. **Environment Validation** - Checks for required build tools
2. **Dependency Installation** - Installs build tools via package managers (Homebrew on macOS)
3. **FFMPEG Build** - Downloads and compiles FFMPEG with audio-focused configuration
4. **Project Integration** - Installs built libraries to `native/` directory

#### Command Options

| Option | Description | Default |
|--------|-------------|---------|
| `--help`, `-h` | Show help message | - |
| `--version`, `-v` | Show version info | - |
| `--verbose` | Enable detailed output | false |
| `--install-deps` | Auto-install dependencies | false |
| `--no-install` | Build only, don't install to project | false |
| `--working-dir <dir>` | Build directory | `build/ffmpeg` |
| `--ffmpeg-version <ver>` | FFMPEG version | `6.1` |
| `--platform <platform>` | Target platform | auto-detect |
| `--architecture <arch>` | Target architecture | auto-detect |
| `--decoders <list>` | Enabled decoders (comma-separated) | `mp3,aac,flac,vorbis,opus` |
| `--demuxers <list>` | Enabled demuxers (comma-separated) | `mp3,mp4,flac,ogg,wav` |

#### Platform Support

- **Windows** - Installs MSYS2 and MinGW toolchain
- **macOS** - Uses Homebrew for dependencies
- **Linux** - Supports apt, yum, dnf, pacman, zypper
- **Android** - Requires Android NDK
- **iOS** - Requires Xcode

#### Examples

```bash
# Show all available options
dart run tools/setup_ffmpeg.dart --help

# Build for specific platform
dart run tools/setup_ffmpeg.dart --platform windows --architecture x86_64

# Custom decoder selection
dart run tools/setup_ffmpeg.dart --decoders mp3,flac --demuxers mp3,flac

# Development build with verbose output
dart run tools/setup_ffmpeg.dart --verbose --working-dir build/dev
```

### Test Data Generator (`test_data_generator.dart`)

Generates test audio files for comprehensive testing.

```bash
dart run tools/test_data_generator.dart
```

### MP4 Test Data Generator (`mp4_test_data_generator.dart`)

Creates MP4 test files with various audio configurations.

```bash
dart run tools/mp4_test_data_generator.dart
```

### MP4 Test Validator (`validate_mp4_test_files.dart`)

Validates generated MP4 test files for correctness.

```bash
dart run tools/validate_mp4_test_files.dart
```

## Prerequisites

### macOS
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew (recommended): https://brew.sh/

### Windows
- MSYS2 (auto-installed by setup script)
- Visual Studio Build Tools (recommended)

### Linux
- Build essentials (`build-essential` on Ubuntu/Debian)
- pkg-config, yasm, nasm

### Android
- Android NDK with `ANDROID_NDK_HOME` environment variable

### iOS
- Xcode with iOS SDK

## Troubleshooting

### Common Issues

**Build fails with "command not found"**
- Run with `--install-deps` to auto-install dependencies
- Manually install build tools for your platform

**Permission denied errors**
- Ensure you have write permissions to the working directory
- On Linux/macOS, you may need `sudo` for dependency installation

**MSYS2 installation fails on Windows**
- Try running as administrator
- Install MSYS2 manually from https://www.msys2.org/

**macOS: "pkg-config not found"**
- Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- Run: `brew install pkg-config yasm nasm`

### Getting Help

1. Run with `--verbose` for detailed output
2. Check the build logs in the working directory
3. Ensure all prerequisites are installed
4. Try a clean build by deleting the working directory