#!/usr/bin/env bash

set -e

APP_NAME="Yamata Launcher"

REPO_OWNER="Gr3gorywolf"
REPO_NAME="Yamata-launcher"

INSTALL_DIR="$HOME/Applications"
ICON_BASE_DIR="$HOME/.local/share/com.gregoryc.dev.yamata_launcher"
ICON_FILE_NAME="logo-orig.svg"

DESKTOP_DIR_USER="$HOME/.local/share/applications"
DESKTOP_DIR_SYSTEM="/usr/share/applications"
DESKTOP_FILENAME="yamata-launcher.desktop"

APPIMAGE_PATH_ARG=""
DOWNLOAD_TOOL=""

# -------------------------------------------------
# Helpers
# -------------------------------------------------

log() {
  echo "[INFO] $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

detect_downloader() {
  if command -v wget >/dev/null 2>&1; then
    DOWNLOAD_TOOL="wget"
  elif command -v curl >/dev/null 2>&1; then
    DOWNLOAD_TOOL="curl"
  else
    error "Neither wget nor curl is installed"
  fi
}

detect_arch() {
  local arch
  arch="$(uname -m)"

  case "$arch" in
    x86_64|amd64)
      echo "x86"
      ;;
    aarch64|arm64|armv7l)
      echo "arm"
      ;;
    *)
      error "Unsupported architecture: $arch"
      ;;
  esac
}

download_file() {
  local url="$1"
  local output="$2"

  log "Downloading $url"

  if [ "$DOWNLOAD_TOOL" = "wget" ]; then
    wget -O "$output" "$url"
  else
    curl -L --progress-bar -o "$output" "$url"
  fi
}

# -------------------------------------------------
# Argument parsing
# -------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appimage)
      APPIMAGE_PATH_ARG="$2"
      shift 2
      ;;
    *)
      error "Unknown argument: $1"
      ;;
  esac
done

# -------------------------------------------------
# Prepare directories
# -------------------------------------------------

mkdir -p "$INSTALL_DIR"
mkdir -p "$DESKTOP_DIR_USER"
mkdir -p "$ICON_BASE_DIR"

# -------------------------------------------------
# AppImage handling
# -------------------------------------------------

APPIMAGE_TARGET=""

if [ -n "$APPIMAGE_PATH_ARG" ]; then
  if [ ! -f "$APPIMAGE_PATH_ARG" ]; then
    error "Provided AppImage does not exist: $APPIMAGE_PATH_ARG"
  fi

  APPIMAGE_TARGET="$INSTALL_DIR/$(basename "$APPIMAGE_PATH_ARG")"
  log "Using provided AppImage"
  cp "$APPIMAGE_PATH_ARG" "$APPIMAGE_TARGET"

else
  detect_downloader
  ARCH="$(detect_arch)"

  APPIMAGE_NAME="yamata-launcher-${ARCH}.AppImage"
  APPIMAGE_TARGET="$INSTALL_DIR/$APPIMAGE_NAME"

  DOWNLOAD_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download/${APPIMAGE_NAME}"

  download_file "$DOWNLOAD_URL" "$APPIMAGE_TARGET"
fi

chmod +x "$APPIMAGE_TARGET"
log "AppImage installed at $APPIMAGE_TARGET"

# -------------------------------------------------
# Icon download (from repo assets)
# -------------------------------------------------

detect_downloader

ICON_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/master/assets/svgs/${ICON_FILE_NAME}"
ICON_TARGET="$ICON_BASE_DIR/$ICON_FILE_NAME"

download_file "$ICON_URL" "$ICON_TARGET"

log "Icon installed at $ICON_TARGET"

# -------------------------------------------------
# Desktop file
# -------------------------------------------------

DESKTOP_CONTENT="[Desktop Entry]
Type=Application
Version=1.0
Name=Yamata Launcher
Comment=Multi-platform game launcher
Exec=\"$APPIMAGE_TARGET\"
Icon=$ICON_TARGET
Terminal=false
Categories=Game;Utility;
StartupWMClass=YamataLauncher
X-AppImage-Name=Yamata Launcher
X-AppImage-Version=latest
X-AppImage-Arch=$(detect_arch)
"

DESKTOP_FILE_USER="$DESKTOP_DIR_USER/$DESKTOP_FILENAME"

echo "$DESKTOP_CONTENT" > "$DESKTOP_FILE_USER"
chmod 644 "$DESKTOP_FILE_USER"

log "Desktop entry installed at $DESKTOP_FILE_USER"

# -------------------------------------------------
# Optional system-wide desktop install
# -------------------------------------------------

if [ -w "$DESKTOP_DIR_SYSTEM" ]; then
  cp "$DESKTOP_FILE_USER" "$DESKTOP_DIR_SYSTEM/$DESKTOP_FILENAME"
  log "Desktop entry also installed system-wide"
else
  log "System-wide desktop install skipped (no permissions)"
fi

log "Installation completed successfully"
