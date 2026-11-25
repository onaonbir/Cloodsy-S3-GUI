# This release machine's settings. Copy to tool/release.local.ps1 (ignored by
# git) and fill in; release.ps1 and build-windows.ps1 read it when present.
# Environment variables of the same names work as well.

# The updater's private key (Tauri/minisign, empty password). Keep it outside
# the repository; without it builds are not signed for the updater.
$env:CLOODSY_S3_GUI_UPDATER_KEY = 'C:\path\to\cloodsy-s3-gui-updater.key'

# The Mac that builds the macOS packages, reachable with an SSH key login.
$env:CLOODSY_S3_GUI_MAC_HOST = 'user@mac.local'
