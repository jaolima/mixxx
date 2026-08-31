@ECHO OFF
REM ---------------------------------------------------------------------------
REM dev.bat - Mixxx development helper for Windows.
REM
REM One entry point to set up the build environment, configure, build, run and
REM test a development build of Mixxx. Keeps the dev build's settings separate
REM from a system-wide Mixxx install.
REM
REM Quick start (from a plain cmd.exe prompt, inside the source tree):
REM     dev.bat setup     :: once; the first configure downloads ~2.5 GB
REM     dev.bat run       :: build and launch
REM
REM Requires: Visual Studio with "Desktop development with C++", CMake and
REM Ninja on PATH (both ship with that workload).
REM
REM Run 'dev.bat help' for all commands.
REM ---------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION

SET "MIXXX_ROOT=%~dp0"
IF "%MIXXX_ROOT:~-1%"=="\" SET "MIXXX_ROOT=%MIXXX_ROOT:~0,-1%"

IF NOT DEFINED BUILD_DIR        SET "BUILD_DIR=%MIXXX_ROOT%\build"
IF NOT DEFINED BUILD_TYPE       SET "BUILD_TYPE=RelWithDebInfo"
IF NOT DEFINED SETTINGS_DIR     SET "SETTINGS_DIR=%LOCALAPPDATA%\Mixxx-dev"
IF NOT DEFINED PLATFORM         SET "PLATFORM=x64"
IF NOT DEFINED CMAKE_EXTRA_ARGS SET "CMAKE_EXTRA_ARGS="

REM windows_buildenv.bat does not export VCPKG_TARGET_TRIPLET, so mirror the
REM value it picks for a non-release (debug-capable) build environment.
IF /I "%PLATFORM%"=="arm64" (
    SET "TRIPLET=arm64-windows"
) ELSE (
    SET "TRIPLET=x64-windows"
)

SET "COMMAND=%~1"
IF "%COMMAND%"=="" SET "COMMAND=run"
REM Collect everything after the command into ARGS (each element keeps its
REM original quoting, and ARGS keeps a leading space so it can be appended).
SET "ARGS="
IF NOT "%~1"=="" SHIFT
:COLLECT_ARGS
IF "%~1"=="" GOTO ARGS_DONE
SET "ARGS=!ARGS! %1"
SHIFT
GOTO COLLECT_ARGS
:ARGS_DONE

IF /I "%COMMAND%"=="setup"     GOTO CMD_SETUP
IF /I "%COMMAND%"=="configure" GOTO CMD_CONFIGURE
IF /I "%COMMAND%"=="build"     GOTO CMD_BUILD
IF /I "%COMMAND%"=="run"       GOTO CMD_RUN
IF /I "%COMMAND%"=="test"      GOTO CMD_TEST
IF /I "%COMMAND%"=="clean"     GOTO CMD_CLEAN
IF /I "%COMMAND%"=="shortcut"  GOTO CMD_SHORTCUT
IF /I "%COMMAND%"=="doctor"    GOTO CMD_DOCTOR
IF /I "%COMMAND%"=="help"      GOTO CMD_HELP
IF /I "%COMMAND%"=="-h"        GOTO CMD_HELP
IF /I "%COMMAND%"=="--help"    GOTO CMD_HELP

ECHO fail unknown command: %COMMAND% ^(try 'dev.bat help'^)
GOTO FAIL

