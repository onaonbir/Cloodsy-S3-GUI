<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/brand/logo-dark.svg">
  <img src="docs/brand/logo-light.svg" alt="Cloodsy S3 GUI" height="64">
</picture>

# Cloodsy S3 GUI

**A desktop admin console for [Cloodsy S3](https://github.com/onaonbir/Cloodsy-S3) servers.**

Built with Flutter. Connects to one or more Cloodsy S3 servers through the Admin REST API.

[![Built by OnaOnbir](https://img.shields.io/badge/Built%20by-OnaOnbir-blue?style=flat-square)](https://onaonbir.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
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

> **Server version:** most of the above needs **Cloodsy S3 1.4.0 or newer**.
> The app reads `features` from `GET /admin/status` and hides anything an
> older server doesn't support, so 1.2/1.3 servers keep working with the
> 1.x feature set.

## Download

Prebuilt desktop binaries are attached to every [release](https://github.com/onaonbir/Cloodsy-S3-GUI/releases/latest):

| Platform | File | Install |
|----------|------|---------|
| Windows | `cloodsy-s3-gui-*.msix` | Double-click to install (one-time: trust the bundled test certificate) |
| Windows (portable) | `cloodsy-s3-gui-windows-x64.zip` | Unzip and run `cloodsy-s3.exe` |
| macOS | `cloodsy-s3-gui-*-macos.dmg` | Open the DMG, drag to Applications |
| Linux | `cloodsy-s3-gui-*-x86_64.AppImage` | `chmod +x` then run |
| Linux (portable) | `cloodsy-s3-gui-linux-x64.tar.gz` | Extract and run `cloodsy-s3` |

### First-launch notes (unsigned builds)

- **Windows (SmartScreen):** *More info* → *Run anyway*. For the MSIX, first install the included `.cer` test certificate (right-click → Install Certificate → Local Machine → *Trusted People*).
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

Requirements: Flutter **3.50.0**, pinned with [FVM](https://fvm.app) in `.fvmrc`.

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run -d windows   # or macos / linux
```

### Architecture

```
lib/
├── main.dart                 window setup, font licences
├── app.dart                  providers, MaterialApp, session gate
├── core/
│   ├── api/api_client.dart   Admin API client: JSON calls, streaming upload/download, cancel
│   ├── storage/              settings file + keychain behind small interfaces (memory fakes for tests)
│   └── format.dart           bytes, dates, versions, content types
├── models/                   API DTOs
├── state/                    ChangeNotifier controllers
│   ├── session_controller    login, token reuse, silent renewal, revocation recovery
│   ├── navigation_controller sealed destinations; every screen is reachable from every other
│   ├── server_controller     status + bucket list (per session)
│   ├── bucket_controller     one bucket: settings, keys, rules, webhooks (per open bucket)
│   ├── objects_controller    file browser with pagination and selection (per open bucket)
│   ├── transfers_controller  upload/download queue (per session)
│   └── admins_controller
└── ui/
    ├── theme/                colour tokens (light/dark), spacing, typography
    ├── widgets/common.dart   page scaffold, panels, pills, dialogs, confirm/prompt, toasts
    ├── shell/                title bar, sidebar, server switcher, transfers panel
    ├── dialogs/
    └── screens/              welcome, dashboard, buckets, bucket/<tab>, admins, settings
```

Controllers that belong to a session are created inside `SessionScope` and
disposed when the session ends, so nothing leaks between servers. Screen-scoped
controllers (bucket, objects, admins) live as long as their screen.

`material_ui` replaces the deprecated `package:flutter/material.dart`, and
`window_manager` 0.7 is used through its native API (`WindowManager.instance`).

### Releasing

```bash
# bump version in pubspec.yaml, commit, then:
git tag v2.0.0 && git push origin v2.0.0
```

`.github/workflows/release.yml` runs analyze + tests (`ci.yml`) and then builds
on Windows, macOS and Linux runners, attaching `.msix`/`.zip`, `.dmg` and
`.AppImage`/`.tar.gz` to the release. Builds are unsigned.

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
