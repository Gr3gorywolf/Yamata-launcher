import os
import binascii
import ssl
import urllib.request

# =========================
# CONFIG
# =========================

APP_NAME = "Yamata Launcher"
EXEC_PATH = os.path.expanduser("~/Applications/yamata-launcher-x86.AppImage")
ARGS = "--fullscreen"

# Usa JPG para mejor compatibilidad con Gaming Mode
ART_VERTICAL = "https://github.com/Gr3gorywolf/Yamata-launcher/raw/master/assets/images/steamgrid/Portrait.png"
ART_ICON = "https://raw.githubusercontent.com/Gr3gorywolf/Yamata-launcher/refs/heads/master/assets/icons/app.ico"
ART_HORIZONTAL ="https://github.com/Gr3gorywolf/Yamata-launcher/raw/master/assets/images/steamgrid/LargePortrait.png"
ART_HERO = "https://github.com/Gr3gorywolf/Yamata-launcher/raw/master/assets/images/steamgrid/Wallpaper.png"
ART_LOGO = "https://github.com/Gr3gorywolf/Yamata-launcher/raw/master/assets/images/logo.png"

STEAM_ROOT = os.path.expanduser("~/.steam/steam")
USERDATA = os.path.join(STEAM_ROOT, "userdata")

# =========================
# HELPERS
# =========================

def calculate_appid(name, exe):
    return binascii.crc32((exe + name).encode()) | 0x80000000


def int_to_le_bytes(value):
    return value.to_bytes(4, byteorder="little")


def download(url, path):
    ssl._create_default_https_context = ssl._create_unverified_context
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        with urllib.request.urlopen(url) as r:
            with open(path, "wb") as f:
                f.write(r.read())
    except Exception as e:
        print("Download failed:", e)


def add_artwork(userid, appid):
    grid_path = os.path.join(USERDATA, userid, "config", "grid")
    os.makedirs(grid_path, exist_ok=True)

    artwork = {
        f"{appid}.jpg": ART_VERTICAL,        # Vertical / Big Picture
        f"{appid}p.jpg": ART_HORIZONTAL,     # Horizontal library
        f"{appid}_hero.jpg": ART_HERO,       # Hero
        f"{appid}_logo.png": ART_LOGO,       # Logo
        f"{appid}_icon.ico": ART_ICON,
    }

    for filename, url in artwork.items():
        path = os.path.join(grid_path, filename)
        download(url, path)


def add_shortcut(userid, appid, exe_string):
    shortcuts_path = os.path.join(USERDATA, userid, "config", "shortcuts.vdf")

    if not os.path.exists(shortcuts_path):
        return

    with open(shortcuts_path, "rb") as f:
        data = f.read()

    # Avoid duplicates
    if APP_NAME in data.decode("utf-8", "ignore"):
        print(f"[{userid}] Shortcut already exists")
        return

    nul = b"\x00"
    soh = b"\x01"
    stx = b"\x02"
    bs  = b"\x08"

    appid_bytes = int_to_le_bytes(appid)
    base = os.path.join(USERDATA, userid)
    grid_path = os.path.join(base, "config", "grid")
    icon_path = os.path.join(grid_path, f"{appid}_icon.ico")

    entry = (
        nul + b"0" + nul +
        stx + b"appid" + nul + appid_bytes +
        soh + b"AppName" + nul + APP_NAME.encode() + nul +
        soh + b"Exe" + nul + exe_string.encode() + nul +
        soh + b"StartDir" + nul + f"\"{os.path.dirname(EXEC_PATH)}\"".encode() + nul +
        soh + b"icon" + nul + icon_path.encode() + nul +
        soh + b"ShortcutPath" + nul + nul +
        soh + b"LaunchOptions" + nul + nul +
        stx + b"IsHidden" + nul + b"\x00\x00\x00\x00" +
        stx + b"AllowDesktopConfig" + nul + b"\x01\x00\x00\x00" +
        stx + b"AllowOverlay" + nul + b"\x01\x00\x00\x00" +
        stx + b"OpenVR" + nul + b"\x00\x00\x00\x00" +
        stx + b"Devkit" + nul + b"\x00\x00\x00\x00" +
        soh + b"DevkitGameID" + nul + nul +
        stx + b"DevkitOverrideAppID" + nul + b"\x00\x00\x00\x00" +
        stx + b"LastPlayTime" + nul + b"\x00\x00\x00\x00" +
        nul + b"tags" + nul +
        bs + bs
    )

    with open(shortcuts_path, "wb") as f:
        f.write(data[:-2] + entry + data[-2:])

    print(f"[{userid}] Shortcut added")


# =========================
# MAIN
# =========================

exe_string = f"\"{EXEC_PATH}\" {ARGS}"
appid = calculate_appid(APP_NAME, exe_string)

print("AppID:", appid)

for userid in os.listdir(USERDATA):
    if userid in ("0", "ac"):
        continue

    print("Processing user:", userid)

    add_shortcut(userid, appid, exe_string)
    add_artwork(userid, appid)

print("\nDone.")
print("IMPORTANT:")
print("1) steam -shutdown")
print("2) Open Steam again (or restart Gaming Mode)")
