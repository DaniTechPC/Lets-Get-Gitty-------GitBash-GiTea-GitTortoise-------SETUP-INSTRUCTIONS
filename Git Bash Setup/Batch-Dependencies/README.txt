GIT BASH LINUX-LIKE SETUP
=========================

INSTALL
-------
1. Install normal Git for Windows.
2. Put Setup-GitBash-Linux.bat anywhere you want.
3. Keep the Batch-Dependencies folder directly beside the BAT file.
4. Double-click: Setup-GitBash-Linux.bat
5. Approve the Windows administrator prompt if the installer needs to enable sudo.
6. Close every open Git Bash window.
7. Open Git Bash again.
8. Run: linux-help

WHAT THE SETUP DOES
-------------------
- Backs up an existing .minttyrc, .bashrc and .bash_profile when present.
- Replaces ~/.minttyrc with the supplied theme/settings.
- Replaces ~/.bashrc with the Linux-like shell configuration.
- Replaces ~/.bash_profile so ~/.bashrc is always loaded.
- Starts every new interactive Git Bash session in ~ (the user's home folder).
- Installs compatibility commands into ~/bin.
- If Sudo for Windows is available and disabled, enables it automatically.
  Existing sudo modes are preserved. Newly enabled sudo uses Microsoft's
  safer "In a new window" mode.
- Tries to install nano, wget and jq through WinGet.

TEST IT
-------
Run these in the newly opened Git Bash:

  pwd
  ll
  sudo whoami
  nano test.txt
  wget --version
  jq --version
  ifconfig
  ip addr
  free
  apt update
  apt search python
  apt install make
  linux-help
  linux-check

IMPORTANT
---------
The included 'apt' and 'apt-get' commands are compatibility wrappers using
Windows Package Manager (WinGet). They are not Debian/Ubuntu APT.

Sudo for Windows is available on Windows 11 version 24H2 and newer. It is a
Windows elevation feature, not the Unix/Linux sudo program. If sudo.exe is not
available, the installer skips that step and continues normally.

Snap and Linux service/kernel commands require real Linux or WSL.


PORTABLE FOLDER LAYOUT
----------------------
Setup-GitBash-Linux.bat
Batch-Dependencies\
  .minttyrc
  .bashrc
  .bash_profile
  README.txt
  bin\

The BAT resolves Batch-Dependencies relative to its own location, so the pair
can be copied to any folder or USB drive without changing the script.
