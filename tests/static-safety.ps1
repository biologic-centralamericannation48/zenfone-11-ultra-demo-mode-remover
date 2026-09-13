$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $root "asus-demo-rescue.ps1"
$source = Get-Content -LiteralPath $scriptPath -Raw

$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
)

if ($parseErrors.Count -ne 0) {
    $messages = ($parseErrors | ForEach-Object { $_.Message }) -join "`n"
    throw "PowerShell parse errors:`n$messages"
}

$requiredPattern = '@\("erase",\s*"ADF"\)'
$requiredMatches = [regex]::Matches($source, $requiredPattern)
if ($requiredMatches.Count -ne 1) {
    throw "Expected exactly one fixed ADF erase invocation, found $($requiredMatches.Count)."
}

$forbiddenPatterns = @(
    'flashing\s+unlock',
    'oem\s+unlock',
    '@\("erase",\s*"(?:boot|system|vendor|userdata|misc|super|recovery)"\)',
    'Read-Host\s+".*partition'
)

foreach ($pattern in $forbiddenPatterns) {
    if ($source -match $pattern) {
        throw "Forbidden safety pattern found: $pattern"
    }
}

Write-Host "Static safety checks passed." -ForegroundColor Green
