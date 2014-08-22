PowerShellMods
==============

A collection of PowerShell modules that integrate various third party executables and  thier corresponding functionality into the PowerShell shell

This repository contains a collection of PowerShell modules that can be imported into the PowerShell Shell, some of which interact with 3rd party executables, to provide additional functionality such as: encryption, SFTp/FTP file transfers, SSH, and data processing functionality

Modules that rely on external 3rd party executable have a global variable defined which point to the location of the executable. By default this global variable points to a folder called Deploy in the folder in which the module currently resides. This variable can be changed by editing the module if need be. Below is a list of modules and the third party executable required - for more information refer to the Documentation folder in the PowerShellMods repository for information about individual commands contained in the module

Encryption.psm1 - Requires gpg.exe, iconv.dll
Data.psm1 - Requires nothing
Compression.psm1 - Requires 7za.exe
FileTransfer.psm1 - Requires winscp.exe, winscp.dll
SSH.psm1 - Requires plink.exe
GPG - http://www.gnupg.org
Winscp - http://winscp.net/
7Zip - http://www.7-zip.org/
Putty - http://www.putty.org/
