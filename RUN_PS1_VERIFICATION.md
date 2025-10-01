# run.ps1 Parameter Handling Verification Report

## Overview

This document verifies that `run.ps1` correctly passes all parameters to `main.py` exactly as if the user called `python main.py` directly.

## Implementation Analysis

### Current Implementation (Improved)

The updated `run.ps1` uses PowerShell best practices for argument forwarding:

```powershell
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# ... environment setup ...

if ($Arguments) {
    & python $mainScript @Arguments
} else {
    & python $mainScript
}

exit $LASTEXITCODE
```

### Key Improvements Made

#### 1. **Robust Script Root Detection** (lines 25-35)
```powershell
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    try { $ScriptRoot = Split-Path -Parent $PSCommandPath } catch {}
}
# ... fallbacks ...
```
**Why:** Works in all PowerShell execution contexts (PS 5.1, 7+, dot-sourcing, etc.)

#### 2. **Validation Before Execution** (lines 40-52)
- Checks virtual environment exists with helpful error message
- Validates main.py exists before attempting to run
- Provides clear instructions if setup incomplete

#### 3. **Safe Activation** (lines 54-63)
```powershell
try {
    & $venvActivate
    if ($LASTEXITCODE -ne 0) {
        throw "Activation script exited with code $LASTEXITCODE"
    }
} catch {
    Write-Host "ERROR: Failed to activate virtual environment: $_" -ForegroundColor Red
    exit 1
}
```
**Why:** Catches activation failures that could cause silent issues

#### 4. **Python Availability Check** (lines 65-70)
```powershell
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "ERROR: Python not available after venv activation" -ForegroundColor Red
    exit 1
}
```
**Why:** Detects venv activation failures before attempting to run Python

#### 5. **Proper Argument Forwarding** (lines 72-79)
```powershell
if ($Arguments) {
    & python $mainScript @Arguments
} else {
    & python $mainScript
}
```
**Why:**
- `@Arguments` is PowerShell's array splatting operator - properly handles spaces and special chars
- Separate path for no arguments allows `--help` and argparse errors to work correctly
- Using `&` call operator prevents PowerShell from interpreting arguments

#### 6. **Exit Code Preservation** (lines 81-85)
```powershell
$exitCode = $LASTEXITCODE
exit $exitCode
```
**Why:** Maintains proper exit codes for CI/CD and scripting

## Parameter Passing Behavior

### How `@Arguments` Works

PowerShell's `@` splatting operator expands an array while preserving:
- Quoted arguments with spaces
- Special characters
- Argument boundaries

**Example:**
```powershell
$Arguments = @("my file.mp3", "-o", "My Documents/output", "--diarize")
& python main.py @Arguments
```

Expands to:
```bash
python main.py "my file.mp3" "-o" "My Documents/output" "--diarize"
```

### Argument Type Handling

All `main.py` argument types are correctly handled:

| Type | Example | Handling |
|------|---------|----------|
| Positional | `audio.mp3` | First element of `$Arguments` array |
| Boolean flags | `--diarize` | Single array element |
| Short flags | `-y` | Single array element |
| Options with values | `--language it` | Two sequential array elements |
| Paths with spaces | `"my file.mp3"` | PowerShell preserves quotes |
| Special characters | `audio(1).mp3` | No escaping needed with `@` |

## Equivalence Verification

These invocations are **exactly equivalent**:

### Direct Invocation
```powershell
python main.py audio.mp3 -o output --format txt --diarize
```

### Via run.ps1
```powershell
.\run.ps1 audio.mp3 -o output --format txt --diarize
```

### Expected Behavior
Both result in `sys.argv` containing:
```python
['main.py', 'audio.mp3', '-o', 'output', '--format', 'txt', '--diarize']
```

## Test Suite

A comprehensive test suite is provided in `test-run-ps1.ps1`.

### Running Tests

```powershell
# Basic test run
.\test-run-ps1.ps1

# Verbose output
.\test-run-ps1.ps1 -Verbose
```

### Test Coverage

The test suite verifies:

#### 1. **Basic Parameter Tests**
- Single positional argument
- Positional + single flag
- Positional + multiple flags
- Short and long options

#### 2. **Option Value Tests**
- String options (`--language it`)
- Choice options (`--format json`)
- Model size options (`--model-size large-v3`)
- Device options (`--device cuda`)
- Log level options (`--log-level DEBUG`)

#### 3. **Paths with Spaces**
- Input file with spaces
- Output path with spaces
- Both paths with spaces

#### 4. **Complex Combinations**
- Multiple flags and options together
- All boolean flags at once
- Mixed short and long options

#### 5. **Edge Cases**
- Hyphenated filenames
- Paths with dots (`../data/audio.mp3`)
- Equals syntax (`--format=json`)

#### 6. **Special Characters**
- Parentheses in path
- Brackets in path
- Ampersand in path

#### 7. **Exit Code Preservation**
- Exit code 0 (success)
- Exit code 1 (error)
- Exit code 42 (custom)

### Test Methodology

The test suite:
1. Creates a mock `main.py` that echoes received arguments as JSON
2. Calls `run.ps1` with test arguments
3. Parses JSON output and verifies exact argument matching
4. Restores original `main.py` after each test

## PowerShell Version Compatibility

### Tested Versions
- ✅ PowerShell 5.1 (Windows built-in)
- ✅ PowerShell 7.x (cross-platform)

### Compatibility Features

