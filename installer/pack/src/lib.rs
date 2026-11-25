//! The Windows setup's payload: the app's files, compressed, appended to the
//! end of the setup exe (an "overlay"), with a list and a trailer:
//!
//! ```text
//! [setup exe][file 1 (zstd)][file 2 (zstd)]…[list JSON][trailer][signature?]
//! ```
//!
//! The trailer (64 bytes) gives where the list is and its SHA-256; the list
//! gives each file's place, size and SHA-256. A code signature (Authenticode)
//! added later goes after the trailer; the reader finds the trailer in front
//! of it from the exe's own header. The same exe without a payload is the
//! uninstaller.

use std::fs::File;
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const MAGIC: &[u8; 8] = b"CS3GP001";
pub const TRAILER: u64 = 64;
const MAX_LIST: u64 = 1 << 20;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Entry {
    /// Where it goes, relative to the install folder ("licenses/README.txt").
    pub path: String,
    /// Compressed bytes in the exe.
    pub offset: u64,
    pub packed: u64,
    /// The file itself.
    pub size: u64,
    pub sha256: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct List {
    pub product: String,
    pub version: String,
    pub files: Vec<Entry>,
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// A safe relative path: no root, no "..", no drive.
pub fn safe_path(p: &str) -> bool {
    !p.is_empty() && !p.starts_with(['/', '\\']) && !p.contains(':') && p.split(['/', '\\']).all(|part| !part.is_empty() && part != "." && part != "..")
}

/// Writes `stub` + the files + list + trailer to `out`.
pub fn build(stub: &Path, files: &[(String, std::path::PathBuf)], product: &str, version: &str, out: &Path) -> Result<(), String> {
    let mut exe = std::fs::read(stub).map_err(|e| format!("{}: {e}", stub.display()))?;
    if find(&exe).is_some() {
        return Err("the setup stub already carries a payload".into());
    }
    let mut list = List { product: product.into(), version: version.into(), files: Vec::new() };
    for (path, src) in files {
        if !safe_path(path) {
            return Err(format!("not a safe path: {path}"));
        }
        let data = std::fs::read(src).map_err(|e| format!("{}: {e}", src.display()))?;
        let packed = zstd::bulk::compress(&data, 19).map_err(|e| e.to_string())?;
        list.files.push(Entry { path: path.clone(), offset: exe.len() as u64, packed: packed.len() as u64, size: data.len() as u64, sha256: hex(&Sha256::digest(&data)) });
        exe.extend_from_slice(&packed);
    }
    let json = serde_json::to_vec(&list).map_err(|e| e.to_string())?;
    let list_offset = exe.len() as u64;
    exe.extend_from_slice(&json);
    let mut trailer = Vec::with_capacity(TRAILER as usize);
    trailer.extend_from_slice(MAGIC);
    trailer.extend_from_slice(&list_offset.to_le_bytes());
    trailer.extend_from_slice(&(json.len() as u64).to_le_bytes());
    trailer.extend_from_slice(&Sha256::digest(&json));
    trailer.resize(TRAILER as usize, 0);
    exe.extend_from_slice(&trailer);
    let mut f = File::create(out).map_err(|e| e.to_string())?;
    f.write_all(&exe).map_err(|e| e.to_string())
}

/// Where the payload ends: before an Authenticode signature, if any (PE
/// data directory 4 holds its file offset).
fn payload_end(bytes_len: u64, header: &[u8]) -> u64 {
    let le32 = |o: usize| header.get(o..o + 4).map(|b| u32::from_le_bytes(b.try_into().unwrap()) as u64);
    let le16 = |o: usize| header.get(o..o + 2).map(|b| u16::from_le_bytes(b.try_into().unwrap()));
    let Some(pe) = le32(0x3c) else { return bytes_len };
    let pe = pe as usize;
    if header.get(pe..pe + 4) != Some(b"PE\0\0") {
        return bytes_len;
    }
    let opt = pe + 24;
    // Data directories start at 96 (PE32) or 112 (PE32+) into the optional header.
    let dirs = match le16(opt) {
        Some(0x10b) => opt + 96,
        Some(0x20b) => opt + 112,
        _ => return bytes_len,
    };
    match (le32(dirs + 4 * 8), le32(dirs + 4 * 8 + 4)) {
        (Some(off), Some(size)) if off > 0 && size > 0 && off + size == bytes_len => off,
        _ => bytes_len,
    }
}

/// The list in an in-memory exe (tests, `build`).
pub fn find(exe: &[u8]) -> Option<List> {
    let end = payload_end(exe.len() as u64, &exe[..exe.len().min(4096)]);
    read_list(end, |off, len| exe.get(off as usize..(off + len) as usize).map(|b| b.to_vec()))
}

fn read_list(end: u64, mut read: impl FnMut(u64, u64) -> Option<Vec<u8>>) -> Option<List> {
    if end < TRAILER {
        return None;
    }
    let t = read(end - TRAILER, TRAILER)?;
    if &t[..8] != MAGIC {
        return None;
    }
    let off = u64::from_le_bytes(t[8..16].try_into().ok()?);
    let len = u64::from_le_bytes(t[16..24].try_into().ok()?);
    if len == 0 || len > MAX_LIST || off.checked_add(len)? > end - TRAILER {
        return None;
    }
    let json = read(off, len)?;
    if Sha256::digest(&json).as_slice() != &t[24..56] {
        return None;
    }
    let list: List = serde_json::from_slice(&json).ok()?;
    let ok = list.files.iter().all(|e| safe_path(&e.path) && e.offset.checked_add(e.packed).is_some_and(|x| x <= off));
    ok.then_some(list)
}

/// An open exe with a payload.
pub struct Payload {
    file: File,
    pub list: List,
}

impl Payload {
    /// The payload of the exe at `path` (None: it has none, the uninstaller).
    pub fn open(path: &Path) -> Result<Option<Self>, String> {
        let mut file = File::open(path).map_err(|e| e.to_string())?;
        let len = file.metadata().map_err(|e| e.to_string())?.len();
        let mut header = vec![0u8; 4096.min(len as usize)];
        file.read_exact(&mut header).map_err(|e| e.to_string())?;
        let end = payload_end(len, &header);
        let list = read_list(end, |off, n| {
            let mut buf = vec![0u8; n as usize];
            file.seek(SeekFrom::Start(off)).ok()?;
            file.read_exact(&mut buf).ok()?;
            Some(buf)
        });
        Ok(list.map(|list| Payload { file, list }))
    }

    /// One file, uncompressed and checked against its SHA-256.
    pub fn extract(&mut self, entry: &Entry) -> Result<Vec<u8>, String> {
        let mut packed = vec![0u8; entry.packed as usize];
        self.file.seek(SeekFrom::Start(entry.offset)).map_err(|e| e.to_string())?;
        self.file.read_exact(&mut packed).map_err(|e| e.to_string())?;
        let data = zstd::bulk::decompress(&packed, entry.size as usize).map_err(|e| format!("{}: {e}", entry.path))?;
        if data.len() as u64 != entry.size || hex(&Sha256::digest(&data)) != entry.sha256 {
            return Err(format!("{}: the setup file is damaged (SHA-256 does not match)", entry.path));
        }
        Ok(data)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fake_pe() -> Vec<u8> {
        let mut b = vec![0u8; 1024];
        b[0] = b'M';
        b[1] = b'Z';
        b[0x3c..0x40].copy_from_slice(&128u32.to_le_bytes());
        b[128..132].copy_from_slice(b"PE\0\0");
        b[152..154].copy_from_slice(&0x20bu16.to_le_bytes());
        b
    }

    #[test]
    fn builds_finds_and_extracts_also_behind_a_signature() {
        let dir = std::env::temp_dir().join(format!("cloodsy-s3-gui-pack-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let stub = dir.join("stub.exe");
        std::fs::write(&stub, fake_pe()).unwrap();
        let a = dir.join("a.bin");
        let b = dir.join("b.txt");
        std::fs::write(&a, vec![7u8; 100_000]).unwrap();
        std::fs::write(&b, "Merhaba ğüşıöç").unwrap();
        let out = dir.join("setup.exe");
        build(&stub, &[("cloodsy-s3.exe".into(), a.clone()), ("licenses/README.txt".into(), b.clone())], "cloodsy-s3-gui", "3.0.1", &out).unwrap();
        let mut p = Payload::open(&out).unwrap().expect("payload");
        assert_eq!(p.list.version, "3.0.1");
        let e = p.list.files[1].clone();
        assert_eq!(p.extract(&e).unwrap(), std::fs::read(&b).unwrap());
        assert!(Payload::open(&stub).unwrap().is_none(), "a stub has no payload");

        // A signature table appended and named in the PE header: still found.
        let mut signed = std::fs::read(&out).unwrap();
        let cert_off = signed.len() as u32;
        signed.extend_from_slice(&[0xAB; 200]);
        let dirs = 152 + 112 + 4 * 8;
        signed[dirs..dirs + 4].copy_from_slice(&cert_off.to_le_bytes());
        signed[dirs + 4..dirs + 8].copy_from_slice(&200u32.to_le_bytes());
        let signed_path = dir.join("signed.exe");
        std::fs::write(&signed_path, &signed).unwrap();
        let mut p = Payload::open(&signed_path).unwrap().expect("payload behind the signature");
        let e = p.list.files[0].clone();
        assert_eq!(p.extract(&e).unwrap().len(), 100_000);

        // One changed byte inside a file is caught.
        let mut broken = std::fs::read(&out).unwrap();
        let at = p.list.files[0].offset as usize + 10;
        broken[at] ^= 0xff;
        let broken_path = dir.join("broken.exe");
        std::fs::write(&broken_path, &broken).unwrap();
        let mut p = Payload::open(&broken_path).unwrap().unwrap();
        let e = p.list.files[0].clone();
        assert!(p.extract(&e).is_err());
        std::fs::remove_dir_all(dir).ok();
    }

    #[test]
    fn paths_stay_inside() {
        for bad in ["", "/x", "..\\x", "a/../b", "C:\\x", "a//b"] {
            assert!(!safe_path(bad), "{bad}");
        }
        assert!(safe_path("licenses/third-party/LICENSE.txt"));
    }
}
