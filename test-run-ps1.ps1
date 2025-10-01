<#
.SYNOPSIS
    Test suite for run.ps1 parameter handling
.DESCRIPTION
    Verifies that run.ps1 correctly passes all parameters to main.py
    Tests various argument scenarios and edge cases
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$ScriptRoot = Split-Path -Parent $PSCommandPath

# ANSI color codes for output
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

# Test counter
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsTotal = 0

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n$Cyan=== $Message ===$Reset"
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    $script:TestsTotal++
    if ($Passed) {
        $script:TestsPassed++
        Write-Host "  ${Green}✓${Reset} $TestName" -NoNewline
        if ($Details) { Write-Host " ${Yellow}($Details)${Reset}" } else { Write-Host "" }
    } else {
        $script:TestsFailed++
        Write-Host "  ${Red}✗${Reset} $TestName" -NoNewline
        if ($Details) { Write-Host " ${Red}($Details)${Reset}" } else { Write-Host "" }
    }
}

function Test-ArgumentPassing {
    param(
        [string]$TestName,
        [string[]]$Arguments,
        [string]$ExpectedPattern,
        [switch]$ShouldFail
    )

    if ($Verbose) {
        Write-Host "    Testing: $TestName"
        Write-Host "    Args: $($Arguments -join ' ')"
    }

    # Create a mock main.py that echoes arguments
    $mockScript = @'
import sys
import json
print(json.dumps({
    "args": sys.argv[1:],
    "count": len(sys.argv) - 1
}))
'@

    $mockPath = Join-Path $ScriptRoot "test_main.py"
    Set-Content -Path $mockPath -Value $mockScript -Encoding UTF8

    try {
        # Temporarily replace main.py
        $originalMain = Join-Path $ScriptRoot "main.py"
        $backupMain = Join-Path $ScriptRoot "main.py.testbackup"

        if (Test-Path $originalMain) {
            Move-Item $originalMain $backupMain -Force
        }
        Move-Item $mockPath $originalMain -Force

        # Run test
        $output = & (Join-Path $ScriptRoot "run.ps1") @Arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        # Parse JSON output from mock script
        $jsonMatch = $output | Select-String -Pattern '\{.*"args".*\}' -AllMatches
        if ($jsonMatch) {
            $result = $jsonMatch.Matches[0].Value | ConvertFrom-Json
            $receivedArgs = $result.args

            # Verify arguments match
            $argsMatch = ($receivedArgs.Count -eq $Arguments.Count)
            if ($argsMatch) {
                for ($i = 0; $i -lt $Arguments.Count; $i++) {
                    if ($receivedArgs[$i] -ne $Arguments[$i]) {
                        $argsMatch = $false
                        if ($Verbose) {
                            Write-Host "    Mismatch at index $i`: Expected '$($Arguments[$i])', Got '$($receivedArgs[$i])'"
                        }
                        break
                    }
                }
            }

            if ($ShouldFail) {
                Write-TestResult $TestName (-not $argsMatch) "Should fail but arguments matched"
            } else {
                $details = if ($argsMatch) { "Passed $($receivedArgs.Count) args" } else { "Args mismatch" }
                Write-TestResult $TestName $argsMatch $details
            }
        } else {
            if ($ShouldFail) {
                Write-TestResult $TestName $true "Failed as expected"
            } else {
                Write-TestResult $TestName $false "No JSON output received"
            }
        }

    } finally {
        # Restore original main.py
        if (Test-Path $originalMain) {
            Remove-Item $originalMain -Force
        }
        if (Test-Path $backupMain) {
            Move-Item $backupMain $originalMain -Force
        }
        if (Test-Path $mockPath) {
            Remove-Item $mockPath -Force
        }
    }
}

function Test-ExitCodePreservation {
    Write-TestHeader "Exit Code Preservation Tests"

    # Create mock scripts with different exit codes
    $mockScript = @'
import sys
exit_code = int(sys.argv[1]) if len(sys.argv) > 1 else 0
sys.exit(exit_code)
'@

    $mockPath = Join-Path $ScriptRoot "test_main.py"
    Set-Content -Path $mockPath -Value $mockScript -Encoding UTF8

    try {
        $originalMain = Join-Path $ScriptRoot "main.py"
        $backupMain = Join-Path $ScriptRoot "main.py.testbackup"

        if (Test-Path $originalMain) {
            Move-Item $originalMain $backupMain -Force
        }
        Move-Item $mockPath $originalMain -Force

        # Test exit code 0
        & (Join-Path $ScriptRoot "run.ps1") "0" 2>&1 | Out-Null
        Write-TestResult "Exit code 0 preserved" ($LASTEXITCODE -eq 0)

        # Test exit code 1
        & (Join-Path $ScriptRoot "run.ps1") "1" 2>&1 | Out-Null
        Write-TestResult "Exit code 1 preserved" ($LASTEXITCODE -eq 1)

        # Test exit code 42
        & (Join-Path $ScriptRoot "run.ps1") "42" 2>&1 | Out-Null
        Write-TestResult "Exit code 42 preserved" ($LASTEXITCODE -eq 42)

    } finally {
        if (Test-Path $originalMain) {
            Remove-Item $originalMain -Force
        }
        if (Test-Path $backupMain) {
            Move-Item $backupMain $originalMain -Force
        }
        if (Test-Path $mockPath) {
            Remove-Item $mockPath -Force
        }
    }
}

