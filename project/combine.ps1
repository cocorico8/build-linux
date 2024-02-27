## Take the built project files and combines them into a release folder.

# Function that pretends the date/time to the start of a log
function Write-Log {
    Param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

Write-Log "✅ Combining Release Files"

# Set directories
$DIR_ABS = (Get-Location).Path
$DIR_OUTPUT = "$DIR_ABS\release"
$MERGE_DIRS = @(
	# Project build directories
    "$DIR_ABS\builds\Server\project\build\",
    "$DIR_ABS\builds\Modules\project\build\",
    "$DIR_ABS\builds\Launcher\project\Build\",
	
	# Static files
	"$DIR_ABS\project\static\BepInEx.Config\",
	"$DIR_ABS\project\static\BepInEx.ConfigurationManager.Config\",
	"$DIR_ABS\project\static\BepInEx.ConfigurationManager_v18.0.1\",
	"$DIR_ABS\project\static\BepInEx_x64_5.4.22.0\"
)

# Remove the release directory if it already exists
if (Test-Path -Path $DIR_OUTPUT) {
    Write-Log "⏳ Removing Previous release Directory"
    Remove-Item -Recurse -Force $DIR_OUTPUT
}

# Create new directory
New-Item -Path $DIR_OUTPUT -ItemType Directory -Force | Out-Null

# Function to copy project build files
function Copy-ProjectFiles {
    param (
        [string]$SOURCE
    )

	Write-Log "⏳ Combining directory into release: $SOURCE"
	
    Get-ChildItem -Path $SOURCE -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($SOURCE.Length)
        $targetPath = Join-Path -Path $DIR_OUTPUT -ChildPath $relativePath

        if (-not $_.PSIsContainer) {
            $targetDir = Split-Path -Path $targetPath -Parent
            if (-not (Test-Path -Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            if ($_.FullName -ne $targetPath) {
                Copy-Item -Path $_.FullName -Destination $targetPath -Force
            }
        }
    }
}

try {
    foreach ($DIR in $MERGE_DIRS) {
        Copy-ProjectFiles -SOURCE $DIR
    }
} catch {
    Write-Log "❌ An error occurred: $_"
}

Write-Log "⏳ Compressing release directory into ZIP archive."
try {
    # Define the 7Zip executable path
    $7Z_PATH = "C:\Program Files\7-Zip\7z.exe"
    
    # Define the source directory and the output ZIP file path
    $ZIP_FILE = "$DIR_ABS\SPT.zip"

    # Display the compression details
    Write-Log " ↪ Algorithm: Deflate"
	Write-Log " ↪ Compression Level: 9"
	
    # Calculate and display the size of the original source folder
    $DIR_SIZE = (Get-ChildItem $DIR_OUTPUT -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Log " ↪ Original Directory Size: $DIR_SIZE MB"
	
	Write-Log " ↪ Writing archive..."

    # Execute 7-Zip to compress the folder
    & $7Z_PATH a -tzip -mm=Deflate -mx=9 "$ZIP_FILE" "$DIR_OUTPUT\*" > $null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "❌ 7-Zip command failed."
        exit 1 # Fail the build
    }

    # Calculate and display the size of the zip file after compression
    $SIZE_NEW = (Get-Item $ZIP_FILE).Length / 1MB
    Write-Log " ↪ Compressed ZIP File Size: $SIZE_NEW MB"
}
catch {
    Write-Log "❌ FAIL: Error executing 7-Zip: $_"
    exit 1 # Exit with an error code
}

Write-Log "⚡ Release Files Combined ⚡"
Write-Output ""
