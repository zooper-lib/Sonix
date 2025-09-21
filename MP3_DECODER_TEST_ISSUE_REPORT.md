# MP3 Decoder Test Issue Report

## Problem Summary

The MP3 decoder tests are failing due to a **missing FFmpeg implementation** in the native library. The current native library uses a stub implementation that cannot actually decode MP3 audio data.

## Root Cause Analysis - UPDATED

### What Works ✅

- Native library loading (`NativeAudioBindings.initialize()`)
- Backend detection (using "Legacy" backend)
- Format detection from file headers (MP3 format properly detected)
- Basic FFI binding setup and null pointer handling
- File system access and reading
- Proper error handling (DecodingException instead of segmentation fault)

### What Fails ❌

- **Actual audio decoding** (`NativeAudioBindings.decodeAudio()`)
- The native library returns NULL for `sonix_decode_audio()` calls
- Stub implementation has no actual MP3 decoding logic

### Technical Details - UPDATED

- **Backend**: Legacy (not FFMPEG) - stub implementation
- **Issue Type**: DecodingException with message "Failed to decode MP3: no valid frames found"
- **Native Library**: Built with stub implementation (`sonix_native_stub.c`)
- **FFmpeg Libraries**: Available in `native/windows/` and `native/macos/` but not linked to build
- **Platform**: Windows (development), macOS ARM64 (likely production environment)

## Impact on Tests - UPDATED

- **Tests now properly fail** with clear error messages instead of segmentation fault
- Tests correctly expose the missing implementation issue
- Error handling works as intended (DecodingException instead of crash)
- No segmentation faults - the issue was caused by DLL not being found in the correct path

## Required Fixes - UPDATED

### 1. Build Native Library with FFmpeg Support

The current library uses a stub implementation. Need to build with FFmpeg:

```bash
# Option 1: Use CMake with proper compiler
cd native
# Ensure Visual Studio or MinGW is available
./build.bat  # Windows
./build.sh   # macOS/Linux

# Option 2: Setup FFmpeg using provided tool
dart run tools/setup_ffmpeg.dart

# Option 3: Use Flutter's native build system (if configured)
flutter build windows
```

### 2. Alternative: Fix Library Path Issues

The previous segmentation fault was caused by DLL loading issues:

```bash
# Ensure native library is in the correct location
# Copy sonix_native.dll and FFmpeg DLLs to project root for tests
# Or update library loading path in SonixNativeBindings
```

### 3. Build System Integration

Integrate native library building into Flutter's build process:

- Add native assets configuration
- Ensure proper platform-specific library paths
- Include FFmpeg dependencies in distribution

## Test Strategy - UPDATED

### Current Approach ✅

The tests now work correctly:

- Tests properly **fail** with clear error messages when implementation is missing
- No segmentation faults or crashes
- Clear indication of the actual problem (missing FFmpeg implementation)
- Proper error handling through exception system

### What NOT to Do ❌

- ~~Skip tests when native library fails~~
- ~~Mark tests as "expected to fail"~~
- ~~Hide the missing implementation with try-catch~~

### Proper Fix Required

The missing FFmpeg implementation must be addressed:

1. Build native library with FFmpeg support
2. Ensure FFmpeg libraries are properly linked
3. Test with actual MP3 decoding capability
4. Verify cross-platform compatibility

## Files Affected - UPDATED

- `test/decoders/mp3_decoder_test.dart` - Tests work correctly (proper failure)
- `test/decoders/mp3_decoder_diagnostic_test.dart` - Diagnostic test confirms issue
- `lib/src/native/native_audio_bindings.dart` - FFI bindings work correctly
- `lib/src/native/sonix_bindings.dart` - Native function signatures correct
- `native/src/sonix_native_stub.c` - Current stub implementation (needs replacement)
- `native/src/ffmpeg_wrapper.c` - Proper implementation (needs to be built and linked)
- `native/CMakeLists.txt` - Build configuration (needs compiler setup)

## Next Steps - UPDATED

1. **Setup build environment** - Install Visual Studio or MinGW for Windows builds
2. **Build with FFmpeg** - Use build scripts to create proper implementation
3. **Test library loading** - Ensure proper DLL/dylib placement for Flutter tests
4. **Verify cross-platform** - Test on both Windows and macOS environments
5. **Update CI/CD** - Include native library building in automated builds

## Conclusion - UPDATED

The original segmentation fault was resolved by fixing the library loading path. The tests now correctly expose the real issue: the native library is using a stub implementation instead of the full FFmpeg-based MP3 decoder. This is a build/configuration issue, not a code bug.

### Status

- ✅ **Segmentation fault fixed** - Tests run without crashing
- ✅ **Error handling works** - Proper exceptions instead of crashes
- ❌ **MP3 decoding not implemented** - Need to build with FFmpeg support
- ⚠️ **Build system needs setup** - Requires compiler installation and configuration
