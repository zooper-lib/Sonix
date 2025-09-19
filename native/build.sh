#!/bin/bash

# Build script for Sonix native library
# Usage: ./build.sh [platform] [build_type]
# platform: android, ios, windows, macos, linux, all
# build_type: debug, release (default: release)

set -e

PLATFORM=${1:-all}
BUILD_TYPE=${2:-release}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

echo "Building Sonix native library..."
echo "Platform: $PLATFORM"
echo "Build type: $BUILD_TYPE"

# Create build directory
mkdir -p "$BUILD_DIR"

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local cmake_file="$SCRIPT_DIR/$platform/CMakeLists.txt"
    local platform_build_dir="$BUILD_DIR/$platform"
    
    if [ ! -f "$cmake_file" ]; then
        echo "Warning: CMakeLists.txt not found for $platform, using main CMakeLists.txt"
        cmake_file="$SCRIPT_DIR/CMakeLists.txt"
    fi
    
    echo "Building for $platform..."
    mkdir -p "$platform_build_dir"
    cd "$platform_build_dir"
    
    # Configure CMake based on platform
    case $platform in
        android)
            echo "Android build requires NDK setup - skipping automated build"
            echo "Use: flutter build apk or flutter build appbundle"
            ;;
        ios)
            echo "iOS build uses CocoaPods - skipping automated build"
            echo "Use: flutter build ios"
            ;;
        windows)
            cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_BUILD_TYPE=$BUILD_TYPE -S "$SCRIPT_DIR" -B .
            cmake --build . --config $BUILD_TYPE
            ;;
        macos)
            cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE -S "$SCRIPT_DIR" -B .
            make -j$(sysctl -n hw.ncpu)
            ;;
        linux)
            cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE -S "$SCRIPT_DIR" -B .
            make -j$(nproc)
            ;;
        *)
            echo "Unknown platform: $platform"
            return 1
            ;;
    esac
    
    cd "$SCRIPT_DIR"
}

# Build for specified platform(s)
if [ "$PLATFORM" = "all" ]; then
    # Detect current platform and build accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        build_platform "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        build_platform "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        build_platform "windows"
    else
        echo "Unknown OS type: $OSTYPE"
        exit 1
    fi
else
    build_platform "$PLATFORM"
fi

echo "Build completed successfully!"