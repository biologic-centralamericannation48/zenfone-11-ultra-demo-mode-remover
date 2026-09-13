# Troubleshooting

## `No ADB device found`

- Use a USB data cable, not a charge-only cable.
- Unlock Android and enable Developer options > USB debugging.
- Accept the USB debugging fingerprint prompt.
- Run `adb devices` and confirm the state is `device`, not `unauthorized` or `offline`.

## The phone reaches bootloader but `fastboot devices` is empty

This was observed on the validated AI2401. Keep the bootloader screen open, then:

1. Disconnect and reconnect the cable.
2. Try another USB port on the computer.
3. Avoid USB hubs.
4. Confirm Windows Device Manager shows **ASUS Android Bootloader Interface** or another working Android bootloader driver.

Do not select **Start** while the tool is waiting for fastboot.

## `is-userspace: yes`

The phone is in fastbootd, not the bottom-level bootloader. Do not erase `ADF` there. Return to Android and let this tool run the Clear workflow, or use:

```text
fastboot reboot bootloader
```

Reconnect the USB cable if Windows loses the device during the transition. Continue only after:

```text
fastboot getvar is-userspace
is-userspace: no
```

## `Erase is not allowed on locked devices`

On the validated device, this message appeared in fastbootd. It did **not** mean the bootloader needed to be unlocked. Switching to the bottom-level bootloader allowed the fixed `ADF` erase while the bootloader remained locked.

Do not attempt random unlock commands or third-party unlock APKs. This project neither needs nor supports bootloader unlocking.

## Model, product, type, or size mismatch

Stop. The tool intentionally refuses to continue unless every validated value matches:

```text
Android model:      ASUS_AI2401_H
Boot product:       pineapple
ADF type:           ext4
ADF size:           0x2000000
Boot mode:          is-userspace: no
```

A mismatch may indicate a different phone, firmware layout, or partition. Do not edit the script to bypass the check unless you are developing and validating support for new hardware.

## The erase succeeded but Settings still shows demo management

1. Reboot Android once.
2. Run the Verify workflow.
3. Check `adb shell dpm list-owners` for an independent Device Owner or Profile Owner.
4. Complete a normal factory reset from Settings after backing up data and removing accounts if appropriate.

Do not use this project to remove legitimate enterprise management from an organization-owned device.

## Factory Reset Protection

This project does not remove FRP. Before factory reset, know the credentials for the Google account currently on the phone. If you are preparing your own device for transfer, remove your Google account through Android Settings first.

