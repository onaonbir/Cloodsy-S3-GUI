# Changelog

All notable changes to Cloodsy S3 GUI are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [3.0.1] - 2026-11-25

### Added

- **Language picker before signing in**: English or Türkçe on the start
  screen (Settings needs a connected server).
- **Language picker in the Windows setup** (TR / EN in its title bar). The
  language picked there becomes the app's; an update opens in the app's
  current language.

### Fixed

- The setup's welcome icons were grey on the coloured tile; both now use the
  same turquoise badge.

## [3.0.0] - 2026-11-25

The app is rebuilt on Tauri 2 (Rust) and Vue 3, with every 2.0 feature kept.

### Added

- **Our own Windows setup**: one exe installs, updates, repairs and
  uninstalls, per user and without administrator rights; Start menu and
  optional desktop shortcut; "Also remove my data" on uninstall.
- **Updates in place**: Settings → About → *Download and install* fetches the
  new version from the GitHub release, checks its signature against the key
  built into the app and installs it (Windows, macOS, Linux).
- **Remove a server** from inside the app (server menu in the sidebar, and
  Settings → Connection), not only from the start screen.
- Linux `.deb` package next to the AppImage.

### Changed

- **Smaller**: a native window (WebView2 / WebKit) instead of Flutter; the
  Windows setup is 7 MB, against 19 MB for 2.0's zip.
- Network, uploads, downloads and secrets live in the Rust side; the window
  has no network access of its own.
- Settings are a plain `settings.json`; passwords and session tokens stay in
  the system keychain. The first start imports the servers saved by 2.0
  (passwords are asked once more).
- Every string is translated (2.0 left some dialog titles and labels in
  English), relative times included.
- New Cloodsy logo, ink/cream/turquoise colours from the brand kit.

### Fixed

- Webhook events are sent as the comma-separated list the server expects.
- Esc closes only the topmost of stacked dialogs.
- Deleting, downloading or editing the "null" (unversioned) version of an
  object targets that version only.

### Removed

- The MSIX, the portable zip and the snap; the GitHub Actions workflows
  (releases are built locally).

## [2.0.0] - 2026-11-14

A complete rewrite: new architecture, new design and many new features.
Features marked *(server 1.4)* need Cloodsy S3 1.4.0 or newer; the app reads
the server's `features` list and hides what an older server doesn't support.

### Added

- **New design** in the Cloodsy app family style: slate surfaces, Plus Jakarta
  Sans and JetBrains Mono (bundled, no runtime font download), light, dark
  and system themes, and a layout that adapts down to tablet width.
- **Navigation**: a persistent sidebar with a server switcher, a bucket table
  with search and sorting, tabbed bucket pages and a `Ctrl+K` command palette
  for pages, buckets and actions.
- **File browser**: breadcrumbs, filtering and sorting, pagination for large
  folders, multi-select, right-click menus and keyboard shortcuts (`Ctrl+A`,
  `Delete`, `F2`, `Enter`, `Backspace`, `F5`, `Esc`).
- **Upload and download** *(server 1.4)*: files and whole folders (drag and
  drop on desktop), a transfer queue with progress, cancel and retry, taskbar
  progress and a system notification when a batch finishes. Files over 64 MB
  are uploaded in parts and resume after a failure.
- **Object details** *(server 1.4)*: previews for images, text/JSON and PDF
  (media opens in the default player), content type, metadata and the file's
  location on the server disk, with "Show in folder" when the server runs on
  the same machine (including inside WSL).
- **Share links**: time-limited presigned URLs signed locally with one of the
  bucket's access keys, public URLs for public-read buckets and image resize
  parameters.
- **Object operations** *(server 1.4)*: rename, move and copy (also folders
  and across buckets, done on the server), metadata editing, object versions
  (download or delete a version), bucket-wide search and folder sizes.
- **Bucket settings**: full lifecycle rules *(server 1.4)* (expire objects,
  delete old versions, abort incomplete uploads, remove orphan delete markers,
  enable/disable, edit), a list of incomplete multipart uploads with abort
  *(server 1.4)*, and webhook editing, test events and delivery history
  *(server 1.4)*.
- **Server pages** *(server 1.4)*: admin sessions, a live activity log,
  request and traffic metrics, a disk consistency scan with orphan folder
  cleanup, and the effective configuration.
- **Dashboard** with bucket, object and storage totals, disk space, uptime,
  TLS and WebDAV state and a notice when a newer server release exists.
- **All servers overview**, a reachability check on the server list, an
  English/Turkish user interface, and an update check for the app itself.

### Changed

- Rebuilt on Flutter 3.50 with `material_ui`, `window_manager` 0.7 (native
  API), `flutter_secure_storage` 11 and `lucide_icons_flutter` 4.
- State is split into per-session and per-screen controllers; nothing from one
  server leaks into another session.
- Linux uses the system title bar (window dragging from Flutter widgets is not
  supported there yet); Windows and macOS keep the custom title bar.
- Saved servers, passwords and the theme carry over from 1.x unchanged.

### Fixed

- The Admin Users page could not be left without disconnecting.
- The theme toggle did nothing in release builds.
- Changing your own admin password ended the session; the app now signs in
  again with the new password.
- Folders with more than 200 objects only showed the first 200.
- Keys containing `?` or `#` could not be deleted; usernames and lifecycle
  prefixes are now URL-encoded.
- macOS release builds had no network access (missing sandbox entitlement).

## [1.1.0]

### Changed

- Adapted to the hardened Cloodsy S3 1.2 Admin API: server error messages,
  session expiry and renewal, and forced deletion of non-empty buckets.

### Added

- Release workflow building Windows (MSIX and zip), macOS (DMG) and Linux
  (AppImage and tar.gz) packages.

## [1.0.0]

Initial release.

[3.0.1]: https://github.com/onaonbir/Cloodsy-S3-GUI/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/onaonbir/Cloodsy-S3-GUI/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/onaonbir/Cloodsy-S3-GUI/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/onaonbir/Cloodsy-S3-GUI/releases/tag/v1.1.0
