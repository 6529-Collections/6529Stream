#Requires -Version 5.1

function Invoke-CheckedNative {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $FilePath @Arguments
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        $displayArgs = if ($Arguments.Count -gt 0) { " " + ($Arguments -join " ") } else { "" }
        throw "$FilePath$displayArgs failed with exit code $exitCode."
    }
}
