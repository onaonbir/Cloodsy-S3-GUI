//! Cloodsy S3 GUI's Windows setup: one exe that installs, updates and
//! (without its payload, as `uninstall.exe`) removes the app. Its window is a
//! page in the GUI's look (Vue in WebView2, src-setup/). installer/README.md.
//!
//! Per user, no administrator: %LOCALAPPDATA%\Programs\Cloodsy S3 GUI, the
//! current user's registry and shortcuts.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod args;
mod install;
mod system;
mod ui;

use std::io::Write;
use std::path::Path;

use cloodsy_s3_gui_pack::Payload;
use install::{Existing, Options, System};

/// Exit codes (as NSIS's callers expect): 0 done, 1 failed, 3 the payload is broken.
pub const EXIT_FAILED: i32 = 1;
pub const EXIT_PAYLOAD: i32 = 3;

pub fn log(line: &str) {
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(system::log_path()) {
        let _ = writeln!(f, "{} {line}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0));
    }
}

/// The text in the system language (only the message boxes need it here).
fn say(en: &str, tr: &str) -> String {
    if system::turkish() { tr.into() } else { en.into() }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Install,
    Update,
    Reinstall,
    Downgrade,
    Uninstall,
}

fn mode_for(payload_version: &str, existing: Option<&Existing>) -> Mode {
    let parts = |v: &str| -> Option<Vec<u64>> { v.split(['.', '-', '+']).take(3).map(|p| p.parse().ok()).collect() };
    match existing {
        None => Mode::Install,
        Some(e) => match (parts(payload_version), parts(&e.version)) {
            (Some(a), Some(b)) if a > b => Mode::Update,
            (Some(a), Some(b)) if a == b => Mode::Reinstall,
            (Some(_), Some(_)) => Mode::Downgrade,
            _ => Mode::Update,
        },
    }
}

/// The exe's bytes before its payload: the uninstaller.
fn stub_bytes(exe: &Path, payload: &Payload) -> Result<Vec<u8>, String> {
    let bytes = std::fs::read(exe).map_err(|e| e.to_string())?;
    let end = payload.list.files.iter().map(|f| f.offset).min().unwrap_or(bytes.len() as u64) as usize;
    Ok(bytes[..end.min(bytes.len())].to_vec())
}

/// Without WebView2 the window cannot open: offer Microsoft's own installer.
fn ensure_webview2() -> bool {
    if system::webview2() {
        return true;
    }
    if !system::message(
        &say(
            "The setup window needs Microsoft WebView2 (Windows 11 has it).\n\nDownload and install it from Microsoft now?",
            "Kurulum penceresi için Microsoft WebView2 gerekiyor (Windows 11'de hazırdır).\n\nMicrosoft'tan indirilip kurulsun mu?",
        ),
        true,
    ) {
        return false;
    }
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        let file = std::env::temp_dir().join("MicrosoftEdgeWebview2Setup.exe");
        // curl ships with Windows 10 and 11; the file must carry Microsoft's signature.
        let script = format!(
            "$ErrorActionPreference='Stop'; curl.exe -fsSL -o '{f}' 'https://go.microsoft.com/fwlink/p/?LinkId=2124703'; $s=Get-AuthenticodeSignature '{f}'; if ($s.Status -ne 'Valid' -or $s.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {{ exit 9 }}; $p=Start-Process '{f}' -ArgumentList '/silent','/install' -Wait -PassThru; exit $p.ExitCode",
            f = file.display()
        );
        let ok = std::process::Command::new("powershell").args(["-NoProfile", "-NonInteractive", "-Command", &script]).creation_flags(0x0800_0000).status().is_ok_and(|s| s.success());
        let _ = std::fs::remove_file(&file);
        if ok && system::webview2() {
            return true;
        }
        system::message(&say("WebView2 could not be installed. Check the internet connection and open the setup again.", "WebView2 kurulamadı. İnternet bağlantınızı denetleyip kurulumu yeniden açın."), false);
    }
    false
}