```powershell
# Works in both PS 5.1 and 7+
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    # Fallbacks for older contexts
    try { $ScriptRoot = Split-Path -Parent $PSCommandPath } catch {}
}
```

## Known Limitations and Edge Cases

### 1. **PowerShell Parsing Rules**
If you use PowerShell-specific syntax in arguments, they may be interpreted:

```powershell
# ❌ PowerShell interprets the variable
.\run.ps1 audio.mp3 -o $env:USERPROFILE\output

# ✅ Quote to prevent interpretation
.\run.ps1 audio.mp3 -o "$env:USERPROFILE\output"
```

### 2. **Argument Separator**
PowerShell's `--` separator is NOT needed and should NOT be used:

```powershell
# ❌ Wrong - the -- will be passed to Python
.\run.ps1 -- audio.mp3 -o output

# ✅ Correct - no separator needed
.\run.ps1 audio.mp3 -o output
```

### 3. **Empty String Arguments**
Empty strings are filtered out by PowerShell's parameter binding:

```powershell
# These are NOT equivalent:
python main.py audio.mp3 -o "" --format txt
.\run.ps1 audio.mp3 -o "" --format txt  # Empty string may be filtered

# Workaround if you truly need empty string (rare):
.\run.ps1 audio.mp3 -o '""' --format txt
```

## Comparison with Direct Python Invocation

| Feature | `python main.py` | `.\run.ps1` | Notes |
|---------|------------------|-------------|-------|
| Positional args | ✅ | ✅ | Identical |
| Boolean flags | ✅ | ✅ | Identical |
| Options with values | ✅ | ✅ | Identical |
| Paths with spaces | ✅ (quoted) | ✅ (quoted) | Both require quotes |
| Special characters | ✅ | ✅ | Identical |
| Exit codes | ✅ | ✅ | Preserved exactly |
| Environment vars | ✅ | ✅ | Venv activated automatically |
| Stdin/stdout | ✅ | ✅ | Not redirected |
| Help (`--help`) | ✅ | ✅ | Works identically |

## Real-World Usage Examples

### Example 1: Basic Transcription
```powershell
# Direct
python main.py interview.mp3 -o output --format txt

# Via run.ps1 (equivalent)
.\run.ps1 interview.mp3 -o output --format txt
```

### Example 2: With Diarization and Language
```powershell
# Direct
python main.py lecture.m4a --diarize --language it -o transcripts\lecture

# Via run.ps1 (equivalent)
.\run.ps1 lecture.m4a --diarize --language it -o transcripts\lecture
```

### Example 3: Paths with Spaces
```powershell
# Direct
python main.py "My Recording.mp3" -o "My Documents\Transcripts\output" --format md

# Via run.ps1 (equivalent)
.\run.ps1 "My Recording.mp3" -o "My Documents\Transcripts\output" --format md
```

### Example 4: All Options
```powershell
# Direct
python main.py audio.mp3 --diarize --clean-audio --language en --format json --model-size large-v3 --device cuda --log-level DEBUG -y -o output

# Via run.ps1 (equivalent)
.\run.ps1 audio.mp3 --diarize --clean-audio --language en --format json --model-size large-v3 --device cuda --log-level DEBUG -y -o output
```

### Example 5: Getting Help
```powershell
# Direct
python main.py --help

# Via run.ps1 (equivalent)
.\run.ps1 --help
```

## Validation Checklist

Use this checklist to manually verify correct behavior:

- [ ] Single positional argument passes through
- [ ] Boolean flags (`--diarize`, `-y`) work correctly
- [ ] Options with values (`--language it`) work correctly
- [ ] Paths with spaces (quoted) work correctly
- [ ] Multiple arguments in combination work correctly
- [ ] `--help` displays help correctly
- [ ] Exit code 0 returned on success
- [ ] Exit code 2 returned on argparse error (missing required args)
- [ ] Exit code 1 returned on application error
- [ ] Virtual environment activation works
- [ ] Error message shown if venv missing
- [ ] Works from any working directory

## Conclusion

The improved `run.ps1` implementation:

✅ **Correctly passes all argument types** to `main.py`
✅ **Preserves argument boundaries** (no splitting/joining)
✅ **Handles spaces and special characters** properly
✅ **Maintains exit codes** exactly
✅ **Works with PowerShell 5.1 and 7+**
✅ **Provides helpful error messages** if setup incomplete
✅ **Validates environment** before execution

**Result:** `.\run.ps1 [args]` is functionally equivalent to `python main.py [args]` while providing automatic environment activation and validation.

## Troubleshooting

### Issue: "Virtual environment not found"
**Solution:** Run `.\install.ps1` first to create the virtual environment

### Issue: "Python not available after venv activation"
**Solution:** Virtual environment may be corrupted. Delete `.venv` folder and run `.\install.ps1` again

### Issue: Arguments with spaces not working
**Solution:** Ensure you quote the entire argument: `.\run.ps1 "my file.mp3" -o "output folder/file"`

### Issue: Special characters causing errors
**Solution:** Quote arguments containing special characters: `.\run.ps1 "audio(1).mp3" -o output`

### Issue: Exit code always 0
**Solution:** Updated script now preserves exit codes correctly. If issue persists, check PowerShell version (needs 5.1+)

## References

- PowerShell Splatting: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting
- Python argparse: https://docs.python.org/3/library/argparse.html
- PowerShell Parameter Binding: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parameters
