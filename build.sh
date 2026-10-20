#!/bin/bash
# Build Ubuntu Touch (Halium 9) for Xiaomi Redmi 6 Pro (sakura)
# Run from the root of this repository on an Ubuntu/Debian x86_64 machine.
set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
OUT="$REPO/build-out"

echo "==> 1/5 Installing build packages"
sudo apt update
sudo apt install -y bc bison build-essential ca-certificates cpio curl flex git \
  kmod libssl-dev unzip wget xz-utils jq android-sdk-libsparse-utils \
  python3 python-is-python3 || true
# Old prebuilt toolchains need libtinfo.so.5
if [ ! -e /usr/lib/x86_64-linux-gnu/libtinfo.so.5 ] && [ -e /usr/lib/x86_64-linux-gnu/libtinfo.so.6 ]; then
  sudo ln -s libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5
fi

mkdir -p "$OUT"
cd "$OUT"

echo "==> 2/5 Kernel source (Xiaomi sakura-p-oss) + port patches"
if [ ! -d kernel ]; then
  git clone --depth 1 -b sakura-p-oss https://github.com/MiCode/Xiaomi_Kernel_OpenSource kernel
  cd kernel
  git checkout -b halium-9
  git -c user.name=build -c user.email=build@local am "$REPO"/kernel-patches/*.patch
  cd ..
fi

echo "==> 3/5 Device folder and UBports build tools"
mkdir -p device
cp "$REPO/deviceinfo" device/deviceinfo
sed -i "s|^deviceinfo_kernel_source=.*|deviceinfo_kernel_source=\"$OUT/kernel\"|" device/deviceinfo
rm -rf device/overlay && cp -a "$REPO/overlay" device/overlay
if [ ! -d device/build ]; then
  git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools device/build
fi
cd device

echo "==> 4/5 Kernel and boot.img"
./build/build.sh -b workdir
mkdir -p images
cp workdir/tmp/partitions/boot.img images/boot.img 2>/dev/null || true

echo "==> 5/5 rootfs.img (downloads ~1 GB)"
./build/prepare-fake-ota.sh out/device_sakura_usrmerge.tar.xz ota
./build/system-image-from-ota.sh ota/ubuntu_command images
cp workdir/tmp/partitions/boot.img images/boot.img 2>/dev/null || true

echo
echo "DONE:"
ls -lh "$OUT/device/images"
