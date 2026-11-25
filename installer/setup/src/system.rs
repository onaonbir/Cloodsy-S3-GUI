//! The machine: where things go, and the Windows parts (registry, shortcuts,
//! processes). Elsewhere a stand-in lets the setup build and be tried.
//!
//! A trial run (`/SANDBOX=<folder>`) puts every folder under <folder> and uses
//! its own registry entry, so it never touches a real install.

use std::path::{Path, PathBuf};

#[cfg(windows)]
use crate::install::{MAIN_EXE, PUBLISHER, UNINSTALLER};
use crate::install::{Existing, Paths, Registration, System, PRODUCT_NAME};

#[cfg_attr(not(windows), allow(dead_code))]
const UNINSTALL_KEY: &str = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\Cloodsy S3 GUI";
#[cfg_attr(not(windows), allow(dead_code))]
const TRIAL_UNINSTALL_KEY: &str = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\Cloodsy S3 GUI (setup trial)";
/// The GUI's identifier (src-tauri/tauri.conf.json): its data folders.
const APP_ID: &str = "com.onaonbir.cloodsys3gui";
/// Our registry marker: an entry this setup wrote.
#[cfg_attr(not(windows), allow(dead_code))]
const KIND: &str = "cloodsy-s3-gui-setup";

/// The default folder: per user, no administrator needed.
pub fn default_dir(sandbox: Option<&Path>) -> PathBuf {
    match sandbox {
        Some(s) => s.join("Programs").join(PRODUCT_NAME),
        None => dirs::data_local_dir().unwrap_or_else(std::env::temp_dir).join("Programs").join(PRODUCT_NAME),
    }
}

pub fn paths(install: PathBuf, sandbox: Option<&Path>) -> Paths {
    if let Some(s) = sandbox {
        return Paths {
            install,
            start_menu: Some(s.join("Start Menu")),
            desktop: Some(s.join("Desktop")),
            data: vec![s.join("Roaming").join(APP_ID), s.join("Local").join(APP_ID)],
        };
    }
    Paths {
        install,
        start_menu: dirs::data_dir().map(|d| d.join(r"Microsoft\Windows\Start Menu\Programs")),
        desktop: dirs::desktop_dir(),
        data: [dirs::data_dir(), dirs::data_local_dir()].into_iter().flatten().map(|d| d.join(APP_ID)).collect(),
    }
}

pub fn log_path() -> PathBuf {
    std::env::temp_dir().join("cloodsy-s3-gui-setup.log")
}

/// This machine; in a trial run, the trial's own registry entry.
pub struct Machine {
    pub sandbox: bool,
}

#[cfg(windows)]
mod imp {
    use super::*;
    use std::os::windows::process::CommandExt;
    use winreg::enums::{HKEY_CURRENT_USER, KEY_READ};
    use winreg::RegKey;

    const NO_WINDOW: u32 = 0x0800_0000;

    fn hkcu() -> RegKey {
        RegKey::predef(HKEY_CURRENT_USER)
    }

