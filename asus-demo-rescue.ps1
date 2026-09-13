[CmdletBinding()]
param(
    [ValidateSet("Interactive", "Diagnose", "Clear", "Verify", "Help")]
    [string]$Mode = "Interactive",

    [string]$AdbPath,

    [string]$FastbootPath,

    [ValidateRange(15, 300)]
    [int]$TimeoutSeconds = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:SupportedModel = "ASUS_AI2401_H"
$script:SupportedBootProduct = "pineapple"
$script:ExpectedAdfType = "ext4"
$script:ExpectedAdfSize = "0x2000000"
$script:Version = "0.1.0"
$script:Adb = $null
$script:Fastboot = $null

function Write-Banner {
    Write-Host ""
    Write-Host "AI2401 ADF Rescue v$script:Version" -ForegroundColor Cyan
    Write-Host "Unofficial ASUS Zenfone 11 Ultra retail-demo recovery tool"
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "[>] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarningText {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Find-AndroidTool {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$ExplicitPath
    )

    $runningOnWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or ($env:OS -eq "Windows_NT")
    $fileName = if ($runningOnWindows) { "$Name.exe" } else { $Name }
    $candidates = New-Object System.Collections.Generic.List[string]

    if ($ExplicitPath) {
        $candidates.Add($ExplicitPath)
    }

    $candidates.Add((Join-Path $PSScriptRoot "platform-tools\$fileName"))
    $candidates.Add((Join-Path (Split-Path $PSScriptRoot -Parent) "platform-tools\$fileName"))

    if ($env:ANDROID_HOME) {
        $candidates.Add((Join-Path $env:ANDROID_HOME "platform-tools\$fileName"))
    }

    $pathCommand = Get-Command $fileName -ErrorAction SilentlyContinue
    if ($pathCommand) {
        $candidates.Add($pathCommand.Source)
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Could not find $fileName. Download Android SDK Platform-Tools and place the platform-tools folder beside this script."
}

function Initialize-Tools {
    $script:Adb = Find-AndroidTool -Name "adb" -ExplicitPath $AdbPath
    $script:Fastboot = Find-AndroidTool -Name "fastboot" -ExplicitPath $FastbootPath
    Write-Success "adb: $script:Adb"
    Write-Success "fastboot: $script:Fastboot"
}

function Invoke-ExternalTool {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = & $Path @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    $text = (($lines | ForEach-Object { "$_" }) -join "`n").Trim()

    if ((-not $AllowFailure) -and $exitCode -ne 0) {
        throw "Command failed ($exitCode): $([IO.Path]::GetFileName($Path)) $($Arguments -join ' ')`n$text"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Text = $text
    }
}

function Invoke-Adb {
    param(
        [string]$Serial,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $allArguments = New-Object System.Collections.Generic.List[string]
    if ($Serial) {
        $allArguments.Add("-s")
        $allArguments.Add($Serial)
    }
    foreach ($argument in $Arguments) {
        $allArguments.Add($argument)
    }

    return Invoke-ExternalTool -Path $script:Adb -Arguments $allArguments.ToArray() -AllowFailure:$AllowFailure
}

function Invoke-Fastboot {
    param(
        [string]$Serial,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $allArguments = New-Object System.Collections.Generic.List[string]
    if ($Serial) {
        $allArguments.Add("-s")
        $allArguments.Add($Serial)
    }
    foreach ($argument in $Arguments) {
        $allArguments.Add($argument)
    }

    return Invoke-ExternalTool -Path $script:Fastboot -Arguments $allArguments.ToArray() -AllowFailure:$AllowFailure
}

function Get-AdbDevice {
    $result = Invoke-Adb -Arguments @("devices")
    $devices = New-Object System.Collections.Generic.List[object]

    foreach ($line in ($result.Text -split "`r?`n")) {
        if ($line -match '^\s*(\S+)\s+(device|unauthorized|offline)\b') {
            $devices.Add([pscustomobject]@{ Serial = $Matches[1]; State = $Matches[2] })
        }
    }

    if ($devices.Count -eq 0) {
        throw "No ADB device found. Enable USB debugging, connect one phone, and accept the authorization prompt."
    }
    if ($devices.Count -gt 1) {
        throw "More than one ADB device is connected. Disconnect every device except the target phone."
    }
    if ($devices[0].State -ne "device") {
        throw "ADB device state is '$($devices[0].State)'. Unlock the phone and accept the USB debugging prompt."
    }

    return $devices[0]
}

function Get-FastbootDevices {
    $result = Invoke-Fastboot -Arguments @("devices") -AllowFailure
    $devices = New-Object System.Collections.Generic.List[string]

    foreach ($line in ($result.Text -split "`r?`n")) {
        if ($line -match '^\s*(\S+)\s+fastboot\b') {
            $devices.Add($Matches[1])
        }
    }

    return $devices.ToArray()
}

function Wait-FastbootDevice {
    param(
        [int]$Seconds,
        [switch]$RequireBootloader
    )

    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $devices = @(Get-FastbootDevices)
        if ($devices.Count -gt 1) {
            throw "More than one fastboot device is connected. Disconnect every device except the target phone."
        }
        if ($devices.Count -eq 1) {
            if (-not $RequireBootloader) {
                return $devices[0]
            }

            $mode = Get-FastbootVariable -Serial $devices[0] -Name "is-userspace" -AllowFailure
            if ($mode -eq "no") {
                return $devices[0]
            }
        }
        Start-Sleep -Milliseconds 1500
    } while ((Get-Date) -lt $deadline)

    return $null
}

function Get-FastbootVariable {
    param(
        [Parameter(Mandatory = $true)][string]$Serial,
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$AllowFailure
    )

    $result = Invoke-Fastboot -Serial $Serial -Arguments @("getvar", $Name) -AllowFailure:$AllowFailure
    if ($result.ExitCode -ne 0) {
        return $null
    }

    $escapedName = [regex]::Escape($Name)
    $match = [regex]::Match($result.Text, "(?m)^$escapedName\s*:\s*(.+?)\s*$")
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

function Get-AdbValue {
    param(
        [Parameter(Mandatory = $true)][string]$Serial,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $result = Invoke-Adb -Serial $Serial -Arguments $Arguments -AllowFailure
    if ($result.ExitCode -ne 0) {
        return "unavailable"
    }
    if (-not $result.Text) {
        return "empty"
    }
    return $result.Text.Trim()
}

function Get-DeviceProfile {
    param([Parameter(Mandatory = $true)][string]$Serial)

    return [pscustomobject]@{
        Serial = $Serial
        Model = Get-AdbValue -Serial $Serial -Arguments @("shell", "getprop", "ro.product.model")
        Device = Get-AdbValue -Serial $Serial -Arguments @("shell", "getprop", "ro.product.device")
        Sku = Get-AdbValue -Serial $Serial -Arguments @("shell", "getprop", "ro.boot.product.hardware.sku")
        DemoMode = Get-AdbValue -Serial $Serial -Arguments @("shell", "settings", "get", "global", "device_demo_mode")
        RetailMode = Get-AdbValue -Serial $Serial -Arguments @("shell", "settings", "get", "global", "retail_demo_mode")
    }
}

function Assert-SupportedModel {
    param([Parameter(Mandatory = $true)]$Profile)

    if ($Profile.Model -ne $script:SupportedModel) {
        throw "Unsupported model '$($Profile.Model)'. This release only permits the validated model '$script:SupportedModel'."
    }
}

function Show-Diagnosis {
    Write-Step "Checking the connected Android device"
    $device = Get-AdbDevice
    $profile = Get-DeviceProfile -Serial $device.Serial

    Write-Host "Serial:       $($profile.Serial)"
    Write-Host "Model:        $($profile.Model)"
    Write-Host "Device:       $($profile.Device)"
    Write-Host "SKU:          $($profile.Sku)"
    Write-Host "Demo mode:    $($profile.DemoMode)"
    Write-Host "Retail mode:  $($profile.RetailMode)"

    $owners = Get-AdbValue -Serial $device.Serial -Arguments @("shell", "dpm", "list-owners")
    Write-Host "DPM owners:   $owners"

    $adf = Invoke-Adb -Serial $device.Serial -Arguments @("shell", "ls", "-l", "/dev/block/by-name/ADF") -AllowFailure
    if ($adf.ExitCode -eq 0 -and $adf.Text) {
        Write-Success "ADF partition link exists: $($adf.Text)"
    }
    else {
        Write-WarningText "The Android shell could not confirm /dev/block/by-name/ADF."
    }

    if ($profile.Model -eq $script:SupportedModel) {
        Write-Success "The connected model matches the validated allowlist."
    }
    else {
        Write-WarningText "This model is not supported by the Clear workflow."
    }
}

function Confirm-DestructiveAction {
    param([Parameter(Mandatory = $true)][string]$Serial)

    Write-Host ""
    Write-WarningText "This operation permanently erases only the 32 MiB ADF partition."
    Write-WarningText "Use this tool only on a device you own or are authorized to service."
    Write-WarningText "This tool does not bypass FRP, screen locks, or account security."
    Write-Host ""

    $ownership = (Read-Host "Type I OWN THIS DEVICE").Trim()
    if ($ownership -cne "I OWN THIS DEVICE") {
        throw "Ownership confirmation did not match. Nothing was changed."
    }

    $expected = "ERASE ADF $Serial"
    $confirmation = (Read-Host "Type $expected").Trim()
    if ($confirmation -cne $expected) {
        throw "Device confirmation did not match. Nothing was changed."
    }
}

function Enter-Bootloader {
    param([Parameter(Mandatory = $true)][string]$AdbSerial)

    Write-Step "Rebooting into the bootloader"
    Invoke-Adb -Serial $AdbSerial -Arguments @("reboot", "bootloader") | Out-Null

    $fastbootSerial = Wait-FastbootDevice -Seconds 15 -RequireBootloader
    if (-not $fastbootSerial) {
        Write-WarningText "Windows has not detected the bootloader USB interface."
        Read-Host "Keep the bootloader screen open, reconnect the cable (try another USB port), then press Enter"
        $fastbootSerial = Wait-FastbootDevice -Seconds $TimeoutSeconds -RequireBootloader
    }

    if (-not $fastbootSerial) {
        throw "Timed out waiting for the bottom-level bootloader. The phone was not modified."
    }
    if ($fastbootSerial -ne $AdbSerial) {
        throw "Serial mismatch: ADB was '$AdbSerial' but fastboot is '$fastbootSerial'. Nothing was erased."
    }

    Write-Success "Bottom-level bootloader connected: $fastbootSerial"
    return $fastbootSerial
}

function Assert-AdfPartition {
    param([Parameter(Mandatory = $true)][string]$Serial)

    $isUserspace = Get-FastbootVariable -Serial $Serial -Name "is-userspace"
    $bootProduct = Get-FastbootVariable -Serial $Serial -Name "product"
    $adfType = Get-FastbootVariable -Serial $Serial -Name "partition-type:ADF"
    $adfSize = Get-FastbootVariable -Serial $Serial -Name "partition-size:ADF"

    Write-Host "Boot mode:    is-userspace=$isUserspace"
    Write-Host "Boot product: $bootProduct"
    Write-Host "ADF type:     $adfType"
    Write-Host "ADF size:     $adfSize"

    foreach ($missing in @(
        @{ Name = "is-userspace"; Value = $isUserspace },
        @{ Name = "product"; Value = $bootProduct },
        @{ Name = "partition-type:ADF"; Value = $adfType },
        @{ Name = "partition-size:ADF"; Value = $adfSize }
    )) {
        if ([string]::IsNullOrWhiteSpace($missing.Value)) {
            throw "The bootloader did not report '$($missing.Name)'. Nothing was erased."
        }
    }

    if ($isUserspace -ne "no") {
        throw "Refusing to erase from fastbootd. The tool requires the bottom-level bootloader (is-userspace: no)."
    }
    if ($bootProduct -ne $script:SupportedBootProduct) {
        throw "Unexpected boot product '$bootProduct'. Expected '$script:SupportedBootProduct'."
    }
    if ($adfType -ne $script:ExpectedAdfType) {
        throw "Unexpected ADF type '$adfType'. Expected '$script:ExpectedAdfType'."
    }
    if ($adfSize.Trim().ToLowerInvariant() -ne $script:ExpectedAdfSize) {
        throw "Unexpected ADF size '$adfSize'. Expected '$script:ExpectedAdfSize' (32 MiB)."
    }
}

function Clear-Adf {
    Write-Step "Running read-only preflight checks"
    $device = Get-AdbDevice
    $profile = Get-DeviceProfile -Serial $device.Serial
    Assert-SupportedModel -Profile $profile

    Write-Success "Validated model: $($profile.Model)"
    Confirm-DestructiveAction -Serial $device.Serial

    $fastbootSerial = Enter-Bootloader -AdbSerial $device.Serial
    Assert-AdfPartition -Serial $fastbootSerial

    Write-Step "Erasing only the ADF partition"
    $eraseResult = Invoke-Fastboot -Serial $fastbootSerial -Arguments @("erase", "ADF")
    if ($eraseResult.Text -notmatch "OKAY") {
        throw "fastboot returned success but no OKAY marker was found. Stop and inspect the device before continuing."
    }
    Write-Success "ADF erase completed."
    Write-Host $eraseResult.Text

    Write-Step "Rebooting Android"
    Invoke-Fastboot -Serial $fastbootSerial -Arguments @("reboot") | Out-Null
    Write-Host "The first boot can take longer than usual."

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $adbReady = $false
    do {
        $result = Invoke-Adb -Arguments @("devices") -AllowFailure
        if ($result.Text -match "(?m)^$([regex]::Escape($device.Serial))\s+device\b") {
            $adbReady = $true
            break
        }
        Start-Sleep -Milliseconds 1500
    } while ((Get-Date) -lt $deadline)

    if ($adbReady) {
        Invoke-Adb -Serial $device.Serial -Arguments @("shell", "settings", "put", "global", "device_demo_mode", "0") -AllowFailure | Out-Null
        Invoke-Adb -Serial $device.Serial -Arguments @("shell", "settings", "put", "global", "retail_demo_mode", "0") -AllowFailure | Out-Null
        Write-Success "Android restarted and demo settings are off."
    }
    else {
        Write-WarningText "Android did not reconnect before the timeout. Unlock the phone and run Verify later."
    }

    Write-Host ""
    Write-Success "Finished. Open Settings > System > Reset options and confirm that factory reset is enabled."
}

function Verify-Result {
    Write-Step "Verifying Android-side state"
    $device = Get-AdbDevice
    $profile = Get-DeviceProfile -Serial $device.Serial
    Assert-SupportedModel -Profile $profile

    $owners = Get-AdbValue -Serial $device.Serial -Arguments @("shell", "dpm", "list-owners")
    $dmClient = Get-AdbValue -Serial $device.Serial -Arguments @("shell", "pm", "list", "packages", "com.asus.dm")

    Write-Host "Model:        $($profile.Model)"
    Write-Host "Demo mode:    $($profile.DemoMode)"
    Write-Host "Retail mode:  $($profile.RetailMode)"
    Write-Host "DPM owners:   $owners"
    Write-Host "ASUS DM:      $dmClient"

    if ($profile.DemoMode -eq "0" -and $profile.RetailMode -eq "0") {
        Write-Success "Android demo settings are off."
    }
    else {
        Write-WarningText "One or more Android demo settings are not 0."
    }

    Write-Host ""
    Write-Host "Manual verification:"
    Write-Host "1. Open Settings > System > Reset options."
    Write-Host "2. Confirm factory reset is enabled and has no retail-demo management message."
    Write-Host "3. Reboot once and confirm the demo launcher or video does not return."
}

function Show-HelpText {
    Write-Host "Usage:"
    Write-Host "  .\asus-demo-rescue.ps1"
    Write-Host "  .\asus-demo-rescue.ps1 -Mode Diagnose"
    Write-Host "  .\asus-demo-rescue.ps1 -Mode Clear"
    Write-Host "  .\asus-demo-rescue.ps1 -Mode Verify"
    Write-Host ""
    Write-Host "Optional parameters:"
    Write-Host "  -AdbPath <path>       Explicit adb executable"
    Write-Host "  -FastbootPath <path>  Explicit fastboot executable"
    Write-Host "  -TimeoutSeconds <n>   USB wait timeout (15-300, default 90)"
}

function Start-Interactive {
    Write-Host "1. Diagnose (read-only)"
    Write-Host "2. Clear ADF (destructive; exact-device confirmation required)"
    Write-Host "3. Verify"
    Write-Host "4. Exit"
    Write-Host ""
    $choice = Read-Host "Choose 1-4"

    switch ($choice) {
        "1" { Show-Diagnosis }
        "2" { Clear-Adf }
        "3" { Verify-Result }
        "4" { return }
        default { throw "Invalid choice '$choice'." }
    }
}

try {
    Write-Banner
    if ($Mode -eq "Help") {
        Show-HelpText
        exit 0
    }

    Initialize-Tools
    switch ($Mode) {
        "Interactive" { Start-Interactive }
        "Diagnose" { Show-Diagnosis }
        "Clear" { Clear-Adf }
        "Verify" { Verify-Result }
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
