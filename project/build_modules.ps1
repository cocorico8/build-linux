# Build the Modules project.

Param(
    [Parameter(Mandatory = $true)]
    [string] $RELEASE_TAG,

    [Parameter(Mandatory = $true)]
    [string] $MODULE_DOMAIN
)

# Function that pretends the date/time to the start of a log
function Write-Log {
    Param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

Write-Log "✅ Building Modules Project"

# Set directories
$DIR_ABS = (Get-Location).Path
$DIR = "$DIR_ABS\builds\Modules"
$DIR_PROJECT = "$DIR\project"
$DIR_BUILD = "$DIR_PROJECT\build"
$DIR_MANAGED = "$DIR_PROJECT\Shared\Managed"

# Remove the build directory if it already exists
if (Test-Path -Path $DIR) {
	Write-Log "⏳ Removing Previous Modules Project Build Directory"
    Remove-Item -Recurse -Force $DIR
}

# Pull down the modules project, at the tag, with no history
Write-Log "⏳ Cloning Modules Project"
$REPO = "https://dev.sp-tarkov.com/SPT-AKI/Modules.git"
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
New-Item -Path $DIR_MANAGED -ItemType Directory -Force | Out-Null

Set-Location $DIR

Write-Log "⏳ Fetching Required Client Version"
$coreJsonPath = "$DIR_ABS\builds\Server\project\build\Aki_Data\Server\configs\core.json"
if (-not (Test-Path -Path $coreJsonPath) -or (Get-Item -Path $coreJsonPath).Length -eq 0) {
    Write-Log "❌ FAIL: core.json does not exist or is empty."
    exit 1 # Fail the build
}
try {
    # Attempt to read and parse the core.json file
    $RELEASE_METADATA_RAW = Get-Content -Path $coreJsonPath -ErrorAction Stop
    $RELEASE_METADATA = $RELEASE_METADATA_RAW | ConvertFrom-Json -ErrorAction Stop
    $CLIENT_VERSION = $RELEASE_METADATA.compatibleTarkovVersion.Split('.') | Select-Object -Last 1

    # Check if the $CLIENT_VERSION is valid
    if ([string]::IsNullOrWhiteSpace($CLIENT_VERSION)) {
        throw "Invalid or missing 'compatibleTarkovVersion' in core.json."
    }
}
catch {
    Write-Log "❌ FAIL: Error fetching or parsing core.json: $_"
    exit 1 # Fail the build
}
Write-Log "⏳ Client Version $CLIENT_VERSION Fetched Successfully."

# Download the module files
Write-Log "⏳ Downloading Client Module Package"
$DOWNLOAD_PATH = "$DIR_MANAGED\$CLIENT_VERSION.zip"
$DOWNLOAD_URL = "$MODULE_DOMAIN/$CLIENT_VERSION.zip"
try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $DOWNLOAD_PATH -UseBasicParsing -ErrorAction Stop
    if (-not (Test-Path -Path $DOWNLOAD_PATH) -or (Get-Item -Path $DOWNLOAD_PATH).Length -eq 0) {
        throw "The module package does not exist or is empty."
    }
}
catch {
    Write-Log "❌ FAIL: Unable to download the module. Error: $_"
    exit 1 # Fail the build
}
Write-Log "⏳ Download Successful: $DOWNLOAD_PATH"

Write-Log "⏳ Extracting Client Module Package"
try {
    Expand-Archive -Path $DOWNLOAD_PATH -DestinationPath $DIR_MANAGED -Force -ErrorAction Stop
    Write-Log "⏳ Client Module Package Extracted: $DIR_MANAGED"
}
catch {
    Write-Log "❌ FAIL: Error Extracting Client Module Package: $_"
    exit 1 # Fail the build
}

# Delete the modules archive now that it's been uncompressed
try {
    Remove-Item -Path $DOWNLOAD_PATH -Force -ErrorAction Stop
    Write-Log "⏳ Client Module Package Deleted"
}
catch {
    Write-Warning "❌ Failed to Delete ZIP File: $_"
    exit 1 # Fail the build
}

Set-Location $DIR_PROJECT

Write-Log "⏳ Running Modules Project Build Task"
try {
    $BUILD_RESULT = dotnet build *>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Build output: $BUILD_RESULT"
		throw "dotnet build failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Error "❌ FAIL: Error executing dotnet build: $_"
    exit 1 # Fail the build
}

Write-Log "⚡ Modules Project Built ⚡"
Write-Output ""
