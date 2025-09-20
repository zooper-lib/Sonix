#!/bin/bash

# Sonix Native Library Build Script
# Builds the native library with FFMPEG integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_DIR="${SCRIPT_DIR}/../example"

print_status "Building Sonix Native Library"
print_status "Script directory: ${SCRIPT_DIR}"

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    LIB_NAME="libsonix_native.so"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    LIB_NAME="libsonix_native.dylib"
else
    print_error "Unsupported platform: $OSTYPE"
    exit 1
fi

print_status "Detected platform: ${PLATFORM}"

# Check for FFMPEG libraries
FFMPEG_DIR="${SCRIPT_DIR}/${PLATFORM}"
if [[ -d "${FFMPEG_DIR}" ]] && [[ -f "${FFMPEG_DIR}/libavformat.so" || -f "${FFMPEG_DIR}/libavformat.dylib" ]]; then
    print_status "FFMPEG libraries found in ${FFMPEG_DIR}"
    USE_FFMPEG=ON
else
    print_warning "FFMPEG libraries not found in ${FFMPEG_DIR}"
    print_warning "Building with stub implementation"
    print_warning "Run 'dart run tools/setup_ffmpeg.dart' to build FFMPEG libraries"
    USE_FFMPEG=OFF
fi

# Configure with CMake
print_status "Configuring build with CMake..."
cmake "${SCRIPT_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${OUTPUT_DIR}"

# Build
print_status "Building native library..."
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Install/copy to output directory
print_status "Installing to ${OUTPUT_DIR}..."
make install

# Copy library to example directory for testing
if [[ -f "${LIB_NAME}" ]]; then
    cp "${LIB_NAME}" "${OUTPUT_DIR}/"
    print_status "Copied ${LIB_NAME} to ${OUTPUT_DIR}/"
else
    print_error "Built library ${LIB_NAME} not found"
    exit 1
fi

# Copy FFMPEG libraries if they exist
if [[ "${USE_FFMPEG}" == "ON" ]]; then
    print_status "Copying FFMPEG libraries..."
    if [[ "$PLATFORM" == "linux" ]]; then
        cp "${FFMPEG_DIR}"/lib*.so* "${OUTPUT_DIR}/" 2>/dev/null || true
    elif [[ "$PLATFORM" == "macos" ]]; then
        cp "${FFMPEG_DIR}"/lib*.dylib "${OUTPUT_DIR}/" 2>/dev/null || true
    fi
fi

print_status "Build completed successfully!"
print_status "Native library: ${OUTPUT_DIR}/${LIB_NAME}"

# Verify the library
if command -v ldd >/dev/null 2>&1; then
    print_status "Library dependencies:"
    ldd "${OUTPUT_DIR}/${LIB_NAME}" || true
elif command -v otool >/dev/null 2>&1; then
    print_status "Library dependencies:"
    otool -L "${OUTPUT_DIR}/${LIB_NAME}" || true
fi