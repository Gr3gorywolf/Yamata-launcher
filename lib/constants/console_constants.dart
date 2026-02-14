import 'package:yamata_launcher/models/console.dart';

enum CONSOLE_SLUGS {
  gb('gb'),
  gbc('gbc'),
  gba('gba'),
  nes('nes'),
  snes('snes'),
  n64('n64'),
  gc('gc'),
  wii('wii'),
  nds('nds'),
  n3ds('3ds'),
  virtualboy('virtualboy'),
  psx('psx'),
  ps2('ps2'),
  ps3('ps3'),
  psp('psp'),
  vita('vita'),
  xbox('xbox'),
  xbox360('xbox360'),
  windows('windows'),
  genesis('genesis'),
  sega32x('sega32x'),
  saturn('saturn'),
  dreamcast('dreamcast'),
  gamegear('gamegear'),
  neogeo('neogeo'),
  ngp('ngp'),
  ngpc('ngpc'),
  c64('c64'),
  amiga('amiga'),
  ws('ws'),
  wsc('wsc'),
  vectrex('vectrex'),
  threeDo('3do'),
  aamberpegasus('aamberpegasus'),
  archimedes('archimedes'),
  atom('atom'),
  electron('electron'),
  cpc('cpc'),
  gx4000('gx4000'),
  android('android'),
  apfm1000('apfm1000'),
  bk01('bk01'),
  appleii('appleii'),
  appleiigs('appleiigs'),
  ios('ios'),
  macos('macos'),
  arcade('arcade'),
  arduboy('arduboy'),
  atari2600('atari2600'),
  atari5200('atari5200'),
  atari7800('atari7800'),
  atari800('atari800'),
  jaguar('jaguar'),
  jaguarcd('jaguarcd'),
  lynx('lynx'),
  atarist('atarist'),
  xegs('xegs'),
  astrocade('astrocade'),
  sv8000('sv8000'),
  bbcmicro('bbcmicro'),
  camputerslynx('camputerslynx'),
  casioloopy('casioloopy'),
  pv1000('pv1000'),
  adam('adam'),
  coleco('coleco'),
  c128('c128'),
  amigacd32('amigacd32'),
  cdtv('cdtv'),
  maxmachine('maxmachine'),
  pet('pet'),
  plus4('plus4'),
  vic20('vic20'),
  dragon32('dragon32'),
  colourgenie('colourgenie'),
  elektor('elektor'),
  bk0010('bk0010'),
  arcadia('arcadia'),
  enterprise('enterprise'),
  adventurevision('adventurevision'),
  gamepocket('gamepocket'),
  scv('scv'),
  exl100('exl100'),
  sorcerer('sorcerer'),
  channelf('channelf'),
  fm7('fm7'),
  fmtowns('fmtowns'),
  supracan('supracan'),
  gp32('gp32'),
  gamewave('gamewave'),
  gamewavefes('gamewavefes'),
  gamemaster('gamemaster'),
  hector('hector'),
  vc4000('vc4000'),
  jupiterace('jupiterace'),
  linux('linux'),
  odyssey('odyssey'),
  odyssey2('odyssey2'),
  alice('alice'),
  aquarius('aquarius'),
  hyperscan('hyperscan'),
  intellivision('intellivision'),
  megaduck('megaduck'),
  mtx('mtx'),
  msx('msx'),
  msx2('msx2'),
  msx2plus('msx2plus'),
  xboxone('xboxone'),
  xboxseries('xboxseries'),
  dos('dos'),
  mugen('mugen'),
  namcos22('namcos22'),
  pc88('pc88'),
  pc98('pc98'),
  pcfx('pcfx'),
  tg16('tg16'),
  tgcd('tgcd'),
  n64dd('n64dd'),
  fds('fds'),
  gw('gw'),
  pokemini('pokemini'),
  satellaview('satellaview'),
  nSwitch('switch'),
  switch2('switch2'),
  wiiu('wiiu'),
  ngage('ngage'),
  nuon('nuon'),
  openbor('openbor'),
  oric('oric'),
  omv('omv'),
  ouya('ouya'),
  supergrafx('supergrafx'),
  cdi('cdi'),
  vg5000('vg5000'),
  g7400('g7400'),
  pico8('pico8'),
  pinball('pinball'),
  studio2('studio2'),
  samcoupe('samcoupe'),
  atomiswave('atomiswave'),
  scummvm('scummvm'),
  segacd('segacd'),
  segacd32x('segacd32x'),
  vmu('vmu'),
  hikaru('hikaru'),
  master('master'),
  model1('model1'),
  model2('model2'),
  model3('model3'),
  naomi('naomi'),
  naomi2('naomi2'),
  pico('pico'),
  sc3000('sc3000'),
  sg1000('sg1000'),
  stv('stv'),
  system16('system16'),
  system32('system32'),
  triforce('triforce'),
  mz2500('mz2500'),
  x1('x1'),
  x68000('x68000'),
  zx81('zx81'),
  zxspectrum('zxspectrum'),
  neogeocd('neogeocd'),
  neogeomvs('neogeomvs'),
  ps4('ps4'),
  ps5('ps5'),
  pocketstation('pocketstation'),
  pspminis('pspminis'),
  sordm5('sordm5'),
  spectravideo('spectravideo'),
  typex('typex'),
  trs80('trs80'),
  zodiac('zodiac'),
  ti99('ti99'),
  gamecom('gamecom'),
  tomytutor('tomytutor'),
  coco('coco'),
  uzebox('uzebox'),
  vector06c('vector06c'),
  creativision('creativision'),
  socrates('socrates'),
  vsmile('vsmile'),
  wasm4('wasm4'),
  supervision('supervision'),
  web('web'),
  win3x('win3x'),
  actionmax('actionmax'),
  xavix('xavix'),
  zinc('zinc');

