@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  HookCast release-line quick push - thin entry point.
rem
rem  Everything real lives in ONE place: <source repo>\installer\publish-release.ps1,
rem  which this calls with -SkipUpload. That script does the prechecks, runs cmd\publisher
rem  to generate and sign the manifest, and does the commit and the push. This file only
rem  answers "where is the source repo", forwards the arguments, and pauses at the end so
rem  a double-click keeps its output on screen.
rem
rem  The package itself is NOT handled here: upload the exe to the GitHub Release tagged
rem  v<version> first, then run this. The order is deliberate - the moment the manifest
rem  lands the installed App sees the new version, so the asset must already be reachable.
rem  cmd\publisher looks the asset ID up by package name and refuses to sign a manifest for
rem  a package it cannot actually download, so a missing upload stops the run here.
rem
rem  The version comes from the VERSION file in the source repo and nowhere else. Do not rename
rem  a package to talk the script into publishing something else: the manifest names
rem  HookCast-setup-<VERSION>.exe, and that file has to exist under release\.
rem
rem  NOTE ON ENCODING: this file is pure ASCII on purpose. cmd.exe loses its byte offset inside
rem  batch files that contain multi-byte characters (the console codepage does not matter), and
rem  the damage is not cosmetic - statements get re-read or skipped, which for a script that runs
rem  git push could mean jumping past a guard. Chinese wording lives in README.md instead.
rem
rem  Usage (from this directory, or double-click):
rem    publish-line.bat                push the stable line
rem    publish-line.bat beta           push to releases\beta
rem    publish-line.bat stable dry     build the manifest only, no commit, no push
rem  Set HC_SOURCE_ROOT when the source repo is not two levels above this file.
rem ============================================================

set "LINE_DIR=%~dp0"
for %%I in ("%LINE_DIR%.") do set "LINE_DIR=%%~fI"
set "REPO_ROOT=%HC_SOURCE_ROOT%"
if "%REPO_ROOT%"=="" for %%I in ("%LINE_DIR%\..\..") do set "REPO_ROOT=%%~fI"

set "CHANNEL=%~1"
if "%CHANNEL%"=="" set "CHANNEL=stable"
set "EXTRA="
if /i "%~2"=="dry" set "EXTRA=-DryRun"
if not "%~2"=="" if /i not "%~2"=="dry" (
  echo [ERROR] unparsed second argument: %~2
  echo Usage: publish-line.bat [channel] [dry]
  goto :fail
)

set "PUBLISH_PS1=%REPO_ROOT%\installer\publish-release.ps1"
if not exist "%PUBLISH_PS1%" goto :need_source_root

rem The signing key lives outside both repos; the repo root holds only a working copy.
set "SIGN_KEY=%REPO_ROOT%\plugin-private.pem"
for %%I in ("%REPO_ROOT%\..\HookCast-registrar\secrets\plugin-private.pem") do set "OFFLINE_KEY=%%~fI"
if not exist "%SIGN_KEY%" goto :need_sign_key

powershell -NoProfile -ExecutionPolicy Bypass -File "%PUBLISH_PS1%" -Channel "%CHANNEL%" -DistClone "%LINE_DIR%" -SkipUpload !EXTRA!
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" goto :publish_failed
echo.
echo Note: the manifest now comes from api.github.com, which caches privately for about a
echo       minute instead of the several minutes the raw CDN took. To verify right away, click
echo       page Settings; the built-in poll is hourly.
echo Reminder: %SIGN_KEY% is a working copy - delete it from the source repo when done.
pause
endlocal
exit /b 0

:need_sign_key
echo [ERROR] signing key not found: %SIGN_KEY%
echo The private key is kept outside the source repo. Copy it in to publish, then delete it:
echo   copy "%OFFLINE_KEY%" "%SIGN_KEY%"
echo   del "%SIGN_KEY%"
echo It is git-ignored, but it must never be committed, packaged or sent out.
goto :fail

:need_source_root
echo [ERROR] source repo not found at %REPO_ROOT% (no installer\publish-release.ps1 there).
echo This clone expects the source repo two levels up, or HC_SOURCE_ROOT pointing at it, e.g.
echo   set "HC_SOURCE_ROOT=C:\path\to\HookCast"
goto :fail

:publish_failed
echo [ERROR] publish-release.ps1 exited with code %RC%. Release line untouched.
echo Read the lines above: the script refuses to sign a manifest when the tag carries no
echo asset named HookCast-setup-^<VERSION^>.exe, when it cannot reach the Releases API, or when
echo the address it built does not actually serve the package. Upload or replace the exe on
echo the Release first, then run this script again.
goto :fail

:fail
pause
endlocal
exit /b 1
