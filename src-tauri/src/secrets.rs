//! Passwords and session tokens in the system keychain (Windows Credential
//! Manager, macOS Keychain, the Secret Service on Linux). Nothing secret is
//! written to the settings file.

use serde::{Deserialize, Serialize};

const SERVICE: &str = "com.onaonbir.cloodsys3gui";

fn entry(name: &str) -> Option<keyring::Entry> {
    keyring::Entry::new(SERVICE, name).ok()
}

fn get(name: &str) -> Option<String> {
    entry(name)?.get_password().ok()
}

fn set(name: &str, value: &str) -> Result<(), String> {
    entry(name)
        .ok_or_else(|| "the system keychain is not available".to_string())?
        .set_password(value)
        .map_err(|e| format!("could not save to the system keychain: {e}"))
}

fn delete(name: &str) {
    if let Some(e) = entry(name) {
        let _ = e.delete_credential();
    }
}

pub fn password(server_id: &str) -> Option<String> {
    get(&format!("pw:{server_id}"))
}

pub fn set_password(server_id: &str, pw: &str) -> Result<(), String> {
    set(&format!("pw:{server_id}"), pw)
}

/// A saved session: reused on the next start while it has time left.
#[derive(Clone, Serialize, Deserialize)]
pub struct SavedToken {
    pub token: String,
    pub username: String,
    /// Unix seconds.
    pub expires_at: i64,
}

pub fn token(server_id: &str) -> Option<SavedToken> {
    serde_json::from_str(&get(&format!("token:{server_id}"))?).ok()
}

pub fn set_token(server_id: &str, t: &SavedToken) {
    if let Ok(s) = serde_json::to_string(t) {
        let _ = set(&format!("token:{server_id}"), &s);
    }
}

pub fn clear_token(server_id: &str) {
    delete(&format!("token:{server_id}"));
}

pub fn forget(server_id: &str) {
    delete(&format!("pw:{server_id}"));
    clear_token(server_id);
}