fn main() {
    let args = args::parse(std::env::args().skip(1));
    let exe = std::env::current_exe().unwrap_or_default();
    let sandbox = args.sandbox.clone();
    let payload = match Payload::open(&exe) {
        Ok(p) => p,
        Err(e) => {
            log(&format!("cannot read the setup file: {e}"));
            system::message(&say("The setup file cannot be read. Download it again.", "Kurulum dosyası okunamadı. Yeniden indirin."), false);
            std::process::exit(EXIT_PAYLOAD);
        }
    };
    let sys = system::Machine { sandbox: sandbox.is_some() };

    // Removing (the payload-less uninstall.exe, or /UNINSTALL).
    if payload.is_none() || args.uninstall {
        let dir = args.from.clone().or_else(|| exe.parent().map(Path::to_path_buf)).unwrap_or_default();
        // An exe cannot delete itself: a temporary copy does the work.
        if args.from.is_none() {
            let copy = std::env::temp_dir().join(format!("cloodsy-s3-gui-uninstall-{}.exe", std::process::id()));
            if std::fs::copy(&exe, &copy).is_ok() {
                let mut pass = vec!["/UNINSTALL".to_string(), format!("/FROM={}", dir.display())];
                if args.silent {
                    pass.push("/S".into());
                }
                if args.wipe {
                    pass.push("/WIPE".into());
                }
                pass.extend(args.sandbox_arg());
                if system::spawn(&copy, &pass).is_ok() {
                    return;
                }
            }
        }
        let paths = system::paths(dir, sandbox.as_deref());
        if args.silent {
            let code = match install::uninstall(&paths, args.wipe, &sys, &mut |s| log(&format!("{:?} {:?} {}", s.id, s.state, s.detail))) {
                Ok(()) => 0,
                Err(f) => {
                    log(&format!("uninstall: {} ({})", f.message, f.detail));
                    EXIT_FAILED
                }
            };
            system::delete_later(&exe);
            std::process::exit(code);
        }
        if !ensure_webview2() {
            std::process::exit(EXIT_FAILED);
        }
        ui::run(ui::Context { mode: Mode::Uninstall, args, exe, payload: None, stub: Vec::new(), paths, existing: None, version: String::new(), sys });
        return;
    }

    let mut payload = payload.expect("payload");
    let existing = sys.existing();
    let dir = args.dir.clone().or_else(|| existing.as_ref().map(|e| e.dir.clone())).unwrap_or_else(|| system::default_dir(sandbox.as_deref()));
    let paths = system::paths(dir, sandbox.as_deref());
    let stub = match stub_bytes(&exe, &payload) {
        Ok(s) => s,
        Err(e) => {
            log(&format!("cannot read the setup file: {e}"));
            std::process::exit(EXIT_PAYLOAD);
        }
    };
    let mode = mode_for(&payload.list.version, existing.as_ref());
    log(&format!("setup {} -> {} ({mode:?}, {}{})", existing.as_ref().map(|e| e.version.as_str()).unwrap_or("none"), payload.list.version, paths.install.display(), if sandbox.is_some() { ", trial" } else { "" }));

    if args.silent {
        let desktop = args.desktop.unwrap_or_else(|| existing.is_none() || paths.desktop.as_ref().is_some_and(|d| d.join(install::Paths::shortcut_name()).exists()));
        let code = match install::install(&mut payload, &stub, &paths, Options { desktop }, &sys, &mut |s| log(&format!("{:?} {:?} {}", s.id, s.state, s.detail))) {
            Ok(()) => {
                if args.launch && args.sandbox.is_none() {
                    let _ = system::spawn(&paths.install.join(install::MAIN_EXE), &[]);
                }
                0
            }
            Err(f) => {
                log(&format!("setup: {} ({})", f.message, f.detail));
                EXIT_FAILED
            }
        };
        std::process::exit(code);
    }
    if !ensure_webview2() {
        std::process::exit(EXIT_FAILED);
    }
    let version = payload.list.version.clone();
    ui::run(ui::Context { mode, args, exe, payload: Some(payload), stub, paths, existing, version, sys });
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn modes_follow_the_installed_version() {
        let e = |v: &str| Existing { dir: PathBuf::from("x"), version: v.into() };
        assert_eq!(mode_for("3.0.1", None), Mode::Install);
        assert_eq!(mode_for("3.0.1", Some(&e("3.0.0"))), Mode::Update);
        assert_eq!(mode_for("3.0.1", Some(&e("3.0.1"))), Mode::Reinstall);
        assert_eq!(mode_for("3.0.1", Some(&e("3.1.0"))), Mode::Downgrade);
        assert_eq!(mode_for("3.10.0", Some(&e("3.9.2"))), Mode::Update);
        // An entry whose version cannot be read: an update.
        assert_eq!(mode_for("3.0.1", Some(&e(""))), Mode::Update);
    }

    #[test]
    fn the_uninstaller_is_the_exe_without_its_payload() {
        let dir = std::env::temp_dir().join(format!("cloodsy-s3-gui-stub-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let stub = dir.join("stub.exe");
        std::fs::write(&stub, b"MZ the setup itself").unwrap();
        let app = dir.join("app.bin");
        std::fs::write(&app, b"app").unwrap();
        let out = dir.join("setup.exe");
        cloodsy_s3_gui_pack::build(&stub, &[(install::MAIN_EXE.into(), app)], "cloodsy-s3-gui", "3.0.0", &out).unwrap();
        let payload = Payload::open(&out).unwrap().unwrap();
        assert_eq!(stub_bytes(&out, &payload).unwrap(), b"MZ the setup itself");
        std::fs::remove_dir_all(dir).ok();
    }
}
