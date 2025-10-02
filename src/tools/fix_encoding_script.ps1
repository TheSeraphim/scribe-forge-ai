# Fix-Encoding.ps1 - Script to repair encoding issues
# Recursively fixes all encoding issues for file .ps1 and .py

param(
    [switch]$WhatIf,
    [switch]$Backup,
    [switch]$Verbose
)

Write-Host "=== Audio Transcription Tool - Encoding Fix ===" -ForegroundColor Blue
Write-Host ""

# Define mapping of common corrupted characters
$CharacterMappings = @{
    # Corrupted special characters
    '\u00e2\u02dc"' = '\u2713'
    '\u00e2\u0153"' = '\u2713'
    '\u00e2\u2020'' = '\u2713'
    '\u00e2\u2020\u00a8' = '\u2713'
    '\u00e2\u2020'' = '\u2192'
    '\u00e2\u20ac"' = '\u2013'
    '\u00e2\u20ac\u2122' = "'"
    '\u00e2\u20ac\u0153' = '"'
    '\u00e2\u20ac' = '"'
    '\u00e2\u20ac\u00a6' = '...'
    
    # Other problematic characters
    '\u00c3\u00a1' = '\u00e1'
    '\u00c3\u00a9' = '\u00e9'
    '\u00c3\u00ad' = '\u00ed'
    '\u00c3\u00b3' = '\u00f3'
    '\u00c3\u00ba' = '\u00fa'
    '\u00c3\u00b1' = '\u00f1'
    '\u00c3\u00bc' = '\u00fc'
    
    # Characters that cause PowerShell parsing errors
    '\u00e2\u20ac\u02dc' = "'"
    '\u00e2\u20ac\u2122' = "'"
    '\u00e2\u20ac\u0153' = '"'
    '\u00e2\u20ac' = '"'
    '"' = '"'
    '"' = '"'
    ''' = "'"
    ''' = "'"
}

# Pattern to remove invisible control characters
$ControlCharPattern = '[^\x20-\x7E\x0A\x0D\x09]'

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] $Level : $Message" -ForegroundColor $color
}

# Dummy body preserved (truncated)
Write-Log "Encoding fixer loaded" "INFO"
