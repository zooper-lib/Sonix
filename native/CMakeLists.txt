cmake_minimum_required(VERSION 3.10)
project(sonix_native)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
# Option: prefer using system-installed FFmpeg (e.g., Homebrew) over local binaries
option(SONIX_USE_SYSTEM_FFMPEG "Use system-installed FFmpeg (Homebrew, system lib paths)" ON)


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

if(SONIX_USE_SYSTEM_FFMPEG)
    message(STATUS "SONIX_USE_SYSTEM_FFMPEG=ON — searching system/default paths for FFmpeg")
    # Clear any cached library/header paths from previous non-system builds to avoid stale references
    unset(AVFORMAT_LIBRARY CACHE)
    unset(AVCODEC_LIBRARY CACHE)
    unset(AVUTIL_LIBRARY CACHE)
    unset(SWRESAMPLE_LIBRARY CACHE)
    unset(FFMPEG_INCLUDE_DIR CACHE)
    # Allow CMake to search default system locations (Homebrew, /usr/local, etc.).
    # If a brew prefix is provided, prefer it explicitly, and also query the specific ffmpeg prefix.
    set(_FFMPEG_LIB_HINTS)
    set(_FFMPEG_INCLUDE_HINTS)
    if(DEFINED SONIX_BREW_PREFIX)
        message(STATUS "Using Homebrew prefix: ${SONIX_BREW_PREFIX}")
        list(APPEND _FFMPEG_LIB_HINTS
            ${SONIX_BREW_PREFIX}/opt/ffmpeg/lib
            ${SONIX_BREW_PREFIX}/opt/ffmpeg@6/lib
            ${SONIX_BREW_PREFIX}/lib
        )
        list(APPEND _FFMPEG_INCLUDE_HINTS
            ${SONIX_BREW_PREFIX}/opt/ffmpeg/include
            ${SONIX_BREW_PREFIX}/opt/ffmpeg@6/include
            ${SONIX_BREW_PREFIX}/include
        )
        # Try to get the exact prefix for the installed ffmpeg formula (resolves Cellar path)
        if(EXISTS ${SONIX_BREW_PREFIX}/bin/brew)
            execute_process(
                COMMAND ${SONIX_BREW_PREFIX}/bin/brew --prefix ffmpeg
                OUTPUT_VARIABLE _BREW_FFMPEG_PREFIX
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET
            )
            if(_BREW_FFMPEG_PREFIX)
                message(STATUS "brew --prefix ffmpeg: ${_BREW_FFMPEG_PREFIX}")
                list(APPEND _FFMPEG_LIB_HINTS ${_BREW_FFMPEG_PREFIX}/lib)
                list(APPEND _FFMPEG_INCLUDE_HINTS ${_BREW_FFMPEG_PREFIX}/include)
            endif()
        endif()
    endif()
    # Also add common default locations for Apple Silicon/Intel Macs and generic UNIX
    list(APPEND _FFMPEG_LIB_HINTS
        /opt/homebrew/opt/ffmpeg/lib
        /opt/homebrew/lib
        /usr/local/opt/ffmpeg/lib
        /usr/local/lib
        /opt/local/lib
    )
    list(APPEND _FFMPEG_INCLUDE_HINTS
        /opt/homebrew/opt/ffmpeg/include
        /opt/homebrew/include
        /usr/local/opt/ffmpeg/include
        /usr/local/include
        /opt/local/include
    )
    
    # Add Windows-specific paths for Chocolatey and manual FFmpeg installations
    if(WIN32)
        list(APPEND _FFMPEG_LIB_HINTS
            "C:/tools/msys64/mingw64/lib"
            "C:/ProgramData/chocolatey/lib/ffmpeg/tools/ffmpeg/bin"
            "C:/ProgramData/chocolatey/lib/ffmpeg/tools/ffmpeg/lib"
            "C:/ffmpeg/bin"
            "C:/ffmpeg/lib"
            "$ENV{PROGRAMFILES}/ffmpeg/bin"
            "$ENV{PROGRAMFILES}/ffmpeg/lib"
        )
        list(APPEND _FFMPEG_INCLUDE_HINTS
            "C:/tools/msys64/mingw64/include"
            "C:/ProgramData/chocolatey/lib/ffmpeg/tools/ffmpeg/include"
            "C:/ffmpeg/include"
            "$ENV{PROGRAMFILES}/ffmpeg/include"
        )
    endif()
    
    find_library(AVFORMAT_LIBRARY NAMES avformat HINTS ${_FFMPEG_LIB_HINTS} REQUIRED)
    find_library(AVCODEC_LIBRARY  NAMES avcodec  HINTS ${_FFMPEG_LIB_HINTS} REQUIRED)
    find_library(AVUTIL_LIBRARY   NAMES avutil   HINTS ${_FFMPEG_LIB_HINTS} REQUIRED)
    find_library(SWRESAMPLE_LIBRARY NAMES swresample HINTS ${_FFMPEG_LIB_HINTS} REQUIRED)
    find_path(FFMPEG_INCLUDE_DIR NAMES libavformat/avformat.h HINTS ${_FFMPEG_INCLUDE_HINTS} REQUIRED)

    message(STATUS "Found system FFmpeg libraries:")
    message(STATUS "  avformat: ${AVFORMAT_LIBRARY}")
    message(STATUS "  avcodec: ${AVCODEC_LIBRARY}")
    message(STATUS "  avutil: ${AVUTIL_LIBRARY}")
    message(STATUS "  swresample: ${SWRESAMPLE_LIBRARY}")
    message(STATUS "Found FFmpeg headers: ${FFMPEG_INCLUDE_DIR}")
