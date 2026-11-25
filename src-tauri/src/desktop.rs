//! Desktop helpers: walking dropped or picked folders, the preview folder and
//! mapping a server's disk path to one this machine can open.

use std::path::{Path, PathBuf};

use serde::Serialize;

#[derive(Serialize, Debug, PartialEq)]
pub struct LocalFile {
    pub path: String,
    /// Relative to the picked item's parent, with `/` (the object key suffix).
    pub rel: String,
    pub size: u64,
}

/// Files under the given paths (folders recursively). Each file's `rel` keeps
/// the dropped folder's own name: dropping `C:\a\photos` gives `photos/x.jpg`.
pub fn walk(paths: &[String]) -> Vec<LocalFile> {
    let mut out = Vec::new();
    for p in paths {
        let p = PathBuf::from(p);
        let root = p.parent().map(Path::to_path_buf).unwrap_or_default();
        collect(&p, &root, &mut out);
    }
    out
}

fn collect(p: &Path, root: &Path, out: &mut Vec<LocalFile>) {
    let Ok(meta) = std::fs::symlink_metadata(p) else { return };
    if meta.file_type().is_symlink() {
        // Followed only when it points at a file (no loops through folders).
        if let Ok(m) = std::fs::metadata(p) {
            if m.is_file() {
                push(p, root, m.len(), out);
            }
        }
        return;
    }
    if meta.is_dir() {
        let Ok(rd) = std::fs::read_dir(p) else { return };
        let mut entries: Vec<_> = rd.flatten().map(|e| e.path()).collect();
        entries.sort();
        for e in entries {
            collect(&e, root, out);
        }
    } else if meta.is_file() {
        push(p, root, meta.len(), out);
    }
}

fn push(p: &Path, root: &Path, size: u64, out: &mut Vec<LocalFile>) {
    let rel = p.strip_prefix(root).unwrap_or(p);
    let rel = rel.components().map(|c| c.as_os_str().to_string_lossy().into_owned()).collect::<Vec<_>>().join("/");
    out.push(LocalFile { path: p.display().to_string(), rel, size });
}

/// `<temp>/cloodsy-preview/<name>` for "Open with default app".
pub fn preview_path(name: &str) -> Result<String, String> {
    let safe: String = name.chars().map(|c| if matches!(c, '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|') { '_' } else { c }).collect();
    let safe = if safe.trim().is_empty() || safe == "." || safe == ".." { "file".to_string() } else { safe };
    let dir = std::env::temp_dir().join("cloodsy-preview");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join(safe).display().to_string())
}

fn local_hostname() -> String {
    std::env::var("COMPUTERNAME")
        .or_else(|_| std::env::var("HOSTNAME"))
        .ok()
        .or_else(|| std::fs::read_to_string("/etc/hostname").ok())
        .unwrap_or_default()
        .trim()
        .to_lowercase()
}

fn is_loopback(host: &str) -> bool {
    let h = host.trim_start_matches('[').trim_end_matches(']').to_lowercase();
    h == "localhost" || h == "::1" || h.starts_with("127.")
}

/// A WSL NAT address (172.16.0.0/12).
fn is_wsl_nat(host: &str) -> bool {
    let mut it = host.split('.');
    matches!((it.next(), it.next().and_then(|s| s.parse::<u8>().ok())), (Some("172"), Some(16..=31)))
}

/// Maps a disk path on the server to one this machine can open, when the
/// server runs here (or in this PC's WSL).
pub fn local_path(server_url: &str, host_os: &str, hostname: &str, wsl_distro: &str, path: &str) -> Option<String> {
    let host = url::Url::parse(server_url).ok()?.host_str()?.to_string();
    if cfg!(windows) && !wsl_distro.is_empty() && (is_loopback(&host) || is_wsl_nat(&host) || host.ends_with(".local")) {
        return Some(format!(r"\\wsl.localhost\{wsl_distro}{}", path.replace('/', "\\")));
    }
    let same_os = host_os.eq_ignore_ascii_case(std::env::consts::OS);
    let same_host = is_loopback(&host) || (!hostname.is_empty() && hostname.eq_ignore_ascii_case(&local_hostname()));
    (same_os && same_host).then(|| path.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn walk_keeps_the_dropped_folder_name() {
        let d = tempfile::tempdir().unwrap();
        let photos = d.path().join("photos");
        std::fs::create_dir_all(photos.join("2026")).unwrap();
        std::fs::write(photos.join("a.jpg"), b"12").unwrap();
        std::fs::write(photos.join("2026").join("b.jpg"), b"345").unwrap();
        std::fs::write(d.path().join("single.txt"), b"x").unwrap();
        let files = walk(&[photos.display().to_string(), d.path().join("single.txt").display().to_string()]);
        let rels: Vec<_> = files.iter().map(|f| (f.rel.as_str(), f.size)).collect();
        assert_eq!(rels, vec![("photos/2026/b.jpg", 3), ("photos/a.jpg", 2), ("single.txt", 1)]);
    }

    #[test]
    fn maps_wsl_and_local_paths() {
        if cfg!(windows) {
            assert_eq!(
                local_path("http://localhost:9001", "linux", "x", "ubuntu", "/home/u/data/b").as_deref(),
                Some(r"\\wsl.localhost\ubuntu\home\u\data\b")
            );
            assert_eq!(local_path("http://172.22.177.157:9001", "linux", "x", "ubuntu", "/d").as_deref(), Some(r"\\wsl.localhost\ubuntu\d"));
        }
        assert_eq!(local_path("http://s3-admin.example.net", "linux", "nas", "", "/opt/x"), None);
        assert_eq!(local_path("http://127.0.0.1:9001", std::env::consts::OS, "", "", "/srv/x").as_deref(), Some("/srv/x"));
    }

    #[test]
    fn preview_names_are_safe() {
        assert!(preview_path("../a/b:c.txt").unwrap().ends_with(".._a_b_c.txt"));
        assert!(preview_path("..").unwrap().ends_with("file"));
    }
}
