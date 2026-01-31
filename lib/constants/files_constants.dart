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

const VALID_ROM_EXTENSIONS = [
  // Nintendo
  'nes', // NES
  'fds', // Famicom Disk System
  'sfc', // SNES
  'smc', // SNES
  'n64', // Nintendo 64
  'z64', // Nintendo 64
  'v64', // Nintendo 64
  'gb', // Game Boy
  'gbc', // Game Boy Color
  'gba', // Game Boy Advance
  'nds', // Nintendo DS
  '3ds', // Nintendo 3DS
  'cia', // Nintendo 3DS
  'wad', // Wii / Virtual Console
  'iso', // GameCube / Wii
  'gcm', // GameCube
  'wbfs', // Wii
  'wux', // Wii U
  'wud', // Wii U
  'nsp', // Nintendo Switch
  'xci', // Nintendo Switch
  'vb', // Virtual Boy

  // Sony
  'psx', // PlayStation
  'ps1', // PlayStation
  'bin', // PlayStation / Sega CD
  'cue', // PlayStation / Sega CD
  'img', // PlayStation
  'ccd', // PlayStation
  'sub', // PlayStation
  'mdf', // PlayStation
  'pbp', // PSP / PS1 eboot
  'iso', // PS2 / PSP / PS3
  'cso', // PSP compressed ISO
  'chd', // PS1 / PS2 / PSP
  'pkg', // PS3
  'elf', // PS3 / homebrew

  // Sega
  'sms', // Master System
  'gg', // Game Gear
  'sg', // SG-1000
  'gen', // Genesis
  'md', // Mega Drive
  '32x', // Sega 32X
  'cue', // Sega CD
  'iso', // Sega CD
  'cdi', // Dreamcast
  'gdi', // Dreamcast

  // Arcade
  'rom', // Arcade generic

  // PC / OTHERS
  'exe', // DOS / PC
  'com', // DOS
  'dsk', // Amstrad / Apple II
  'chd',
  'rvz',
];

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
