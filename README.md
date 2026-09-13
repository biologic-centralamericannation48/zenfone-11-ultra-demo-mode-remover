# Zenfone 11 Ultra Demo Mode Remover

**Remove ASUS retail demo mode from a Zenfone 11 Ultra (`ASUS_AI2401_H` / AI2401).**

[繁體中文說明 / 解除華碩 Zenfone 11 Ultra 展示模式](README.zh-TW.md)

An unofficial, safety-focused Windows tool for removing the persistent ASUS retail-demo flag from a **validated Zenfone 11 Ultra (`ASUS_AI2401_H` / AI2401)**.

## Does this match your problem?

Use this tool if, on a Zenfone 11 Ultra:

- **Settings > System > Reset options** says factory reset is **managed by retail demo mode** / 「已被展示模式管理」.
- **Erase all data (factory reset)** is greyed out and cannot be tapped.
- A recovery-mode factory reset completed, but the demo management came back anyway.
- The phone was bought ex-display / as a store demo unit (店頭展示機) and still behaves like one.
- The retail demo launcher or demo video returns after every reset.

If instead the phone is managed by a company or school (a real Device Owner shown by `adb shell dpm list-owners`), this tool is not for you and will not help. See [CONTRIBUTING.md](CONTRIBUTING.md) for what this project deliberately refuses to do.

The tool automates the recovery path that was validated on real hardware: it moves from authorized ADB into the bottom-level bootloader, verifies the exact device and `ADF` partition metadata, and erases only `ADF`.

> [!WARNING]
> This is an unofficial community project, not an ASUS product. Erasing a partition is destructive. Use it only on a device you own or are authorized to service. There is no warranty.

## Safety design

- Allows only the validated Android model `ASUS_AI2401_H`.
- Requires bottom-level bootloader mode (`is-userspace: no`), not fastbootd.
- Requires boot product `pineapple`.
- Requires `ADF` to be `ext4` and exactly `0x2000000` bytes (32 MiB).
- Requires two typed confirmations, including the connected device serial.
- Contains one fixed erase target: `ADF`.
- Does not unlock the bootloader.
- Does not erase `boot`, `system`, `vendor`, `userdata`, `misc`, or any user-selected partition.
- Does not bypass Factory Reset Protection, screen locks, Google accounts, or other ownership controls.
- Does not redistribute ASUS firmware, APKs, drivers, or Google Platform-Tools.

## Requirements

- Windows 10 or Windows 11.
- ASUS Zenfone 11 Ultra reporting model `ASUS_AI2401_H`.
- A USB data cable and physical access to the unlocked phone.
- USB debugging enabled and authorized.
- The latest [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools).
- A working ASUS/Android bootloader USB driver.

Extract Google's `platform-tools` folder beside this repository, or make `adb` and `fastboot` available on `PATH`:

```text
asus-retail-demo-rescue/
  asus-demo-rescue.ps1
  Start-Rescue.cmd
  platform-tools/
    adb.exe
    fastboot.exe
```

The script also checks for a sibling `../platform-tools` directory and `%ANDROID_HOME%\platform-tools`.

## Use

1. Back up anything important.
2. Enable Developer options and USB debugging on the phone.
3. Connect the phone and accept the USB debugging authorization prompt.
4. Double-click `Start-Rescue.cmd`.
5. Run **Diagnose** first.
6. Choose **Clear ADF** only if the model and partition checks pass.
7. Follow the cable-reconnect prompt if Windows loses the device while entering the bottom-level bootloader.
8. After reboot, run **Verify**.

PowerShell users can run each stage directly without changing the machine-wide execution policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\asus-demo-rescue.ps1 -Mode Diagnose
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\asus-demo-rescue.ps1 -Mode Clear
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\asus-demo-rescue.ps1 -Mode Verify
```

## What success looks like

The erase step must end with an `OKAY` result for `ADF`. After Android boots:

- `Settings > System > Reset options` no longer says the factory reset is managed by retail/demo mode.
- **Erase all data (factory reset)** is enabled and opens normally.
- Rebooting does not restore the retail launcher or demo video.

A later factory reset should not recreate the retail state because the persistent OEM demo flag has been removed. Factory reset still erases user data, and Google account protection remains active.

## Why bottom-level bootloader matters

On the validated AI2401, userspace fastboot (`fastbootd`) could not access `ADF` correctly and rejected the erase. The bottom-level bootloader reported:

```text
is-userspace: no
partition-type:ADF: ext4
partition-size:ADF: 0x2000000
```

Only after all of those checks did `fastboot erase ADF` succeed. The tool encodes these checks and refuses to continue when they differ.

Android's generic retail-demo implementation varies by OEM. AOSP documents that leaving retail mode requires removing device management and factory-resetting from the bootloader; ASUS AI2401 adds the OEM-specific `ADF` state addressed here. See the [AOSP retail demo documentation](https://source.android.com/docs/core/display/retail-mode).

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

Do not download modified fastboot binaries, unlock APKs, or service tools from unknown sources. This project intentionally does not automate bootloader unlocking, Qualcomm EDL, authentication bypasses, or arbitrary partition writes.

## Scope and contributions

This release is deliberately restricted to the one hardware/software combination validated on a physical device. Pull requests for other models must include reproducible read-only evidence, exact partition metadata, and a safety review. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Search keywords

ASUS Zenfone 11 Ultra demo mode, retail demo mode removal, ASUS_AI2401_H, AI2401, ADF partition, factory reset managed by retail demo mode, ex-display phone, store demo unit.

華碩 Zenfone 11 Ultra 解除展示模式、解除 demo 模式、已被展示模式管理、無法恢復原廠設定、展示機、店頭展示機、零售展示模式、ADF 分割區。

## License and trademarks

MIT licensed. ASUS, Zenfone, Android, and Google are trademarks of their respective owners. This project is not affiliated with or endorsed by ASUS or Google.