    impl Machine {
        fn uninstall_key(&self) -> &'static str {
            if self.sandbox { TRIAL_UNINSTALL_KEY } else { UNINSTALL_KEY }
        }
    }

    /// The full paths of the running processes named cloodsy-s3.exe.
    fn running_paths() -> Vec<PathBuf> {
        use windows_sys::Win32::Foundation::{CloseHandle, INVALID_HANDLE_VALUE};
        use windows_sys::Win32::System::Diagnostics::ToolHelp::{CreateToolhelp32Snapshot, Process32FirstW, Process32NextW, PROCESSENTRY32W, TH32CS_SNAPPROCESS};
        use windows_sys::Win32::System::Threading::{OpenProcess, QueryFullProcessImageNameW, PROCESS_NAME_WIN32, PROCESS_QUERY_LIMITED_INFORMATION};
        let mut out = Vec::new();
        unsafe {
            let snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
            if snap == INVALID_HANDLE_VALUE {
                return out;
            }
            let mut entry: PROCESSENTRY32W = std::mem::zeroed();
            entry.dwSize = std::mem::size_of::<PROCESSENTRY32W>() as u32;
            let mut ok = Process32FirstW(snap, &mut entry) != 0;
            while ok {
                let len = entry.szExeFile.iter().position(|c| *c == 0).unwrap_or(entry.szExeFile.len());
                if String::from_utf16_lossy(&entry.szExeFile[..len]).eq_ignore_ascii_case(MAIN_EXE) {
                    let h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, entry.th32ProcessID);
                    if !h.is_null() {
                        let mut buf = [0u16; 1024];
                        let mut size = buf.len() as u32;
                        if QueryFullProcessImageNameW(h, PROCESS_NAME_WIN32, buf.as_mut_ptr(), &mut size) != 0 {
                            out.push(PathBuf::from(String::from_utf16_lossy(&buf[..size as usize])));
                        }
                        CloseHandle(h);
                    }
                }
                ok = Process32NextW(snap, &mut entry) != 0;
            }
            CloseHandle(snap);
        }
        out
    }

    fn same_path(a: &Path, b: &Path) -> bool {
        let norm = |p: &Path| p.to_string_lossy().replace('/', "\\").trim_end_matches('\\').to_lowercase();
        norm(a) == norm(b)
    }

    impl System for Machine {
        fn existing(&self) -> Option<Existing> {
            let key = hkcu().open_subkey_with_flags(self.uninstall_key(), KEY_READ).ok()?;
            let dir: String = key.get_value("InstallLocation").ok()?;
            let dir = PathBuf::from(dir.trim().trim_matches('"'));
            let version: String = key.get_value("DisplayVersion").unwrap_or_default();
            dir.join(MAIN_EXE).exists().then_some(Existing { dir, version })
        }

        fn running(&self, exe: &Path) -> bool {
            running_paths().iter().any(|p| same_path(p, exe))
        }

        fn ask_quit(&self, exe: &Path) {
            // The GUI's single-instance plugin hands "--quit" to the running copy.
            let _ = std::process::Command::new(exe).arg("--quit").creation_flags(NO_WINDOW).spawn();
        }

        fn shortcut(&self, target: &Path, lnk: &Path) -> Result<(), String> {
            // The Start menu folder, or a desktop that does not exist yet (a
            // fresh profile, the /SANDBOX trial): made first.
            if let Some(dir) = lnk.parent() {
                std::fs::create_dir_all(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
            }
            let mut link = mslnk::ShellLink::new(target).map_err(|e| e.to_string())?;
            link.set_working_dir(target.parent().map(|p| p.to_string_lossy().into_owned()));
            link.create_lnk(lnk).map_err(|e| format!("{}: {e}", lnk.display()))
        }

        fn register(&self, r: &Registration) -> Result<(), String> {
            let (key, _) = hkcu().create_subkey(self.uninstall_key()).map_err(|e| e.to_string())?;
            let exe = r.dir.join(MAIN_EXE);
            let uninst = r.dir.join(UNINSTALLER);
            let set = |name: &str, value: String| key.set_value(name, &value).map_err(|e| e.to_string());
            set("DisplayName", if self.sandbox { format!("{PRODUCT_NAME} (setup trial)") } else { PRODUCT_NAME.into() })?;
            set("DisplayVersion", r.version.clone())?;
            set("Publisher", PUBLISHER.into())?;
            set("DisplayIcon", format!("\"{}\"", exe.display()))?;
            set("InstallLocation", r.dir.display().to_string())?;
            let trial = if self.sandbox { format!(" /SANDBOX=\"{}\"", r.dir.parent().and_then(Path::parent).unwrap_or(&r.dir).display()) } else { String::new() };
            set("UninstallString", format!("\"{}\"{trial}", uninst.display()))?;
            set("QuietUninstallString", format!("\"{}\" /S{trial}", uninst.display()))?;
            set("URLInfoAbout", "https://github.com/onaonbir/Cloodsy-S3-GUI".into())?;
            set("InstallerKind", KIND.into())?;
            key.set_value("NoModify", &1u32).map_err(|e| e.to_string())?;
            key.set_value("NoRepair", &1u32).map_err(|e| e.to_string())?;
            key.set_value("EstimatedSize", &(r.size_kb.min(u32::MAX as u64) as u32)).map_err(|e| e.to_string())
        }

        fn unregister(&self) {
            let _ = hkcu().delete_subkey_all(self.uninstall_key());
        }
    }

    /// The UI language is Turkish (the window follows the browser's; this is
    /// for the plain message boxes before it).
    pub fn turkish() -> bool {
        use windows_sys::Win32::Globalization::GetUserDefaultUILanguage;
        unsafe { GetUserDefaultUILanguage() & 0x3ff == 0x1f }
    }

    /// A plain Windows message box (before or without the web view).
    pub fn message(text: &str, ask: bool) -> bool {
        use windows_sys::Win32::UI::WindowsAndMessaging::{MessageBoxW, IDYES, MB_ICONINFORMATION, MB_ICONQUESTION, MB_OK, MB_YESNO};
        let wide = |s: &str| s.encode_utf16().chain(Some(0)).collect::<Vec<u16>>();
        let (t, c) = (wide(text), wide(if turkish() { "Cloodsy S3 GUI Kurulum" } else { "Cloodsy S3 GUI Setup" }));
        let flags = if ask { MB_YESNO | MB_ICONQUESTION } else { MB_OK | MB_ICONINFORMATION };
        unsafe { MessageBoxW(std::ptr::null_mut(), t.as_ptr(), c.as_ptr(), flags) == IDYES }
    }

    /// Whether the WebView2 runtime (the window's engine) is there.
    pub fn webview2() -> bool {
        use winreg::enums::HKEY_LOCAL_MACHINE;
        const CLIENT: &str = r"Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}";
        let has = |root: RegKey, path: String| root.open_subkey_with_flags(path, KEY_READ).and_then(|k| k.get_value::<String, _>("pv")).is_ok_and(|v| !v.is_empty() && v != "0.0.0.0");
        has(RegKey::predef(HKEY_LOCAL_MACHINE), format!(r"SOFTWARE\WOW6432Node\{CLIENT}")) || has(RegKey::predef(HKEY_LOCAL_MACHINE), format!(r"SOFTWARE\{CLIENT}")) || has(hkcu(), format!(r"Software\{CLIENT}"))
    }

    /// Removes a temporary uninstaller copy once it has exited.
    pub fn delete_later(path: &Path) {
        let cmd = format!("ping 127.0.0.1 -n 3 > nul & del /f /q \"{}\"", path.display());
        let _ = std::process::Command::new("cmd").args(["/C", &cmd]).creation_flags(NO_WINDOW).spawn();
    }

    pub fn spawn(exe: &Path, args: &[String]) -> std::io::Result<()> {
        std::process::Command::new(exe).args(args).spawn().map(|_| ())
    }
}

