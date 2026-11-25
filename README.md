<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/brand/logo-dark.svg">
  <img src="docs/brand/logo-light.svg" alt="Cloodsy S3 GUI" height="64">
</picture>

# Cloodsy S3 GUI

**A desktop admin console for [Cloodsy S3](https://github.com/onaonbir/Cloodsy-S3) servers.**

Built with Tauri 2, Rust and Vue 3. Connects to one or more Cloodsy S3 servers through the Admin REST API.

[![Built by OnaOnbir](https://img.shields.io/badge/Built%20by-OnaOnbir-blue?style=flat-square)](https://onaonbir.com)
[![Tauri](https://img.shields.io/badge/Tauri-2-24C8DB?style=flat-square&logo=tauri&logoColor=white)](https://tauri.app)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-green?style=flat-square)]()

[Website](https://onaonbir.com) | [Cloodsy S3 Server](https://github.com/onaonbir/Cloodsy-S3) | [Getting started](#getting-started)

</div>

---

## Features

- **Several servers** — save any number of servers, switch between them from the sidebar
- **Dashboard** — buckets, objects, stored bytes, disk space, uptime, TLS/ACME and WebDAV state, update notice
- **Buckets** — searchable, sortable table with quota bars; create, delete (with a guarded force-delete for non-empty buckets)
- **File browser** — folders, breadcrumbs, filter and sort, paginated listing for large folders, multi-select
- **Upload & download** — files and whole folders (drag and drop on desktop), a transfer queue with progress, cancel and retry
- **Object versions** — list, download or delete individual versions and delete markers
- **Access keys** — read/write or read-only keys per bucket, reveal and copy secrets
- **Bucket settings** — versioning, public read, WebDAV, quota, storage directory, image reprocessing
- **Lifecycle rules and webhooks** — expiration by prefix and age; webhook event picker
- **Admin users** — add admins, reset passwords (changing your own keeps you signed in)
- **Object details** — preview (images, text/JSON, PDF; media opens in the default player), where the file lives on the server disk, "show in folder" when the server runs on the same machine (WSL included)
- **Share links** — time-limited presigned URLs signed locally with a bucket key, public URLs, image resize parameters
- **File operations** — rename, move/copy (also folders and across buckets, done server-side), metadata editing, bucket-wide search, folder sizes, right-click menus, keyboard shortcuts
- **Large uploads** — multipart above 64 MB, resumable after a failure; incomplete uploads can be listed and aborted
- **Server tools** — active sessions, live activity log, request/traffic metrics, disk consistency scan with orphan cleanup, effective configuration
- **Lifecycle v2 & webhooks v2** — every rule action with enable/edit; webhook edit, test event and delivery history
- **Everyday comfort** — Ctrl+K command palette, English/Türkçe, notifications when transfers finish, taskbar progress, "all servers" overview, update check
- **Light, dark and system themes**, bundled fonts (works fully offline), responsive layout down to tablet width
- **Installs and updates itself** — our own Windows setup (per user, no administrator rights), and signed in-place updates from GitHub releases on Windows, macOS and Linux

> **Server version:** most of the above needs **Cloodsy S3 1.4.0 or newer**.
> The app reads `features` from `GET /admin/status` and hides anything an
> older server doesn't support, so 1.2/1.3 servers keep working with the
> 1.x feature set.

## Download

Prebuilt desktop binaries are attached to every [release](https://github.com/onaonbir/Cloodsy-S3-GUI/releases/latest):

| Platform | File | Install |
|----------|------|---------|
| Windows 10/11 | `cloodsy-s3-gui-<version>-windows-x64-setup.exe` | Run it: installs for your user (no administrator), Start menu and optional desktop shortcut, uninstall from *Settings → Apps* |
| macOS | `cloodsy-s3-gui-<version>-macos-<arch>.dmg` | Open the DMG, drag to Applications |
| Linux | `cloodsy-s3-gui-<version>-linux-x64.AppImage` | `chmod +x` then run |
| Linux (Debian/Ubuntu) | `cloodsy-s3-gui-<version>-linux-x64.deb` | `sudo apt install ./cloodsy-s3-gui-…deb` |

Installed copies update themselves: **Settings → About → Download and install**
(the app checks GitHub once per launch). Every update is signed; the app refuses
one whose signature does not match the key built into it.

Coming from 2.0? The first start imports the servers you had saved (names,
addresses and usernames); enter each password once more. The 2.0 MSIX can be
removed from *Settings → Apps*.

### First-launch notes (builds are not code-signed)

- **Windows (SmartScreen):** *More info* → *Run anyway*.
- **macOS (Gatekeeper):** right-click the app → *Open* → *Open*, or run `xattr -cr "/Applications/Cloodsy S3 GUI.app"` once.
- **Linux (AppImage):** needs FUSE (`sudo apt install libfuse2`).

## Getting started

### Server side

```yaml
# config.yaml of your Cloodsy S3 server
admin:
  enabled: true
  listen: ":9001"
  tls:
    enabled: true   # strongly recommended when the admin port is reachable from the network
```

```bash
./cloodsys3 admin create myadmin --generate
```

### In the app

1. **Add server** → Admin API URL (e.g. `https://storage.example.com:9001`), username, password.
2. Click the server to connect. The password is kept in the system keychain; sessions renew automatically.

## Development

Requirements: Rust (stable), Node 22+, and the [Tauri 2 prerequisites](https://tauri.app/start/prerequisites/)
for your OS (WebView2 on Windows, Xcode tools on macOS, `libwebkit2gtk-4.1-dev` and friends on Linux).

```bash
npm install
npm run tauri dev        # the app with hot reload
npm run typecheck        # vue-tsc
npm test                 # vitest (pure logic)
cargo test --workspace   # Rust: API client, sessions, transfers, SigV4, settings, setup
node tool/i18n-missing.mjs   # every UI string has Turkish
```

### Architecture

```
src-tauri/            the app (Rust): everything that leaves the machine or touches secrets
  src/api.rs          Admin API client and sessions: token reuse, silent renewal, 401 recovery
  src/transfers.rs    streamed uploads/downloads, 3 at a time, multipart above 64 MB, resume, cancel
  src/presign.rs      SigV4 presigning for share links (secrets never leave the machine)
  src/settings.rs     settings.json (servers, preferences), import of 2.0's settings
  src/secrets.rs      passwords and tokens in the OS keychain
  src/desktop.rs      folder walks, preview files, server-path → local-path mapping (WSL included)
src/                  the window (Vue 3 + TypeScript): no file, shell or network access of its own
  lib/                typed Admin API, IPC, i18n, formatting, dialogs, menus
  stores/             session, navigation, servers, preferences, transfers, updates
  shell/              title bar, sidebar, command palette, transfers panel, welcome, server dialog
  screens/            dashboard, buckets, bucket/<tab> (files in bucket/files/), admins, server pages, settings
  i18n/               Turkish strings (English is the key)
installer/            our Windows setup: pack (payload) + setup (Tauri window), see installer/README.md
src-setup/            the setup window's page
tool/                 build and release scripts
```

The window talks only to the Rust side (Tauri commands); its CSP allows no
network access. The Rust side keeps one session per server and renews it
before it expires.

### Releasing

Packages are built locally (no CI) and published as a GitHub release with a
signed `latest.json` for the updater. See [docs/RELEASE.md](docs/RELEASE.md).

## License

Cloodsy S3 GUI is source-available under the [Cloodsy S3 GUI Community License 1.0](LICENSE).

You can use it freely for personal, internal, educational, and self-hosted purposes.
Commercial resale and redistribution require a separate commercial license.

Bundled fonts: Plus Jakarta Sans and JetBrains Mono, both under the SIL Open Font License (`assets/fonts/`).

Contact: [trademark@onaonbir.com](mailto:trademark@onaonbir.com)

---

<div align="center">

**Cloodsy S3 GUI** is built and maintained by **[OnaOnbir](https://onaonbir.com)**

</div>
