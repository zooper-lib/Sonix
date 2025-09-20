# MP3 Decoder Test Issue Report

## Problem Summary
The MP3 decoder tests are failing due to a **segmentation fault (SIGABRT -6)** in the native library when attempting to decode MP3 audio data.

## Root Cause Analysis

### What Works ✅
- Native library loading (`NativeAudioBindings.initialize()`)
- Backend detection (using "Legacy" backend)
- Format detection from file headers
- Basic FFI binding setup
- File system access and reading

### What Fails ❌
- **Actual audio decoding** (`NativeAudioBindings.decodeAudio()`)
- Any operation that calls the native MP3 decoding functions
- Tests crash with SIGABRT (-6) during native decoding

### Technical Details
- **Backend**: Legacy (not FFMPEG)
- **Crash Type**: SIGABRT (-6) - indicates memory violation or assertion failure
- **Crash Location**: Native `sonix_decode_audio` function
- **Platform**: macOS ARM64
- **Native Library**: `libsonix_native.dylib` exists and loads successfully

## Impact on Tests
- **15 tests failing** due to segmentation fault
- Tests properly expose the bug (as they should)
- No false positives - the failure indicates a real issue that needs fixing

## Required Fixes

### 1. Native Library Issues
The segmentation fault suggests problems in the native C code:

```bash
# Rebuild the native library with debug symbols
cd native
./build.sh --debug

# Check for memory issues with valgrind (if available)
valgrind --tool=memcheck ./test_native_decoder

# Verify FFmpeg dependencies
otool -L libsonix_native.dylib
```

### 2. Potential Issues to Investigate

#### Memory Management
- Buffer allocation/deallocation in native code
- Pointer arithmetic errors
- Stack/heap corruption

#### FFI Binding Mismatches
- Function signature mismatches between Dart and C
- Data structure alignment issues
- Incorrect parameter passing

#### Native Dependencies
- Missing or incompatible FFmpeg libraries
- Library loading order issues
- Symbol resolution problems

### 3. Debugging Steps

#### Step 1: Native Library Debugging
```bash
# Enable debug logging in native code
export SONIX_DEBUG=1

# Run with debug symbols
lldb flutter_tester
(lldb) run test/decoders/mp3_decoder_test.dart
```

#### Step 2: FFI Binding Verification
```dart
// Verify function signatures match native implementation
// Check sonix_bindings.dart against native header files
```

#### Step 3: Memory Analysis
```bash
# Check for memory leaks
leaks -atExit -- flutter test test/decoders/mp3_decoder_test.dart

# Monitor memory usage
instruments -t "Allocations" flutter test
```

## Test Strategy

### Current Approach ✅
The tests now properly **fail** when there are issues, which is correct behavior:
- Tests expose the segmentation fault
- No false positives or hidden bugs
- Clear failure indication for developers

### What NOT to Do ❌
- ~~Skip tests when native library fails~~
- ~~Mark tests as "expected to fail"~~
- ~~Hide the segmentation fault with try-catch~~

### Proper Fix Required
The segmentation fault in the native library must be fixed at the source:
1. Debug the native C code
2. Fix memory management issues
3. Verify FFI bindings
4. Ensure proper library dependencies

## Files Affected
- `test/decoders/mp3_decoder_test.dart` - Main test file (properly failing)
- `test/decoders/mp3_decoder_diagnostic_test.dart` - Diagnostic test
- `lib/src/native/native_audio_bindings.dart` - FFI bindings
- `lib/src/native/sonix_bindings.dart` - Native function signatures
- `native/src/sonix_native.c` - Native implementation (likely source of bug)

## Next Steps
1. **Debug native library** - Use debugger to find exact crash location
2. **Fix memory issues** - Address buffer overflows, null pointers, etc.
3. **Verify FFI bindings** - Ensure Dart/C interface is correct
4. **Test with smaller files** - Use minimal test cases for debugging
5. **Add native unit tests** - Test native functions independently

## Conclusion
The tests are working correctly by exposing a real bug in the native library. The segmentation fault must be fixed in the native C code, not hidden in the tests.