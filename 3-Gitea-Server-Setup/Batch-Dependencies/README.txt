GITEA SERVER SETUP - BATCH FILE GUIDE
=====================================

FOLDER LAYOUT
-------------
Keep the setup files arranged like this:

Gitea-Enviroment-Setup.bat
Gitea-Post-Setup-Settings.bat
Setup-Gitea-Help-Banner.bat
Batch-Dependencies\
    README.txt
    Gitea_Server_Monitor\
        <all Gitea Server Monitor files and folders>

The batch files can be placed on C:, D:, or another drive. They use the drive
they are running from instead of hard-coding C:.


1. Gitea-Enviroment-Setup.bat
-----------------------------
Run this BEFORE setting up Gitea.

What it does:
- Creates the main Gitea folder at:
    <current drive>:\Gitea
- Creates:
    data
    lfs
    logs
    repositories
    Gitea_Server_Monitor
- Copies ALL files and subfolders from:
    .\Batch-Dependencies\Gitea_Server_Monitor\
  into:
    <current drive>:\Gitea\Gitea_Server_Monitor\
- Leaves existing folders in place.
- Requests administrator permission if Windows requires it.


2. Gitea-Post-Setup-Settings.bat
--------------------------------
Run this AFTER completing the normal Gitea web setup and after Gitea has created:

    <current drive>:\Gitea\custom\conf\app.ini

What it does:
- Creates a timestamped backup of app.ini before changing it.
- Adds or updates these repository upload settings:

    [repository.upload]
    ENABLED = true
    MAX_FILES = 100
    FILE_MAX_SIZE = 100
    ALLOWED_TYPES = */*

- Adds or updates:

    [repository]
    DEFAULT_BRANCH = master

- Checks existing settings so it does not unnecessarily duplicate them.
- Leaves unrelated app.ini settings unchanged.
- Gitea must be restarted after these changes.


3. Setup-Gitea-Help-Banner.bat
------------------------------
Run this AFTER Gitea is installed.

What it does:
- Asks for the REQUIRED Gitea username that owns the repository:
    Gitea-Help-Documents
- There is NO default username.
- Creates the folder if necessary:
    <current drive>:\Gitea\custom\templates\custom
- Creates or replaces:
    extra_links.tmpl
    body_inner_pre.tmpl
- Inserts the entered username into the repository links.
- Creates timestamped backups if either template already exists.
- Gitea must be restarted for the custom templates to appear.


RECOMMENDED ORDER
-----------------
1. Run Gitea-Enviroment-Setup.bat
2. Install/start Gitea and complete the normal web setup
3. Run Gitea-Post-Setup-Settings.bat
4. Run Setup-Gitea-Help-Banner.bat
5. Restart Gitea


IMPORTANT
---------
The Gitea_Server_Monitor source files must be stored here:

    .\Batch-Dependencies\Gitea_Server_Monitor\

They are copied into the actual Gitea installation by
Gitea-Enviroment-Setup.bat.