REM ===========================================================================
:CMD_HELP
ECHO dev.bat - Mixxx development helper ^(Windows^)
ECHO.
ECHO Usage:
ECHO   dev.bat ^<command^> [arguments]
ECHO.
ECHO Commands:
ECHO   setup        Prepare the build environment and configure ^(downloads ~2.5 GB^)
ECHO   configure    Run the CMake configure step
ECHO   build        Configure if needed, then compile
ECHO   run          Build, then launch Mixxx with --developer   ^(default^)
ECHO   test         Build, then run the test suite with ctest
ECHO   clean        Delete the build directory
ECHO   shortcut     Create a "Mixxx (dev)" shortcut on the Desktop
ECHO   doctor       Report toolchain and build directory status
ECHO   help         Show this help
ECHO.
ECHO Environment variables:
ECHO   BUILD_DIR         Build directory       ^(default: ^<repo^>\build^)
ECHO   BUILD_TYPE        CMake build type      ^(default: RelWithDebInfo^)
ECHO   SETTINGS_DIR      Mixxx settings folder ^(default: %%LOCALAPPDATA%%\Mixxx-dev^)
ECHO   PLATFORM          x64 or arm64          ^(default: x64^)
ECHO   CMAKE_EXTRA_ARGS  Extra flags for the configure step
ECHO.
ECHO Examples:
ECHO   dev.bat setup
ECHO   dev.bat run
ECHO   dev.bat run --controller-debug
ECHO   dev.bat build --target mixxx-test
GOTO DONE

REM ===========================================================================
:CMD_SETUP
ECHO ==^> Preparing the Mixxx build environment for %PLATFORM% ^(%TRIPLET%^)
REM The plain call also writes CMakeSettings.json for Visual Studio users.
CALL "%MIXXX_ROOT%\tools\windows_buildenv.bat" setup
IF ERRORLEVEL 1 GOTO FAIL
CALL :LOAD_MSVC
IF ERRORLEVEL 1 GOTO FAIL
ECHO ==^> First configure downloads and unpacks the dependencies ^(~2.5 GB^)
CALL :DO_CONFIGURE
IF ERRORLEVEL 1 GOTO FAIL
ECHO  ok  ready - now run 'dev.bat run'
GOTO DONE

REM ===========================================================================
:CMD_CONFIGURE
CALL :LOAD_ENV
IF ERRORLEVEL 1 GOTO FAIL
CALL :DO_CONFIGURE
IF ERRORLEVEL 1 GOTO FAIL
GOTO DONE

REM ===========================================================================
:CMD_BUILD
CALL :LOAD_ENV
IF ERRORLEVEL 1 GOTO FAIL
CALL :DO_BUILD %ARGS%
IF ERRORLEVEL 1 GOTO FAIL
GOTO DONE

REM ===========================================================================
:CMD_RUN
CALL :LOAD_ENV
IF ERRORLEVEL 1 GOTO FAIL
CALL :DO_BUILD
IF ERRORLEVEL 1 GOTO FAIL
CALL :FIND_EXE
IF ERRORLEVEL 1 GOTO FAIL
IF NOT EXIST "%SETTINGS_DIR%" MD "%SETTINGS_DIR%"
ECHO ==^> Launching Mixxx in developer mode ^(settings: %SETTINGS_DIR%^)
"%MIXXX_EXE%" --developer --settings-path "%SETTINGS_DIR%"%ARGS%
IF ERRORLEVEL 1 GOTO FAIL
GOTO DONE

REM ===========================================================================
:CMD_TEST
CALL :LOAD_ENV
IF ERRORLEVEL 1 GOTO FAIL
CALL :DO_BUILD
IF ERRORLEVEL 1 GOTO FAIL
ECHO ==^> Running the test suite
REM AutoDJProcessorTest is excluded on Windows in CI too - it is known broken.
ctest --test-dir "%BUILD_DIR%" --output-on-failure --exclude-regex "^AutoDJProcessorTest.*$"%ARGS%
IF ERRORLEVEL 1 GOTO FAIL
GOTO DONE

REM ===========================================================================
:CMD_CLEAN
REM Only delete something that really is a CMake build directory.
IF NOT EXIST "%BUILD_DIR%" (
    ECHO  ok  nothing to clean, "%BUILD_DIR%" does not exist
    GOTO DONE
)
IF NOT EXIST "%BUILD_DIR%\CMakeCache.txt" (
    ECHO fail refusing to delete "%BUILD_DIR%": no CMakeCache.txt, not a build directory
    GOTO FAIL
)
ECHO ==^> Removing "%BUILD_DIR%"
RD /S /Q "%BUILD_DIR%"
ECHO  ok  clean
GOTO DONE