# Run tests
Write-Host "${Cyan}╔════════════════════════════════════════════════════════════════╗${Reset}"
Write-Host "${Cyan}║         run.ps1 Parameter Passing Test Suite                  ║${Reset}"
Write-Host "${Cyan}╚════════════════════════════════════════════════════════════════╝${Reset}"

Write-TestHeader "Basic Parameter Tests"
Test-ArgumentPassing "Single positional argument" @("audio.mp3")
Test-ArgumentPassing "Positional + single flag" @("audio.mp3", "--diarize")
Test-ArgumentPassing "Positional + multiple flags" @("audio.mp3", "--diarize", "--clean-audio")
Test-ArgumentPassing "With short option" @("audio.mp3", "-o", "output.txt")
Test-ArgumentPassing "With long option" @("audio.mp3", "--output", "output.txt")

Write-TestHeader "Option Value Tests"
Test-ArgumentPassing "String option with value" @("audio.mp3", "--language", "it", "-o", "out")
Test-ArgumentPassing "Choice option" @("audio.mp3", "--format", "json", "-o", "out")
Test-ArgumentPassing "Model size option" @("audio.mp3", "--model-size", "large-v3", "-o", "out")
Test-ArgumentPassing "Device option" @("audio.mp3", "--device", "cuda", "-o", "out")
Test-ArgumentPassing "Log level option" @("audio.mp3", "--log-level", "DEBUG", "-o", "out")

Write-TestHeader "Path with Spaces Tests"
Test-ArgumentPassing "Input file with spaces" @("my audio file.mp3", "-o", "output")
Test-ArgumentPassing "Output path with spaces" @("audio.mp3", "-o", "My Documents/output")
Test-ArgumentPassing "Both paths with spaces" @("my file.mp3", "-o", "My Folder/output")

Write-TestHeader "Complex Argument Combinations"
Test-ArgumentPassing "Multiple flags and options" @(
    "audio.mp3",
    "--diarize",
    "--clean-audio",
    "--assume-yes",
    "--language", "en",
    "--format", "md",
    "--model-size", "base",
    "-o", "output"
)

Test-ArgumentPassing "All boolean flags" @(
    "audio.mp3",
    "--diarize",
    "--clean-audio",
    "--assume-yes",
    "--download-models",
    "--create-output-dir",
    "-o", "output"
)

Test-ArgumentPassing "Short and long options mixed" @(
    "audio.mp3",
    "-o", "output",
    "--format", "txt",
    "-y",
    "--device", "cpu"
)

Write-TestHeader "Edge Case Tests"
Test-ArgumentPassing "Hyphenated filename" @("my-audio-file.mp3", "-o", "out")
Test-ArgumentPassing "Path with dots" @("../data/audio.mp3", "-o", "./output")
Test-ArgumentPassing "Equals in option (argparse style)" @("audio.mp3", "--format=json", "-o", "out")

Write-TestHeader "Special Characters Tests"
Test-ArgumentPassing "Parentheses in path" @("audio(1).mp3", "-o", "output")
Test-ArgumentPassing "Brackets in path" @("audio[test].mp3", "-o", "output")
Test-ArgumentPassing "Ampersand in path" @("audio&test.mp3", "-o", "output")

# Exit code tests
Test-ExitCodePreservation

# Summary
Write-Host "`n${Cyan}╔════════════════════════════════════════════════════════════════╗${Reset}"
Write-Host "${Cyan}║                        Test Summary                            ║${Reset}"
Write-Host "${Cyan}╚════════════════════════════════════════════════════════════════╝${Reset}"
Write-Host ""
Write-Host "  Total Tests:  $script:TestsTotal"
Write-Host "  ${Green}Passed:       $script:TestsPassed${Reset}"
if ($script:TestsFailed -gt 0) {
    Write-Host "  ${Red}Failed:       $script:TestsFailed${Reset}"
} else {
    Write-Host "  Failed:       $script:TestsFailed"
}
Write-Host ""

$successRate = if ($script:TestsTotal -gt 0) {
    [math]::Round(($script:TestsPassed / $script:TestsTotal) * 100, 1)
} else { 0 }

if ($script:TestsFailed -eq 0) {
    Write-Host "${Green}✓ All tests passed! (100%)${Reset}"
    exit 0
} else {
    Write-Host "${Yellow}⚠ Some tests failed ($successRate% passed)${Reset}"
    exit 1
}
