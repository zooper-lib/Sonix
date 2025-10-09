cmake_minimum_required(VERSION 3.10)
project(sonix_native)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Force CMake to use install RPATH even during build phase
# This prevents hardcoded CI build paths from being embedded in the library
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)

# Determine platform-specific directory
if(WIN32)
    set(PLATFORM_NAME "windows")
    set(LIBRARY_EXTENSION ".dll")
elseif(APPLE)
    set(PLATFORM_NAME "macos")
    set(LIBRARY_EXTENSION ".dylib")
elseif(UNIX)
    set(PLATFORM_NAME "linux")
    set(LIBRARY_EXTENSION ".so")
endif()

# CRITICAL: Look for FFMPEG libraries in platform-specific directories
# Check if FFMPEG_ROOT is provided, otherwise use the old default location
if(DEFINED FFMPEG_ROOT)
    # Convert to absolute path if it's relative
    if(IS_ABSOLUTE ${FFMPEG_ROOT})
        set(FFMPEG_ROOT_DIR "${FFMPEG_ROOT}")
    else()
        set(FFMPEG_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../${FFMPEG_ROOT}")
    endif()
else()
    set(FFMPEG_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}")
endif()

message(STATUS "Looking for FFMPEG libraries in: ${FFMPEG_ROOT_DIR}")

# REQUIRE FFMPEG libraries - NO FALLBACKS
find_library(AVFORMAT_LIBRARY 
    NAMES avformat
    PATHS ${FFMPEG_ROOT_DIR}/lib
    NO_DEFAULT_PATH 
    REQUIRED)

find_library(AVCODEC_LIBRARY 
    NAMES avcodec
    PATHS ${FFMPEG_ROOT_DIR}/lib
    NO_DEFAULT_PATH 
    REQUIRED)

find_library(AVUTIL_LIBRARY 
    NAMES avutil
    PATHS ${FFMPEG_ROOT_DIR}/lib
    NO_DEFAULT_PATH 
    REQUIRED)

find_library(SWRESAMPLE_LIBRARY 
    NAMES swresample
    PATHS ${FFMPEG_ROOT_DIR}/lib
    NO_DEFAULT_PATH 
    REQUIRED)

# Fail if any library is missing
if(NOT AVFORMAT_LIBRARY OR NOT AVCODEC_LIBRARY OR NOT AVUTIL_LIBRARY OR NOT SWRESAMPLE_LIBRARY)
    message(FATAL_ERROR "FFMPEG libraries are required in native/${PLATFORM_NAME}/lib/. Please ensure FFMPEG development files are downloaded.")
endif()

message(STATUS "Found FFMPEG libraries:")
message(STATUS "  avformat: ${AVFORMAT_LIBRARY}")
message(STATUS "  avcodec: ${AVCODEC_LIBRARY}")
message(STATUS "  avutil: ${AVUTIL_LIBRARY}")
message(STATUS "  swresample: ${SWRESAMPLE_LIBRARY}")

# Find FFMPEG headers
find_path(FFMPEG_INCLUDE_DIR 
    NAMES libavformat/avformat.h
    PATHS ${FFMPEG_ROOT_DIR}/include
    NO_DEFAULT_PATH
    REQUIRED)

if(NOT FFMPEG_INCLUDE_DIR)
    message(FATAL_ERROR "FFMPEG headers not found in ${FFMPEG_ROOT_DIR}/include. Please ensure FFMPEG development files are downloaded.")
endif()

message(STATUS "Found FFMPEG headers: ${FFMPEG_INCLUDE_DIR}")

# Create the native library
add_library(sonix_native SHARED
    src/sonix_ffmpeg.c
)

# Include FFMPEG headers
target_include_directories(sonix_native PRIVATE 
    ${FFMPEG_INCLUDE_DIR}
    src/
)

# Link FFMPEG libraries
target_link_libraries(sonix_native 
    ${AVFORMAT_LIBRARY}
    ${AVCODEC_LIBRARY} 
    ${AVUTIL_LIBRARY}
    ${SWRESAMPLE_LIBRARY}
)

# Platform-specific configurations
if(WIN32)
    # Windows-specific settings
    target_compile_definitions(sonix_native PRIVATE WIN32_LEAN_AND_MEAN SONIX_NATIVE_EXPORTS)

elseif(APPLE)
    # macOS-specific settings
    # Set deployment target to match Flutter's minimum (10.15)
    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING "Minimum macOS deployment version")
    endif()
    
    set_target_properties(sonix_native PROPERTIES
        MACOSX_RPATH TRUE
        INSTALL_RPATH "@loader_path"
    )

elseif(UNIX)
    # Linux-specific settings
    set_target_properties(sonix_native PROPERTIES
        INSTALL_RPATH "$ORIGIN"
    )
endif()

# For Flutter packages, the native library will be built by the consuming app
# No need to copy files - the Flutter build system handles this