REM ===========================================================================
:CMD_SHORTCUT
SET "LNK=%USERPROFILE%\Desktop\Mixxx (dev).lnk"
SET "ICON=%MIXXX_ROOT%\res\images\icons\ic_mixxx.ico"
ECHO ==^> Creating "%LNK%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%LNK%');" ^
  "$s.TargetPath='%COMSPEC%';" ^
  "$s.Arguments='/k \"\"%MIXXX_ROOT%\dev.bat\" run\"';" ^
  "$s.WorkingDirectory='%MIXXX_ROOT%';" ^
  "if (Test-Path '%ICON%') { $s.IconLocation='%ICON%' };" ^
  "$s.Description='Mixxx development build';" ^
  "$s.Save()"
IF ERRORLEVEL 1 GOTO FAIL
ECHO  ok  shortcut "Mixxx (dev)" created on the Desktop
GOTO DONE

REM ===========================================================================
:CMD_DOCTOR
ECHO Mixxx dev environment
ECHO   repo:       %MIXXX_ROOT%
IF EXIST "%BUILD_DIR%\CMakeCache.txt" (
    ECHO   build dir:  %BUILD_DIR% ^(configured^)
) ELSE (
    ECHO   build dir:  %BUILD_DIR% ^(not configured^)
)
ECHO   build type: %BUILD_TYPE%
ECHO   settings:   %SETTINGS_DIR%
ECHO   platform:   %PLATFORM% ^(%TRIPLET%^)
ECHO.
ECHO Toolchain
CALL :REPORT_TOOL cmake
CALL :REPORT_TOOL ninja
CALL :REPORT_TOOL git
IF EXIST "%MIXXX_ROOT%\buildenv" (
    ECHO   buildenv:   downloaded to %MIXXX_ROOT%\buildenv
) ELSE (
    ECHO   buildenv:   not downloaded yet - run 'dev.bat setup'
)
CALL :FIND_VS
IF DEFINED VCVARSALL (
    ECHO   MSVC:       !VCVARSALL!
) ELSE (
    ECHO   MSVC:       not found - install "Desktop development with C++"
)
GOTO DONE

REM ===========================================================================
REM Subroutines
REM ===========================================================================

:REPORT_TOOL
WHERE %1 >NUL 2>NUL
IF ERRORLEVEL 1 (
    ECHO   %1:      missing
    GOTO :EOF
)
FOR /F "delims=" %%i IN ('WHERE %1') DO (
    ECHO   %1:      %%i
    GOTO :EOF
)
GOTO :EOF

REM Locate vcvarsall.bat via vswhere, which ships with every VS installer.
:FIND_VS
SET "VCVARSALL="
SET "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
IF NOT EXIST "!VSWHERE!" SET "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
IF NOT EXIST "!VSWHERE!" GOTO :EOF
FOR /F "usebackq tokens=*" %%i IN (`"!VSWHERE!" -latest -prerelease -products * -property installationPath`) DO (
    IF EXIST "%%i\VC\Auxiliary\Build\vcvarsall.bat" SET "VCVARSALL=%%i\VC\Auxiliary\Build\vcvarsall.bat"
)
GOTO :EOF

:LOAD_MSVC
IF DEFINED VCINSTALLDIR GOTO :EOF
CALL :FIND_VS
IF NOT DEFINED VCVARSALL (
    ECHO fail Visual Studio C++ tools not found.
    ECHO      Install the "Desktop development with C++" workload.
    EXIT /B 1
)
ECHO ==^> Loading MSVC environment for %PLATFORM%
CALL "!VCVARSALL!" %PLATFORM% >NUL
IF ERRORLEVEL 1 (
    ECHO fail vcvarsall.bat failed
    EXIT /B 1
)
GOTO :EOF