  final String value;
  const CONSOLE_SLUGS(this.value);
}

class ConsoleConstants {
  static List<Console> defaultConsoles = [
// =========================
    // Nintendo
    // =========================
    Console(
        name: "Game Boy",
        altName: "Nintendo - Game Boy",
        slug: "gb",
        vendor: "Nintendo"),
    Console(
        name: "Game Boy Color",
        altName: "Nintendo - Game Boy Color",
        slug: "gbc",
        vendor: "Nintendo"),
    Console(
        name: "Game Boy Advance",
        altName: "Nintendo - Game Boy Advance",
        slug: "gba",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Entertainment System",
        altName: "Nintendo - Nintendo Entertainment System",
        slug: "nes",
        vendor: "Nintendo"),
    Console(
        name: "Super Nintendo Entertainment System",
        altName: "Nintendo - Super Nintendo Entertainment System",
        slug: "snes",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo 64",
        altName: "Nintendo - Nintendo 64",
        slug: "n64",
        vendor: "Nintendo"),
    Console(
        name: "GameCube",
        altName: "Nintendo - GameCube",
        slug: "gc",
        vendor: "Nintendo"),
    Console(
        name: "Wii",
        altName: "Nintendo - Wii",
        slug: "wii",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo DS",
        altName: "Nintendo - Nintendo DS",
        slug: "nds",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo 3DS",
        altName: "Nintendo - Nintendo 3DS",
        slug: "3ds",
        vendor: "Nintendo"),
    Console(
        name: "Virtual Boy",
        altName: "Nintendo - Virtual Boy",
        slug: "virtualboy",
        vendor: "Nintendo"),

    // =========================
    // Sony
    // =========================
    Console(
        name: "PlayStation",
        altName: "Sony - PlayStation",
        slug: "psx",
        vendor: "Sony"),
    Console(
        name: "PlayStation 2",
        altName: "Sony - PlayStation 2",
        slug: "ps2",
        vendor: "Sony"),
    Console(
        name: "PlayStation 3",
        altName: "Sony - PlayStation 3",
        slug: "ps3",
        vendor: "Sony"),
    Console(
        name: "PlayStation Portable",
        altName: "Sony - PlayStation Portable",
        slug: "psp",
        vendor: "Sony"),
    Console(
        name: "PlayStation Vita",
        altName: "Sony - PlayStation Vita",
        slug: "vita",
        vendor: "Sony"),
    // =========================
    // Microsoft
    // =========================
    Console(
        name: "Xbox",
        altName: "Microsoft - Xbox",
        slug: "xbox",
        vendor: "Microsoft"),
    Console(
        name: "Xbox 360",
        altName: "Microsoft - Xbox 360",
        slug: "xbox360",
        vendor: "Microsoft"),
    Console(
        name: "Windows",
        altName: "Windows",
        slug: "windows",
        vendor: "Microsoft"),
    // =========================
    // Sega
    // =========================
    Console(
        name: "Mega Drive / Genesis",
        altName: "Sega - Mega Drive - Genesis",
        slug: "genesis",
        vendor: "Sega"),
    Console(
        name: "Sega 32X",
        altName: "Sega - 32X",
        slug: "sega32x",
        vendor: "Sega"),
    Console(
        name: "Sega Saturn",
        altName: "Sega - Saturn",
        slug: "saturn",
        vendor: "Sega"),
    Console(
        name: "Dreamcast",
        altName: "Sega - Dreamcast",
        slug: "dreamcast",
        vendor: "Sega"),
    Console(
        name: "Game Gear",
        altName: "Sega - Game Gear",
        slug: "gamegear",
        vendor: "Sega"),

    // =========================
    // SNK
    // =========================
    Console(
        name: "Neo Geo",
        altName: "SNK - Neo Geo",
        slug: "neogeo",
        vendor: "SNK"),
    Console(
        name: "Neo Geo Pocket",
        altName: "SNK - Neo Geo Pocket",
        slug: "ngp",
        vendor: "SNK"),
    Console(
        name: "Neo Geo Pocket Color",
        altName: "SNK - Neo Geo Pocket Color",
        slug: "ngpc",
        vendor: "SNK"),
    // =========================
    // Commodore
    // =========================
    Console(
        name: "Commodore 64",
        altName: "Commodore - 64",
        slug: "c64",
        vendor: "Commodore"),
    Console(
        name: "Commodore Amiga",
        altName: "Commodore - Amiga",
        slug: "amiga",
        vendor: "Commodore"),

    // =========================
    // Others
    // =========================
    Console(
        name: "WonderSwan",
        altName: "Bandai - WonderSwan",
        slug: "ws",
        vendor: "Bandai"),
    Console(
        name: "WonderSwan Color",
        altName: "Bandai - WonderSwan Color",
        slug: "wsc",
        vendor: "Bandai"),
    Console(
        name: "Vectrex",
        altName: "GCE - Vectrex",
        slug: "vectrex",
        vendor: "GCE"),
  ];

