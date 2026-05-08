@echo off
setlocal

call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if %errorlevel% neq 0 (
    echo vcvars64 failed
    exit /b %errorlevel%
)

set ANDROID_HOME=E:\CodeBase\android-sdk
set ANDROID_SDK_ROOT=E:\CodeBase\android-sdk
set JAVA_HOME=E:\CodeBase\jdk17\jdk-17.0.14+7
set PATH=C:\Program Files\CMake\cmake-3.31.6-windows-x86_64\bin;%JAVA_HOME%\bin;%PATH%

cd /d E:\CodeBase\localsend\app

echo ======== Environment set, calling Flutter ========

REM Run flutter in a way that outputs build logs
call C:\flutter\flutter\bin\flutter.bat clean > nul 2>&1
call C:\flutter\flutter\bin\flutter.bat pub get > nul 2>&1
call C:\flutter\flutter\bin\flutter.bat build windows --release

echo ======== Build exit code: %errorlevel% ========
exit /b %errorlevel%
