# Windows setup

Cloodsy S3 GUI's own setup for Windows, in place of Tauri's NSIS installer.
One exe installs, updates and repairs the GUI; the same exe without its payload is `uninstall.exe`.

| Part | What |
|---|---|
| `pack/` (`cloodsy_s3_gui_pack`, `cloodsy-s3-gui-pack`) | The payload: the GUI's files zstd-compressed and appended to the setup exe, with a list (path, size, SHA-256) and a 64-byte trailer (`CS3GP001`). A later Authenticode signature goes after the trailer and is skipped when reading. |
| `setup/` (`cloodsy_s3_gui_setup`, `cloodsy-s3-gui-setup.exe`) | Tauri 2: the steps (`install.rs`), the Windows parts (`system.rs`: registry, shortcuts, the running app), the window (`ui.rs`), the flags (`args.rs`). |
| `../src-setup/` | The window's page (Vue, the GUI's tokens, fonts and brand mark, English and Turkish by the Windows language). Built with `npm run build:setup` into `dist-setup/`. |

## What it does

- Per user, no administrator: `%LOCALAPPDATA%\Programs\Cloodsy S3 GUI` (`cloodsy-s3.exe`,
  `uninstall.exe`, `licenses\`), a Start menu shortcut, an optional desktop shortcut and the
  "Apps" entry (`HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Cloodsy S3 GUI`,
  `InstallerKind=cloodsy-s3-gui-setup`).
- Modes: install, update, repair (same version), downgrade, uninstall. An update goes to the
  folder the entry names.
- Files are written as `.new`, checked against their SHA-256, then swapped in: a failure leaves
  the installed version as it was. A running GUI is asked to quit (`cloodsy-s3.exe --quit`,
  handed over by the single-instance plugin, `src-tauri/src/lib.rs`) and given 20 seconds.
- Uninstall removes the files it installed (from `installed-files.txt`; the user's own files in
  the folder stay), the shortcuts and the entry. "Also remove my data" deletes
  `%APPDATA%\com.onaonbir.cloodsys3gui` (saved servers, settings) and
  `%LOCALAPPDATA%\com.onaonbir.cloodsys3gui` (the web view's data). Nothing on the servers changes.
- Without WebView2 it offers Microsoft's bootstrapper (checked for Microsoft's signature).
- Log: `%TEMP%\cloodsy-s3-gui-setup.log`.
- An earlier MSIX install (2.x) is a separate package; the setup does not touch it.

## Flags (NSIS style)

| Flag | |
|---|---|
| `/S` | Silent: no window. Exit code 0 done, 1 failed, 3 the setup file is damaged. |
| `/P` | Passive: the window, straight to installing (Tauri's updater runs `/P /UPDATE /R`). |
| `/UPDATE` | Straight to installing. |
| `/R`, `/LAUNCH` | Start Cloodsy S3 GUI after. |
| `/D=<folder>` | The install folder (a fresh install). |
| `/DESKTOP=0\|1` | The desktop shortcut (default: on for a fresh install, as it was for an update). |
| `/UNINSTALL` | Remove (what `uninstall.exe` does without flags). |
| `/WIPE` | With `/UNINSTALL`: also remove the data folders. |
| `/SANDBOX=<folder>` | A trial run, below. |

Unknown flags are ignored. `uninstall.exe` copies itself to `%TEMP%` and runs from there
(`/FROM=<folder>`), so it can remove its own folder.

### `/SANDBOX`: a trial run

`cloodsy-s3-gui-<version>-windows-x64-setup.exe /SANDBOX=C:\setup-trial` installs into
`C:\setup-trial\Programs\Cloodsy S3 GUI`, with the Start menu, desktop and data folders under
`C:\setup-trial` too, and its own entry `Cloodsy S3 GUI (setup trial)` in "Apps" (its uninstall
string carries the same `/SANDBOX`). The running-app check only looks at the trial's own
`cloodsy-s3.exe`, and the GUI is not started after it. Nothing of a real install is touched.
Remove it from "Apps" or with `C:\setup-trial\Programs\Cloodsy S3 GUI\uninstall.exe`.

## Building

On Windows, from the repository:

```powershell
pwsh tool/build-windows.ps1            # -SkipApp reuses target/release/cloodsy-s3.exe
```

It builds the GUI (`npm run tauri build -- --no-bundle`), the page (`npm run build:setup`) and
`cloodsy-s3-gui-setup.exe`, then packs `cloodsy-s3.exe` and the licence texts into
`dist-release/cloodsy-s3-gui-<version>-windows-x64-setup.exe` (the version is `package.json`'s).
The updater signature is not made yet (marked in the script). By hand:

```powershell
npm run build:setup
cargo build --release -p cloodsy_s3_gui_setup --features custom-protocol
cargo run --release -p cloodsy_s3_gui_pack -- target/release/cloodsy-s3-gui-setup.exe out.exe cloodsy-s3-gui 3.0.0 <folder with cloodsy-s3.exe>
```

Tests (the install flow runs in temporary folders with a stand-in for the registry and shortcuts):
`cargo test -p cloodsy_s3_gui_pack -p cloodsy_s3_gui_setup`.

The window in a browser, with a stand-in for the Rust side: `npm run dev:setup`, then
`http://localhost:1441/?mode=install|update|reinstall|downgrade|uninstall&scene=options|done|error`
(`&fail=files` fails a step, `&trial` shows the trial note, `&auto` starts at once like `/P`).
