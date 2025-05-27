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
    'â˜"' = '✓'
    'âœ"' = '✓'
    'â†'' = '✓'
    'â†¨' = '✓'
    'â†'' = '→'
    'â€"' = '–'
    'â€™' = "'"
    'â€œ' = '"'
    'â€' = '"'
    'â€¦' = '...'
    
    # Other problematic characters
    'Ã¡' = 'á'
    'Ã©' = 'é'
    'Ã­' = 'í'
    'Ã³' = 'ó'
    'Ãº' = 'ú'
    'Ã±' = 'ñ'
    'Ã¼' = 'ü'
    
    # Characters that cause PowerShell parsing errors
    'â€˜' = "'"
    'â€™' = "'"
    'â€œ' = '"'
    'â€' = '"'
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

function Test-FileEncoding {
    param([string]$FilePath)
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        
        # Check for BOM
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return "UTF8-BOM"
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            return "UTF16-LE"
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            return "UTF16-BE"
        }
        else {
            # Try to detect by content
            $content = [System.Text.Encoding]::UTF8.GetString($bytes)
            if ($content -match $ControlCharPattern -or $content -match 'â|Ã') {
                return "CORRUPTED"
            }
            return "UTF8"
        }
    }
    catch {
        return "ERROR"
    }
}

function Fix-FileContent {
    param([string]$FilePath, [string]$Content)
    
    $fixedContent = $Content
    $changesApplied = @()
    
    # Apply character mappings
    foreach ($corruptedChar in $CharacterMappings.Keys) {
        $correctChar = $CharacterMappings[$corruptedChar]
        if ($fixedContent.Contains($corruptedChar)) {
            $fixedContent = $fixedContent.Replace($corruptedChar, $correctChar)
            $changesApplied += "$corruptedChar -> $correctChar"
        }
    }
    
    # Remove invisible control characters (except tabs, newlines, carriage returns)
    $originalLength = $fixedContent.Length
    $fixedContent = $fixedContent -replace $ControlCharPattern, ''
    if ($fixedContent.Length -ne $originalLength) {
        $removedChars = $originalLength - $fixedContent.Length
        $changesApplied += "Removed $removedChars invisible control characters"
    }
    
    # Fix common PowerShell syntax issues
    if ($FilePath -match '\.ps1$') {
        # Fix broken string quotes
        $fixedContent = $fixedContent -replace '(?<!\\)"([^"]*?)"(?=\s|$)', '"$1"'
        
        # Fix function brackets
        $fixedContent = $fixedContent -replace '\{\s*$', '{'
        
        # Ensure proper line endings
        $fixedContent = $fixedContent -replace '\r\n', "`n"
        $fixedContent = $fixedContent -replace '\r', "`n"
        $fixedContent = $fixedContent -replace '\n', "`r`n"
    }
    
    return @{
        Content = $fixedContent
        Changes = $changesApplied
        Modified = $changesApplied.Count -gt 0
    }
}

function Backup-File {
    param([string]$FilePath)
    
    $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    try {
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-Log "Backup created: $backupPath" "INFO"
        return $backupPath
    }
    catch {
        Write-Log "Failed to create backup for $FilePath : $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Test-PowerShellSyntax {
    param([string]$FilePath)
    
    if ($FilePath -notmatch '\.ps1$') {
        return $true
    }
    
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$null)
        return $true
    }
    catch {
        return $false
    }
}