  static List<Console> additionalConsoles = [
    // =========================
    // Computers & Others
    // =========================
    Console(
        name: "3DO Interactive Multiplayer",
        altName: "3DO Interactive Multiplayer",
        slug: "3do",
        vendor: "3DO"),
    Console(
        name: "Aamber Pegasus",
        altName: "Aamber Pegasus",
        slug: "aamberpegasus",
        vendor: "Aamber"),
    Console(
        name: "Acorn Archimedes",
        altName: "Acorn Archimedes",
        slug: "archimedes",
        vendor: "Acorn"),
    Console(
        name: "Acorn Atom",
        altName: "Acorn Atom",
        slug: "atom",
        vendor: "Acorn"),
    Console(
        name: "Acorn Electron",
        altName: "Acorn Electron",
        slug: "electron",
        vendor: "Acorn"),
    Console(
        name: "Amstrad CPC",
        altName: "Amstrad CPC",
        slug: "cpc",
        vendor: "Amstrad"),
    Console(
        name: "Amstrad GX4000",
        altName: "Amstrad GX4000",
        slug: "gx4000",
        vendor: "Amstrad"),
    Console(
        name: "Android", altName: "Android", slug: "android", vendor: "Google"),
    Console(
        name: "APF Imagination Machine",
        altName: "APF Imagination Machine",
        slug: "apfm1000",
        vendor: "APF"),
    Console(
        name: "Apogee BK-01",
        altName: "Apogee BK-01",
        slug: "bk01",
        vendor: "Apogee"),
    Console(
        name: "Apple II",
        altName: "Apple II",
        slug: "appleii",
        vendor: "Apple"),
    Console(
        name: "Apple IIGS",
        altName: "Apple IIGS",
        slug: "appleiigs",
        vendor: "Apple"),
    Console(
        name: "Apple iOS", altName: "Apple iOS", slug: "ios", vendor: "Apple"),
    Console(
        name: "Apple Mac OS",
        altName: "Apple Mac OS",
        slug: "macos",
        vendor: "Apple"),
    Console(
        name: "Arcade", altName: "Arcade", slug: "arcade", vendor: "Various"),
    Console(
        name: "Arduboy",
        altName: "Arduboy",
        slug: "arduboy",
        vendor: "Arduboy"),
    // =========================
    // Atari
    // =========================
    Console(
        name: "Atari 2600",
        altName: "Atari 2600",
        slug: "atari2600",
        vendor: "Atari"),
    Console(
        name: "Atari 5200",
        altName: "Atari 5200",
        slug: "atari5200",
        vendor: "Atari"),
    Console(
        name: "Atari 7800",
        altName: "Atari 7800",
        slug: "atari7800",
        vendor: "Atari"),
    Console(
        name: "Atari 800",
        altName: "Atari 800",
        slug: "atari800",
        vendor: "Atari"),
    Console(
        name: "Atari Jaguar",
        altName: "Atari Jaguar",
        slug: "jaguar",
        vendor: "Atari"),
    Console(
        name: "Atari Jaguar CD",
        altName: "Atari Jaguar CD",
        slug: "jaguarcd",
        vendor: "Atari"),
    Console(
        name: "Atari Lynx",
        altName: "Atari Lynx",
        slug: "lynx",
        vendor: "Atari"),
    Console(
        name: "Atari ST",
        altName: "Atari ST",
        slug: "atarist",
        vendor: "Atari"),
    Console(
        name: "Atari XEGS",
        altName: "Atari XEGS",
        slug: "xegs",
        vendor: "Atari"),
    // =========================
    // Misc Retro
    // =========================
    Console(
        name: "Bally Astrocade",
        altName: "Bally Astrocade",
        slug: "astrocade",
        vendor: "Bally"),
    Console(
        name: "Bandai Super Vision 8000",
        altName: "Bandai Super Vision 8000",
        slug: "sv8000",
        vendor: "Bandai"),
    Console(
        name: "BBC Microcomputer System",
        altName: "BBC Microcomputer System",
        slug: "bbcmicro",
        vendor: "Acorn"),
    Console(
        name: "Camputers Lynx",
        altName: "Camputers Lynx",
        slug: "camputerslynx",
        vendor: "Camputers"),
    Console(
        name: "Casio Loopy",
        altName: "Casio Loopy",
        slug: "casioloopy",
        vendor: "Casio"),
    Console(
        name: "Casio PV-1000",
        altName: "Casio PV-1000",
        slug: "pv1000",
        vendor: "Casio"),
    Console(
        name: "Coleco ADAM",
        altName: "Coleco ADAM",
        slug: "adam",
        vendor: "Coleco"),
    Console(
        name: "ColecoVision",
        altName: "ColecoVision",
        slug: "coleco",
        vendor: "Coleco"),
    // =========================
    // Commodore (Extended)
    // =========================
    Console(
        name: "Commodore 128",
        altName: "Commodore 128",
        slug: "c128",
        vendor: "Commodore"),
    Console(
        name: "Commodore Amiga CD32",
        altName: "Commodore Amiga CD32",
        slug: "amigacd32",
        vendor: "Commodore"),
    Console(
        name: "Commodore CDTV",
        altName: "Commodore CDTV",
        slug: "cdtv",
        vendor: "Commodore"),
    Console(
        name: "Commodore MAX Machine",
        altName: "Commodore MAX Machine",
        slug: "maxmachine",
        vendor: "Commodore"),
    Console(
        name: "Commodore PET",
        altName: "Commodore PET",
        slug: "pet",
        vendor: "Commodore"),
    Console(
        name: "Commodore Plus 4",
        altName: "Commodore Plus 4",
        slug: "plus4",
        vendor: "Commodore"),
    Console(
        name: "Commodore VIC-20",
        altName: "Commodore VIC-20",
        slug: "vic20",
        vendor: "Commodore"),
    // =========================
    // More Retro Systems
    // =========================
    Console(
        name: "Dragon 32/64",
        altName: "Dragon 32/64",
        slug: "dragon32",
        vendor: "Dragon Data"),
    Console(
        name: "EACA EG2000 Colour Genie",
        altName: "EACA EG2000 Colour Genie",
        slug: "colourgenie",
        vendor: "EACA"),
    Console(
        name: "Elektor TV Games Computer",
        altName: "Elektor TV Games Computer",
        slug: "elektor",
        vendor: "Elektor"),
    Console(
        name: "Elektronika BK",
        altName: "Elektronika BK",
        slug: "bk0010",
        vendor: "Elektronika"),
    Console(
        name: "Emerson Arcadia 2001",
        altName: "Emerson Arcadia 2001",
        slug: "arcadia",
        vendor: "Emerson"),
    Console(
        name: "Enterprise",
        altName: "Enterprise",
        slug: "enterprise",
        vendor: "Enterprise"),
    Console(
        name: "Entex Adventure Vision",
        altName: "Entex Adventure Vision",
        slug: "adventurevision",
        vendor: "Entex"),
    Console(
        name: "Epoch Game Pocket Computer",
        altName: "Epoch Game Pocket Computer",
        slug: "gamepocket",
        vendor: "Epoch"),
    Console(
        name: "Epoch Super Cassette Vision",
        altName: "Epoch Super Cassette Vision",
        slug: "scv",
        vendor: "Epoch"),
    Console(
        name: "Exelvision EXL 100",
        altName: "Exelvision EXL 100",
        slug: "exl100",
        vendor: "Exelvision"),
    Console(
        name: "Exidy Sorcerer",
        altName: "Exidy Sorcerer",
        slug: "sorcerer",
        vendor: "Exidy"),
    Console(
        name: "Fairchild Channel F",
        altName: "Fairchild Channel F",
        slug: "channelf",
        vendor: "Fairchild"),
    Console(
        name: "Fujitsu FM-7",
        altName: "Fujitsu FM-7",
        slug: "fm7",
        vendor: "Fujitsu"),
    Console(
        name: "Fujitsu FM Towns Marty",
        altName: "Fujitsu FM Towns Marty",
        slug: "fmtowns",
        vendor: "Fujitsu"),
    Console(
        name: "Funtech Super Acan",
        altName: "Funtech Super Acan",
        slug: "supracan",
        vendor: "Funtech"),
    Console(
        name: "GamePark GP32",
        altName: "GamePark GP32",
        slug: "gp32",
        vendor: "GamePark"),
    Console(
        name: "GameWave",
        altName: "GameWave",
        slug: "gamewave",
        vendor: "GameWave"),
    Console(
        name: "Game Wave Family Entertainment System",
        altName: "Game Wave Family Entertainment System",
        slug: "gamewavefes",
        vendor: "GameWave"),
    Console(
        name: "Hartung Game Master",
        altName: "Hartung Game Master",
        slug: "gamemaster",
        vendor: "Hartung"),
    Console(
        name: "Hector HRX",
        altName: "Hector HRX",
        slug: "hector",
        vendor: "Hector"),
    Console(
        name: "Interton VC 4000",
        altName: "Interton VC 4000",
        slug: "vc4000",
        vendor: "Interton"),
    Console(
        name: "Jupiter Ace",
        altName: "Jupiter Ace",
        slug: "jupiterace",
        vendor: "Jupiter"),
    Console(name: "Linux", altName: "Linux", slug: "linux", vendor: "Linux"),
    Console(
        name: "Magnavox Odyssey",
        altName: "Magnavox Odyssey",
        slug: "odyssey",
        vendor: "Magnavox"),
    Console(
        name: "Magnavox Odyssey 2",
        altName: "Magnavox Odyssey 2",
        slug: "odyssey2",
        vendor: "Magnavox"),
    Console(
        name: "Matra and Hachette Alice",
        altName: "Matra and Hachette Alice",
        slug: "alice",
        vendor: "Matra and Hachette"),
    Console(
        name: "Mattel Aquarius",
        altName: "Mattel Aquarius",
        slug: "aquarius",
        vendor: "Mattel"),
    Console(
        name: "Mattel HyperScan",
        altName: "Mattel HyperScan",
        slug: "hyperscan",
        vendor: "Mattel"),
    Console(
        name: "Mattel Intellivision",
        altName: "Mattel Intellivision",
        slug: "intellivision",
        vendor: "Mattel"),
    Console(
        name: "Mega Duck",
        altName: "Mega Duck",
        slug: "megaduck",
        vendor: "Mega Duck"),
    Console(
        name: "Memotech MTX512",
        altName: "Memotech MTX512",
        slug: "mtx",
        vendor: "Memotech"),
    Console(
        name: "Microsoft MSX",
        altName: "Microsoft MSX",
        slug: "msx",
        vendor: "Microsoft"),
    Console(
        name: "Microsoft MSX2",
        altName: "Microsoft MSX2",
        slug: "msx2",
        vendor: "Microsoft"),
    Console(
        name: "Microsoft MSX2+",
        altName: "Microsoft MSX2+",
        slug: "msx2plus",
        vendor: "Microsoft"),
    // =========================
    // Microsoft (Extended)
    // =========================
    Console(
        name: "Microsoft Xbox One",
        altName: "Microsoft Xbox One",
        slug: "xboxone",
        vendor: "Microsoft"),
    Console(
        name: "Microsoft Xbox Series X/S",
        altName: "Microsoft Xbox Series X/S",
        slug: "xboxseries",
        vendor: "Microsoft"),
    // =========================
    // Misc PC & Arcade
    // =========================
    Console(
        name: "MS-DOS", altName: "MS-DOS", slug: "dos", vendor: "Microsoft"),
    Console(name: "MUGEN", altName: "MUGEN", slug: "mugen", vendor: "MUGEN"),
    Console(
        name: "Namco System 22",
        altName: "Namco System 22",
        slug: "namcos22",
        vendor: "Namco"),
    Console(
        name: "NEC PC-8801",
        altName: "NEC PC-8801",
        slug: "pc88",
        vendor: "NEC"),
    Console(
        name: "NEC PC-9801",
        altName: "NEC PC-9801",
        slug: "pc98",
        vendor: "NEC"),
    Console(
        name: "NEC PC-FX", altName: "NEC PC-FX", slug: "pcfx", vendor: "NEC"),
    Console(
        name: "NEC TurboGrafx-16",
        altName: "NEC TurboGrafx-16",
        slug: "tg16",
        vendor: "NEC"),
    Console(
        name: "NEC TurboGrafx-CD",
        altName: "NEC TurboGrafx-CD",
        slug: "tgcd",
        vendor: "NEC"),
    // =========================
    // Nintendo (Extended)
    // =========================
    Console(
        name: "Nintendo 64DD",
        altName: "Nintendo 64DD",
        slug: "n64dd",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Famicom Disk System",
        altName: "Nintendo Famicom Disk System",
        slug: "fds",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Game & Watch",
        altName: "Nintendo Game & Watch",
        slug: "gw",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Pokemon Mini",
        altName: "Nintendo Pokemon Mini",
        slug: "pokemini",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Satellaview",
        altName: "Nintendo Satellaview",
        slug: "satellaview",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Switch",
        altName: "Nintendo Switch",
        slug: "switch",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Switch 2",
        altName: "Nintendo Switch 2",
        slug: "switch2",
        vendor: "Nintendo"),
    Console(
        name: "Nintendo Wii U",
        altName: "Nintendo Wii U",
        slug: "wiiu",
        vendor: "Nintendo"),
    // =========================
    // Others
    // =========================
    Console(
        name: "Nokia N-Gage",
        altName: "Nokia N-Gage",
        slug: "ngage",
        vendor: "Nokia"),
    Console(name: "Nuon", altName: "Nuon", slug: "nuon", vendor: "Nuon"),
    Console(
        name: "OpenBOR",
        altName: "OpenBOR",
        slug: "openbor",
        vendor: "OpenBOR"),
    Console(
        name: "Oric Atmos",
        altName: "Oric Atmos",
        slug: "oric",
        vendor: "Oric"),
    Console(
        name: "Othello Multivision",
        altName: "Othello Multivision",
        slug: "omv",
        vendor: "Othello"),
    Console(name: "Ouya", altName: "Ouya", slug: "ouya", vendor: "Ouya"),
    Console(
        name: "PC Engine SuperGrafx",
        altName: "PC Engine SuperGrafx",
        slug: "supergrafx",
        vendor: "NEC"),
    Console(
        name: "Philips CD-i",
        altName: "Philips CD-i",
        slug: "cdi",
        vendor: "Philips"),
    Console(
        name: "Philips VG 5000",
        altName: "Philips VG 5000",
        slug: "vg5000",
        vendor: "Philips"),
    Console(
        name: "Philips Videopac+",
        altName: "Philips Videopac+",
        slug: "g7400",
        vendor: "Philips"),
    Console(
        name: "PICO-8", altName: "PICO-8", slug: "pico8", vendor: "Lexaloffle"),
    Console(
        name: "Pinball",
        altName: "Pinball",
        slug: "pinball",
        vendor: "Various"),
    Console(
        name: "RCA Studio II",
        altName: "RCA Studio II",
        slug: "studio2",
        vendor: "RCA"),
    Console(
        name: "SAM Coupé",
        altName: "SAM Coupé",
        slug: "samcoupe",
        vendor: "SAM"),
    Console(
        name: "Sammy Atomiswave",
        altName: "Sammy Atomiswave",
        slug: "atomiswave",
        vendor: "Sammy"),
    Console(
        name: "ScummVM",
        altName: "ScummVM",
        slug: "scummvm",
        vendor: "ScummVM"),
    // =========================
    // Sega (Extended)
    // =========================
    Console(
        name: "Sega CD", altName: "Sega CD", slug: "segacd", vendor: "Sega"),
    Console(
        name: "Sega CD 32X",
        altName: "Sega CD 32X",
        slug: "segacd32x",
        vendor: "Sega"),
    Console(
        name: "Sega Dreamcast VMU",
        altName: "Sega Dreamcast VMU",
        slug: "vmu",
        vendor: "Sega"),
    Console(
        name: "Sega Hikaru",
        altName: "Sega Hikaru",
        slug: "hikaru",
        vendor: "Sega"),
    Console(
        name: "Sega Master System",
        altName: "Sega Master System",
        slug: "master",
        vendor: "Sega"),
    Console(
        name: "Sega Model 1",
        altName: "Sega Model 1",
        slug: "model1",
        vendor: "Sega"),
    Console(
        name: "Sega Model 2",
        altName: "Sega Model 2",
        slug: "model2",
        vendor: "Sega"),
    Console(
        name: "Sega Model 3",
        altName: "Sega Model 3",
        slug: "model3",
        vendor: "Sega"),
    Console(
        name: "Sega Naomi",
        altName: "Sega Naomi",
        slug: "naomi",
        vendor: "Sega"),
    Console(
        name: "Sega Naomi 2",
        altName: "Sega Naomi 2",
        slug: "naomi2",
        vendor: "Sega"),
    Console(
        name: "Sega Pico", altName: "Sega Pico", slug: "pico", vendor: "Sega"),
    Console(
        name: "Sega SC-3000",
        altName: "Sega SC-3000",
        slug: "sc3000",
        vendor: "Sega"),
    Console(
        name: "Sega SG-1000",
        altName: "Sega SG-1000",
        slug: "sg1000",
        vendor: "Sega"),
    Console(
        name: "Sega ST-V", altName: "Sega ST-V", slug: "stv", vendor: "Sega"),
    Console(
        name: "Sega System 16",
        altName: "Sega System 16",
        slug: "system16",
        vendor: "Sega"),
    Console(
        name: "Sega System 32",
        altName: "Sega System 32",
        slug: "system32",
        vendor: "Sega"),
    Console(
        name: "Sega Triforce",
        altName: "Sega Triforce",
        slug: "triforce",
        vendor: "Sega"),
    // =========================
    // Sharp & Sinclair
    // =========================
    Console(
        name: "Sharp MZ-2500",
        altName: "Sharp MZ-2500",
        slug: "mz2500",
        vendor: "Sharp"),
    Console(name: "Sharp X1", altName: "Sharp X1", slug: "x1", vendor: "Sharp"),
    Console(
        name: "Sharp X68000",
        altName: "Sharp X68000",
        slug: "x68000",
        vendor: "Sharp"),
    Console(
        name: "Sinclair ZX-81",
        altName: "Sinclair ZX-81",
        slug: "zx81",
        vendor: "Sinclair"),
    Console(
        name: "Sinclair ZX Spectrum",
        altName: "Sinclair ZX Spectrum",
        slug: "zxspectrum",
        vendor: "Sinclair"),
    // =========================
    // SNK (Extended)
    // =========================
    Console(
        name: "SNK Neo Geo CD",
        altName: "SNK Neo Geo CD",
        slug: "neogeocd",
        vendor: "SNK"),
    Console(
        name: "SNK Neo Geo MVS",
        altName: "SNK Neo Geo MVS",
        slug: "neogeomvs",
        vendor: "SNK"),
    // =========================
    // Sony (Extended)
    // =========================
    Console(
        name: "Sony Playstation 4",
        altName: "Sony Playstation 4",
        slug: "ps4",
        vendor: "Sony"),
    Console(
        name: "Sony Playstation 5",
        altName: "Sony Playstation 5",
        slug: "ps5",
        vendor: "Sony"),
    Console(
        name: "Sony PocketStation",
        altName: "Sony PocketStation",
        slug: "pocketstation",
        vendor: "Sony"),
    Console(
        name: "Sony PSP Minis",
        altName: "Sony PSP Minis",
        slug: "pspminis",
        vendor: "Sony"),
    // =========================
    // Others (T-Z)
    // =========================
    Console(
        name: "Sord M5", altName: "Sord M5", slug: "sordm5", vendor: "Sord"),
    Console(
        name: "Spectravideo",
        altName: "Spectravideo",
        slug: "spectravideo",
        vendor: "Spectravideo"),
    Console(
        name: "Taito Type X",
        altName: "Taito Type X",
        slug: "typex",
        vendor: "Taito"),
    Console(
        name: "Tandy TRS-80",
        altName: "Tandy TRS-80",
        slug: "trs80",
        vendor: "Tandy"),
    Console(
        name: "Tapwave Zodiac",
        altName: "Tapwave Zodiac",
        slug: "zodiac",
        vendor: "Tapwave"),
    Console(
        name: "Texas Instruments TI 99/4A",
        altName: "Texas Instruments TI 99/4A",
        slug: "ti99",
        vendor: "Texas Instruments"),
    Console(
        name: "Tiger Game.com",
        altName: "Tiger Game.com",
        slug: "gamecom",
        vendor: "Tiger"),
    Console(
        name: "Tomy Tutor",
        altName: "Tomy Tutor",
        slug: "tomytutor",
        vendor: "Tomy"),
    Console(
        name: "TRS-80 Color Computer",
        altName: "TRS-80 Color Computer",
        slug: "coco",
        vendor: "Tandy"),
    Console(
        name: "Uzebox", altName: "Uzebox", slug: "uzebox", vendor: "Uzebox"),
    Console(
        name: "Vector-06C",
        altName: "Vector-06C",
        slug: "vector06c",
        vendor: "Vector"),
    Console(
        name: "VTech CreatiVision",
        altName: "VTech CreatiVision",
        slug: "creativision",
        vendor: "VTech"),
    Console(
        name: "VTech Socrates",
        altName: "VTech Socrates",
        slug: "socrates",
        vendor: "VTech"),
    Console(
        name: "VTech V.Smile",
        altName: "VTech V.Smile",
        slug: "vsmile",
        vendor: "VTech"),
    Console(name: "WASM-4", altName: "WASM-4", slug: "wasm4", vendor: "WASM-4"),
    Console(
        name: "Watara Supervision",
        altName: "Watara Supervision",
        slug: "supervision",
        vendor: "Watara"),
    Console(
        name: "Web Browser",
        altName: "Web Browser",
        slug: "web",
        vendor: "Web"),
    Console(
        name: "Windows 3.X",
        altName: "Windows 3.X",
        slug: "win3x",
        vendor: "Microsoft"),
    Console(
        name: "WoW Action Max",
        altName: "WoW Action Max",
        slug: "actionmax",
        vendor: "WoW"),
    Console(
        name: "XaviXPORT",
        altName: "XaviXPORT",
        slug: "xavix",
        vendor: "XaviX"),
    Console(name: "ZiNc", altName: "ZiNc", slug: "zinc", vendor: "ZiNc"),
  ];
}
