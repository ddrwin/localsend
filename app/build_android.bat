@echo off
chcp 65001 > nul
setlocal

set ANDROID_HOME=E:\CodeBase\android-sdk
set ANDROID_SDK_ROOT=E:\CodeBase\android-sdk
set JAVA_HOME=E:\CodeBase\jdk17\jdk-17.0.14+7
set PATH=%JAVA_HOME%\bin;E:\CodeBase\android-sdk\platform-tools;%PATH%

cd /d E:\CodeBase\localsend\app

echo JAVA_HOME=%JAVA_HOME%
echo Checking Java:
"%JAVA_HOME%\bin\java" -version

call C:\flutter\flutter\bin\flutter.bat build apk --split-per-abi --release

echo Flutter build exited with code: %errorlevel%
exit /b %errorlevel%
