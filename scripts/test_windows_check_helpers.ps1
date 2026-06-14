#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "windows-check-helpers.ps1")

function Get-NativeExitHarness {
    if ($IsWindows -or $env:ComSpec) {
        $cmdPath = if ($env:ComSpec) { $env:ComSpec } else { (Get-Command cmd.exe -CommandType Application -ErrorAction Stop).Source }
        return [pscustomobject]@{
            FilePath = $cmdPath
            SuccessArguments = @("/d", "/c", "exit", "/b", "0")
            FailureArguments = @("/d", "/c", "exit", "/b", "7")
        }
    }

    $shPath = if (Test-Path -LiteralPath "/bin/sh") { "/bin/sh" } else { (Get-Command sh -CommandType Application -ErrorAction Stop).Source }
    return [pscustomobject]@{
        FilePath = $shPath
        SuccessArguments = @("-c", "exit 0")
        FailureArguments = @("-c", "exit 7")
    }
}

function Assert-ThrowsWithMessage {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedMessage
    )

    $threw = $false
    try {
        & $ScriptBlock
    } catch {
        $threw = $true
        if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
            throw "Expected exception matching '$ExpectedMessage', got '$($_.Exception.Message)'."
        }
    }

    if (-not $threw) {
        throw "Expected command to throw with message matching '$ExpectedMessage'."
    }
}

$nativeHarness = Get-NativeExitHarness

Invoke-CheckedNative -FilePath $nativeHarness.FilePath -Arguments $nativeHarness.SuccessArguments

Assert-ThrowsWithMessage `
    -ExpectedMessage "failed with exit code 7" `
    -ScriptBlock {
        Invoke-CheckedNative -FilePath $nativeHarness.FilePath -Arguments $nativeHarness.FailureArguments
    }

Write-Output "Windows check helper runtime harness passed."
