# Build the Server project.

Param(
    [Parameter(Mandatory = $true)]
    [string] $RELEASE_TAG
)

# Function that pretends the date/time to the start of a log
function Write-Log {
    Param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

Write-Log "✅ Building Server Project"

# Set directories
$DIR_ABS = (Get-Location).Path
$DIR = "$DIR_ABS\builds\Server"
$DIR_PROJECT = "$DIR\project"
$DIR_BUILD = "$DIR_PROJECT\build"

# Remove the build directory if it already exists
if (Test-Path -Path $DIR) {
    Write-Log "⏳ Removing Previous Server Project Build Directory"
    Remove-Item -Recurse -Force $DIR
}

# Pull down the server project, at the tag, with no history
Write-Log "⏳ Cloning Server Project"
$REPO = "https://dev.sp-tarkov.com/SPT-AKI/Server.git"
try {
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "git"
    $processInfo.Arguments = "clone $REPO --branch $RELEASE_TAG --depth 1 `"$DIR`""
    $processInfo.RedirectStandardError = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $process.WaitForExit()

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    if ($process.ExitCode -ne 0) {
        Write-Log "error cloning: $stdout"
        throw "git clone command failed with exit code $($process.ExitCode). Error Output: $stderr"
    }
}
catch {
    $errorMessage = "❌ FAIL: Error executing git clone: $_"
    Write-Log $errorMessage
    exit 1 # Fail the build
}

# Create any necessary sub-directories
New-Item -Path $DIR_BUILD -ItemType Directory -Force | Out-Null

# Ensure we are in the correct directory
Set-Location $DIR

# Pull down the LFS files
git lfs fetch | Out-Null
git lfs pull | Out-Null

# Determine the build type based on the tag.
# The 'release' pattern matches tags like '1.2.3' or 'v1.2.3'.
# The 'bleeding' pattern matches tags like '1.2.3-BE', 'v1.2.3-BE', or 'v1.2.3-BE-2024-02-29', case-insensitively.
# The 'debug' pattern will be used for any tag not matching these patterns.
$RELEASE_BUILD_REGEX = '^(v?\d+\.\d+\.\d+)$'
$BLEEDING_BUILD_REGEX = '^(v?\d+\.\d+\.\d+-(?i)BE(?:-[^-]+)?)$'
if ($RELEASE_TAG -match $RELEASE_BUILD_REGEX) {
    $BUILD_TYPE = "release"
}
elseif ($RELEASE_TAG -match $BLEEDING_BUILD_REGEX) {
    $BUILD_TYPE = "bleeding"
}
else {
    $BUILD_TYPE = "debug"
}
Write-Log "⏳ Build Type: $BUILD_TYPE"

Set-Location $DIR_PROJECT

Write-Log "⏳ Installing Server Project Dependencies"
try {
    $RESULT = npm install *>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "NPM install error: $RESULT"
		throw "npm install failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Log "❌ FAIL: Error executing npm install: $_"
    exit 1 # Fail the build
}

Write-Log "⏳ Running Server Project Build Task"
try {
    $RESULT = npm run build:$BUILD_TYPE *>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "NPM run build error: $RESULT"
		throw "npm install failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Log "❌ FAIL: Error executing npm run build: $_"
    exit 1 # Fail the build
}

Write-Log "⚡ Server Project Built ⚡"
Write-Output ""
