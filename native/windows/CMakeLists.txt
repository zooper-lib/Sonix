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
)

# Create shared library (DLL)
add_library(sonix_native SHARED ${SOURCES} sonix_native.def)

# Set include directories
target_include_directories(sonix_native PRIVATE ${INCLUDE_DIRS})

# Windows-specific settings
target_compile_definitions(sonix_native PRIVATE 
    WIN32_LEAN_AND_MEAN
    _CRT_SECURE_NO_WARNINGS
    SONIX_BUILDING_DLL
)

# Set output properties
set_target_properties(sonix_native PROPERTIES
    OUTPUT_NAME "sonix_native"
    SUFFIX ".dll"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../build/windows"
)

# Optimization flags
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(sonix_native PRIVATE /O2 /fp:fast)
else()
    target_compile_options(sonix_native PRIVATE /Od /Zi)
endif()

# Link against Windows libraries if needed
# target_link_libraries(sonix_native kernel32 user32)