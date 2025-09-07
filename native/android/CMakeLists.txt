cmake_minimum_required(VERSION 3.18.1)
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

# Create shared library for Android
add_library(sonix_native SHARED ${SOURCES})

# Set include directories
target_include_directories(sonix_native PRIVATE ${INCLUDE_DIRS})

# Android-specific settings
target_compile_definitions(sonix_native PRIVATE ANDROID)
target_link_libraries(sonix_native log)

# Optimization flags
target_compile_options(sonix_native PRIVATE -O3 -ffast-math)

# Strip symbols in release builds
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set_target_properties(sonix_native PROPERTIES LINK_FLAGS_RELEASE -s)
endif()

# Set output directory based on Android ABI
set_target_properties(sonix_native PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../build/android/${ANDROID_ABI}"
)