GITEA SERVER SETUP - BATCH FILE GUIDE
=====================================

Gitea-Enviroment-Setup.bat
--------------------------
Creates the main Gitea folder structure on the current drive and copies the
Gitea_Server_Monitor files from:
Batch-Dependencies\Gitea_Server_Monitor\

Gitea-Post-Setup-Settings.bat
-----------------------------
Updates:
Gitea\custom\conf\app.ini

Sets:
- Uploads enabled
- Maximum 100 files per upload
- Maximum file size to 100 MB
- All file types allowed
- Default branch name to master

Setup-Gitea-Help-Banner.bat
---------------------------
Asks for the Gitea username that owns the Gitea-Help-Documents repository and
creates the custom Gitea Help / Getting Started links and banner.

Create-Gitea-Web-Shortcut.bat
-----------------------------
Reads the Gitea server URL from app.ini and creates a desktop shortcut to the
Gitea website using:
Batch-Dependencies\Gitea.ico
