Gitea Server Monitor v2.3
=======================

Folder structure
----------------
Main folder:

builder.bat
README.txt
GiteaServerMonitor.exe        <-- created after running builder.bat
build\

Build folder:

build\Build-EXE.bat
build\Clean-Build-Files.bat
build\Install-Dependencies.bat
build\requirements.txt
code\GiteaServerMonitor.pyw
build\GiteaServerMonitor.ico
build\GiteaServerMonitor_icon.png
code\GiteaServerMonitor.pyw
build\dist\
build\dependencies\

How to build
------------
1. Extract this ZIP.
2. Open the extracted folder.
3. Double-click:

builder.bat

When done, the finished EXE is copied to the main folder:

GiteaServerMonitor.exe

The PyInstaller output also remains here:

build\dist\GiteaServerMonitor.exe

What changed in v2
------------------
- Cleaner file structure.
- Main builder.bat stays outside the build folder.
- All build files, icon files, dist folder, source file, and dependency files stay inside build.
- Dark green Gitea-like UI theme.
- Custom icon is used for the EXE and inside the top-left of the app.
- The lower view is split:
  - Left side: C:\Gitea storage usage.
  - Right side: active connection/IP activity log.

What the app does
-----------------
- Starts C:\Gitea\gitea.exe web in the background.
- If Gitea is already running, it does not start a second server.
- Displays CPU, RAM, disk I/O, uptime, storage, and C: drive free space.
- Shows unique IP addresses that accessed Gitea during the current monitor session.
- Tries to read new session-only IP addresses from Gitea log files in:
  - C:\Gitea\log
  - C:\Gitea\logs
  - C:\Gitea
- Includes a Kill All button to stop every running gitea.exe process.

Important note about IP logging
-------------------------------
The active connection list is live. It shows IPs while the browser or Git client is actively connected to the server.

For a full historical access log, Gitea may need access logging enabled in app.ini.
This monitor will attempt to read IPs from log files if Gitea is already writing them.

Expected Gitea location
-----------------------
C:\Gitea\gitea.exe

The monitor starts it with:

gitea.exe web

Readme note
-----------
You mentioned readme.exe. I made this README.txt instead because a readme should not be executable.
The actual executable created by the builder is:

GiteaServerMonitor.exe


v2.1 changes
------------
- Replaced the EXE/header icon with the uploaded GiteaServerMonitor.ico.
- The IP panel now logs unique IPs only once per app start/session.
- Repeated hits from the same IP update the seen count, but they do not create repeated log spam.


v2.2 change
-----------
At the end of builder.bat, the setup now creates a desktop shortcut named:

Server Monitor

The shortcut points to:

GiteaServerMonitor.exe

and uses the EXE's embedded icon.


v2.3 changes
------------
- Opening the EXE no longer automatically starts Gitea.
- If Gitea is already running, opening the EXE no longer shows the "already running" popup.
- Added a large visual server status badge:
  - Green = RUNNING
  - Red = STOPPED
- Buttons are now rounded and more modern-looking.
- Added a separate code folder.
- The Python source now lives here:

code\GiteaServerMonitor.pyw

- The build folder still keeps build scripts, icon assets, dependencies, and dist output.
