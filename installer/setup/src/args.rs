//! Command-line flags, NSIS-style, so scripts and Tauri's updater work:
//!
//! `/S` silent · `/P` passive (the window, straight to installing; Tauri's
//! updater passes `/P /UPDATE /R`) · `/UPDATE` straight to installing ·
//! `/LAUNCH` (or `/R`) start Cloodsy S3 GUI after · `/D=<folder>` ·
//! `/DESKTOP=0|1` · `/UNINSTALL` · `/WIPE` (the app's data too).
//! `/FROM=<folder>`: the uninstaller's temporary copy, the folder it removes.
//! `/SANDBOX=<folder>`: a trial run where every folder and the registry
//! entry live under <folder>, apart from a real install (installer/README.md).
//! Unknown flags are ignored.

use std::path::PathBuf;

#[derive(Debug, Default, Clone, PartialEq)]
pub struct Args {
    pub silent: bool,
    pub update: bool,
    pub launch: bool,
    pub uninstall: bool,
    pub wipe: bool,
    pub dir: Option<PathBuf>,
    pub from: Option<PathBuf>,
    pub desktop: Option<bool>,
    pub sandbox: Option<PathBuf>,
}

impl Args {
    /// The flags a copy of this setup (the uninstaller's) passes on.
    pub fn sandbox_arg(&self) -> Option<String> {
        self.sandbox.as_ref().map(|s| format!("/SANDBOX={}", s.display()))
    }
}

pub fn parse<I: IntoIterator<Item = String>>(args: I) -> Args {
    let mut a = Args::default();
    let flag = |v: &str| matches!(v.to_ascii_lowercase().as_str(), "1" | "true" | "yes" | "evet");
    for raw in args {
        let upper = raw.to_ascii_uppercase();
        let value = || raw.split_once('=').map(|(_, v)| v.trim_matches('"').to_string()).unwrap_or_default();
        match upper.split('=').next().unwrap_or("") {
            "/S" => a.silent = true,
            "/P" | "/UPDATE" => a.update = true,
            "/LAUNCH" | "/R" => a.launch = true,
            "/UNINSTALL" => a.uninstall = true,
            "/WIPE" => a.wipe = true,
            "/D" if !value().is_empty() => a.dir = Some(PathBuf::from(value())),
            "/FROM" if !value().is_empty() => a.from = Some(PathBuf::from(value())),
            "/DESKTOP" => a.desktop = Some(flag(&value())),
            "/SANDBOX" if !value().is_empty() => a.sandbox = Some(PathBuf::from(value())),
            _ => {}
        }
    }
    a
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_nsis_style_flags() {
        let a = parse(["/S", "/UPDATE", "/R", r"/D=C:\Programs\Cloodsy S3 GUI", "/desktop=0"].map(String::from));
        assert!(a.silent && a.update && a.launch && !a.uninstall);
        assert_eq!(a.dir, Some(PathBuf::from(r"C:\Programs\Cloodsy S3 GUI")));
        assert_eq!(a.desktop, Some(false));
        assert_eq!(parse(["/UNINSTALL", "/WIPE", "/FROM=C:\\x"].map(String::from)).from, Some(PathBuf::from("C:\\x")));
        // Tauri's updater: passive window, straight to installing, restart after.
        let t = parse(["/P", "/UPDATE", "/R"].map(String::from));
        assert!(t.update && t.launch && !t.silent && !t.uninstall);
        // Unknown flags are ignored.
        assert_eq!(parse(["/AUTOSTART=1", "/NS"].map(String::from)), Args::default());
        assert_eq!(parse([r#"/SANDBOX="C:\t s""#.to_string()]).sandbox, Some(PathBuf::from(r"C:\t s")));
    }
}
