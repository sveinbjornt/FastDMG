# FastDMG

<!--<img src="fastdmg_icon.png" width="128" height="128" align="right" style="float: right; margin-left: 30px;">-->

FastDMG is a macOS utility to mount `.dmg` disk images quickly and efficiently without any nonsense. It is a practical and reliable replacement for Apple's DiskImageMounter.

**Features**

* Doesn't waste your precious time verifying disk images
* Auto-accepts any attached end user license agreement
* Runs in the background (doesn't show up in the Dock)
* Displays no windows
* Disk image document icons continue to look the same

FastDMG is a minimal wrapper around the [ `hdiutil`](https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man1/hdiutil.1.html) command line tool that ships with macOS. It is free, open source software.

## Download

* [Download FastDMG 1.0](https://sveinbjorn.org/files/software/fastdmg.zip) (~2.0 MB, Intel 64-bit, 10.8 or later)

## How to use

* Move FastDMG.app to your Applications folder
* Select a `.dmg` file and press Cmd-I to show the Finder's Get Info window
* Select FastDMG under "Open with:"
* Press "Change All..."

FastDMG will then take care of mounting your `.dmg` disk images.

## BSD License 

Copyright (C) 2018 <a href="mailto:sveinbjorn@sveinbjorn.org">Sveinbjorn Thordarson</a>

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
