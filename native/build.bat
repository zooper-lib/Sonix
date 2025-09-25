@echo off
REM Build script for Windows

echo Building Sonix native library with FFMPEG...

REM Create build directory
if not exist build mkdir build
cd build

REM Configure with CMake
cmake .. -DCMAKE_BUILD_TYPE=Release -G "Visual Studio 16 2019" -A x64

REM Build
cmake --build . --config Release

echo Build completed successfully!
echo Native library built in: %CD%

REM List built files
dir /B *.dll 2>nul