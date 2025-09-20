cmake_minimum_required(VERSION 3.10)
project(sonix_native)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Define source files
set(SOURCES
    src/sonix_native.c
    src/stb_vorbis_wrapper.c
    src/mp4_container.c
    src/mp4_decoder.c
)

# Define header directories
set(INCLUDE_DIRS
    src
    src/minimp3
    src/dr_flac
    src/dr_wav
    src/stb_vorbis
    src/opus
    src/faad2
)

# Find FAAD2 library
find_library(FAAD2_LIBRARY NAMES faad2 faad libfaad2 libfaad)
find_path(FAAD2_INCLUDE_DIR NAMES neaacdec.h PATHS /usr/include /usr/local/include /opt/homebrew/include)

# Create shared library
add_library(sonix_native SHARED ${SOURCES})

# Set include directories
target_include_directories(sonix_native PRIVATE ${INCLUDE_DIRS})

# Link FAAD2 library if found
if(FAAD2_LIBRARY AND FAAD2_INCLUDE_DIR)
    target_link_libraries(sonix_native ${FAAD2_LIBRARY})
    target_include_directories(sonix_native PRIVATE ${FAAD2_INCLUDE_DIR})
    target_compile_definitions(sonix_native PRIVATE HAVE_FAAD2=1)
    message(STATUS "Found FAAD2: ${FAAD2_LIBRARY}")
else()
    message(WARNING "FAAD2 library not found. MP4/AAC decoding will be disabled.")
    target_compile_definitions(sonix_native PRIVATE HAVE_FAAD2=0)
endif()

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

# Optional: Build test executable for MP4 container parsing
option(BUILD_TESTS "Build test executables" OFF)
if(BUILD_TESTS)
    add_executable(mp4_container_test
        src/mp4_container_test.c
        src/mp4_container.c
    )
    target_include_directories(mp4_container_test PRIVATE src)
    
    add_executable(mp4_integration_test
        src/mp4_integration_test.c
        src/mp4_container.c
        src/mp4_decoder.c
        src/sonix_native.c
        src/stb_vorbis_wrapper.c
    )
    target_include_directories(mp4_integration_test PRIVATE src src/minimp3 src/dr_flac src/dr_wav src/stb_vorbis src/opus)
    
    # Link FAAD2 to integration test if available
    if(FAAD2_LIBRARY AND FAAD2_INCLUDE_DIR)
        target_link_libraries(mp4_integration_test ${FAAD2_LIBRARY})
        target_include_directories(mp4_integration_test PRIVATE ${FAAD2_INCLUDE_DIR})
        target_compile_definitions(mp4_integration_test PRIVATE HAVE_FAAD2=1)
    else()
        target_compile_definitions(mp4_integration_test PRIVATE HAVE_FAAD2=0)
    endif()
    
    add_executable(mp4_faad2_test
        src/mp4_faad2_test.c
        src/mp4_decoder.c
        src/mp4_container.c
        src/sonix_native.c
        src/stb_vorbis_wrapper.c
    )
    target_include_directories(mp4_faad2_test PRIVATE src src/minimp3 src/dr_flac src/dr_wav src/stb_vorbis src/opus)
    
    add_executable(mp4_real_file_test
        src/mp4_real_file_test.c
        src/mp4_decoder.c
        src/mp4_container.c
        src/sonix_native.c
        src/stb_vorbis_wrapper.c
    )
    target_include_directories(mp4_real_file_test PRIVATE src src/minimp3 src/dr_flac src/dr_wav src/stb_vorbis src/opus)
    
    # Link FAAD2 to test executables if available
    if(FAAD2_LIBRARY AND FAAD2_INCLUDE_DIR)
        target_link_libraries(mp4_faad2_test ${FAAD2_LIBRARY})
        target_include_directories(mp4_faad2_test PRIVATE ${FAAD2_INCLUDE_DIR})
        target_compile_definitions(mp4_faad2_test PRIVATE HAVE_FAAD2=1)
        
        target_link_libraries(mp4_integration_test ${FAAD2_LIBRARY})
        target_include_directories(mp4_integration_test PRIVATE ${FAAD2_INCLUDE_DIR})
        target_compile_definitions(mp4_integration_test PRIVATE HAVE_FAAD2=1)
        
        target_link_libraries(mp4_real_file_test ${FAAD2_LIBRARY})
        target_include_directories(mp4_real_file_test PRIVATE ${FAAD2_INCLUDE_DIR})
        target_compile_definitions(mp4_real_file_test PRIVATE HAVE_FAAD2=1)
    else()
        target_compile_definitions(mp4_faad2_test PRIVATE HAVE_FAAD2=0)
        target_compile_definitions(mp4_integration_test PRIVATE HAVE_FAAD2=0)
        target_compile_definitions(mp4_real_file_test PRIVATE HAVE_FAAD2=0)
    endif()
    
    # Platform-specific test configurations
    if(WIN32)
        target_compile_definitions(mp4_container_test PRIVATE WIN32_LEAN_AND_MEAN)
        target_compile_definitions(mp4_integration_test PRIVATE WIN32_LEAN_AND_MEAN)
    endif()
endif()