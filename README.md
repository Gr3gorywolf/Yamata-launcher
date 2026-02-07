<p align="center">
  <img
    src="https://github.com/Gr3gorywolf/Yamata-launcher/blob/master/assets/images/logo.png"
    width="260"
    height="260"
    alt="Yamata Launcher Logo"
  />
  <h1 align="center">Yamata Launcher</h1>
  
 

</p>



<h4 align="center"> Yamata Launcher is a multi-platform game launcher designed to unify game catalogs, downloads, and libraries from multiple ecosystems into a single, extensible application. 
</h4>

<h6 align="center">

> The name Yamata is inspired by Yamata-no-Orochi (八岐大蛇), symbolizing multiplicity, power, and unification under a single entity.

[![Github All Releases](https://img.shields.io/github/downloads/Gr3gorywolf/Yamata-launcher/total.svg)]()
![GitHub last commit](https://img.shields.io/github/last-commit/Gr3gorywolf/Yamata-launcher)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/Gr3gorywolf/Yamata-launcher?label=latest%20release)
![Discord](https://img.shields.io/discord/1469115593025130578)
![Website](https://img.shields.io/website?url=https://yamata-launcher.gregoryc.dev)


</h6>



<br>
<br>


<img width="1260" height="755" alt="image" src="https://github.com/user-attachments/assets/d197b563-759c-42b9-b548-f3ff5f9a622a" />


<br>
<br>




## Table of Contents
- [Key Features](#features)
- [How to Install](#how-to-install)
- [Documentation](#documentation)
- [License](#license)



## Features

- **True Multi-Platform Experience**: Built with full feature parity across Windows, macOS, Linux, and Android, including seamless integration with gaming-focused distributions such as Batocera and SteamOS.
- **Unified Game Catalogs**: Manage and browse game catalogs from multiple platforms and third-party sources through a single, unified interface.
- **Powerful Third-Party Download Support**: Download games from third-party sources designed for Yamata, with full compatibility with providers from [Hydra Launcher](https://hydralauncher.gg/) and an extensible system for future sources.
- **Multi-Protocol Downloads**: Supports both Torrent and HTTP downloads and works with multiple file hosters including GoFile, MediaFire, VikingFile, Rootz, DataNodes, BuzzHeavier, PixelDrain, and FuckingFast.
- **Centralized Game Library**: Keep all your games organized in one place, whether added directly from catalogs or manually as custom entries.
- **Game and ROM Launching**: Launch PC games and ROMs directly from the launcher, with Android-specific ROM intent management to ensure emulator compatibility.
- **Automatic Playtime Tracking**: Automatically tracks total playtime per game on desktop platforms and displays statistics directly in the library.
- **Built-In Extraction System**: Automatically extracts downloaded content using the integrated 7z decompressor, with no external tools required.
- **Smart Executable Detection**: Automatically detects game executables after extraction using a database of known executable names, minimizing manual setup.
- **Rich Game and ROM Metadata**: Enhances your library with detailed metadata powered by [GamesDB](https://gamesdb.launchbox-app.com/) and estimated playtime data from [HowLongToBeat](https://howlongtobeat.com/).

## How to Install
The application binaries are on the [Releases page](https://github.com/Gr3gorywolf/Yamata-launcher/releases)


- <strong>Windows</strong>: Download the installer and follow the setup steps.
- <strong>MacOS</strong>: Download the DMG file, open it, and install the application.
- <strong>Android</strong>: Download and install the APK file.

### Linux install

#### Generic Distros
```sh 
curl -sSL https://links.gregoryc.dev/yamata-launcher | sh
```

#### SteamOs:
This command will install the app and create a steam shortcut
```sh 
curl -sSL https://links.gregoryc.dev/yamata-launcher | sh -s -- --variant=steamos
```

#### Batocera:
This command will install the app and create a ports shortcut
```sh 
curl -sSL https://links.gregoryc.dev/yamata-launcher | sh -s -- --variant=batocera
```

## Documentation

This repo provides a centralized Wiki that contains in-depth documentation covering all major features, advanced configurations, and internal workflows of the project.

In the Wiki you will find:

- General usage guides and getting started tutorials
- Advanced configuration per platform (Windows, Linux, Android, SteamOS, Batocera)
- How to's guides for making downloads and catalogs sources
- Project architecture and extensibility system
- ROM handling, emulators, and Android intent integration
- Troubleshooting and common issues
- Technical documentation for developers and contributors


[Official Project Wiki](https://github.com/Gr3gorywolf/Yamata-launcher/wiki)  


---

## License

Yamata Launcher is an open-source project distributed under the terms of its respective license.

- The source code, scripts, and first-party components are covered by the license specified in this repository.
- Third-party libraries, tools, and services used by the project are subject to their own licenses.
- Yamata Launcher does not distribute copyrighted content (games, ROMs, BIOS files, etc.). The acquisition and use of such content is the sole responsibility of the end user.

[MIT license](https://github.com/Gr3gorywolf/Yamata-launcher/blob/master/LICENSE)




