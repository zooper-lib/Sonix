cmake_minimum_required(VERSION 3.10)
project(sonix_native)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Define source files
set(SOURCES
    src/sonix_native.c
    src/stb_vorbis_wrapper.c
)

# Define header directories
set(INCLUDE_DIRS
    src
    src/minimp3
    src/dr_flac
    src/dr_wav
    src/stb_vorbis
    src/opus
)

# Create shared library
add_library(sonix_native SHARED ${SOURCES})

# Set include directories
target_include_directories(sonix_native PRIVATE ${INCLUDE_DIRS})

# Platform-specific configurations
if(WIN32)
    # Windows-specific settings
    set_target_properties(sonix_native PROPERTIES
        OUTPUT_NAME "sonix_native"
        SUFFIX ".dll"
    )
    target_compile_definitions(sonix_native PRIVATE WIN32_LEAN_AND_MEAN)
elseif(APPLE)
    # macOS/iOS-specific settings
    set_target_properties(sonix_native PROPERTIES
        OUTPUT_NAME "sonix_native"
        SUFFIX ".dylib"
        MACOSX_RPATH TRUE
    )
elseif(ANDROID)
    # Android-specific settings
    set_target_properties(sonix_native PROPERTIES
        OUTPUT_NAME "sonix_native"
    )
    target_link_libraries(sonix_native log)
else()
    # Linux-specific settings
    set_target_properties(sonix_native PROPERTIES
        OUTPUT_NAME "sonix_native"
        SUFFIX ".so"
    )
endif()

# Compiler flags for optimization
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(sonix_native PRIVATE -O3)
else()
    target_compile_options(sonix_native PRIVATE -g -O0)
endif()

# Export symbols for shared library
if(WIN32)
    target_compile_definitions(sonix_native PRIVATE SONIX_EXPORT=__declspec\(dllexport\))
else()
    target_compile_definitions(sonix_native PRIVATE SONIX_EXPORT=__attribute__\(\(visibility\(\"default\"\)\)\))
endif()