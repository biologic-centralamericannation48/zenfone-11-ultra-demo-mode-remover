# Contributing

Safety takes priority over model coverage.

## Pull requests for another model

A new model must not reuse the AI2401 erase path based on name similarity alone. Include:

- Exact Android model and device properties.
- Read-only `fastboot getvar` results for product, mode, ADF type, and ADF size.
- Confirmation that the partition is an OEM retail-demo flag on that exact firmware.
- A successful recovery report from owned hardware.
- A review showing that no user-data, boot, security, or unrelated partition is affected.

Redact device serials, IMEI values, account addresses, and other personal data before posting logs.

## Non-goals

Pull requests that add any of the following will not be accepted:

- Arbitrary partition names or free-form fastboot commands.
- Bootloader unlocking.
- FRP, screen-lock, account, or enterprise-management bypasses.
- Qualcomm EDL authentication bypasses.
- Redistribution of proprietary ASUS or Google binaries.

## Local checks

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\asus-demo-rescue.ps1 -Mode Help
```
