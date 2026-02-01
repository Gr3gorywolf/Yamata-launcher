import 'package:yamata_launcher/models/console.dart';

class ConsoleConstants {
  static List<Console> defaultConsoles = [
// =========================
    // Nintendo
    // =========================
    Console(name: "Game Boy", altName: "Nintendo - Game Boy", slug: "gb"),
    Console(
        name: "Game Boy Color",
        altName: "Nintendo - Game Boy Color",
        slug: "gbc"),
    Console(
        name: "Game Boy Advance",
        altName: "Nintendo - Game Boy Advance",
        slug: "gba"),
    Console(
        name: "Nintendo Entertainment System",
        altName: "Nintendo - Nintendo Entertainment System",
        slug: "nes"),
    Console(
        name: "Super Nintendo Entertainment System",
        altName: "Nintendo - Super Nintendo Entertainment System",
        slug: "snes"),
    Console(
        name: "Nintendo 64", altName: "Nintendo - Nintendo 64", slug: "n64"),
    Console(name: "GameCube", altName: "Nintendo - GameCube", slug: "gc"),
    Console(name: "Wii", altName: "Nintendo - Wii", slug: "wii"),
    Console(
        name: "Nintendo DS", altName: "Nintendo - Nintendo DS", slug: "nds"),
    Console(
        name: "Nintendo 3DS", altName: "Nintendo - Nintendo 3DS", slug: "3ds"),
    Console(
        name: "Virtual Boy",
        altName: "Nintendo - Virtual Boy",
        slug: "virtualboy"),

    // =========================
    // Sony
    // =========================
    Console(name: "PlayStation", altName: "Sony - PlayStation", slug: "psx"),
    Console(
        name: "PlayStation 2", altName: "Sony - PlayStation 2", slug: "ps2"),
    Console(
        name: "PlayStation 3", altName: "Sony - PlayStation 3", slug: "ps3"),
    Console(
        name: "PlayStation Portable",
        altName: "Sony - PlayStation Portable",
        slug: "psp"),
    Console(
        name: "PlayStation Vita",
        altName: "Sony - PlayStation Vita",
        slug: "vita"),
    // =========================
    // Microsoft
    // =========================
    Console(name: "Xbox", altName: "Microsoft - Xbox", slug: "xbox"),
    Console(name: "Xbox 360", altName: "Microsoft - Xbox 360", slug: "xbox360"),
    Console(name: "Windows", altName: "Windows", slug: "windows"),
    // =========================
    // Sega
    // =========================
    Console(
        name: "Mega Drive / Genesis",
        altName: "Sega - Mega Drive - Genesis",
        slug: "genesis"),
    Console(name: "Sega 32X", altName: "Sega - 32X", slug: "sega32x"),
    Console(name: "Sega Saturn", altName: "Sega - Saturn", slug: "saturn"),
    Console(name: "Dreamcast", altName: "Sega - Dreamcast", slug: "dreamcast"),
    Console(name: "Game Gear", altName: "Sega - Game Gear", slug: "gamegear"),

    // =========================
    // SNK
    // =========================
    Console(name: "Neo Geo", altName: "SNK - Neo Geo", slug: "neogeo"),
    Console(
        name: "Neo Geo Pocket", altName: "SNK - Neo Geo Pocket", slug: "ngp"),
    Console(
        name: "Neo Geo Pocket Color",
        altName: "SNK - Neo Geo Pocket Color",
        slug: "ngpc"),
    // =========================
    // Commodore
    // =========================
    Console(name: "Commodore 64", altName: "Commodore - 64", slug: "c64"),
    Console(
        name: "Commodore Amiga", altName: "Commodore - Amiga", slug: "amiga"),

    // =========================
    // Others
    // =========================
    Console(name: "WonderSwan", altName: "Bandai - WonderSwan", slug: "ws"),
    Console(
        name: "WonderSwan Color",
        altName: "Bandai - WonderSwan Color",
        slug: "wsc"),
    Console(name: "Vectrex", altName: "GCE - Vectrex", slug: "vectrex"),
  ];