function Test-PythonSyntax {
    param([string]$FilePath)
    
    if ($FilePath -notmatch '\.py$') {
        return $true
    }
    
    try {
        $result = python -m py_compile $FilePath 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Main execution
$scriptFiles = Get-ChildItem -Path "." -Recurse -Include "*.ps1", "*.py" | Where-Object { !$_.PSIsContainer }

Write-Log "Found $($scriptFiles.Count) script files to check" "INFO"

$stats = @{
    Total = 0
    Fixed = 0
    Errors = 0
    Skipped = 0
}

foreach ($file in $scriptFiles) {
    $stats.Total++
    $filePath = $file.FullName
    $relativePath = Resolve-Path -Path $filePath -Relative
    
    Write-Host ""
    Write-Log "Processing: $relativePath" "INFO"
    
    # Test current encoding
    $encoding = Test-FileEncoding -FilePath $filePath
    Write-Log "Current encoding: $encoding" "INFO"
    
    try {
        # Read file content with best-effort encoding detection
        $content = $null
        
        try {
            $content = Get-Content -Path $filePath -Raw -Encoding UTF8
        }
        catch {
            try {
                $content = Get-Content -Path $filePath -Raw -Encoding Default
            }
            catch {
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $content = [System.Text.Encoding]::UTF8.GetString($bytes)
            }
        }
        
        if ([string]::IsNullOrEmpty($content)) {
            Write-Log "File is empty or unreadable, skipping" "WARNING"
            $stats.Skipped++
            continue
        }
        
        # Check if file needs fixing
        $needsFix = $false
        
        # Check for encoding issues
        if ($encoding -eq "CORRUPTED" -or $content -match 'â|Ã') {
            $needsFix = $true
            Write-Log "Encoding issues detected" "WARNING"
        }
        
        # Check syntax
        $syntaxOk = $true
        if ($filePath -match '\.ps1$') {
            $syntaxOk = Test-PowerShellSyntax -FilePath $filePath
            if (-not $syntaxOk) {
                $needsFix = $true
                Write-Log "PowerShell syntax errors detected" "WARNING"
            }
        }
        elseif ($filePath -match '\.py$') {
            $syntaxOk = Test-PythonSyntax -FilePath $filePath
            if (-not $syntaxOk) {
                $needsFix = $true
                Write-Log "Python syntax issues detected" "WARNING"
            }
        }
        
        if (-not $needsFix) {
            Write-Log "File is OK, no changes needed" "SUCCESS"
            continue
        }
        
        # Fix the content
        $fixResult = Fix-FileContent -FilePath $filePath -Content $content
        
        if (-not $fixResult.Modified) {
            Write-Log "No fixable issues found" "INFO"
            continue
        }
        
        # Show what will be changed
        Write-Log "Changes to apply:" "INFO"
        foreach ($change in $fixResult.Changes) {
            Write-Log "  - $change" "INFO"
        }
        
        if ($WhatIf) {
            Write-Log "WHATIF: Would apply changes to $relativePath" "INFO"
            continue
        }
        
        # Create backup if requested
        if ($Backup) {
            $backupPath = Backup-File -FilePath $filePath
            if (-not $backupPath) {
                Write-Log "Skipping file due to backup failure" "ERROR"
                $stats.Errors++
                continue
            }
        }
        
        # Apply fixes
        try {
            [System.IO.File]::WriteAllText($filePath, $fixResult.Content, [System.Text.Encoding]::UTF8)
            Write-Log "File fixed successfully" "SUCCESS"
            $stats.Fixed++
            
            # Verify syntax after fix
            if ($filePath -match '\.ps1$') {
                if (Test-PowerShellSyntax -FilePath $filePath) {
                    Write-Log "PowerShell syntax verification: OK" "SUCCESS"
                }
                else {
                    Write-Log "PowerShell syntax verification: FAILED" "ERROR"
                }
            }
            elseif ($filePath -match '\.py$') {
                if (Test-PythonSyntax -FilePath $filePath) {
                    Write-Log "Python syntax verification: OK" "SUCCESS"
                }
                else {
                    Write-Log "Python syntax verification: FAILED" "ERROR"
                }
            }
        }
        catch {
            Write-Log "Failed to write fixed content: $($_.Exception.Message)" "ERROR"
            $stats.Errors++
        }
    }
    catch {
        Write-Log "Error processing file: $($_.Exception.Message)" "ERROR"
        $stats.Errors++
    }
}

# Summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Blue
Write-Log "Total files processed: $($stats.Total)" "INFO"
Write-Log "Files fixed: $($stats.Fixed)" "SUCCESS"
Write-Log "Files with errors: $($stats.Errors)" "ERROR"
Write-Log "Files skipped: $($stats.Skipped)" "WARNING"

if ($WhatIf) {
    Write-Host ""
    Write-Log "This was a dry run. Use without -WhatIf to apply changes." "INFO"
}

if ($stats.Fixed -gt 0) {
    Write-Host ""
    Write-Log "Encoding fix completed! You can now run your scripts." "SUCCESS"
}
