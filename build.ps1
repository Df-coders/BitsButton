<#
Simple PowerShell helper to configure, build and run tests on Windows (pwsh).

Notes:
- Running the script with only `-Clean` will *only* remove the build directory and exit
  (it will NOT recreate the build directory or trigger a configure/build). To clean then
  build, run the script twice or pass additional flags (e.g. `-RunTests`) on the second call.

Usage examples (run from project root):
    .\build.ps1                                # configure + build (defaults)
    .\build.ps1 -Clean                         # remove build dir only and exit
    .\build.ps1 -RunTests                      # configure + build, then run ctest
    .\build.ps1 -Clean; .\build.ps1 -RunTests  # clean first, then build+test

Common options:
    -Generator "Ninja"        # CMake generator (default: "MinGW Makefiles")
    -CCompiler <path>          # full path to C compiler (gcc)
    -CxxCompiler <path>        # full path to C++ compiler (g++)
    -BuildType <Release|Debug> # build type (default: Release)
    -Jobs <N>                  # parallel build jobs (passed to make/ninja/msbuild)
    -InstallDir <path>         # install prefix (will run `cmake --install`)
    -ExtraCMakeArgs "..."     # additional -D arguments for cmake (as a quoted string)

Examples:
    .\build.ps1 -Generator "Ninja" -Jobs 8 -RunTests
    .\build.ps1 -ExtraCMakeArgs "-DBITS_BTN_DISABLE_BUFFER=ON" -RunTests

This script is intended for interactive use on Windows (pwsh). For CI, call cmake
directly or invoke this script with explicit generator/compiler settings.
#>

param(
        [switch]$Clean,
        [switch]$RunTests,
        [string]$Generator = "MinGW Makefiles",
        [string]$CCompiler = "",
        [string]$CxxCompiler = "",
        [string]$BuildType = "Release",
        [int]$Jobs = 0,
        [string]$InstallDir = "",
        [string]$ExtraCMakeArgs = ""
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir

$buildDir = Join-Path $scriptDir "build"
if($Clean -and (Test-Path $buildDir)){
    Write-Host "Removing build directory..."
    Remove-Item -Recurse -Force $buildDir
}

if(-not (Test-Path $buildDir)){
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

Set-Location $buildDir

# If the caller only asked for cleaning (no other parameters), exit now.
if($Clean -and $PSBoundParameters.Count -eq 1){
    Write-Host "Clean completed. Exiting without configuring/building because only -Clean was provided."
    Pop-Location
    exit 0
}

Write-Host "Configuring with CMake..."

# Assemble cmake configure command
$cmakeArgs = @()
$cmakeArgs += ".."
$cmakeArgs += "-G"
$cmakeArgs += $Generator
$cmakeArgs += "-DCMAKE_BUILD_TYPE=$BuildType"
$cmakeArgs += "-DCMAKE_C_STANDARD=11"

if($CCompiler -ne ""){
    $cmakeArgs += "-DCMAKE_C_COMPILER=$CCompiler"
}
if($CxxCompiler -ne ""){
    $cmakeArgs += "-DCMAKE_CXX_COMPILER=$CxxCompiler"
}
if($InstallDir -ne ""){
    $cmakeArgs += "-DCMAKE_INSTALL_PREFIX=$InstallDir"
}
if($ExtraCMakeArgs -ne ""){
    # split extra args on spaces — user can pass quoted string for complex args
    $extra = $ExtraCMakeArgs -split ' '
    $cmakeArgs += $extra
}

Write-Host "cmake arguments: $($cmakeArgs -join ' ')"
cmake @cmakeArgs

Write-Host "Building..."

# Assemble build command
$buildCmd = @('cmake', '--build', '.')
if($BuildType -ne ""){
    $buildCmd += '--config'
    $buildCmd += $BuildType
}

# Parallel jobs handling: pass to underlying build tool
if($Jobs -gt 0){
    # For Makefile/Ninja pass -j, for MSBuild use /m:
    if($Generator -match 'Makefiles' -or $Generator -match 'Ninja'){
        $buildCmd += '--'
        $buildCmd += "-j$Jobs"
    } elseif($Generator -match 'Visual Studio' -or $Generator -match 'MSBuild'){
        $buildCmd += '--'
        $buildCmd += "/m:$Jobs"
    }
}

Write-Host ($buildCmd -join ' ')

# Execute build command properly using splatting to pass arguments safely
$buildArgs = $buildCmd
& $buildArgs[0] $buildArgs[1] $buildArgs[2] @($buildArgs[3..($buildArgs.Count-1)])

if($LastExitCode -ne 0){
    Write-Host "Build failed with exit code $LastExitCode"
    Pop-Location
    exit $LastExitCode
}

if($InstallDir -ne ""){
    Write-Host "Installing to $InstallDir..."
    cmake --install . --prefix $InstallDir
}

if($RunTests){
    Write-Host "Running tests..."
    ctest --output-on-failure
}

Pop-Location
Write-Host "Done."