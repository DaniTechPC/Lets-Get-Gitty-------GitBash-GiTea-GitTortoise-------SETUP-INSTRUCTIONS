GIT BASH LINUX-LIKE SETUP
=========================

INSTALL
-------
1. Install normal Git for Windows.
2. Put GitBash-Setup.bat anywhere you want.
3. Keep the Batch-Dependencies folder directly beside the BAT file.
4. Double-click GitBash-Setup.bat.
5. Approve the administrator prompt if sudo needs to be enabled.
6. Close all Git Bash windows.
7. Open Git Bash again.
8. Run: linux-check

RELIABILITY CHANGES
-------------------
- The setup no longer uses WinGet to automatically install nano, wget or jq.
- wget is included locally as a compatibility command that uses Git Bash curl.
- jq is optional.
- WinGet is only used later if a user explicitly runs apt install.
- The base Git Bash environment works even when WinGet is unavailable.

WHAT THE SETUP DOES
-------------------
- Verifies git works from normal Windows CMD.
- Repairs the current user's Windows PATH if Git is installed but CMD cannot find it.
- Installs the supplied .minttyrc, .bashrc and .bash_profile.
- Starts Git Bash in ~.
- Installs Linux-like compatibility commands into ~/bin.
- Enables Windows sudo when supported and currently disabled.
- Preserves an already configured sudo mode.
- Keeps apt/apt-get as WinGet-backed compatibility commands.

TEST
----
Windows CMD:
  git --version

Git Bash:
  pwd
  ll
  nano --version
  wget --version
  ifconfig
  ip addr
  free
  linux-help
  linux-check

OPTIONAL PACKAGE INSTALLATION
-----------------------------
If WinGet is available:
  apt update
  apt search python
  apt install jq
  apt install make

The apt command is a compatibility wrapper, not real Ubuntu/Debian APT.

PORTABLE FOLDER LAYOUT
----------------------
GitBash-Setup.bat
Batch-Dependencies\
  .minttyrc
  .bashrc
  .bash_profile
  README.txt
  bin\
    apt
    apt-get
    wget
    linux-check
    linux-help
    free
    ifconfig
    ip
    man
    open
    snap

Keep GitBash-Setup.bat and Batch-Dependencies beside each other. They can be
copied together to any folder or USB drive.
