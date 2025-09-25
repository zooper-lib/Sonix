cmake_minimum_required(VERSION 3.10)

project(sonix_native)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Platform detection
if(WIN32)
    set(PLATFORM_NAME "windows")
    set(LIB_EXTENSION ".dll")
    set(LIB_PREFIX "")
elseif(APPLE)
    if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
        set(PLATFORM_NAME "ios")
        set(LIB_EXTENSION ".framework")
        set(LIB_PREFIX "")
    else()
        set(PLATFORM_NAME "macos")
        set(LIB_EXTENSION ".dylib")
        set(LIB_PREFIX "lib")
    endif()
elseif(ANDROID)
    set(PLATFORM_NAME "android")
    set(LIB_EXTENSION ".so")
    set(LIB_PREFIX "lib")
elseif(UNIX)
    set(PLATFORM_NAME "linux")
    set(LIB_EXTENSION ".so")
    set(LIB_PREFIX "lib")
else()
    message(FATAL_ERROR "Unsupported platform")
endif()

# FFMPEG library paths
set(FFMPEG_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}")

# Find FFMPEG libraries
find_library(AVFORMAT_LIBRARY
    NAMES avformat avformat-60
    PATHS ${FFMPEG_ROOT_DIR}
    NO_DEFAULT_PATH
)

find_library(AVCODEC_LIBRARY
    NAMES avcodec avcodec-60
    PATHS ${FFMPEG_ROOT_DIR}
    NO_DEFAULT_PATH
)

find_library(AVUTIL_LIBRARY
    NAMES avutil avutil-58
    PATHS ${FFMPEG_ROOT_DIR}
    NO_DEFAULT_PATH
)

find_library(SWRESAMPLE_LIBRARY
    NAMES swresample swresample-4
    PATHS ${FFMPEG_ROOT_DIR}
    NO_DEFAULT_PATH
)

# Check if FFMPEG libraries are found
if(WIN32 AND EXISTS "${FFMPEG_ROOT_DIR}/avformat-60.dll")
    # On Windows, check for DLL files directly
    message(STATUS "Found FFMPEG DLL libraries in ${FFMPEG_ROOT_DIR}")
    message(STATUS "  avformat: ${FFMPEG_ROOT_DIR}/avformat-60.dll")
    message(STATUS "  avcodec: ${FFMPEG_ROOT_DIR}/avcodec-60.dll") 
    message(STATUS "  avutil: ${FFMPEG_ROOT_DIR}/avutil-58.dll")
    message(STATUS "  swresample: ${FFMPEG_ROOT_DIR}/swresample-4.dll")
    
    # Set library paths for Windows DLLs
    set(AVFORMAT_LIBRARY "${FFMPEG_ROOT_DIR}/avformat-60.dll")
    set(AVCODEC_LIBRARY "${FFMPEG_ROOT_DIR}/avcodec-60.dll") 
    set(AVUTIL_LIBRARY "${FFMPEG_ROOT_DIR}/avutil-58.dll")
    set(SWRESAMPLE_LIBRARY "${FFMPEG_ROOT_DIR}/swresample-4.dll")
elseif(NOT AVFORMAT_LIBRARY OR NOT AVCODEC_LIBRARY OR NOT AVUTIL_LIBRARY OR NOT SWRESAMPLE_LIBRARY)
    message(FATAL_ERROR "FFMPEG libraries not found in ${FFMPEG_ROOT_DIR}. Required libraries: avformat, avcodec, avutil, swresample. Please provide FFMPEG binaries in the native/${PLATFORM_NAME}/ directory.")
else()
    message(STATUS "Found FFMPEG libraries:")
    message(STATUS "  avformat: ${AVFORMAT_LIBRARY}")
    message(STATUS "  avcodec: ${AVCODEC_LIBRARY}")
    message(STATUS "  avutil: ${AVUTIL_LIBRARY}")
    message(STATUS "  swresample: ${SWRESAMPLE_LIBRARY}")
endif()

# Source files
set(SOURCES
    src/ffmpeg_wrapper.c
)

# Create shared library
add_library(sonix_native SHARED ${SOURCES})

# Set output name
set_target_properties(sonix_native PROPERTIES
    OUTPUT_NAME "sonix_native"
    PREFIX "${LIB_PREFIX}"
    SUFFIX "${LIB_EXTENSION}"
)

# Include directories for FFMPEG headers - check multiple possible locations
set(FFMPEG_INCLUDE_DIRS "")

# Try to find include directory
if(EXISTS "${FFMPEG_ROOT_DIR}/include")
    list(APPEND FFMPEG_INCLUDE_DIRS "${FFMPEG_ROOT_DIR}/include")
endif()

if(FFMPEG_INCLUDE_DIRS)
    target_include_directories(sonix_native PRIVATE ${FFMPEG_INCLUDE_DIRS})
    message(STATUS "Using FFMPEG headers from: ${FFMPEG_INCLUDE_DIRS}")
else()
    message(FATAL_ERROR "Could not find FFMPEG headers in ${FFMPEG_ROOT_DIR}/include")
endif()

# Link FFMPEG libraries
target_link_libraries(sonix_native
    ${AVFORMAT_LIBRARY}
    ${AVCODEC_LIBRARY}
    ${AVUTIL_LIBRARY}
    ${SWRESAMPLE_LIBRARY}
)

target_compile_definitions(sonix_native PRIVATE USE_FFMPEG=1)
message(STATUS "Building with FFMPEG integration")

# Platform-specific settings
if(WIN32)
    # Windows-specific settings
    target_compile_definitions(sonix_native PRIVATE _CRT_SECURE_NO_WARNINGS)
    
    # Copy FFMPEG DLLs to output directory
    add_custom_command(TARGET sonix_native POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/avformat${LIB_EXTENSION}"
            "$<TARGET_FILE_DIR:sonix_native>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/avcodec${LIB_EXTENSION}"
            "$<TARGET_FILE_DIR:sonix_native>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/avutil${LIB_EXTENSION}"
            "$<TARGET_FILE_DIR:sonix_native>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/swresample${LIB_EXTENSION}"
            "$<TARGET_FILE_DIR:sonix_native>"
        COMMENT "Copying FFMPEG DLLs to output directory"
    )
    
elseif(APPLE)
    # macOS/iOS-specific settings
    if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
        set_target_properties(sonix_native PROPERTIES
            FRAMEWORK TRUE
            FRAMEWORK_VERSION A
            MACOSX_FRAMEWORK_IDENTIFIER com.sonix.native
        )
    endif()
    
elseif(ANDROID)
    # Android-specific settings
    target_link_libraries(sonix_native log)
    
elseif(UNIX)
    # Linux-specific settings
    target_link_libraries(sonix_native m)
endif()

# Install targets
install(TARGETS sonix_native
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
    FRAMEWORK DESTINATION Frameworks
)

# Install FFMPEG libraries on platforms that need them
if(WIN32 OR APPLE OR UNIX)
    install(FILES
        ${AVFORMAT_LIBRARY}
        ${AVCODEC_LIBRARY}
        ${AVUTIL_LIBRARY}
        ${SWRESAMPLE_LIBRARY}
        DESTINATION lib
        OPTIONAL
    )
endif()

# Build information
message(STATUS "Sonix Native Library Configuration:")
message(STATUS "  Platform: ${PLATFORM_NAME}")
message(STATUS "  Library extension: ${LIB_EXTENSION}")
message(STATUS "  Using FFMPEG: TRUE")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")