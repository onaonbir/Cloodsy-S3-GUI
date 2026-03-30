<div align="center">

# Cloodsy S3 GUI

**A desktop and mobile admin interface for [Cloodsy S3](https://github.com/onaonbir/Cloodsy-S3) servers.**

Built with Flutter and Material Design 3. Connects to one or more Cloodsy S3 servers via the Admin REST API.

[![Built by OnaOnbir](https://img.shields.io/badge/Built%20by-OnaOnbir-blue?style=flat-square)](https://onaonbir.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.11-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Mobile-green?style=flat-square)]()

[Website](https://onaonbir.com) | [Cloodsy S3 Backend](https://github.com/onaonbir/Cloodsy-S3) | [Documentation](#getting-started)

</div>

---

## Features

- **Multi-Server Management** — Connect to multiple S3 servers, switch between them
- **Bucket Operations** — Create, delete, browse, configure quotas and storage directories
- **File Manager** — Browse folders, view files, bulk select and delete, folder delete
- **Credential Management** — Generate access keys, show/hide secret keys, copy to clipboard
- **Lifecycle Rules** — Create auto-expiration rules by age and prefix
- **Webhook Notifications** — Configure event notification endpoints
- **Admin User Management** — Create admins, reset passwords, auto-generate or custom passwords
- **Versioning Control** — Enable/disable bucket versioning with a toggle
- **Custom Window Frame** — Native title bar with drag, minimize, maximize, close (desktop)
- **Sidebar Navigation** — Server list, bucket tabs, settings section
- **Dark Mode** — Light and dark themes with system detection
- **Responsive Layout** — Desktop sidebar layout (900px+) and mobile navigation
- **Secure Credential Storage** — Passwords and tokens stored via platform secure storage

## Screenshots

### Desktop Layout

```
┌──────────────────────────────────────────────────────────┐
│  Cloodsy S3  /  Production                     _ [] X    │
├──────────┬───────────────────────────────────────────────┤
│ <- bucket│  my-bucket          [Files]         Refresh   │
│          │ ─────────────────────────────────────────     │
│ Overview │  Root > photos > 2024                         │
│ Files    │ ┌────┬──────────────┬───────┬──────┬────┐    │
│ Creds    │ │    │ Name         │ Size  │ Type │    │    │
│ Settings │ │ [] │ vacation/    │ -     │ Dir  │ x  │    │
│ Lifecycle│ │ [] │ img001.jpg   │ 2.4MB │ image│ x  │    │
│ Webhooks │ │ [] │ notes.txt    │ 142B  │ text │ x  │    │
│          │ └────┴──────────────┴───────┴──────┴────┘    │
│ SETTINGS │                                              │
│ Admins   │                                              │
│          │                                              │
│ SERVERS  │                                              │
│ * Prod   │                                              │
│   Dev    │                                              │
│          │                                              │
│ Disconn  │                                              │
└──────────┴───────────────────────────────────────────────┘
```

## Requirements

- Flutter SDK 3.11.0+
- A running Cloodsy S3 server with the Admin API enabled

### Server-Side Setup

```yaml
# In your Cloodsy S3 config.yaml
admin:
  enabled: true
  listen: ":9001"
  cors_origins: ["*"]
```

```bash
# Create an admin user
./cloodsys3 admin create myadmin
```

## Getting Started

### 1. Clone and Install

```bash
git clone <repo-url>
cd cloodsy_s3_gui
flutter pub get
```

### 2. Run

```bash
# Desktop (Windows/Linux/macOS)
flutter run -d windows
flutter run -d linux
flutter run -d macos

# Mobile
flutter run -d chrome     # Web
flutter run               # Connected device
```

### 3. Add a Server

1. Click **Add Server** (or the `+` button)
2. Enter:
   - **Name**: A label (e.g., "Production")
   - **URL**: Admin API address (e.g., `http://192.168.1.100:9001`)
   - **Username**: Admin username
   - **Password**: Admin password
3. Click **Add**
4. Click the server to connect

## Architecture

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.11+ / Dart |
| State Management | Provider (3-level proxy hierarchy) |
| HTTP Client | `http` package with Bearer token auth |
| Local Storage | `shared_preferences` (server list) |
| Secure Storage | `flutter_secure_storage` (passwords, tokens) |
| Window Management | `window_manager` (custom title bar) |
| Typography | Google Fonts (Inter) |
| Design System | Material 3 with shadcn/zinc color palette |

### Provider Hierarchy

```
ServerProvider          — Manages server list, passwords, tokens
    └─ AuthProvider     — Handles login/logout, token refresh, 401 recovery
        └─ BucketProvider — Buckets, objects, credentials, lifecycle, webhooks, admins
```

### Project Structure

```
lib/
├── main.dart                          # Entry point, window setup, providers
├── config/
│   └── app_config.dart               # Constants
├── models/
│   ├── server_connection.dart        # Server config model
│   ├── server_status.dart            # Server health model
│   ├── bucket.dart                   # Bucket model with computed fields
│   ├── credential.dart               # Access key model
│   ├── s3_object.dart                # Object + list result models
│   ├── lifecycle_rule.dart           # Expiration rule model
│   ├── webhook.dart                  # Webhook model
│   └── admin_user.dart              # Admin user model
├── providers/
│   ├── server_provider.dart          # Multi-server CRUD + secure storage
│   ├── auth_provider.dart            # Auth state, auto-reconnect
│   └── bucket_provider.dart          # 30+ methods for all operations
├── services/
│   └── api_client.dart              # HTTP wrapper, error handling, 401 callback
├── screens/
│   ├── shell_screen.dart            # Main shell (title bar + sidebar + content)
│   ├── dashboard_screen.dart        # Stats cards + bucket list
│   ├── bucket_detail_screen.dart    # 6 tabs: Overview, Files, Creds, Settings, Lifecycle, Webhooks
│   └── admin_screen.dart            # Admin user management
├── widgets/
│   ├── window_title_bar.dart        # Custom draggable title bar
│   ├── app_sidebar.dart             # Navigation sidebar (230px)
│   ├── bucket_card.dart             # Bucket summary card
│   ├── server_card.dart             # Server connection card
│   ├── stat_card.dart               # Dashboard statistics card
│   ├── empty_state.dart             # Empty state placeholder
│   └── dialogs/
│       ├── add_server_dialog.dart
│       ├── create_bucket_dialog.dart
│       ├── create_credential_dialog.dart
│       ├── set_quota_dialog.dart
│       ├── set_storage_dialog.dart
│       ├── add_lifecycle_dialog.dart
│       └── add_webhook_dialog.dart
└── theme/
    └── app_theme.dart               # Shadcn/zinc theme (light + dark)
```

## Screens

### Server List (Home)

The starting screen on desktop shows a sidebar with saved servers. Click a server to connect. On mobile, a full-screen list is shown.

- Add, edit, delete servers
- Connection status indicator (green dot)
- Hover actions for edit/delete (desktop)
- Credentials stored securely per server

### Dashboard

After connecting to a server:

- **Status card** — Online/offline indicator
- **Buckets card** — Total bucket count
- **Objects card** — Total object count across all buckets
- **Total Size card** — Combined storage usage
- **Bucket list** — Cards with name, object count, usage, credentials, versioning, quota progress bar
- **Create Bucket** — FAB button with optional custom storage directory

### Bucket Detail

Six tabs managed from the sidebar (desktop) or tab bar (mobile):

**Overview** — Bucket metadata in a two-column card layout (name, ID, created, objects, usage, quota, versioning, storage path, credentials count).

**Files** — File manager with:
- Breadcrumb navigation (Root > folder > subfolder)
- Table with Name, Size, Type, Modified columns
- Folder icons with click-to-enter navigation
- File icons by extension (image, PDF, video, audio, archive, code, text)
- Checkbox multi-select with bulk delete
- Individual file and folder delete with confirmation

**Credentials** — Access key management:
- Name label and permission badge (read-write / read-only)
- Access key displayed in monospace with copy button
- Secret key with show/hide toggle (masked by default)
- Create dialog with optional name and permission selector

**Settings** — Bucket configuration:
- Quota: set size with unit selector (KB/MB/GB/TB), remove quota option
- Storage directory: set absolute path or reset to default
- Versioning: toggle switch (Enabled/Suspended)

**Lifecycle** — Auto-expiration rules:
- Rule name, expiration days, prefix filter
- Add and delete rules

**Webhooks** — Event notification endpoints:
- Webhook name, URL, event types, active status indicator
- Add and delete webhooks

### Admin Users

Accessible from the sidebar Settings section:

- List all admin users with creation date
- Current user badge ("you")
- Create admin with auto-generated or custom password
- Reset password (auto or custom)
- Password shown once with copy button and warning
- Cannot delete your own account or the last admin

## Desktop Features

### Custom Window Frame

On Windows, Linux, and macOS the system title bar is replaced with a custom Flutter-rendered title bar:

- Draggable area for window movement
- Double-click to maximize/restore
- Minimize, maximize, close buttons with hover effects
- Server name badge when connected
- Default size: 1200 x 800, minimum: 900 x 600

### Sidebar Navigation

When screen width is 900px or wider:

- 230px sidebar with server list, bucket tabs, settings
- Bucket detail tabs move into sidebar (no tab bar in content area)
- Content area fills remaining width
- No page transitions — instant tab switching

## Theme

Inspired by shadcn/ui with a zinc color palette:

| Element | Light | Dark |
|---------|-------|------|
| Background | #FAFAFA | #09090B |
| Surface | #FFFFFF | #18181B |
| Border | #E4E4E7 | #27272A |
| Text | #09090B | #FAFAFA |
| Muted | #71717A | #71717A |
| Primary | #171717 | #FAFAFA |
| Error | #EF4444 | #EF4444 |
| Success | #22C55E | #22C55E |

Typography: **Inter** via Google Fonts.

## Admin API Endpoints

The GUI communicates with the Cloodsy S3 Admin API (default port 9001):

| Category | Endpoints |
|----------|-----------|
| Auth | `POST /login`, `POST /logout` |
| Status | `GET /status` |
| Admins | `GET/POST /admins`, `DELETE /admins/{user}`, `PUT /admins/{user}/password` |
| Buckets | `GET/POST /buckets`, `GET/DELETE /buckets/{name}` |
| Config | `PUT .../quota`, `PUT .../storage`, `GET/PUT .../versioning` |
| Credentials | `GET/POST .../credentials`, `DELETE /credentials/{key}` |
| Lifecycle | `GET/POST/DELETE .../lifecycle` |
| Webhooks | `GET/POST .../webhooks`, `DELETE /webhooks/{id}` |
| Objects | `GET .../objects`, `DELETE .../objects/{key}`, `POST .../objects/delete-prefix` |

## Build

```bash
# Desktop
flutter build windows    # Windows (.exe)
flutter build linux      # Linux
flutter build macos      # macOS

# Mobile
flutter build apk        # Android
flutter build ios         # iOS
flutter build web         # Web
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| provider | 6.1.5 | State management |
| http | 1.6.0 | HTTP client |
| shared_preferences | 2.5.4 | Server list persistence |
| flutter_secure_storage | 10.0.0 | Encrypted credential storage |
| window_manager | 0.5.1 | Desktop window management |
| google_fonts | 8.0.2 | Inter font family |

## License

Cloodsy S3 GUI is source-available under the [Cloodsy S3 GUI Community License 1.0](LICENSE).

You can use it freely for personal, internal, educational, and self-hosted purposes.
Commercial resale and redistribution require a separate commercial license.

Contact: [trademark@onaonbir.com](mailto:trademark@onaonbir.com)

---

<div align="center">

**Cloodsy S3 GUI** is built and maintained by **[OnaOnbir](https://onaonbir.com)**

[onaonbir.com](https://onaonbir.com)

</div>