REM Load the vcpkg build environment variables plus the MSVC compiler
REM environment. windows_buildenv.bat exports BUILDENV_URL / BUILDENV_SHA256 /
REM BUILDENV_BASEPATH / MIXXX_VCPKG_ROOT into this session; CMake reads them and
REM downloads the dependencies itself on the first configure. GITHUB_ENV is
REM pointed at a scratch file so the script takes its CI code path and does not
REM rewrite (and back up) CMakeSettings.json on every invocation.
:LOAD_ENV
IF NOT DEFINED MIXXX_VCPKG_ROOT (
    SET "GITHUB_ENV=%TEMP%\mixxx_dev_buildenv_%RANDOM%.txt"
    CALL "%MIXXX_ROOT%\tools\windows_buildenv.bat" setup >NUL
    SET "_BUILDENV_RC=!ERRORLEVEL!"
    IF EXIST "!GITHUB_ENV!" DEL /Q "!GITHUB_ENV!"
    SET "GITHUB_ENV="
    IF NOT "!_BUILDENV_RC!"=="0" (
        ECHO fail could not load the build environment
        EXIT /B 1
    )
)
CALL :LOAD_MSVC
IF ERRORLEVEL 1 EXIT /B 1
EXIT /B 0

:DO_CONFIGURE
WHERE cmake >NUL 2>NUL
IF ERRORLEVEL 1 (
    ECHO fail cmake not found in PATH
    EXIT /B 1
)
REM The generator can only be chosen on the first configure of a build dir.
SET "GENERATOR_ARG=-G Ninja"
IF EXIST "%BUILD_DIR%\CMakeCache.txt" SET "GENERATOR_ARG="
ECHO ==^> Configuring %BUILD_TYPE% build in "%BUILD_DIR%"
REM Feature flags mirror the "Windows Server 2025" job in
REM .github/workflows/build.yml, so a local build matches what CI checks.
cmake -S "%MIXXX_ROOT%" -B "%BUILD_DIR%" !GENERATOR_ARG! ^
    -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
    -DCMAKE_C_COMPILER=cl ^
    -DCMAKE_CXX_COMPILER=cl ^
    -DVCPKG_TARGET_TRIPLET=%TRIPLET% ^
    -DQT6=ON ^
    -DQML=ON ^
    -DBULK=ON ^
    -DHSS1394=ON ^
    -DLOCALECOMPARE=ON ^
    -DMAD=ON ^
    -DMEDIAFOUNDATION=ON ^
    -DMODPLUG=ON ^
    -DWAVPACK=ON %CMAKE_EXTRA_ARGS%
IF ERRORLEVEL 1 (
    ECHO fail cmake configure failed
    EXIT /B 1
)
ECHO  ok  configured
EXIT /B 0

:DO_BUILD
IF NOT EXIST "%BUILD_DIR%\CMakeCache.txt" (
    CALL :DO_CONFIGURE
    IF ERRORLEVEL 1 EXIT /B 1
)
ECHO ==^> Building
cmake --build "%BUILD_DIR%" --parallel %*
IF ERRORLEVEL 1 (
    ECHO fail build failed
    EXIT /B 1
)
ECHO  ok  build finished
EXIT /B 0

REM Ninja puts mixxx.exe in the build root; a multi-config generator uses a
REM per-configuration subdirectory.
:FIND_EXE
SET "MIXXX_EXE=%BUILD_DIR%\mixxx.exe"
IF EXIST "!MIXXX_EXE!" EXIT /B 0
SET "MIXXX_EXE=%BUILD_DIR%\%BUILD_TYPE%\mixxx.exe"
IF EXIST "!MIXXX_EXE!" EXIT /B 0
ECHO fail mixxx.exe not found under "%BUILD_DIR%"
EXIT /B 1

REM ===========================================================================
:FAIL
ENDLOCAL
EXIT /B 1

:DONE
ENDLOCAL
EXIT /B 0
