//! The saved servers and the app's preferences: `settings.json` in the app's
//! config folder, written atomically. Passwords and tokens are in the
//! keychain (`secrets`), never here.
//!
//! On the first start the 2.0 server list is imported from the Flutter app's
//! `settings.dat` (XOR-obfuscated JSON next to a `.key` file). Its passwords
//! were in flutter_secure_storage, so they are asked for again.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Server {
    pub id: String,
    pub name: String,
    /// Admin API base URL (scheme + host[:port], no trailing slash).
    pub url: String,
    pub username: String,
    /// Public S3 endpoint for share links (optional override).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub s3_url: Option<String>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Settings {
    #[serde(default)]
    pub servers: Vec<Server>,
    /// theme_mode, locale, notifications, last_upload_dir, last_download_dir…
    #[serde(default)]
    pub prefs: BTreeMap<String, String>,
    /// Set once the 2.0 import ran (found something or not).
    #[serde(default)]
    pub imported_v2: bool,
}

pub struct Store {
    path: PathBuf,
    inner: Mutex<Settings>,
}

impl Store {
    pub fn open(dir: &Path) -> Self {
        Self::open_with(dir, legacy_dirs())
    }

    pub fn open_with(dir: &Path, legacy: Vec<PathBuf>) -> Self {
        let path = dir.join("settings.json");
        let mut s: Settings = std::fs::read(&path)
            .ok()
            .and_then(|b| serde_json::from_slice(&b).ok())
            .unwrap_or_default();
        if !s.imported_v2 {
            if s.servers.is_empty() {
                if let Some(v2) = legacy.into_iter().find_map(|d| read_v2(&d)) {
                    s.servers = v2.servers;
                    for (k, v) in v2.prefs {
                        s.prefs.entry(k).or_insert(v);
                    }
                }
            }
            s.imported_v2 = true;
        }
        let store = Self { path, inner: Mutex::new(s) };
        let _ = store.save();
        store
    }

    pub fn get(&self) -> Settings {
        self.inner.lock().unwrap().clone()
    }

    pub fn update<R>(&self, f: impl FnOnce(&mut Settings) -> R) -> Result<R, String> {
        let r = {
            let mut s = self.inner.lock().unwrap();
            f(&mut s)
        };
        self.save()?;
        Ok(r)
    }

    pub fn server(&self, id: &str) -> Option<Server> {
        self.inner.lock().unwrap().servers.iter().find(|s| s.id == id).cloned()
    }

    fn save(&self) -> Result<(), String> {
        let bytes = serde_json::to_vec_pretty(&*self.inner.lock().unwrap()).map_err(|e| e.to_string())?;
        if let Some(dir) = self.path.parent() {
            std::fs::create_dir_all(dir).map_err(|e| format!("could not create {}: {e}", dir.display()))?;
        }
        let tmp = self.path.with_extension("json.tmp");
        std::fs::write(&tmp, bytes).map_err(|e| format!("could not write settings: {e}"))?;
        std::fs::rename(&tmp, &self.path).map_err(|e| format!("could not write settings: {e}"))
    }
}

/// Where the Flutter 2.0 app kept its settings.
fn legacy_dirs() -> Vec<PathBuf> {
    let mut v = Vec::new();
    if cfg!(windows) {
        if let Some(d) = dirs::config_dir() {
            v.push(d.join("OnaOnbir").join("Cloodsy S3"));
        }
    } else if cfg!(target_os = "macos") {
        if let Some(d) = dirs::data_dir() {
            v.push(d.join("com.onaonbir.cloodsys3"));
        }
    } else if let Some(d) = dirs::data_dir() {
        v.push(d.join("cloodsy-s3"));
        v.push(d.join("com.onaonbir.cloodsys3"));
    }
    v
}

fn xor(data: &[u8], key: &[u8]) -> Vec<u8> {
    data.iter()
        .enumerate()
        .map(|(i, b)| b ^ key[i % key.len()] ^ ((i.wrapping_mul(7).wrapping_add(13)) & 0xFF) as u8)
        .collect()
}

/// Reads a 2.0 `settings.dat` (servers and the plain preferences).
pub fn read_v2(dir: &Path) -> Option<Settings> {
    let key = std::fs::read(dir.join(".key")).ok().filter(|k| !k.is_empty())?;
    let data = std::fs::read(dir.join("settings.dat")).ok()?;
    let json: serde_json::Map<String, Value> = serde_json::from_slice(&xor(&data, &key)).ok()?;
    let mut out = Settings::default();
    if let Some(list) = json.get("servers_list").and_then(Value::as_str) {
        if let Ok(Value::Array(items)) = serde_json::from_str::<Value>(list) {
            for it in items {
                let s = |k: &str| it.get(k).and_then(Value::as_str).map(str::to_string);
                if let (Some(id), Some(url)) = (s("id"), s("url")) {
                    out.servers.push(Server {
                        name: s("name").unwrap_or_else(|| url.clone()),
                        username: s("username").unwrap_or_else(|| "admin".into()),
                        s3_url: s("s3_url").filter(|v| !v.is_empty()),
                        id,
                        url,
                    });
                }
            }
        }
    }
    for k in ["theme_mode", "locale", "notifications", "last_download_dir", "last_upload_dir"] {
        if let Some(v) = json.get(k).and_then(Value::as_str) {
            out.prefs.insert(k.into(), v.into());
        }
    }
    Some(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_a_2_0_settings_file() {
        let dir = tempfile::tempdir().unwrap();
        let key: Vec<u8> = (0..64u8).map(|i| i.wrapping_mul(37).wrapping_add(5)).collect();
        let servers = r#"[{"id":"1","name":"Mini","url":"http://mini:9001","username":"cloodsy","s3_url":"http://mini:9000"},{"id":"2","url":"https://x"}]"#;
        let plain = serde_json::json!({"servers_list": servers, "theme_mode": "dark", "locale": "tr", "other": 1});
        std::fs::write(dir.path().join(".key"), &key).unwrap();
        std::fs::write(dir.path().join("settings.dat"), xor(plain.to_string().as_bytes(), &key)).unwrap();
        let s = read_v2(dir.path()).unwrap();
        assert_eq!(s.servers.len(), 2);
        assert_eq!(s.servers[0].s3_url.as_deref(), Some("http://mini:9000"));
        assert_eq!((s.servers[1].name.as_str(), s.servers[1].username.as_str()), ("https://x", "admin"));
        assert_eq!(s.prefs.get("locale").map(String::as_str), Some("tr"));
        assert!(!s.prefs.contains_key("other"));
    }

    #[test]
    fn saves_atomically_and_reloads() {
        let dir = tempfile::tempdir().unwrap();
        let st = Store::open_with(dir.path(), vec![]);
        st.update(|s| s.prefs.insert("theme_mode".into(), "light".into())).unwrap();
        let again = Store::open_with(dir.path(), vec![]);
        assert_eq!(again.get().prefs.get("theme_mode").map(String::as_str), Some("light"));
        assert!(again.get().imported_v2);
    }
}
