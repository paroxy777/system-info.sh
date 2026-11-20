
@ECHO OFF
SETLOCAL

TITLE System Info - Hardware Report

ECHO.
ECHO   SYSTEM INFO
ECHO   -----------
ECHO Starting system information scan ...
ECHO.
ECHO ==========================================

REM Locate PowerShell
SET "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

IF NOT EXIST "%PS_EXE%" (
    ECHO ERROR: Windows PowerShell could not be found.
    GOTO END
)

REM Locate the PowerShell script beside this launcher
IF NOT EXIST "%~dp0system-info.ps1" (
    ECHO ERROR: system-info.ps1 could not be found.
    ECHO.
    ECHO Make sure both files are in the same folder.
    GOTO END
)

REM Run system-info.ps1
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0system-info.ps1"

IF ERRORLEVEL 1 (
    ECHO.
    ECHO WARNING: The script reported an error.
)

:END
ECHO ==========================================
ECHO.
ECHO Press any key to close this window...
PAUSE >NUL

ENDLOCAL
