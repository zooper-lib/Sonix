@echo off
REM Build script for Sonix native library on Windows
REM Usage: build.bat [build_type]
REM build_type: debug, release (default: release)

setlocal enabledelayedexpansion

set BUILD_TYPE=%1
if "%BUILD_TYPE%"=="" set BUILD_TYPE=release

set SCRIPT_DIR=%~dp0
REM Remove potential trailing backslash quote issues
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
echo Script directory: %SCRIPT_DIR%
set BUILD_DIR=%SCRIPT_DIR%build\windows

echo Building Sonix native library for Windows...
echo Build type: %BUILD_TYPE%

REM Create build directory
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

cd /d "%BUILD_DIR%"

REM Configure and build with CMake
REM Configure project (separate source/build specification)
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_BUILD_TYPE=%BUILD_TYPE% %SCRIPT_DIR%
if errorlevel 1 (
    echo CMake configuration failed
    exit /b 1
)

cmake --build . --config %BUILD_TYPE%
if errorlevel 1 (
    echo Build failed
    exit /b 1
)

echo Build completed successfully!
cd /d "%SCRIPT_DIR%"