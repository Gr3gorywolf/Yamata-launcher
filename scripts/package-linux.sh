#!/usr/bin/env bash
set -e

ARCH="$1"

if [[ "$ARCH" != "x86" && "$ARCH" != "arm" ]]; then
  echo "Usage: $0 <x86|arm>"
  exit 1
fi

if [[ "$ARCH" == "x86" ]]; then
  FLUTTER_ARCH="x64"
  APT_ARCH="amd64"
  LIB_ARCH="x86_64-linux-gnu"
  APPIMAGE_ARCH="x86_64"
else
  FLUTTER_ARCH="arm64"
  APT_ARCH="arm64"
  LIB_ARCH="aarch64-linux-gnu"
  APPIMAGE_ARCH="aarch64"
fi
echo "Compiling application..."
flutter build linux --release
echo "Application compiled successfully!"

echo "Building AppImage for $ARCH"
echo " - Flutter: $FLUTTER_ARCH"
echo " - APT: $APT_ARCH"
echo " - LIB: $LIB_ARCH"
echo " - AppImage: $APPIMAGE_ARCH"

cd "linux"

sed \
  -e "s/{{FLUTTER_ARCH}}/$FLUTTER_ARCH/g" \
  -e "s/{{APT_ARCH}}/$APT_ARCH/g" \
  -e "s/{{LIB_ARCH}}/$LIB_ARCH/g" \
  -e "s/{{APPIMAGE_ARCH}}/$APPIMAGE_ARCH/g" \
  appimage-template.yml > appimage.yml

echo "Running appimage-builder"
appimage-builder --recipe appimage.yml

echo "AppImage ($ARCH) built successfully"

mkdir -p ../build/output
mv "Yamata Launcher-latest-$APPIMAGE_ARCH.AppImage" "../build/output/yamata-launcher-$ARCH.AppImage"
echo "AppImage created at build/output/yamata-launcher-$ARCH.AppImage"