@echo off
setlocal enabledelayedexpansion

REM Sonix Native Library Build Script for Windows
REM Builds the native library with FFMPEG integration

echo [INFO] Building Sonix Native Library for Windows

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build"
set "OUTPUT_DIR=%SCRIPT_DIR%..\example"

echo [INFO] Script directory: %SCRIPT_DIR%

REM Create build directory
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

REM Check for FFMPEG libraries
set "FFMPEG_DIR=%SCRIPT_DIR%windows"
set "USE_FFMPEG=OFF"

if exist "%FFMPEG_DIR%\avformat.dll" (
    echo [INFO] FFMPEG libraries found in %FFMPEG_DIR%
    set "USE_FFMPEG=ON"
) else (
    echo [WARNING] FFMPEG libraries not found in %FFMPEG_DIR%
    echo [WARNING] Building with stub implementation
    echo [WARNING] Run 'dart run tools/setup_ffmpeg.dart' to build FFMPEG libraries
)

REM Check for required build tools
where cmake >nul 2>&1
if errorlevel 1 (
    echo [ERROR] CMake not found. Please install CMake and add it to PATH
    exit /b 1
)

REM Try to find Visual Studio or MinGW
set "GENERATOR="
where cl >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Found Visual Studio compiler
    set "GENERATOR=-G "Visual Studio 16 2019""
) else (
    where gcc >nul 2>&1
    if not errorlevel 1 (
        echo [INFO] Found MinGW compiler
        set "GENERATOR=-G "MinGW Makefiles""
    ) else (
        echo [ERROR] No suitable compiler found. Please install Visual Studio or MinGW
        exit /b 1
    )
)

REM Configure with CMake
echo [INFO] Configuring build with CMake...
cmake "%SCRIPT_DIR%" ^
    %GENERATOR% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX="%OUTPUT_DIR%"

if errorlevel 1 (
    echo [ERROR] CMake configuration failed
    exit /b 1
)

REM Build
echo [INFO] Building native library...
cmake --build . --config Release

if errorlevel 1 (
    echo [ERROR] Build failed
    exit /b 1
)

REM Install/copy to output directory
echo [INFO] Installing to %OUTPUT_DIR%...
cmake --install . --config Release

REM Copy library to example directory for testing
set "LIB_NAME=sonix_native.dll"
if exist "Release\%LIB_NAME%" (
    copy "Release\%LIB_NAME%" "%OUTPUT_DIR%\"
    echo [INFO] Copied %LIB_NAME% to %OUTPUT_DIR%\
) else if exist "%LIB_NAME%" (
    copy "%LIB_NAME%" "%OUTPUT_DIR%\"
    echo [INFO] Copied %LIB_NAME% to %OUTPUT_DIR%\
) else (
    echo [ERROR] Built library %LIB_NAME% not found
    exit /b 1
)

REM Copy FFMPEG libraries if they exist
if "%USE_FFMPEG%"=="ON" (
    echo [INFO] Copying FFMPEG libraries...
    copy "%FFMPEG_DIR%\*.dll" "%OUTPUT_DIR%\" >nul 2>&1
)

echo [INFO] Build completed successfully!
echo [INFO] Native library: %OUTPUT_DIR%\%LIB_NAME%

REM Verify the library
where dumpbin >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Library dependencies:
    dumpbin /dependents "%OUTPUT_DIR%\%LIB_NAME%"
)

endlocal