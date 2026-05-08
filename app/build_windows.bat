@echo off
setlocal enabledelayedexpansion

call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if %errorlevel% neq 0 (
    echo vcvars failed with error %errorlevel%
    exit /b %errorlevel%
)

set VS_INSTALL_PATH=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools
set VS_VERSION=18.5.1
set VS_MSVC_VERSION=14.50.35717
set VS170COMNTOOLS=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\
set FLUTTER_CMAKE_PATH=C:\Program Files\CMake\cmake-3.31.6-windows-x86_64\bin\cmake.exe
set FLUTTER_USE_NINJA=true
set PATH=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%

cd /d E:\CodeBase\localsend\app

echo Building Windows release...
call C:\flutter\flutter\bin\flutter.bat build windows --release
set BUILD_RESULT=%errorlevel%

echo Flutter build exited with code: %BUILD_RESULT%
exit /b %BUILD_RESULT%
