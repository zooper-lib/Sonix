cmake_minimum_required(VERSION 3.15)
project(sonix_native)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Define source files
set(SOURCES
    ../src/sonix_native.c
)

# Define header directories
set(INCLUDE_DIRS
    ../src
    ../src/minimp3
    ../src/dr_flac
    ../src/dr_wav
    ../src/stb_vorbis
    ../src/opus
)

# Create shared library (dylib)
add_library(sonix_native SHARED ${SOURCES})

# Set include directories
target_include_directories(sonix_native PRIVATE ${INCLUDE_DIRS})

# macOS-specific settings
target_compile_definitions(sonix_native PRIVATE MACOS)

# Set output properties
set_target_properties(sonix_native PROPERTIES
    OUTPUT_NAME "sonix_native"
    SUFFIX ".dylib"
    MACOSX_RPATH TRUE
    INSTALL_RPATH "@loader_path"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../build/macos"
)

# Optimization flags
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(sonix_native PRIVATE -O3 -ffast-math)
else()
    target_compile_options(sonix_native PRIVATE -g -O0)
endif()

# Set minimum macOS version
set_target_properties(sonix_native PROPERTIES
    OSX_DEPLOYMENT_TARGET "10.13"
)