else()
    message(FATAL_ERROR "System FFmpeg is required. Reconfigure with -DSONIX_USE_SYSTEM_FFMPEG=ON")
endif()

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
    # Ensure DLL name does not get a 'lib' prefix when using MinGW/Ninja
    set_target_properties(sonix_native PROPERTIES PREFIX "")
    # Place the DLL in the binary (build) directory for single-config generators like Ninja
    set_target_properties(sonix_native PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")

elseif(APPLE)
    # macOS-specific settings
    # Set deployment target to match Flutter's minimum (10.15)
    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING "Minimum macOS deployment version")
    endif()
    
    # Base rpath always includes @loader_path so local colocated libs can be found
    set(_SONIX_MAC_BASE_RPATH "@loader_path")

    # If we're using system FFmpeg, also include the directory that contains the discovered FFmpeg libs
    if(SONIX_USE_SYSTEM_FFMPEG)
        get_filename_component(_FFMPEG_LIB_DIR ${AVFORMAT_LIBRARY} DIRECTORY)
        if(_FFMPEG_LIB_DIR)
            set(_SONIX_MAC_BASE_RPATH "${_SONIX_MAC_BASE_RPATH};${_FFMPEG_LIB_DIR}")
            message(STATUS "Adding FFmpeg lib dir to INSTALL_RPATH: ${_FFMPEG_LIB_DIR}")
        endif()
    endif()

    set_target_properties(sonix_native PROPERTIES
        MACOSX_RPATH TRUE
        INSTALL_RPATH "${_SONIX_MAC_BASE_RPATH}"
    )

elseif(UNIX)
    # Linux-specific settings
    set_target_properties(sonix_native PROPERTIES
        INSTALL_RPATH "$ORIGIN"
    )
    # Ensure exported API functions are not removed by linker garbage collection.
    # Some environments enable -ffunction-sections/-Wl,--gc-sections by default,
    # which can drop unreferenced symbols from shared libraries.
    # We explicitly disable section GC for this target to retain the public API.
    target_link_options(sonix_native PRIVATE -Wl,--no-gc-sections)
endif()

# For Flutter packages, the native library will be built by the consuming app
# No need to copy files - the Flutter build system handles this