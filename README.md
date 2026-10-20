# Ubuntu Touch for Xiaomi Redmi 6 Pro (sakura)

A community port of [Ubuntu Touch](https://ubports.com) to the **Xiaomi Redmi 6 Pro** (Snapdragon 625 / msm8953), built on **Halium 9**.

> ⚠️ **Work in progress.** It boots to a working Lomiri desktop with touch, sound, Wi-Fi and Bluetooth. The camera does not work yet, and calls, mobile data and GPS have not been tested. Not ready to be your daily phone.

| | |
|---|---|
| Device | Xiaomi Redmi 6 Pro (`sakura`) |
| Tested model | India (`sakura_india`), 4 GB RAM / 64 GB |
| SoC | Qualcomm Snapdragon 625 (msm8953), Adreno 506 |
| Android base | Halium 9 (stock MIUI 12, Android 9 vendor) |
| Kernel | Xiaomi `sakura-p-oss` 3.18.120 with Halium patches |
| Ubuntu Touch | 24.04 (Noble) based, Lomiri |

## What works

| Feature | Status | Notes |
|---|---|---|
| Boot / Lomiri UI | ✅ Working | |
| Display & graphics (Adreno 506) | ✅ Working | Hardware-accelerated via libhybris |
| Touchscreen | ✅ Working | Goodix; needs the udev override in this repo |
| Sound (speaker) | ✅ Working | |
| Wi-Fi | ✅ Working | Prima/pronto driver built into the kernel |
| Bluetooth | ⚠️ Partial | Radio works and finds devices; scanning from Settings is unreliable; pairing not tested yet |
| Vibration | ✅ Working | |
| Battery / charging status | ✅ Working | |
| Sensors (sensorfw) | ✅ Running | Auto-rotation not yet confirmed |
| Deep sleep / suspend | ✅ Working | |
| zram swap | ✅ Working | 1.5 GB, enabled by default |
| AppArmor app confinement | ✅ Working | AppArmor 3 backport |
| SSH / USB networking | ✅ Working | |

## What doesn't work (yet)

| Feature | Status | Notes |
|---|---|---|
| Camera | ❌ Not working | The app opens but there is no preview. The camera HAL fails to start the preview stream (see [Known issues](#known-issues)) |
| Fingerprint | ❌ Disabled | The vendor HAL reports the sensor as not available and crash-loops, so it is turned off |
| Calls / SMS / mobile data | ❓ Untested | The modem boots and oFono is running |
| GPS | ❓ Untested | Location services are running |
| Microphone, earpiece, headphone jack | ❓ Untested | |
| Flashlight | ❓ Untested | |
| Video playback (hardware decoding) | ❓ Untested | |
| MTP (file transfer to PC) | ❓ Untested | |
| Second rear camera | ❌ | Fails to power up (GPIO conflict with the main camera) |

Help testing the ❓ items is very welcome. Please open an issue with what you tried and what happened.

## Before you start

- **Unlocked bootloader** is required.
- **This wipes your phone.** Back up everything first.
- You need the **stock MIUI 12 (Android 9) firmware** on the phone. Ubuntu Touch uses its vendor and firmware partitions. Tested with **V12.0.2.0.PDMMIXM** (India).
- A recovery that can push files: TWRP for sakura.
- A Linux PC with `adb` and `fastboot` ([platform-tools](https://developer.android.com/tools/releases/platform-tools)).

Check your exact model in fastboot mode:

```bash
fastboot getvar product   # sakura_india or sakura
```

Only `sakura_india` has been tested. The global `sakura` uses the same hardware and should work, but is unconfirmed.

## Installation

### 1. Flash stock MIUI 12 (Android 9)

Download the **Fastboot ROM** for your model (for India: `sakura_india_global_images_V12.0.2.0.PDMMIXM`) and flash it **without** relocking the bootloader:

```bash
tar xzf sakura_india_global_images_*.tgz
cd sakura_india_global_images_*/
./flash_all.sh -S 256M      # NEVER use flash_all_lock.sh
```

> If flashing stops with `Protocol error`, keep the `-S 256M` (or a smaller value). It splits large images into chunks.

Boot MIUI once, then go back to fastboot and flash TWRP:

```bash
fastboot flash recovery twrp.img
```

### 2. Flash the Ubuntu Touch boot image

Download `boot.img` and `rootfs.img.xz` from the [Releases](../../releases) page.

```bash
fastboot -S 16M flash boot boot.img
```

### 3. Install the system image

Boot into TWRP (**Volume Up + Power**). Go to **Wipe → Format Data** and type `yes`. This removes MIUI's encryption.

Then, on the PC:

```bash
xz -d rootfs.img.xz
adb push rootfs.img /data/ubuntu.img      # must be named ubuntu.img
adb reboot
```

The first boot takes a few minutes.

### 4. (Recommended) Grow the system image

The default image is almost full, so app installs and updates will fail. After the first boot, connect over USB and grow it to 8 GB:

```bash
ssh phablet@10.15.19.82     # see "Connecting over SSH" below
sudo mount -o remount,rw /
sudo truncate -s 8G /userdata/ubuntu.img
sudo losetup -c /dev/loop0
sudo resize2fs /dev/loop0
df -h /
```

## Connecting over SSH

With the phone plugged in over USB, it appears as a network adapter, and the phone has the address `10.15.19.82`. SSH is off by default. To enable it, open **Terminal** on the phone:

```bash
sudo systemctl enable --now ssh
```

(`sudo` asks for the passcode you set during first setup.)

Then add your key to `~/.ssh/authorized_keys` on the phone and connect:

```bash
ssh phablet@10.15.19.82
```

Once Wi-Fi is set up, the phone's Wi-Fi address works too.

## Building it yourself

Requirements: an Ubuntu/Debian x86_64 machine with about 30 GB of free space.

```bash
git clone https://github.com/mastersword64/ubuntu-touch-xiaomi-sakura
cd ubuntu-touch-xiaomi-sakura
./build.sh
```

`build.sh`:
1. installs the build packages,
2. downloads Xiaomi's kernel source (`MiCode/Xiaomi_Kernel_OpenSource`, branch `sakura-p-oss`),
3. applies the patches in `kernel-patches/`,
4. builds the kernel and `boot.img` with the [UBports Halium build tools](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools),
5. builds `rootfs.img` with this repo's `overlay/` included.

Output: `build-out/device/images/boot.img` and `build-out/device/images/rootfs.img`.

## What this port changes

### Kernel (`kernel-patches/`)
- **Halium config** (`arch/arm64/configs/halium.config`): namespaces, devtmpfs, VT, cgroups, binder devices, IKCONFIG.
- **`DEVPTS_MULTIPLE_INSTANCES`**: required for the Android LXC container to start.
- **Wi-Fi**: Xiaomi's stock `pronto_wlan.ko` module is signed with Xiaomi's key and is refused by any custom kernel, so the open-source **prima** driver (from LineageOS `android_kernel_xiaomi_msm8953`) is built into the kernel instead.
- **`BT_HCIVHCI`**: needed by `bluebinder` for Bluetooth.
- **AppArmor 3 backport** (from [ubports-mido/3.18-Kernel-Patches](https://github.com/ubports-mido/3.18-Kernel-Patches)), set as the default LSM. Without it, `media-hub` and the camera app crash.
- Build fixes for modern GCC/hosts (dtc `yylloc`, no python2 wrapper).

### System overlay (`overlay/system/` → copied into the root filesystem)
- `system/etc/udev/rules.d/70-sakura.rules`: device permissions generated from Android's `ueventd.rc`, with Android group names replaced by numeric IDs (Ubuntu has no `camera`, `system`, … groups). Fixes graphics ("could not select EGL config") and camera device access.
- `system/etc/udev/rules.d/99-goodix-touchscreen.rules` + `system/etc/libinput/local-overrides.quirks`: the Goodix touchscreen advertises stylus buttons with no resolution, so libinput ignored it entirely. This forces it to be treated as a touchscreen.
- `system/etc/systemd/system/bluebinder.service.d/wait-for-wifi.conf`: Wi-Fi and Bluetooth share one chip (WCNSS/pronto). If Bluetooth powers it up first, Wi-Fi never starts, so Bluetooth waits for `wlan0`.
- `system/opt/halium-overlay/android/vendor/etc/init/*.rc`: disables 7 vendor services that crash-loop every 5 seconds on Ubuntu Touch (Xiaomi payment/security daemons and the fingerprint HAL).

## Known issues

- **Camera, no preview:** with the default HAL1, `startPreview` fails with `Invalid cam_format 2088533116` (`0x7C7C7C7C`, an uninitialized stream format) followed by `failed to start channels`. Setting `persist.camera.HAL3.enabled=1` was tried; the app then shows a spinner. Help welcome.
- **Bluetooth scanning:** BlueZ's `SetDiscoveryFilter` is not supported by the 3.18 kernel, so scanning from Settings may stop or show nothing. `btmgmt find` works.
- **`lxc-attach` is refused with AppArmor enabled.** For debugging the Android side, use:
  ```bash
  sudo nsenter -t $(sudo lxc-info -n android -p -H) -m -p -- /system/bin/logcat
  ```

## Going back to Android

Flash the stock fastboot ROM again with `flash_all.sh` (not `flash_all_lock.sh`).

## Credits

- [UBports](https://ubports.com): Ubuntu Touch, Lomiri, Halium build tools
- [Halium](https://halium.org)
- [Xiaomi](https://github.com/MiCode/Xiaomi_Kernel_OpenSource): kernel source (`sakura-p-oss`)
- [LineageOS](https://github.com/LineageOS/android_kernel_xiaomi_msm8953): prima Wi-Fi driver
- [ubports-mido](https://github.com/ubports-mido/3.18-Kernel-Patches): AppArmor 3 backport for 3.18

## License

Kernel patches are under **GPL-2.0**, like the Linux kernel. The build scripts and configuration in this repo are also under GPL-2.0 unless a file says otherwise.

**Disclaimer:** flashing custom software can brick your device and void your warranty. You do this at your own risk.
