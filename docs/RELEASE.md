# Releasing Cloodsy S3 GUI

Releases are built and signed on our own machines with one script; there is no CI. The packages go
to a **draft** GitHub release on `onaonbir/Cloodsy-S3-GUI`, and a person publishes it on GitHub.
The app updates itself from the latest published release (Tauri's updater, `latest.json`).

## What a release is

Everything lands in `dist-release/` (ignored by git):

| File | What |
|---|---|
| `cloodsy-s3-gui-<version>-windows-x64-setup.exe` (+ `.sig`) | our own setup (`installer/README.md`): first install and the Windows update |
| `cloodsy-s3-gui-<version>-linux-x64.AppImage` (+ `.sig`) | Linux, also the Linux update |
| `cloodsy-s3-gui-<version>-linux-x64.deb` (+ `.sig` if the bundler signs it) | Debian/Ubuntu |
| `cloodsy-s3-gui-<version>-macos-{arm64,x64}.dmg` | first install on a Mac (Apple Silicon, Intel) |
| `cloodsy-s3-gui-<version>-macos-{arm64,x64}.app.tar.gz` (+ `.sig`) | the Mac update |
| `latest.json` | what the updater reads (below) |
| `SHA256SUMS.txt` | the SHA-256 of every package and signature (`sha256sum -c SHA256SUMS.txt`) |

A `.sig` is the package's minisign signature with the updater key; the app checks it against the
public key in `src-tauri/tauri.conf.json` (`plugins.updater.pubkey`) before it installs anything.

### latest.json

The updater asks `https://github.com/onaonbir/Cloodsy-S3-GUI/releases/latest/download/latest.json`
(`plugins.updater.endpoints`). GitHub serves it from the newest *published* release, so drafts and
pre-releases are invisible to installed apps.

```json
{
  "version": "3.0.0",
  "notes": "…CHANGELOG.md's section for 3.0.0…",
  "pub_date": "2026-11-25T12:00:00Z",
  "platforms": {
    "windows-x86_64": { "signature": "<the .sig file's content>", "url": "https://github.com/onaonbir/Cloodsy-S3-GUI/releases/download/v3.0.0/cloodsy-s3-gui-3.0.0-windows-x64-setup.exe" },
    "linux-x86_64":   { "signature": "…", "url": "…/cloodsy-s3-gui-3.0.0-linux-x64.AppImage" },
    "darwin-aarch64": { "signature": "…", "url": "…/cloodsy-s3-gui-3.0.0-macos-arm64.app.tar.gz" },
    "darwin-x86_64":  { "signature": "…", "url": "…/cloodsy-s3-gui-3.0.0-macos-x64.app.tar.gz" }
  }
}
```

Only the platforms built in that run are listed (`linux-x86_64-deb` too when the `.deb` is signed).
The notes are `CHANGELOG.md`'s `## [<version>]` section, or `## [Unreleased]` when there is none.
On Windows the updater runs the setup with `/P /UPDATE /R` (`windows.installMode: passive`).

## The updater key

It is not in this repository (the repository is public) and never goes to GitHub, WSL's disk or
the Mac's disk. It is a Tauri/minisign key with an empty password, kept outside the repository on
the release PC; `$env:CLOODSY_S3_GUI_UPDATER_KEY` gives its path.

A lost key means installed apps cannot be updated any more (a new key needs a manual reinstall),
so keep an encrypted copy of it off this disk. `release.ps1` reads it and hands it to WSL through an
environment variable (`WSLENV`) and to the Mac over SSH on stdin.

### This machine's settings

`tool/release.local.ps1` (ignored by git) sets the release PC's values; copy
`tool/release.local.example.ps1` to start one:

| Variable | What |
|---|---|
| `CLOODSY_S3_GUI_UPDATER_KEY` | path of the updater's private key |
| `CLOODSY_S3_GUI_MAC_HOST` | `user@host` of the Mac that builds the macOS packages (`-MacHost` overrides it) |

Environment variables of the same names work as well.

## Prerequisites

**Windows (the release PC)**: PowerShell 7, Rust (MSVC), Node 20.19+/22.12+, WebView2; the secrets
folder; `gh` logged in with write access to the repository (only for `-Publish`); OpenSSH's
`ssh`/`scp` with a key login to the Mac (for `macos`).

**Linux (WSL, Ubuntu 24.04)**: Rust (rustup) and Node from nvm *inside* WSL (the Windows Node on
WSL's PATH does not work), `rsync`, and the Tauri packages:

```bash
sudo apt install build-essential pkg-config libssl-dev libdbus-1-dev libwebkit2gtk-4.1-dev \
  libayatana-appindicator3-dev librsvg2-dev patchelf file
```

`tool/release-linux.sh` builds a copy of the sources in `~/.cache/cloodsy-s3-gui-release-src` with
its own target directory (`~/.cache/cloodsy-s3-gui-target-linux`), so the Windows checkout's
`node_modules/` and `target/` stay as they are. Tauri downloads `linuxdeploy` into `~/.cache/tauri`
on the first AppImage build.

**macOS (`CLOODSY_S3_GUI_MAC_HOST`)**: Xcode (command line tools), Rust (rustup; the script adds
the `aarch64-apple-darwin` and `x86_64-apple-darwin` targets if missing), Node, and a key login from
the release PC (`ssh -o BatchMode=yes <user@host> true` must work without a password).
`release.ps1` copies the working tree (also what is not committed yet) to
`~/Workspace/cloodsy-s3-gui-release/src` (replaced on every build); the packages are built into
`~/Workspace/cloodsy-s3-gui-release/out/<version>/` and copied back. The target directory is
`~/Library/Caches/cloodsy-s3-gui-target-macos`.

Without an Apple Developer ID the Mac app is signed ad hoc and not notarized: macOS warns on first
open (right-click → Open, or System Settings → Privacy & Security → Open Anyway). With an ID, set
`APPLE_SIGNING_IDENTITY` (and Tauri's notarization variables) on the Mac.

## Releasing

1. Raise `version` in `package.json` (the GUI's only version; `tauri.conf.json` reads it) and keep
   `src-tauri/Cargo.toml`'s in step.
2. Move `CHANGELOG.md`'s `[Unreleased]` entries to a `## [<version>] - <date>` section.
3. Build everything and look at the result (nothing is uploaded):

   ```powershell
   pwsh tool/release.ps1                          # windows, linux, macos
   pwsh tool/release.ps1 -Platforms linux,macos   # some of them
   pwsh tool/release.ps1 -Platforms windows -SkipApp   # Windows setup around the existing cloodsy-s3.exe
   ```

   It prints every file with its size and the `gh` commands it would run.
4. Commit, tag `v<version>` and push the tag (`gh` needs the tag on GitHub; or pass
   `-Target <branch or commit>` and gh creates it when the draft is published).
5. Upload to a draft release, without building again:

   ```powershell
   pwsh tool/release.ps1 -SkipBuild -Publish
   ```

   This runs `gh release create v<version> --draft`, uploads the packages, `SHA256SUMS.txt` and,
   last, `latest.json`. An existing draft gets its files replaced; an already published release is
   never touched (raise the version instead).
6. On GitHub, check the draft (notes, files, try a download) and publish it. Only then do installed
   apps see the update.

`-SkipBuild` takes the packages already in `dist-release/` for the platforms given (default all
three) and rewrites `latest.json` and `SHA256SUMS.txt`, so a release can be built in parts and
published once.

`tool/build-windows.ps1` alone builds just the Windows setup (it signs it too when it finds the key).
