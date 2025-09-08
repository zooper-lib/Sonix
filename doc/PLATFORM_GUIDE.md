# Platform-Specific Guide

This guide covers platform-specific considerations, setup requirements, and optimizations for the Sonix audio waveform package.

## Table of Contents

1. [Android](#android)
2. [iOS](#ios)
3. [Windows](#windows)
4. [macOS](#macos)
5. [Linux](#linux)
6. [Web](#web)
7. [Cross-Platform Considerations](#cross-platform-considerations)

## Android

### Requirements

- **Minimum SDK**: API level 21 (Android 5.0)
- **Target SDK**: API level 34+ (recommended)
- **NDK**: Automatically handled by Flutter
- **Architectures**: arm64-v8a, armeabi-v7a, x86_64

### Setup

No additional setup is required. The native libraries are automatically included in your APK.

#### Gradle Configuration (Optional)

If you need to customize the build, you can add these configurations to your `android/app/build.gradle`:

```gradle
android {
    // Specify architectures to include (optional)
    ndk {
        abiFilters 'arm64-v8a', 'armeabi-v7a'
    }
    
    // Optimize APK size by splitting per architecture
    splits {
        abi {
            enable true
            reset()
            include 'arm64-v8a', 'armeabi-v7a'
            universalApk false
        }
    }
}
```

### Performance Considerations

```dart
// Android-optimized initialization
void initializeForAndroid() {
  Sonix.initialize(
    memoryLimit: 30 * 1024 * 1024, // 30MB - conservative for mobile
    maxWaveformCacheSize: 20,
    maxAudioDataCacheSize: 10,
  );
}
```

### Memory Management

Android has aggressive memory management. Handle low memory situations:

```dart
class AndroidMemoryHandler {
  static void handleLowMemory() {
    // Clear caches when system is low on memory
    Sonix.forceCleanup();
  }
  
  static void optimizeForAndroid() {
    // Use streaming for files larger than 25MB on Android
    const androidLargeFileThreshold = 25 * 1024 * 1024;
    
    // Monitor memory usage more frequently on Android
    Timer.periodic(const Duration(seconds: 15), (timer) {
      final stats = Sonix.getResourceStatistics();
      if (stats.memoryUsagePercentage > 0.7) {
        Sonix.forceCleanup();
      }
    });
  }
}
```

### Permissions

No special permissions are required for local audio files. For external storage access:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                 android:maxSdkVersion="28" />
```

### ProGuard/R8

Sonix includes optimized ProGuard rules automatically. If you need custom rules:

```proguard
# android/app/proguard-rules.pro
-keep class com.sonix.** { *; }
-keepclassmembers class com.sonix.** { *; }
```

## iOS

### Requirements

- **Minimum iOS**: 11.0
- **Xcode**: 12.0+
- **Architectures**: arm64, x86_64 (simulator)

### Setup

No additional setup is required. The native libraries are statically linked.

#### Podfile Configuration (Optional)

If you need to customize the build, you can modify your `ios/Podfile`:

```ruby
# ios/Podfile
platform :ios, '11.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Optional: Optimize for size
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
      end
    end
  end
end
```

### Performance Considerations

```dart
// iOS-optimized initialization
void initializeForIOS() {
  Sonix.initialize(
    memoryLimit: 50 * 1024 * 1024, // 50MB - iOS handles memory better
    maxWaveformCacheSize: 30,
    maxAudioDataCacheSize: 15,
  );
}
```

### Memory Warnings

Handle iOS memory warnings properly:

```dart
class IOSMemoryHandler extends WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    // iOS memory warning received
    Sonix.forceCleanup();
    super.didHaveMemoryPressure();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background
        Sonix.forceCleanup();
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground
        _preloadFrequentlyUsedData();
        break;
      default:
        break;
    }
  }
  
  void _preloadFrequentlyUsedData() {
    // Preload commonly used waveforms
  }
}
```

### Background Processing

iOS limits background processing. Process waveforms when the app is active:

```dart
class IOSBackgroundHandler {
  static bool get canProcessInBackground {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }
  
  static Future<WaveformData?> safeGenerateWaveform(String filePath) async {
    if (!canProcessInBackground) {
      print('Cannot process waveform in background on iOS');
      return null;
    }
    
    return await Sonix.generateWaveform(filePath);
  }
}
```

## Windows

### Requirements

- **Windows**: 10 version 1903 or later
- **Architecture**: x64, x86
- **Visual Studio**: 2019 or later (for development)

### Setup

No additional setup is required. The DLL is automatically bundled with your application.

### Performance Considerations

```dart
// Windows-optimized initialization
void initializeForWindows() {
  Sonix.initialize(
    memoryLimit: 200 * 1024 * 1024, // 200MB - desktop can handle more
    maxWaveformCacheSize: 100,
    maxAudioDataCacheSize: 50,
  );
}
```

### File Path Handling

Windows has specific path requirements:

```dart
class WindowsPathHandler {
  static String normalizePath(String path) {
    // Convert forward slashes to backslashes
    return path.replaceAll('/', '\\');
  }
  
  static Future<WaveformData> generateWaveformWindows(String filePath) async {
    final normalizedPath = normalizePath(filePath);
    
    // Use absolute paths for better performance on Windows
    final absolutePath = path.isAbsolute(normalizedPath) 
      ? normalizedPath 
      : path.absolute(normalizedPath);
      
    return await Sonix.generateWaveform(absolutePath);
  }
}
```

### Registry and File Associations

For advanced integration, you can register file associations:

```dart
// This would be implemented in a separate package or native code
class WindowsFileAssociation {
  static Future<void> registerAudioFileTypes() async {
    // Register .mp3, .wav, .flac, .ogg file associations
    // This requires platform-specific implementation
  }
}
```

## macOS

### Requirements

- **macOS**: 10.14 (Mojave) or later
- **Xcode**: 12.0+
- **Architecture**: x86_64, arm64 (Apple Silicon)

### Setup

No additional setup is required. The dynamic library is automatically bundled.

### Performance Considerations

```dart
// macOS-optimized initialization
void initializeForMacOS() {
  Sonix.initialize(
    memoryLimit: 150 * 1024 * 1024, // 150MB
    maxWaveformCacheSize: 75,
    maxAudioDataCacheSize: 35,
  );
}
```

### Apple Silicon Optimization

Detect and optimize for Apple Silicon:

```dart
class MacOSOptimization {
  static bool get isAppleSilicon {
    // This would need to be implemented with platform channels
    // For now, assume we can detect it
    return Platform.isMacOS; // Simplified
  }
  
  static void optimizeForAppleSilicon() {
    if (isAppleSilicon) {
      // Apple Silicon can handle more memory and processing
      Sonix.initialize(
        memoryLimit: 200 * 1024 * 1024,
        maxWaveformCacheSize: 100,
      );
    }
  }
}
```

### Sandboxing

If your app is sandboxed, handle file access properly:

```dart
class MacOSSandboxHandler {
  static Future<WaveformData?> generateWaveformSandboxed(String filePath) async {
    try {
      // Check if file is accessible in sandbox
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File not accessible in sandbox', filePath);
      }
      
      return await Sonix.generateWaveform(filePath);
    } catch (e) {
      print('Sandbox access error: $e');
      return null;
    }
  }
}
```

## Linux

### Requirements

- **Distribution**: Ubuntu 18.04+, Fedora 28+, or equivalent
- **Architecture**: x86_64, arm64
- **Dependencies**: Automatically handled

### Setup

No additional setup is required. The shared library is automatically bundled.

### Performance Considerations

```dart
// Linux-optimized initialization
void initializeForLinux() {
  Sonix.initialize(
    memoryLimit: 100 * 1024 * 1024, // 100MB
    maxWaveformCacheSize: 50,
    maxAudioDataCacheSize: 25,
  );
}
```

### Distribution-Specific Considerations

```dart
class LinuxDistributionHandler {
  static String? getDistribution() {
    // This would need platform-specific implementation
    // Could read /etc/os-release or similar
    return null;
  }
  
  static void optimizeForDistribution() {
    final distro = getDistribution();
    
    switch (distro?.toLowerCase()) {
      case 'ubuntu':
        _optimizeForUbuntu();
        break;
      case 'fedora':
        _optimizeForFedora();
        break;
      default:
        _useDefaultOptimization();
    }
  }
  
  static void _optimizeForUbuntu() {
    // Ubuntu-specific optimizations
  }
  
  static void _optimizeForFedora() {
    // Fedora-specific optimizations
  }
  
  static void _useDefaultOptimization() {
    // Default Linux optimizations
  }
}
```

## Web

### Requirements

- **Browsers**: Chrome 88+, Firefox 85+, Safari 14+, Edge 88+
- **WebAssembly**: Automatically supported
- **Memory**: Limited by browser constraints

### Setup

No additional setup is required. WebAssembly modules are automatically loaded.

### Performance Considerations

```dart
// Web-optimized initialization
void initializeForWeb() {
  Sonix.initialize(
    memoryLimit: 50 * 1024 * 1024, // 50MB - conservative for web
    maxWaveformCacheSize: 20,
    maxAudioDataCacheSize: 10,
  );
}
```

### Browser-Specific Optimizations

```dart
class WebBrowserHandler {
  static String? getBrowserType() {
    // This would need web-specific implementation
    // Could use dart:html to detect browser
    return null;
  }
  
  static void optimizeForBrowser() {
    final browser = getBrowserType();
    
    switch (browser?.toLowerCase()) {
      case 'chrome':
        _optimizeForChrome();
        break;
      case 'firefox':
        _optimizeForFirefox();
        break;
      case 'safari':
        _optimizeForSafari();
        break;
      default:
        _useDefaultWebOptimization();
    }
  }
  
  static void _optimizeForChrome() {
    // Chrome can handle more memory
    Sonix.initialize(memoryLimit: 75 * 1024 * 1024);
  }
  
  static void _optimizeForFirefox() {
    // Firefox optimizations
    Sonix.initialize(memoryLimit: 60 * 1024 * 1024);
  }
  
  static void _optimizeForSafari() {
    // Safari is more memory-constrained
    Sonix.initialize(memoryLimit: 40 * 1024 * 1024);
  }
  
  static void _useDefaultWebOptimization() {
    // Conservative defaults for web
    Sonix.initialize(memoryLimit: 50 * 1024 * 1024);
  }
}
```

### File Access on Web

Web has different file access patterns:

```dart
class WebFileHandler {
  static Future<WaveformData?> generateWaveformFromBlob(
    html.Blob blob,
    String filename,
  ) async {
    try {
      // Convert blob to file path (web-specific implementation needed)
      final filePath = await _blobToFilePath(blob, filename);
      return await Sonix.generateWaveform(filePath);
    } catch (e) {
      print('Web file processing error: $e');
      return null;
    }
  }
  
  static Future<String> _blobToFilePath(html.Blob blob, String filename) async {
    // This would need web-specific implementation
    // Could use FileReader API or similar
    throw UnimplementedError('Web blob handling not implemented');
  }
}
```

## Cross-Platform Considerations

### Platform Detection

```dart
class PlatformOptimizer {
  static void initializeForCurrentPlatform() {
    if (Platform.isAndroid) {
      initializeForAndroid();
    } else if (Platform.isIOS) {
      initializeForIOS();
    } else if (Platform.isWindows) {
      initializeForWindows();
    } else if (Platform.isMacOS) {
      initializeForMacOS();
    } else if (Platform.isLinux) {
      initializeForLinux();
    } else if (kIsWeb) {
      initializeForWeb();
    } else {
      // Fallback for unknown platforms
      Sonix.initialize();
    }
  }
  
  static int getOptimalMemoryLimit() {
    if (Platform.isAndroid || Platform.isIOS) {
      return 50 * 1024 * 1024; // 50MB for mobile
    } else if (kIsWeb) {
      return 50 * 1024 * 1024; // 50MB for web
    } else {
      return 150 * 1024 * 1024; // 150MB for desktop
    }
  }
  
  static ProcessingMethod getOptimalProcessingMethod(int fileSize) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final threshold = isMobile ? 25 * 1024 * 1024 : 100 * 1024 * 1024;
    
    if (fileSize > threshold) {
      return ProcessingMethod.memoryEfficient;
    } else {
      return ProcessingMethod.standard;
    }
  }
}
```

### Universal File Path Handling

```dart
class UniversalPathHandler {
  static String normalizePath(String path) {
    if (Platform.isWindows) {
      return path.replaceAll('/', '\\');
    } else {
      return path.replaceAll('\\', '/');
    }
  }
  
  static Future<bool> isFileAccessible(String filePath) async {
    try {
      final file = File(normalizePath(filePath));
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
  
  static Future<WaveformData?> safeGenerateWaveform(String filePath) async {
    final normalizedPath = normalizePath(filePath);
    
    if (!await isFileAccessible(normalizedPath)) {
      print('File not accessible: $normalizedPath');
      return null;
    }
    
    try {
      return await Sonix.generateWaveformAdaptive(normalizedPath);
    } catch (e) {
      print('Platform-specific error: $e');
      return null;
    }
  }
}
```

### Testing Across Platforms

```dart
class PlatformTester {
  static Future<void> runPlatformTests() async {
    print('Running platform-specific tests...');
    
    // Test initialization
    await _testInitialization();
    
    // Test file access
    await _testFileAccess();
    
    // Test memory management
    await _testMemoryManagement();
    
    // Test performance
    await _testPerformance();
    
    print('Platform tests completed');
  }
  
  static Future<void> _testInitialization() async {
    try {
      PlatformOptimizer.initializeForCurrentPlatform();
      print('✓ Platform initialization successful');
    } catch (e) {
      print('✗ Platform initialization failed: $e');
    }
  }
  
  static Future<void> _testFileAccess() async {
    // Test with a known file
    const testFile = 'assets/test_audio.mp3';
    
    try {
      final accessible = await UniversalPathHandler.isFileAccessible(testFile);
      print('✓ File access test: ${accessible ? "accessible" : "not accessible"}');
    } catch (e) {
      print('✗ File access test failed: $e');
    }
  }
  
  static Future<void> _testMemoryManagement() async {
    try {
      final stats = Sonix.getResourceStatistics();
      print('✓ Memory management test: ${stats.memoryUsagePercentage * 100}% usage');
    } catch (e) {
      print('✗ Memory management test failed: $e');
    }
  }
  
  static Future<void> _testPerformance() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Test with a small sample
      final waveform = await Sonix.generateWaveform(
        'assets/test_audio.mp3',
        resolution: 100,
      );
      
      stopwatch.stop();
      print('✓ Performance test: ${stopwatch.elapsedMilliseconds}ms for ${waveform.amplitudes.length} points');
    } catch (e) {
      stopwatch.stop();
      print('✗ Performance test failed after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }
}
```

## Conclusion

Each platform has its own characteristics and constraints. By following the platform-specific guidelines in this document, you can ensure optimal performance and user experience across all supported platforms.

Key takeaways:
- Mobile platforms (Android/iOS) require more conservative memory limits
- Desktop platforms can handle larger memory limits and file sizes
- Web has unique constraints due to browser limitations
- Always test on target platforms to ensure optimal performance
- Use platform detection to automatically optimize settings

For platform-specific issues, refer to the [troubleshooting section](PERFORMANCE_GUIDE.md#troubleshooting) in the Performance Guide.