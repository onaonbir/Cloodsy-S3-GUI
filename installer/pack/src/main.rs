//! cloodsy-s3-gui-pack STUB OUT PRODUCT VERSION DIR
//!
//! Appends every file under DIR (paths kept, relative to DIR) to the setup
//! STUB as its payload and writes OUT (tool/build-windows.ps1).
use std::path::{Path, PathBuf};

fn walk(root: &Path, dir: &Path, out: &mut Vec<(String, PathBuf)>) -> std::io::Result<()> {
    let mut entries: Vec<_> = std::fs::read_dir(dir)?.flatten().collect();
    entries.sort_by_key(|e| e.path());
    for e in entries {
        let p = e.path();
        if p.is_dir() {
            walk(root, &p, out)?;
        } else {
            let rel = p.strip_prefix(root).unwrap().to_string_lossy().replace('\\', "/");
            out.push((rel, p));
        }
    }
    Ok(())
}

fn main() {
    let a: Vec<String> = std::env::args().collect();
    if a.len() != 6 {
        eprintln!("usage: cloodsy-s3-gui-pack STUB OUT PRODUCT VERSION DIR");
        std::process::exit(2);
    }
    let mut files = Vec::new();
    if let Err(e) = walk(Path::new(&a[5]), Path::new(&a[5]), &mut files) {
        eprintln!("cloodsy-s3-gui-pack: {e}");
        std::process::exit(1);
    }
    if let Err(e) = cloodsy_s3_gui_pack::build(Path::new(&a[1]), &files, &a[3], &a[4], Path::new(&a[2])) {
        eprintln!("cloodsy-s3-gui-pack: {e}");
        std::process::exit(1);
    }
    println!("{}: {} file(s)", a[2], files.len());
}
