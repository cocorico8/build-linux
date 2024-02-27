## Validate that the tag exists in each project repository, or fail silent.

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

Write-Log "✅ Validating Tag"
Write-Log "⏳ Checking for existence of tag: $RELEASE_TAG"

$REPOS = @(
    "https://dev.sp-tarkov.com/SPT-AKI/Server.git",
    "https://dev.sp-tarkov.com/SPT-AKI/Modules.git",
	"https://dev.sp-tarkov.com/SPT-AKI/Launcher.git"
)

$TAG_REGEX = "^[a-zA-Z0-9\.\-_]+$" # Modify this regex as necessary to match your tagging conventions
if (-not ($RELEASE_TAG -match $TAG_REGEX)) {
    Write-Log "Invalid tag format: $RELEASE_TAG"
    exit 1 # Exit if tag does not match expected pattern
}

$ALL_FOUND = $true
foreach ($REPO in $REPOS) {
    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "git"
        $processInfo.Arguments = "ls-remote --tags $REPO"
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
            Write-Log "Error listing tags: $stderr"
            throw "git ls-remote command failed with exit code $($process.ExitCode)"
        }

        if ($stdout -match "refs/tags/$RELEASE_TAG") {
            Write-Log " ↪ ✅ Tag '$RELEASE_TAG' found in $REPO"
        } else {
            Write-Log " ↪ ❌ Tag '$RELEASE_TAG' not found in $REPO"
			$ALL_FOUND = $false
        }
    }
    catch {
		$errorMessage = "❌ FAIL: Error checking tag in ${REPO}: $_"
        Write-Log $errorMessage
        $ALL_FOUND = $false
		continue # Continue checking others
    }
}

if (-not $ALL_FOUND) {
	# The build tag is not yet in all modules.
	Write-Log "❌ Required Build Tag Missing ❌"
    exit 1
}

Write-Log "⚡ Build Tag Confirmed ⚡"
Write-Output ""