  static List<Console> additionalConsoles = [
    // =========================
    // Computers & Others
    // =========================
    Console(
        name: "3DO Interactive Multiplayer",
        altName: "3DO Interactive Multiplayer",
        slug: "3do"),
    Console(
        name: "Aamber Pegasus",
        altName: "Aamber Pegasus",
        slug: "aamberpegasus"),
    Console(
        name: "Acorn Archimedes",
        altName: "Acorn Archimedes",
        slug: "archimedes"),
    Console(name: "Acorn Atom", altName: "Acorn Atom", slug: "atom"),
    Console(
        name: "Acorn Electron", altName: "Acorn Electron", slug: "electron"),
    Console(name: "Amstrad CPC", altName: "Amstrad CPC", slug: "cpc"),
    Console(name: "Amstrad GX4000", altName: "Amstrad GX4000", slug: "gx4000"),
    Console(name: "Android", altName: "Android", slug: "android"),
    Console(
        name: "APF Imagination Machine",
        altName: "APF Imagination Machine",
        slug: "apfm1000"),
    Console(name: "Apogee BK-01", altName: "Apogee BK-01", slug: "bk01"),
    Console(name: "Apple II", altName: "Apple II", slug: "appleii"),
    Console(name: "Apple IIGS", altName: "Apple IIGS", slug: "appleiigs"),
    Console(name: "Apple iOS", altName: "Apple iOS", slug: "ios"),
    Console(name: "Apple Mac OS", altName: "Apple Mac OS", slug: "macos"),
    Console(name: "Arcade", altName: "Arcade", slug: "arcade"),
    Console(name: "Arduboy", altName: "Arduboy", slug: "arduboy"),
    // =========================
    // Atari
    // =========================
    Console(name: "Atari 2600", altName: "Atari 2600", slug: "atari2600"),
    Console(name: "Atari 5200", altName: "Atari 5200", slug: "atari5200"),
    Console(name: "Atari 7800", altName: "Atari 7800", slug: "atari7800"),
    Console(name: "Atari 800", altName: "Atari 800", slug: "atari800"),
    Console(name: "Atari Jaguar", altName: "Atari Jaguar", slug: "jaguar"),
    Console(
        name: "Atari Jaguar CD", altName: "Atari Jaguar CD", slug: "jaguarcd"),
    Console(name: "Atari Lynx", altName: "Atari Lynx", slug: "lynx"),
    Console(name: "Atari ST", altName: "Atari ST", slug: "atarist"),
    Console(name: "Atari XEGS", altName: "Atari XEGS", slug: "xegs"),
    // =========================
    // Misc Retro
    // =========================
    Console(
        name: "Bally Astrocade", altName: "Bally Astrocade", slug: "astrocade"),
    Console(
        name: "Bandai Super Vision 8000",
        altName: "Bandai Super Vision 8000",
        slug: "sv8000"),
    Console(
        name: "BBC Microcomputer System",
        altName: "BBC Microcomputer System",
        slug: "bbcmicro"),
    Console(
        name: "Camputers Lynx",
        altName: "Camputers Lynx",
        slug: "camputerslynx"),
    Console(name: "Casio Loopy", altName: "Casio Loopy", slug: "casioloopy"),
    Console(name: "Casio PV-1000", altName: "Casio PV-1000", slug: "pv1000"),
    Console(name: "Coleco ADAM", altName: "Coleco ADAM", slug: "adam"),
    Console(name: "ColecoVision", altName: "ColecoVision", slug: "coleco"),
    // =========================
    // Commodore (Extended)
    // =========================
    Console(name: "Commodore 128", altName: "Commodore 128", slug: "c128"),
    Console(
        name: "Commodore Amiga CD32",
        altName: "Commodore Amiga CD32",
        slug: "amigacd32"),
    Console(name: "Commodore CDTV", altName: "Commodore CDTV", slug: "cdtv"),
    Console(
        name: "Commodore MAX Machine",
        altName: "Commodore MAX Machine",
        slug: "maxmachine"),
    Console(name: "Commodore PET", altName: "Commodore PET", slug: "pet"),
    Console(
        name: "Commodore Plus 4", altName: "Commodore Plus 4", slug: "plus4"),
    Console(
        name: "Commodore VIC-20", altName: "Commodore VIC-20", slug: "vic20"),
    // =========================
    // More Retro Systems
    // =========================
    Console(name: "Dragon 32/64", altName: "Dragon 32/64", slug: "dragon32"),
    Console(
        name: "EACA EG2000 Colour Genie",
        altName: "EACA EG2000 Colour Genie",
        slug: "colourgenie"),
    Console(
        name: "Elektor TV Games Computer",
        altName: "Elektor TV Games Computer",
        slug: "elektor"),
    Console(name: "Elektronika BK", altName: "Elektronika BK", slug: "bk0010"),
    Console(
        name: "Emerson Arcadia 2001",
        altName: "Emerson Arcadia 2001",
        slug: "arcadia"),
    Console(name: "Enterprise", altName: "Enterprise", slug: "enterprise"),
    Console(
        name: "Entex Adventure Vision",
        altName: "Entex Adventure Vision",
        slug: "adventurevision"),
    Console(
        name: "Epoch Game Pocket Computer",
        altName: "Epoch Game Pocket Computer",
        slug: "gamepocket"),
    Console(
        name: "Epoch Super Cassette Vision",
        altName: "Epoch Super Cassette Vision",
        slug: "scv"),
    Console(
        name: "Exelvision EXL 100",
        altName: "Exelvision EXL 100",
        slug: "exl100"),
    Console(
        name: "Exidy Sorcerer", altName: "Exidy Sorcerer", slug: "sorcerer"),
    Console(
        name: "Fairchild Channel F",
        altName: "Fairchild Channel F",
        slug: "channelf"),
    Console(name: "Fujitsu FM-7", altName: "Fujitsu FM-7", slug: "fm7"),
    Console(
        name: "Fujitsu FM Towns Marty",
        altName: "Fujitsu FM Towns Marty",
        slug: "fmtowns"),
    Console(
        name: "Funtech Super Acan",
        altName: "Funtech Super Acan",
        slug: "supracan"),
    Console(name: "GamePark GP32", altName: "GamePark GP32", slug: "gp32"),
    Console(name: "GameWave", altName: "GameWave", slug: "gamewave"),
    Console(
        name: "Game Wave Family Entertainment System",
        altName: "Game Wave Family Entertainment System",
        slug: "gamewavefes"),
    Console(
        name: "Hartung Game Master",
        altName: "Hartung Game Master",
        slug: "gamemaster"),
    Console(name: "Hector HRX", altName: "Hector HRX", slug: "hector"),
    Console(
        name: "Interton VC 4000", altName: "Interton VC 4000", slug: "vc4000"),
    Console(name: "Jupiter Ace", altName: "Jupiter Ace", slug: "jupiterace"),
    Console(name: "Linux", altName: "Linux", slug: "linux"),
    Console(
        name: "Magnavox Odyssey", altName: "Magnavox Odyssey", slug: "odyssey"),
    Console(
        name: "Magnavox Odyssey 2",
        altName: "Magnavox Odyssey 2",
        slug: "odyssey2"),
    Console(
        name: "Matra and Hachette Alice",
        altName: "Matra and Hachette Alice",
        slug: "alice"),
    Console(
        name: "Mattel Aquarius", altName: "Mattel Aquarius", slug: "aquarius"),
    Console(
        name: "Mattel HyperScan",
        altName: "Mattel HyperScan",
        slug: "hyperscan"),
    Console(
        name: "Mattel Intellivision",
        altName: "Mattel Intellivision",
        slug: "intellivision"),
    Console(name: "Mega Duck", altName: "Mega Duck", slug: "megaduck"),
    Console(name: "Memotech MTX512", altName: "Memotech MTX512", slug: "mtx"),
    Console(name: "Microsoft MSX", altName: "Microsoft MSX", slug: "msx"),
    Console(name: "Microsoft MSX2", altName: "Microsoft MSX2", slug: "msx2"),
    Console(
        name: "Microsoft MSX2+", altName: "Microsoft MSX2+", slug: "msx2plus"),
    // =========================
    // Microsoft (Extended)
    // =========================
    Console(
        name: "Microsoft Xbox One",
        altName: "Microsoft Xbox One",
        slug: "xboxone"),
    Console(
        name: "Microsoft Xbox Series X/S",
        altName: "Microsoft Xbox Series X/S",
        slug: "xboxseries"),
    // =========================
    // Misc PC & Arcade
    // =========================
    Console(name: "MS-DOS", altName: "MS-DOS", slug: "dos"),
    Console(name: "MUGEN", altName: "MUGEN", slug: "mugen"),
    Console(
        name: "Namco System 22", altName: "Namco System 22", slug: "namcos22"),
    Console(name: "NEC PC-8801", altName: "NEC PC-8801", slug: "pc88"),
    Console(name: "NEC PC-9801", altName: "NEC PC-9801", slug: "pc98"),
    Console(name: "NEC PC-FX", altName: "NEC PC-FX", slug: "pcfx"),
    Console(
        name: "NEC TurboGrafx-16", altName: "NEC TurboGrafx-16", slug: "tg16"),
    Console(
        name: "NEC TurboGrafx-CD", altName: "NEC TurboGrafx-CD", slug: "tgcd"),
    // =========================
    // Nintendo (Extended)
    // =========================
    Console(name: "Nintendo 64DD", altName: "Nintendo 64DD", slug: "n64dd"),
    Console(
        name: "Nintendo Famicom Disk System",
        altName: "Nintendo Famicom Disk System",
        slug: "fds"),
    Console(
        name: "Nintendo Game & Watch",
        altName: "Nintendo Game & Watch",
        slug: "gw"),
    Console(
        name: "Nintendo Pokemon Mini",
        altName: "Nintendo Pokemon Mini",
        slug: "pokemini"),
    Console(
        name: "Nintendo Satellaview",
        altName: "Nintendo Satellaview",
        slug: "satellaview"),
    Console(
        name: "Nintendo Switch", altName: "Nintendo Switch", slug: "switch"),
    Console(
        name: "Nintendo Switch 2",
        altName: "Nintendo Switch 2",
        slug: "switch2"),
    Console(name: "Nintendo Wii U", altName: "Nintendo Wii U", slug: "wiiu"),
    // =========================
    // Others
    // =========================
    Console(name: "Nokia N-Gage", altName: "Nokia N-Gage", slug: "ngage"),
    Console(name: "Nuon", altName: "Nuon", slug: "nuon"),
    Console(name: "OpenBOR", altName: "OpenBOR", slug: "openbor"),
    Console(name: "Oric Atmos", altName: "Oric Atmos", slug: "oric"),
    Console(
        name: "Othello Multivision",
        altName: "Othello Multivision",
        slug: "omv"),
    Console(name: "Ouya", altName: "Ouya", slug: "ouya"),
    Console(
        name: "PC Engine SuperGrafx",
        altName: "PC Engine SuperGrafx",
        slug: "supergrafx"),
    Console(name: "Philips CD-i", altName: "Philips CD-i", slug: "cdi"),
    Console(
        name: "Philips VG 5000", altName: "Philips VG 5000", slug: "vg5000"),
    Console(
        name: "Philips Videopac+", altName: "Philips Videopac+", slug: "g7400"),
    Console(name: "PICO-8", altName: "PICO-8", slug: "pico8"),
    Console(name: "Pinball", altName: "Pinball", slug: "pinball"),
    Console(name: "RCA Studio II", altName: "RCA Studio II", slug: "studio2"),
    Console(name: "SAM Coupé", altName: "SAM Coupé", slug: "samcoupe"),
    Console(
        name: "Sammy Atomiswave",
        altName: "Sammy Atomiswave",
        slug: "atomiswave"),
    Console(name: "ScummVM", altName: "ScummVM", slug: "scummvm"),
    // =========================
    // Sega (Extended)
    // =========================
    Console(name: "Sega CD", altName: "Sega CD", slug: "segacd"),
    Console(name: "Sega CD 32X", altName: "Sega CD 32X", slug: "segacd32x"),
    Console(
        name: "Sega Dreamcast VMU", altName: "Sega Dreamcast VMU", slug: "vmu"),
    Console(name: "Sega Hikaru", altName: "Sega Hikaru", slug: "hikaru"),
    Console(
        name: "Sega Master System",
        altName: "Sega Master System",
        slug: "master"),
    Console(name: "Sega Model 1", altName: "Sega Model 1", slug: "model1"),
    Console(name: "Sega Model 2", altName: "Sega Model 2", slug: "model2"),
    Console(name: "Sega Model 3", altName: "Sega Model 3", slug: "model3"),
    Console(name: "Sega Naomi", altName: "Sega Naomi", slug: "naomi"),
    Console(name: "Sega Naomi 2", altName: "Sega Naomi 2", slug: "naomi2"),
    Console(name: "Sega Pico", altName: "Sega Pico", slug: "pico"),
    Console(name: "Sega SC-3000", altName: "Sega SC-3000", slug: "sc3000"),
    Console(name: "Sega SG-1000", altName: "Sega SG-1000", slug: "sg1000"),
    Console(name: "Sega ST-V", altName: "Sega ST-V", slug: "stv"),
    Console(
        name: "Sega System 16", altName: "Sega System 16", slug: "system16"),
    Console(
        name: "Sega System 32", altName: "Sega System 32", slug: "system32"),
    Console(name: "Sega Triforce", altName: "Sega Triforce", slug: "triforce"),
    // =========================
    // Sharp & Sinclair
    // =========================
    Console(name: "Sharp MZ-2500", altName: "Sharp MZ-2500", slug: "mz2500"),
    Console(name: "Sharp X1", altName: "Sharp X1", slug: "x1"),
    Console(name: "Sharp X68000", altName: "Sharp X68000", slug: "x68000"),
    Console(name: "Sinclair ZX-81", altName: "Sinclair ZX-81", slug: "zx81"),
    Console(
        name: "Sinclair ZX Spectrum",
        altName: "Sinclair ZX Spectrum",
        slug: "zxspectrum"),
    // =========================
    // SNK (Extended)
    // =========================
    Console(
        name: "SNK Neo Geo CD", altName: "SNK Neo Geo CD", slug: "neogeocd"),
    Console(
        name: "SNK Neo Geo MVS", altName: "SNK Neo Geo MVS", slug: "neogeomvs"),
    // =========================
    // Sony (Extended)
    // =========================
    Console(
        name: "Sony Playstation 4", altName: "Sony Playstation 4", slug: "ps4"),
    Console(
        name: "Sony Playstation 5", altName: "Sony Playstation 5", slug: "ps5"),
    Console(
        name: "Sony PocketStation",
        altName: "Sony PocketStation",
        slug: "pocketstation"),
    Console(
        name: "Sony PSP Minis", altName: "Sony PSP Minis", slug: "pspminis"),
    // =========================
    // Others (T-Z)
    // =========================
    Console(name: "Sord M5", altName: "Sord M5", slug: "sordm5"),
    Console(
        name: "Spectravideo", altName: "Spectravideo", slug: "spectravideo"),
    Console(name: "Taito Type X", altName: "Taito Type X", slug: "typex"),
    Console(name: "Tandy TRS-80", altName: "Tandy TRS-80", slug: "trs80"),
    Console(name: "Tapwave Zodiac", altName: "Tapwave Zodiac", slug: "zodiac"),
    Console(
        name: "Texas Instruments TI 99/4A",
        altName: "Texas Instruments TI 99/4A",
        slug: "ti99"),
    Console(name: "Tiger Game.com", altName: "Tiger Game.com", slug: "gamecom"),
    Console(name: "Tomy Tutor", altName: "Tomy Tutor", slug: "tomytutor"),
    Console(
        name: "TRS-80 Color Computer",
        altName: "TRS-80 Color Computer",
        slug: "coco"),
    Console(name: "Uzebox", altName: "Uzebox", slug: "uzebox"),
    Console(name: "Vector-06C", altName: "Vector-06C", slug: "vector06c"),
    Console(
        name: "VTech CreatiVision",
        altName: "VTech CreatiVision",
        slug: "creativision"),
    Console(
        name: "VTech Socrates", altName: "VTech Socrates", slug: "socrates"),
    Console(name: "VTech V.Smile", altName: "VTech V.Smile", slug: "vsmile"),
    Console(name: "WASM-4", altName: "WASM-4", slug: "wasm4"),
    Console(
        name: "Watara Supervision",
        altName: "Watara Supervision",
        slug: "supervision"),
    Console(name: "Web Browser", altName: "Web Browser", slug: "web"),
    Console(name: "Windows 3.X", altName: "Windows 3.X", slug: "win3x"),
    Console(
        name: "WoW Action Max", altName: "WoW Action Max", slug: "actionmax"),
    Console(name: "XaviXPORT", altName: "XaviXPORT", slug: "xavix"),
    Console(name: "ZiNc", altName: "ZiNc", slug: "zinc"),
  ];
}
