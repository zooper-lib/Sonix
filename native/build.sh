#!/bin/bash

# Build script for Unix-like systems (Linux/macOS)

set -e

echo "Building Sonix native library with FFMPEG..."

# Create build directory
mkdir -p build
cd build

# Configure with CMake
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo "Build completed successfully!"
echo "Native library built in: $(pwd)"

# List built files
ls -la *.so *.dylib 2>/dev/null || true