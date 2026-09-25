$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspec = Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$')
if (-not $versionMatch.Success) {
    throw 'Expected a version such as 1.0.0+1 in pubspec.yaml'
}
$version = $versionMatch.Groups[1].Value
if ($env:GITHUB_REF_TYPE -eq 'tag') {
    $expectedTag = "v$version"
    if ($env:GITHUB_EVENT_NAME -eq 'workflow_dispatch') {
        $expectedTag += '-dryrun'
    }
    if ($env:GITHUB_REF_NAME -ne $expectedTag) {
        throw "Expected tag $expectedTag, got $env:GITHUB_REF_NAME"
    }
}

$buildDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
foreach ($relativePath in @('cue.exe', 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat')) {
    if (-not (Test-Path (Join-Path $buildDir $relativePath) -PathType Leaf)) {
        throw "Missing Windows release file: $relativePath. Run flutter build windows --release first."
    }
}

# Flutter's Windows bundle needs the Visual C++ runtime on machines without Visual Studio.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere -PathType Leaf)) {
    throw 'Visual Studio Installer vswhere.exe was not found'
}
$visualStudio = (& $vswhere -latest -products '*' -property installationPath | Select-Object -First 1)
if (-not $visualStudio) {
    throw 'Visual Studio installation was not found'
}
$redistRoot = Join-Path $visualStudio 'VC\Redist\MSVC'
$runtimeFiles = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
$runtimeDir = Get-ChildItem $redistRoot -Directory |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
    Where-Object {
        $candidate = $_
        @($runtimeFiles | Where-Object { -not (Test-Path (Join-Path $candidate $_) -PathType Leaf) }).Count -eq 0
    } |
    Select-Object -First 1
if (-not $runtimeDir) {
    throw 'The x64 Visual C++ 2022 redistributable DLLs were not found'
}
foreach ($file in $runtimeFiles) {
    Copy-Item (Join-Path $runtimeDir $file) (Join-Path $buildDir $file) -Force
}

$iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($iscc) {
    $compiler = $iscc.Source
} else {
    $compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
}
if (-not (Test-Path $compiler -PathType Leaf)) {
    throw 'Inno Setup 6 ISCC.exe was not found'
}

$outputDir = Join-Path $projectRoot 'build\release'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$script = Join-Path $projectRoot 'windows\installer\Cue.iss'
& $compiler "/DAppVersion=$version" "/O$outputDir" $script
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE"
}

$installer = Join-Path $outputDir "Cue-v$version-windows-x64-setup.exe"
if (-not (Test-Path $installer -PathType Leaf)) {
    throw "Inno Setup did not create $installer"
}
Write-Host "Ready to publish: $installer"
