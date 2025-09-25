# FFMPEG Test Fixtures

This directory should contain FFMPEG shared libraries for running FFMPEG integration tests.

## Why FFMPEG DLLs are not included

To maintain MIT license compliance, this package does not include FFMPEG binaries. FFMPEG uses LGPL/GPL licenses which are incompatible with MIT for binary distribution.

## Automated Setup (Recommended)

The easiest way to set up FFMPEG for testing is to use the built-in downloader tool:

```bash
# Download and install FFMPEG binaries for your platform
dart run tools/download_ffmpeg_binaries.dart

# Verify installation
dart run tools/download_ffmpeg_binaries.dart --verify

# See all available options
dart run tools/download_ffmpeg_binaries.dart --help
```

This tool will:
- ✅ Automatically detect your platform (Windows, macOS, Linux)
- ✅ Download compatible FFMPEG binaries from trusted sources
- ✅ Install them to the correct directories including `test/fixtures/ffmpeg/`
- ✅ Validate the installation
- ✅ Handle all platform-specific requirements

## Manual Setup (Alternative)

If you prefer to install FFMPEG manually or use your own binaries:

### Windows

Place the following DLLs in this directory:
- `avcodec-62.dll`, `avdevice-62.dll`, `avfilter-11.dll`
- `avformat-62.dll`, `avutil-60.dll`, `swresample-6.dll`, `swscale-9.dll`

Download from: [Gyan.dev builds](https://www.gyan.dev/ffmpeg/builds/) (recommended)

### macOS

Place the following dylib files in this directory:
- `libavcodec.dylib`, `libavformat.dylib`, `libavutil.dylib`, `libswresample.dylib`

### Linux

Place the following shared object files in this directory:
- `libavcodec.so`, `libavformat.so`, `libavutil.so`, `libswresample.so`

## Running tests without FFMPEG

If FFMPEG libraries are not available, the tests will be automatically skipped with helpful messages explaining how to set them up.

## License compliance

By requiring users to provide their own FFMPEG binaries:
1. ✅ This package remains MIT licensed
2. ✅ Users can choose FFMPEG builds that match their license requirements
3. ✅ No GPL/LGPL code is distributed with this package
4. ✅ Users have full control over FFMPEG versions and configurations

## Troubleshooting

### "FFMPEG DLLs not found" error
- Ensure all required DLL/dylib/so files are in this directory
- Check that file names match exactly (case-sensitive on Linux/macOS)
- Verify the files are not corrupted

### "Failed to initialize FFMPEG" error  
- Ensure FFMPEG libraries are compatible versions
- Check that all dependencies are available
- Try different FFMPEG builds if issues persist

### Tests are skipped
- This is expected behavior when FFMPEG libraries are not available
- Follow the setup instructions above to enable FFMPEG tests