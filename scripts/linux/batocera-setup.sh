#!/bin/bash

set -e

# Define paths
TEMP_FOLDER="/userdata/system/temp"
ROMS_PORTS_FOLDER="/userdata/roms/ports"
IMAGE_FOLDER="$ROMS_PORTS_FOLDER/images"
DESKTOP_FOLDER="/usr/share/applications"
xml_file="/userdata/roms/ports/gamelist.xml"
YAMATA_EXEC="$HOME/Applications/yamata-launcher-x86.AppImage"

download_file() {
  local url="$1"
  local output="$2"
  if [ "$DOWNLOAD_TOOL" = "wget" ]; then
    wget -O "$output" "$url"
  else
    curl -L --progress-bar -o "$output" "$url"
  fi
}


# Download image and put it in the specified location
mkdir -p "$IMAGE_FOLDER"
ICON_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/refs/heads/master/assets/images/logo.png"
ICON_TARGET="$IMAGE_FOLDER/yamata_launcher.png"

download_file "$ICON_URL" "$ICON_TARGET"

#download launch script
download_file "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/refs/heads/master/scripts/linux/yamata_launcher.sh" "/userdata/roms/ports/yamata_launcher.sh"

#download pad2key script
download_file "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/refs/heads/master/scripts/linux/pad2key.json" "/userdata/roms/ports/yamata_launcher.sh.keys"

# inserts the batocera wine shortcut to the corresponding path
if [ ! -f "$xml_file" ]; then
    echo '<?xml version="1.0"?>
<gameList>
</gameList>' > "$xml_file"
    echo "Created new XML file: $xml_file"
fi
 xml_entry='
	<game>
		<path>./yamata_launcher.sh</path>
		<name>Yamata Launcher</name>
        <desc>The ultimate multi-platform game launcher that unifies game catalogs, downloads, and libraries from multiple ecosystems into a single, extensible application.</desc>
		<rating>0</rating>
        <image>./images/yamata_launcher.png</image>
        <developer>gr3gorywolf</developer>
		<playcount>1</playcount>
		<lang>en</lang>
	</game>'

if ! grep -q '<name>Yamata Launcher</name>' "$xml_file"; then
    awk -v entry="$xml_entry" '/<\/gameList>/ {print entry} 1' "$xml_file" > tmpfile && mv tmpfile "$xml_file"
    echo "Entry added successfully."
else
    echo "Entry already exists."
fi

# Create .desktop file
mkdir -p "$TEMP_FOLDER"
shortcut="$TEMP_FOLDER/yamata_launcher.desktop"
rm -rf $shortcut
echo "[Desktop Entry]" >> $shortcut
echo "Version=1.0" >> $shortcut
echo "Icon=$ICON_TARGET" >> $shortcut
echo "Exec=$YAMATA_EXEC" >> $shortcut
echo "Terminal=false" >> $shortcut
echo "Type=Application" >> $shortcut
echo "Categories=Game;batocera.linux;" >> $shortcut
echo "Name=Yamata Launcher" >> $shortcut

# Move .desktop file to /usr/share/applications
mv "$TEMP_FOLDER/yamata_launcher.desktop" "$DESKTOP_FOLDER"

# Clean up temporary files
rm -rf "$TEMP_FOLDER"
echo "Done!"