@echo off
:: Request admin privileges if not already elevated
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process -WindowStyle hidden '%~f0' -Verb RunAs"
    exit
)

:: Change to the script’s directory
cd /d "%~dp0"

:: Define log file path
set LOG_FILE=%TEMP%\common_redist_install.log

:: Clear log file
> %LOG_FILE% echo.

:: Install .NET Framework 4.0
if exist dotNetFx40_Full_setup.exe (
    echo Installing .NET Framework 4.0 >> %LOG_FILE%
    dotNetFx40_Full_setup.exe /q /norestart /log dotnet_install.log
)

:: Install DirectX
if exist directx_Jun2010_redist.exe (
    echo Installing DirectX >> %LOG_FILE%
    directx_Jun2010_redist.exe /Q /T:"%TEMP%\dx"
    rd /s /q "%TEMP%\dx"
)

:: Install OpenAL
if exist oalinst.exe (
    echo Installing OpenAL >> %LOG_FILE%
    oalinst.exe /silent
)

:: Install Visual C++ Redistributables AIO
if exist VisualCppRedist_AIO_x86_x64.exe (
    echo Installing Visual C++ Redistributable AIO >> %LOG_FILE%
    VisualCppRedist_AIO_x86_x64.exe /ai /gm2
)

:: Install XNA Framework 4.0
if exist xnafx40_redist.msi (
    echo Installing XNA Framework 4.0 >> %LOG_FILE%
    msiexec /i xnafx40_redist.msi /quiet /norestart
)

echo Installation complete >> %LOG_FILE%
pause