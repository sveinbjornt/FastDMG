[![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)]()
[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Language](https://img.shields.io/badge/language-objective--c-lightgrey)]()
[![Release](https://shields.io/github/v/release/sveinbjornt/fastdmg?display_name=tag)]()
[![Build](https://github.com/sveinbjornt/fastdmg/actions/workflows/macos.yml/badge.svg)]()

<img src="Icon/fastdmg.png" width="256" height="256" align="right" style="float: right; margin-left: 30px;">

# FastDMG

> "Replaces the system default DMG mounting application; is better in every way." - Some guy on the Internet

FastDMG is a macOS utility to quickly and efficiently mount `.dmg` and other disk images without any unneeded nonsense. It is a very fast and reliable replacement for Apple's hopelessly inefficient and annoying [DiskImageMounter](https://en.wikipedia.org/wiki/DiskImageMounter) app.

## Features

* Doesn't waste your precious time verifying disk images
* Auto-accepts annoying end user license agreements
* Runs in the background (doesn't show up in the Dock)
* Displays no windows or menus and stays out of your way
* Multithreaded and can concurrently mount several images
* Disk image document icons continue to look the same
* Handles all disk image types supported by DiskImageMounter (dmg, iso, toast, etc.)
* Very fast native app written in Objective-C/Cocoa

<a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=BDT58J7HYKAEE"><img align="right" src="https://www.paypalobjects.com/WEBSCR-640-20110306-1/en_US/i/btn/btn_donate_LG.gif" style="float:right; margin-left: 20px;"></a>

FastDMG is a very minimal wrapper around the [ `hdiutil`](https://web.archive.org/web/20170506155736/https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man1/hdiutil.1.html) command line tool that ships with macOS. It therefore uses Apple's private DiskImages framework indirectly. It is free, open source software. I've used it for many years and it works really well. If you like it, feel free to [make a donation](https://sveinbjorn.org/donations).

## Download

*  **[⬇ Download FastDMG 1.0.3](https://sveinbjorn.org/files/software/FastDMG.zip)** (~1.3 MB, Universal ARM/Intel 64-bit, 10.13 or later, Developer ID signed and notarized by Apple)

If you need to run it on macOS 10.9-10.12, [version 1.0.2](https://sveinbjorn.org/files/software/fastdmg/) continues to work just fine.

## Brew

FastDMG can also be installed via [Homebrew](https://brew.sh/):

```bash
brew install --cask FastDMG
```

Then:

```bash
open /Applications/FastDMG.app
```

## How to use

* Move FastDMG.app to your Applications folder
* Ctrl-click the FastDMG app and select Open to bypass Apple's Gatekeeper
* Select a `.dmg` file and press Cmd-I to show the Finder's Get Info window
* Select FastDMG under the menu item "Open with:"
* Press "Change All..."

FastDMG will then take care of mounting  `.dmg` disk images when you open them in the Finder. 
You can do the same for `.iso`, `.toast` and any other disk image formats supported by FastDMG.

## Version History

### 1.0.3 - 20/05/2025

* App is now notarized by Apple
* New application icon by maxtron95

### 1.0.2 - 28/11/2020

* App is now built as a Universal ARM/Intel 64-bit binary

### 1.0.1 - 08/04/2019

* App is now Developer ID signed
* Built with support for Mojave Dark Mode

### 1.0 - 23/10/2018

* First release as native non-[Platypus](https://sveinbjorn.org/platypus) app

## BSD License 

Copyright (C) 2012-2025 Sveinbjorn Thordarson &lt;<a href="mailto:sveinbjorn@sveinbjorn.org">sveinbjorn@sveinbjorn.org</a>&gt;

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this
list of conditions and the following disclaimer in the documentation and/or other
materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may
be used to endorse or promote products derived from this software without specific
prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

