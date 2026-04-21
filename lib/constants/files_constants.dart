import 'package:yamata_launcher/constants/console_constants.dart';

const SETUP_FILE_NAMES = [
  "setup.exe",
  "install.exe",
  "setup.msi",
  "install.msi",
  "setup.pkg",
  "install.pkg",
  "setup.sh",
  "install.sh",
  "setup.app",
  "install.app",
];

const REDIST_FILE_MATCHES = [
  "unitycrashhandler",
  "redist",
  "dotnet",
  "vcredist",
  "oalinst",
  "dxwebsetup",
  "install",
  "umdf",
  "physx",
  "wmfdist",
  "wmpappcompat",
  ".net"
];

const ENGINE_FILE_MATCHES = ["unity", "sandfall"];
// removes tokens that are not commonly found on game titles and interfere with the lookup
const INVALID_TITLE_TOKENS = ['.nkit', 'ROMSLAB', 'sxs-', 'zzz-UNK -'];

const VALID_EXECUTABLE_EXTENSIONS = [
  "exe",
  "com",
  "bat",
  "cmd",
  "msi",
  "msp",
  "scr",
  "ps1",
  "vbs",
  "js",
  "wsf",
  "hta",
  "cpl",
  "bin",
  "elf",
  "run",
  "sh",
  "bash",
  "zsh",
  "ksh",
  "out",
  "so",
  "appimage",
  "app",
  "command",
  "pkg",
  "py",
  "pyw",
  "jar",
  "class",
  "rb",
  "pl",
  "php",
  "lua",
  "tcl",
  "groovy",
  "r",
  "swift",
  "kt",
  "apk",
  "aab",
  "dex",
  "odex",
  "x86",
  "x64",
  "wasm",
  "cgi",
  "efi",
  "img",
  "hex",
  "elf32",
  "elf64"
];

final Map<String, List<CONSOLE_SLUGS>> CONSOLE_EXTENSIONS = {
  // Nintendo
  'nes': [CONSOLE_SLUGS.nes],
  'fds': [CONSOLE_SLUGS.fds],
  'sfc': [CONSOLE_SLUGS.snes],
  'smc': [CONSOLE_SLUGS.snes],
  'n64': [CONSOLE_SLUGS.n64],
  'z64': [CONSOLE_SLUGS.n64],
  'v64': [CONSOLE_SLUGS.n64],
  'gb': [CONSOLE_SLUGS.gb],
  'gbc': [CONSOLE_SLUGS.gbc],
  'gba': [CONSOLE_SLUGS.gba],
  'nds': [CONSOLE_SLUGS.nds],
  '3ds': [CONSOLE_SLUGS.n3ds],
  'cia': [CONSOLE_SLUGS.n3ds],
  'wad': [CONSOLE_SLUGS.wii],
  'gcm': [CONSOLE_SLUGS.gc],
  'wbfs': [CONSOLE_SLUGS.wii],
  'wux': [CONSOLE_SLUGS.wiiu],
  'wud': [CONSOLE_SLUGS.wiiu],
  'nsp': [CONSOLE_SLUGS.nSwitch],
  'xci': [CONSOLE_SLUGS.nSwitch],
  'nsz': [CONSOLE_SLUGS.nSwitch],
  'xcz': [CONSOLE_SLUGS.nSwitch],
  'vb': [CONSOLE_SLUGS.virtualboy],
  'rvz': [CONSOLE_SLUGS.gc, CONSOLE_SLUGS.wii],

  // Sony
  'psx': [CONSOLE_SLUGS.psx],
  'ps1': [CONSOLE_SLUGS.psx],
  'img': [CONSOLE_SLUGS.psx],
  'ccd': [CONSOLE_SLUGS.psx],
  'sub': [CONSOLE_SLUGS.psx],
  'mdf': [CONSOLE_SLUGS.psx],
  'cso': [CONSOLE_SLUGS.psp],
  'pkg': [CONSOLE_SLUGS.ps3, CONSOLE_SLUGS.psp, CONSOLE_SLUGS.vita],
  'elf': [CONSOLE_SLUGS.ps3],

  // Sega
  'sms': [CONSOLE_SLUGS.master],
  'gg': [CONSOLE_SLUGS.gamegear],
  'sg': [CONSOLE_SLUGS.sg1000],
  'gen': [CONSOLE_SLUGS.genesis],
  'md': [CONSOLE_SLUGS.genesis],
  '32x': [CONSOLE_SLUGS.sega32x],
  'gdi': [CONSOLE_SLUGS.dreamcast],

  // Arcade
  'rom': [CONSOLE_SLUGS.arcade],

  // PC / OTHERS
  'exe': [CONSOLE_SLUGS.windows],
  'com': [CONSOLE_SLUGS.dos],

  // ==========================================
  // Shared extensions
  // ==========================================

  'iso': [
    CONSOLE_SLUGS.gc,
    CONSOLE_SLUGS.wii,
    CONSOLE_SLUGS.ps2,
    CONSOLE_SLUGS.psp,
    CONSOLE_SLUGS.ps3,
    CONSOLE_SLUGS.segacd
  ],

  'bin': [CONSOLE_SLUGS.psx, CONSOLE_SLUGS.segacd],

  'cue': [CONSOLE_SLUGS.psx, CONSOLE_SLUGS.segacd],

  'chd': [
    CONSOLE_SLUGS.psx,
    CONSOLE_SLUGS.ps2,
    CONSOLE_SLUGS.psp,
    CONSOLE_SLUGS.arcade
  ],

  'cdi': [CONSOLE_SLUGS.dreamcast, CONSOLE_SLUGS.cdi],

  'pbp': [CONSOLE_SLUGS.psp, CONSOLE_SLUGS.psx],

  'dsk': [CONSOLE_SLUGS.appleii, CONSOLE_SLUGS.cpc],
};

final VALID_ROM_EXTENSIONS = CONSOLE_EXTENSIONS.keys.toList();

const VALID_COMPRESSED_EXTENSIONS = [
  'zip',
  'rar',
  '7z',
  'tar',
  'gz',
  'bz2',
  'xz',
  'lzma',
  'zst',
  'tgz',
  'tbz2',
  'txz',
];

const PLATFORMS_WITH_DIRECTORY_TYPE_GAMES = [
  'windows',
  'ps3',
  'linux',
  'macos'
];

const DOWNLOAD_MARK_FILENAME = ".yldownload";

const COMMON_ZIP_PASSWORDS = ["online-fix.me", "steamrip.com"];

const METADATA_REQUIRED_FILES = [
  "all-execs.json",
  "all-serials.json",
  "all-sizes.json",
  "libretro-full-database.json",
  "libretro-index.json"
];