#[cfg(not(windows))]
mod imp {
    use super::*;

    /// A stand-in so the setup builds and its window can be tried off Windows.
    impl System for Machine {
        fn existing(&self) -> Option<Existing> {
            None
        }
        fn running(&self, _exe: &Path) -> bool {
            false
        }
        fn ask_quit(&self, _exe: &Path) {}
        fn shortcut(&self, _target: &Path, lnk: &Path) -> Result<(), String> {
            std::fs::write(lnk, b"").map_err(|e| e.to_string())
        }
        fn register(&self, _r: &Registration) -> Result<(), String> {
            Ok(())
        }
        fn unregister(&self) {}
    }

    pub fn turkish() -> bool {
        std::env::var("LANG").is_ok_and(|l| l.starts_with("tr"))
    }

    pub fn message(text: &str, _ask: bool) -> bool {
        eprintln!("{text}");
        false
    }

    pub fn webview2() -> bool {
        true
    }

    pub fn delete_later(_path: &Path) {}

    pub fn spawn(exe: &Path, args: &[String]) -> std::io::Result<()> {
        std::process::Command::new(exe).args(args).spawn().map(|_| ())
    }
}

pub use imp::{delete_later, message, spawn, turkish, webview2};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_trial_keeps_everything_under_its_folder() {
        let s = Path::new(r"C:\trial");
        let p = paths(default_dir(Some(s)), Some(s));
        assert_eq!(p.install, s.join("Programs").join("Cloodsy S3 GUI"));
        assert!(p.start_menu.iter().chain(p.desktop.iter()).chain(p.data.iter()).all(|d| d.starts_with(s)));
        assert_eq!(p.data.len(), 2);
        assert!(p.data.iter().all(|d| d.ends_with("com.onaonbir.cloodsys3gui")));
    }
}
