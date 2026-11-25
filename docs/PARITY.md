# 3.0 parity checklist (Flutter 2.0 → Tauri 2 + Vue 3)

What the Flutter GUI 2.0 does, so the Tauri rewrite keeps all of it. File
references point at the Flutter code (`lib/…`) as it was at 9c23c7c. Tick an
item off in the rewrite's PR when it is done and checked.

## 1. Shell

- Window "Cloodsy S3", min 960×620, initial 1320×840, centred. Own title bar on
  Windows and macOS (80 px left padding for the traffic lights); Linux keeps the
  system bar. Title bar 40 px: brand mark 20 px, "Cloodsy S3", chevron + current
  server. Windows caption buttons 46 px wide, close hovers `#E81123`, maximize
  icon follows the window state (Win11 snap layouts).
- Theme toggle in the title bar: click flips light/dark; right-click: Light /
  Dark / System (checked). Persisted `theme_mode`.
- Root: Welcome screen when signed out, else the shell. A new session resets
  navigation.
- Layout: sidebar 252 px at width ≥ 860; below, an app bar (menu, title, search,
  Back except on Dashboard, theme) with the sidebar as a drawer. Page switch
  200 ms. Transfers panel floats bottom-right and opens on new transfers.
- Sidebar: server switcher card (name, dot: Connecting… / Online · vX / error,
  tooltip host:port; menu: saved servers ✓, Add server…, Edit this server…,
  Disconnect), "Search… Ctrl K", Dashboard, Buckets (count), open bucket
  (indented, ×), SERVER: Admin users, Sessions, Activity log, Metrics,
  Maintenance, Configuration (feature-gated), APP: All servers (> 1 server),
  Settings (● when a GUI update exists). Transfers indicator ("{n} transfers
  running" + bar / "{n} failed" / "Transfers complete"). Account footer
  (initial, username, "Renews {time}" / "Signed in", logout).
- Navigation: Dashboard, Buckets, Bucket(name, tab), Admins,
  Server(sessions|logs|metrics|maintenance|config|servers), Settings. History
  capped at 50; tab switches add no history; a deleted bucket is forgotten.
- Colours (light / dark): background `#F2EFE8`/`#161B29`, sidebar
  `#EBE7DE`/`#121725`, title bar `#E4E0D6`/`#0E121C`, card `#FBFAF6`/`#1D2333`,
  primary `#0A6E90`/`#2EC8F0`, danger `#C0392B`/`#F2665E`, success
  `#12703A`/`#4FD08A`, warning `#A15C07`/`#F2B544`; foreground, muted, subtle,
  border, hover, selected in `lib/ui/theme/app_colors.dart`. Radii 6/8/10/14,
  spacing in `tokens.dart`, type scale `app_theme.dart:12-35`. Folders amber
  `#FFC107`. Brand mark: cyan `#2EC8F0` tile, ink cloud, white prompt (no dots
  under 24 px).
- Fonts: Plus Jakarta Sans 400–700, JetBrains Mono 400/500, bundled (OFL, shown
  under Licences).
- i18n: English text is the key; TR table of 523 entries
  (`lib/core/i18n_tr.dart`), `{name}` placeholders, plural helper. `locale` =
  en | tr | unset (follow the OS). Switching keeps state. 2.0 left some strings
  untranslated (dialog titles, validators, pills, "Load more"): translate all in
  3.0.
- Shortcuts: Ctrl/Cmd+K palette. Files (list focused): Ctrl+A, Delete, Esc
  (selection → search → focus), Ctrl+F, F5, Backspace / Alt+Up, Up/Down, Space,
  F2 rename, Ctrl+U upload, Enter download. Listed in Settings.
- Command palette 580 px: every word must match title + group; Up/Down/Enter,
  hover selects. Go to (feature-gated), open bucket tabs ("bucket › tab"), Open
  bucket per bucket, New bucket, Toggle light/dark, Switch to {server},
  Disconnect.
- Drag & drop upload onto Files (if the server can upload): overlay "Drop to
  upload / into /{prefix}", folders recursive keeping relative paths, > 200
  files asks first.
- Pickers: files / folder for upload, folder for multi-download, save dialog for
  one; remember `last_upload_dir`, `last_download_dir`.
- System notification when a batch of transfers ends (`notifications` pref);
  taskbar / dock progress.
- Toasts: 3 s, errors 6 s; `runAction` success/error toast.
- Update checks: GUI (GitHub releases/latest of Cloodsy-S3-GUI, once per launch,
  8 s; Settings callout + sidebar dot; "Check for updates"). 3.0: download,
  verify and install it. Server (Cloodsy-S3 releases/latest, 6 s; dashboard
  callout "run cloodsys3 update"; skipped for `dev`).

## 2. Servers, session, storage

- Server: `{id, name, url, username, s3_url?}`. Dialog: Admin API URL (required,
  http/https, host; trailing slashes stripped), name (defaults to host),
  username (default "admin"), password (required on add; empty on edit keeps
  it; eye toggle), Advanced: public S3 endpoint (share links). Note: password
  goes to the system keychain. Editing URL/username drops the token; removing a
  server deletes its secrets.
- 2.0 stored `settings.dat` (XOR-obfuscated JSON + `.key`) under
  `AppData\Roaming\OnaOnbir\Cloodsy S3\` and secrets `pw_<id>`, `token_<id>`,
  `token_exp_<id>` in flutter_secure_storage. 3.0: plain JSON settings, secrets
  in the OS keychain; import the 2.0 server list on first start (passwords are
  asked again).
- Welcome: brand mark, hint, session error callout; no servers → Add server.
  Rows: name + reachability pill (unauthenticated GET `/admin/status`, 5 s; any
  HTTP answer = "Online · {ms} ms", else "Unreachable"), lock/unlock for
  https/http, host:port · username, hover Edit / Remove (confirm), spinner,
  click connects, "Add another server".
- Session: reuse a saved token with > 30 s left (checked with GET /status; 401
  → password login). POST /login → token, username, expires_in | expires_at.
  Silent re-login 30 s before expiry and on any 401 (not /login); failure →
  "Session expired. Please reconnect." Own password change stores it and logs
  in again. Disconnect: POST /logout, drop token. One active session.
- No TLS options; TLS handshake errors get an explanatory message.
- Local path mapping (Show in folder): Windows + `host.wsl_distro` + loopback /
  172.16–31.x / *.local host → `\\wsl.localhost\<distro>\path`; else same OS and
  loopback/same hostname.

## 3. Screens

- **Dashboard**: loading/error; "{server} · signed in as {u}", Refresh, New
  bucket; callouts (server update, refresh failed); tiles Buckets ({n} public),
  Objects, Stored, Disk free/total bar (or Status); Largest buckets top 6
  (quota bar only with quota, View all, empty → create); Server panel (status,
  version, uptime, S3/Admin TLS, ACME domains, WebDAV + listen, data dir);
  callout when `features` is empty.
- **Buckets**: filter, refresh, New bucket; sortable NAME, OBJECTS, SIZE, QUOTA
  (bar + "{p}% of {size}" / Unlimited), CREATED; < 760 px hides columns; pills
  Versioned, Public, WebDAV, Custom storage (else "{n} access keys"); row menu
  overview/files/keys/delete; empty/no-match/loading/error. Delete: confirm; 409
  (not "bucket is busy") → "Delete everything" type-the-name → `?force=true`,
  5 min. Create: name 3–63 `^[a-z0-9][a-z0-9-]*[a-z0-9]$`, optional custom
  storage dir (absolute), inline server errors, opens the bucket.
- **Bucket**: back, pills, reload, ⋯ Delete; tabs Overview, Files, Access keys,
  Settings, Lifecycle, Webhooks (badges); loads bucket, credentials, lifecycle,
  webhooks in parallel.
- **Overview**: usage/quota bar, counts; details (name, created, versioning,
  access, WebDAV, storage path); Connect (bucket name, WebDAV URL
  `{scheme}://{adminHost}:{webdavPort}/` when both on, keys hint/manage).
- **Files**: breadcrumbs; filter (local) + Enter = server search
  (`object-search`); refresh; folder size (`prefix-stats`); New folder (`name/`
  marker, no "/"); Upload files… / Upload folder…; selection bar ({n} selected,
  Clear, Download to folder with " (n)" on collisions, Move / copy, Delete).
  List: select-all, sort NAME/SIZE/MODIFIED (folders by name), "..", icons,
  date + relative tooltip, click focus, Ctrl+click select, double-click
  download, context menu = ⋯; "Load more" (500/page, marker); search mode
  ("{n}{+} results for … in /{p}", Back to folder); empty states; old-server
  callout. Object menu: Details, Download, Share link…, Rename… (F2), Move /
  copy…, Edit metadata…, Versions…, Copy key, Delete… ("including all of its
  versions"). Folder menu: Open, Rename…, Move / copy…, Calculate size, Copy
  prefix, Delete folder… (type the name, delete-prefix, counts toast).
  Multi-delete one by one with failures; multi move/copy loops; refresh after
  uploads into the open folder (600 ms debounce). Object panel 380 px side at
  ≥ 1180 px, else a 460×640 dialog.
- **Object panel**: previews — image (jpg/jpeg/png/gif/webp/bmp/ico or image/*
  except svg, ≤ 25 MB; fullscreen zoom ≤ 8×), text (~40 extensions, text/*,
  json, xml; first 256 KB via Range when `object-range`; JSON pretty-printed if
  whole; "Showing the first…"; Copy), PDF ≤ 60 MB in-app (else external), media
  and others external ("Open with default app" downloads to
  `<temp>/cloodsy-preview/`). Chips: Download, Share, Rename, Move / copy,
  Metadata, Versions, Delete. Object: size (+ exact bytes), type, modified,
  ETag, version id, copyable key and `s3://bucket/key`. On disk (`object-info`):
  path, optimized variant path + size, Show in folder / Copy local path, "{n}
  versions are kept", delete-marker note. Metadata list.
- **Share**: Expiring link (SigV4 presigned locally, path-style) or Public URL
  (public-read only); prefers a read-only key with secret, warns for read-write,
  callout when no keys; expiry 15 min / 1 h / 1 d / 7 d; endpoint defaults to the
  server's S3 URL override else `{s3 tls?https:http}://{adminHost}:{s3 port}`;
  region from status (default us-east-1); images: optional w, h, q.
- **Move / copy / rename**: Move|Copy, destination bucket, key or folder; rename
  shows the parent prefix. No leading "/", must differ, no folder into itself,
  rename without "/", multi needs another folder/bucket.
- **Metadata**: Content-Type + x-amz-meta rows; keys lower-cased
  `^[a-z0-9-]+$`; versioned note (new version).
- **Versions**: id ("null (unversioned)"), Current / Delete marker pills, size,
  date; Copy id, Download version (not markers), Delete version; refresh files
  on close after a change.
- **Access keys**: cards (name, created, Read only / Read & write, Revoke with
  the key in the confirmation, copyable access key, secret behind reveal);
  create (label, read-write | read-only) → result shows key + secret.
- **Settings tab**: Versioning (confirm suspend), Public read (confirm enable,
  warning), WebDAV (note when the server has it off); Quota (size + MB/GB/TB,
  Remove quota = 0); Storage directory (move; empty = default; "Moving…");
  Image variants Reprocess (409 → already running / busy); Incomplete uploads
  (`multipart`: ≤ 50, key, started, parts, size, Abort; Abort > 7 days, Abort
  all; refresh); Danger zone delete.
- **Lifecycle**: rules (name or "Rule #id", prefix or "All objects", added,
  action pills, Disabled); Remove all. v2: enable switch, edit, delete by id;
  dialog name, prefix, Expire (30), Delete old versions (30; dim when not
  versioned), Abort incomplete uploads (7), Remove orphan delete markers,
  enabled; positive days, ≥ 1 action, not Expire + markers together. v1: name,
  prefix, days; delete by prefix; prefix-less only via Remove all.
- **Webhooks**: rows (name or "Webhook #id", Active/Inactive, Signed, URL,
  events, created, Delete). v2: Test (40 s; "HTTP {code} in {ms} ms"),
  Deliveries (last 50, "{ok} of {n} succeeded", per row status, event · key,
  code/ms/attempt or error, time, Refresh), Edit (+ Active; empty secret keeps
  it). Dialog: URL http/https + host, name, signing secret, events "All events"
  (`*`) or the 7 types (wildcard clears specifics).
- **Admin users**: sorted, "You" pill, added; Reset/Change password (generate or
  enter 8+ chars, ≤ 72 UTF-8 bytes; own change re-logs in; result shows it
  once); Delete (type to confirm, not yourself); Add admin (username +
  generated/entered password).
- **Sessions**: by last seen; device icon from UA ("dart…" → this GUI; 3.0 sends
  its own UA); IP, UA (60 chars), active / signed in / expires; "This app"; End
  (own → disconnect).
- **Activity log**: poll 2 s with `since_id`, keep 3000; level All / Info+ /
  Warn+ / Errors; search (400 ms debounce, server-side, resets tail); Pause /
  Resume, Copy visible, Clear view; follow + "Follow" when scrolled up; "Paused";
  rows HH:MM:SS, level colour, message + k=v, selectable.
- **Metrics**: every 10 s; Requests (by method), Errors (% + 4xx/5xx), Uploaded,
  Downloaded; four per-minute bar charts, last 60 min, hover tooltips.
- **Maintenance**: Run scan / Scan again; summary (clean / warning + "lists
  capped"); orphan folders (path, bytes; Delete all… type `delete`; rescan +
  toast), missing files, untracked files (≤ 200 each).
- **Configuration**: read-only tree per top-level key, booleans coloured, masked
  secrets dimmed, Copy JSON.
- **All servers**: card per server; probe with saved token or throwaway
  login/logout; Online/Offline + latency, version, buckets, objects, stored,
  disk; Switch to / Connected.
- **Settings**: update callout; Theme, Language (English / Türkçe / System);
  Transfers: notifications, download folder ("Asks every time"); Connection
  (server, Admin API, S3 endpoint, user, renewal, server version, Edit,
  Disconnect); shortcuts; About (version, up to date, Check for updates,
  Licences).
- Shared: confirm (type-to-confirm, detail), prompt, copy value (reveal + "{label}
  copied"), usage bar (warning > 75 %, danger > 90 %), error state (offline icon
  for connection errors, Try again).

## 4. Admin API (base `<url>/admin`)

Client: Bearer token, JSON; timeouts 15 s, 5 min for long operations; path
segments encoded one by one, object keys keep "/"; error text from the server's
`error`, fallbacks for 401, 413, 429 ("Try again in 15 minutes"),
400/403/404/409/500/502–504; transport error = 0, cancel = −1; downloads to
`<dest>.part` then rename.

- Auth/server: POST /login, POST /logout, GET /status (`status, version,
  buckets, admin_exists, webdav{enabled,listen}, features[], uptime_seconds,
  tls{s3,admin,webdav,acme,acme_domains}, storage{path,total_bytes,free_bytes},
  s3{listen,tls,region,virtual_host_domains}, host{os,hostname,wsl_distro}`).
- Buckets: GET/POST /buckets; GET, DELETE[?force=true] /buckets/{b}; PUT quota
  `{quota_bytes}`, storage `{storage_dir}`, versioning `{versioning}`,
  public-read `{public_read}`, webdav `{webdav_enabled}`; POST reprocess.
- Credentials: GET/POST /buckets/{b}/credentials (`{name, permission}`); DELETE
  /credentials/{accessKey}.
- Lifecycle: GET/POST /buckets/{b}/lifecycle; PUT/DELETE …/lifecycle/{id};
  DELETE …/lifecycle[?prefix=].
- Webhooks: GET/POST /buckets/{b}/webhooks; PUT/DELETE /webhooks/{id}; GET
  /webhooks/{id}/deliveries?limit=50; POST /webhooks/{id}/test.
- Objects: GET …/objects?prefix&delimiter=/&max-keys=500&marker; GET
  …/search?q&prefix&max-keys&marker; DELETE …/objects/{key…}[?versionId]; POST
  …/objects/delete-prefix; PUT/GET/HEAD …/object?key (upload raw body; download
  with versionId, inline, Range); GET …/object/info; PUT …/object/meta; POST
  …/objects/copy, …/objects/copy-prefix; GET …/prefix-stats; GET …/versions.
- Multipart: POST …/uploads?key; GET …/uploads; DELETE
  …/uploads[?older_than_days]; DELETE …/uploads/{id}; GET …/uploads/{id}/parts;
  PUT …/uploads/{id}/parts/{n}; POST …/uploads/{id}/complete. 3 concurrent
  transfers; multipart above 64 MB, part = max(16 MB, size/9000); without
  multipart > 5 GB is refused; failed uploads resume with uploaded parts; cancel
  aborts on the server.
- Admins: GET/POST /admins; PUT /admins/{u}/password; DELETE /admins/{u}.
- Server tools: GET /sessions, DELETE /sessions/{id}; GET
  /logs?since_id&level&q&limit=500; GET /metrics; POST /maintenance/scan, POST
  /maintenance/orphan-dirs/delete `{paths}`; GET /config.
- Features: object-download, object-upload, object-versions, object-info,
  object-range, object-copy, object-search, prefix-stats, object-metadata,
  multipart, lifecycle-v2, webhooks-v2, maintenance, sessions, logs, config,
  metrics. Empty set (old server): callouts; upload/download/preview/rename/
  copy/search/metadata hidden; server pages hidden; lifecycle v1; webhooks
  without edit/test/history; share and delete still work.

## 5. Platform and packaging

- Open file / show in folder / open URL per OS; notifications; taskbar progress.
- Ids: 2.0 used `com.onaonbir.cloodsys3` (macOS/Linux) and
  `com.onaonbir.cloodsys3gui` (MSIX). Binary `cloodsy-s3`. macOS network client +
  user-selected files.
- 3.0 packaging replaces MSIX, zip, snap and the GitHub workflow: our own
  Windows setup, macOS dmg + update archive, Linux AppImage + deb, built and
  published locally.

## 6. Tests to carry over

Format helpers; API client (encoding, errors, 401, transport, empty put);
presigner (AWS SigV4 example, path-style); status models (old vs v2);
navigation history; session (login, wrong password, token reuse, own password
change, silent renewal); i18n (fallback, placeholders kept in every TR string);
multipart (split/reassemble, resume); objects (pagination, folders and marker
hiding, filter, create folder). UI flows: connect → dashboard, theme incl.
System, narrow layout, Turkish keeps state, Ctrl+K, bucket tabs and files.

## 7. Behaviour to keep

No telemetry (only the configured servers and the two GitHub checks). Stale
responses dropped by request sequence. Transfer progress throttled (~10 fps);
per item Waiting / x of y / Uploaded or Saved / error / Cancelled, Cancel,
Retry / "Resume ({n} parts)", Open, Show in folder; Cancel all, Clear; all
cancelled when the session ends. Bytes in 1024 units; relative times (translate
in 3.0); content-type guessing table `lib/core/format.dart:126-169`.
