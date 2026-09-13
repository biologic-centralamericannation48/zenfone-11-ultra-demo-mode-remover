$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$mainScript = Join-Path $root "asus-demo-rescue.ps1"
$staticScript = Join-Path $PSScriptRoot "static-safety.ps1"
$fakeAdb = Join-Path $PSScriptRoot "fixtures\fake-adb.cmd"
$fakeFastboot = Join-Path $PSScriptRoot "fixtures\fake-fastboot.cmd"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $staticScript
if ($LASTEXITCODE -ne 0) {
    throw "Static safety checks failed."
}

$diagnose = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $mainScript `
    -Mode Diagnose `
    -AdbPath $fakeAdb `
    -FastbootPath $fakeFastboot 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Fake Diagnose failed:`n$($diagnose -join "`n")"
}

$diagnoseText = $diagnose -join "`n"
if ($diagnoseText -notmatch "ASUS_AI2401_H") {
    throw "Diagnose output did not contain the validated model."
}
if ($diagnoseText -notmatch "ADF partition link exists") {
    throw "Diagnose output did not confirm the ADF fixture."
}

$verify = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $mainScript `
    -Mode Verify `
    -AdbPath $fakeAdb `
    -FastbootPath $fakeFastboot 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Fake Verify failed:`n$($verify -join "`n")"
}

$verifyText = $verify -join "`n"
if ($verifyText -notmatch "Android demo settings are off") {
    throw "Verify output did not report demo settings off."
}

$quotedMain = '"' + $mainScript + '"'
$quotedAdb = '"' + $fakeAdb + '"'
$quotedFastboot = '"' + $fakeFastboot + '"'
$clearCommand = "(echo(I OWN THIS DEVICE& echo(ERASE ADF FAKE123) | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $quotedMain -Mode Clear -AdbPath $quotedAdb -FastbootPath $quotedFastboot"
$clear = & cmd.exe /d /s /c $clearCommand 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Fake Clear failed:`n$($clear -join "`n")"
}

$clearText = $clear -join "`n"
if ($clearText -notmatch "ADF erase completed") {
    throw "Clear output did not report a completed ADF erase."
}
if ($clearText -notmatch "Android restarted and demo settings are off") {
    throw "Clear output did not complete the post-reboot stage."
}

Write-Host "All tests passed." -ForegroundColor Green
