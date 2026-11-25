//! The Admin REST API client and the sessions.
//!
//! One session per server: a token from POST /login kept in memory and in the
//! keychain (reused on the next start while it has more than 30 s left). A
//! request never goes out with a token about to expire: the session is renewed
//! silently first. A 401 (except on /login) triggers one silent re-login with
//! the saved password and a retry; when that fails the session is dropped and
//! the page hears `session-expired`.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use reqwest::Method;
use serde::Serialize;
use serde_json::{json, Value};
use tauri::{AppHandle, Emitter};
use tokio::sync::Mutex;

use crate::error::{ApiError, ApiResult};
use crate::secrets::{self, SavedToken};
use crate::settings::{Server, Store};

pub const DEFAULT_TIMEOUT: Duration = Duration::from_secs(15);
pub const LONG_TIMEOUT: Duration = Duration::from_secs(300);
/// Renew this long before the token expires.
const RENEW_BEFORE: i64 = 30;

#[derive(Clone)]
struct Session {
    token: String,
    username: String,
    expires_at: i64,
}

#[derive(Serialize, Clone)]
pub struct SessionInfo {
    pub server_id: String,
    pub username: String,
    /// Unix seconds.
    pub expires_at: i64,
}

pub struct Api {
    pub http: reqwest::Client,
    settings: Arc<Store>,
    sessions: Mutex<HashMap<String, Session>>,
    /// One login at a time per app (a burst of 401s logs in once).
    login_lock: Mutex<()>,
    app: Option<AppHandle>,
}

pub fn now() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

pub fn user_agent() -> String {
    format!("CloodsyS3GUI/{} ({}; {})", env!("CARGO_PKG_VERSION"), std::env::consts::OS, std::env::consts::ARCH)
}

/// Parses a response body as JSON when it is JSON.
fn parse_body(bytes: &[u8]) -> Option<Value> {
    if bytes.is_empty() {
        return None;
    }
    serde_json::from_slice(bytes).ok()
}

impl Api {
    pub fn new(settings: Arc<Store>, app: Option<AppHandle>) -> Self {
        let http = reqwest::Client::builder()
            .user_agent(user_agent())
            .connect_timeout(Duration::from_secs(10))
            .build()
            .expect("http client");
        Self { http, settings, sessions: Mutex::new(HashMap::new()), login_lock: Mutex::new(()), app }
    }

    fn server(&self, id: &str) -> ApiResult<Server> {
        self.settings.server(id).ok_or_else(|| ApiError::local("This server is no longer saved"))
    }

    pub fn admin_base(server: &Server) -> String {
        format!("{}/admin", server.url.trim_end_matches('/'))
    }

    pub fn base_url(&self, server_id: &str) -> Option<String> {
        self.settings.server(server_id).map(|s| Self::admin_base(&s))
    }

    /// Sends one request with the given token (or none) and parses the reply.
    #[allow(clippy::too_many_arguments)]
    async fn send(
        &self,
        server: &Server,
        token: Option<&str>,
        method: Method,
        path: &str,
        query: &[(String, String)],
        body: Option<&Value>,
        timeout: Duration,
    ) -> ApiResult<Value> {
        let mut req = self.http.request(method, format!("{}{}", Self::admin_base(server), path)).timeout(timeout);
        if !query.is_empty() {
            req = req.query(query);
        }
        if let Some(t) = token {
            req = req.bearer_auth(t);
        }
        if let Some(b) = body {
            req = req.json(b);
        }
        let res = req.send().await.map_err(|e| ApiError::from_reqwest(&e))?;
        let status = res.status();
        let bytes = res.bytes().await.map_err(|e| ApiError::from_reqwest(&e))?;
        let parsed = parse_body(&bytes);
        if status.is_success() {
            Ok(parsed.unwrap_or_else(|| json!({})))
        } else {
            Err(ApiError::http(status.as_u16(), parsed))
        }
    }

    /// POST /login with the saved password; stores the new session.
    async fn login(&self, server: &Server) -> ApiResult<Session> {
        let password = secrets::password(&server.id)
            .ok_or_else(|| ApiError::new(401, "No saved password for this server. Edit the server and enter it."))?;
        let body = json!({"username": server.username, "password": password});
        let v = self.send(server, None, Method::POST, "/login", &[], Some(&body), DEFAULT_TIMEOUT).await?;
        let token = v.get("token").and_then(Value::as_str).filter(|t| !t.is_empty())
            .ok_or_else(|| ApiError::local("The server answered the login without a token"))?
            .to_string();
        let username = v.get("username").and_then(Value::as_str).unwrap_or(&server.username).to_string();
        let expires_at = expiry(&v);
        let s = Session { token, username, expires_at };
        secrets::set_token(&server.id, &SavedToken { token: s.token.clone(), username: s.username.clone(), expires_at });
        self.sessions.lock().await.insert(server.id.clone(), s.clone());
        Ok(s)
    }

    /// The current session, renewed first when it is about to expire.
    async fn session(&self, server: &Server) -> ApiResult<Session> {
        if let Some(s) = self.sessions.lock().await.get(&server.id).cloned() {
            if s.expires_at - now() > RENEW_BEFORE {
                return Ok(s);
            }
        } else {
            return Err(ApiError::new(401, "Not connected"));
        }
        self.relogin(server).await
    }

    async fn relogin(&self, server: &Server) -> ApiResult<Session> {
        let _g = self.login_lock.lock().await;
        // Another request may have renewed it while this one waited.
        if let Some(s) = self.sessions.lock().await.get(&server.id).cloned() {
            if s.expires_at - now() > RENEW_BEFORE + 5 {
                return Ok(s);
            }
        }
        match self.login(server).await {
            Ok(s) => Ok(s),
            Err(e) => {
                if e.status != 0 {
                    self.drop_session(&server.id, "Session expired. Please reconnect.").await;
                }
                Err(e)
            }
        }
    }

    async fn drop_session(&self, server_id: &str, message: &str) {
        self.sessions.lock().await.remove(server_id);
        secrets::clear_token(server_id);
        if let Some(app) = &self.app {
            let _ = app.emit("session-expired", json!({"server_id": server_id, "message": message}));
        }
    }

    /// An authenticated request; one silent re-login on 401.
    pub async fn request(
        &self,
        server_id: &str,
        method: Method,
        path: &str,
        query: &[(String, String)],
        body: Option<&Value>,
        timeout: Duration,
    ) -> ApiResult<Value> {
        let server = self.server(server_id)?;
        let s = self.session(&server).await?;
        match self.send(&server, Some(&s.token), method.clone(), path, query, body, timeout).await {
            Err(e) if e.is_unauthorized() && path != "/login" => {
                // Force a new token even if the old one looked valid (revoked).
                self.sessions.lock().await.entry(server.id.clone()).and_modify(|x| x.expires_at = 0);
                let s = self.relogin(&server).await?;
                self.send(&server, Some(&s.token), method, path, query, body, timeout).await
            }
            r => r,
        }
    }

    /// For streaming transfers: the base URL and a fresh token.
    pub async fn auth(&self, server_id: &str) -> ApiResult<(Server, String)> {
        let server = self.server(server_id)?;
        let s = self.session(&server).await?;
        Ok((server, s.token))
    }

    /// After a raw request answered 401: renew and return the new token.
    pub async fn reauth(&self, server_id: &str) -> ApiResult<String> {
        let server = self.server(server_id)?;
        self.sessions.lock().await.entry(server.id.clone()).and_modify(|x| x.expires_at = 0);
        Ok(self.relogin(&server).await?.token)
    }

    /// Opens a session: a saved token with time left (checked with GET
    /// /status), else a password login. Answers the session and the status.
    pub async fn connect(&self, server_id: &str) -> ApiResult<(SessionInfo, Value)> {
        let server = self.server(server_id)?;
        if let Some(t) = secrets::token(&server.id).filter(|t| t.expires_at - now() > RENEW_BEFORE && t.username == server.username) {
            match self.send(&server, Some(&t.token), Method::GET, "/status", &[], None, DEFAULT_TIMEOUT).await {
                Ok(status) => {
                    let s = Session { token: t.token, username: t.username, expires_at: t.expires_at };
                    self.sessions.lock().await.insert(server.id.clone(), s.clone());
                    return Ok((info(&server.id, &s), status));
                }
                Err(e) if e.is_unauthorized() => secrets::clear_token(&server.id),
                Err(e) => return Err(e),
            }
        }
        let s = {
            let _g = self.login_lock.lock().await;
            self.login(&server).await?
        };
        let status = self.send(&server, Some(&s.token), Method::GET, "/status", &[], None, DEFAULT_TIMEOUT).await?;
        Ok((info(&server.id, &s), status))
    }

    pub async fn session_info(&self, server_id: &str) -> Option<SessionInfo> {
        self.sessions.lock().await.get(server_id).map(|s| info(server_id, s))
    }

    /// POST /logout (best effort) and forget the token.
    pub async fn disconnect(&self, server_id: &str) {
        let token = self.sessions.lock().await.remove(server_id).map(|s| s.token);
        if let (Some(t), Some(server)) = (token, self.settings.server(server_id)) {
            let _ = self.send(&server, Some(&t), Method::POST, "/logout", &[], None, Duration::from_secs(5)).await;
        }
        secrets::clear_token(server_id);
    }

    /// The signed-in admin changed their own password: keep it and log in again.
    pub async fn own_password_changed(&self, server_id: &str, password: &str) -> ApiResult<SessionInfo> {
        secrets::set_password(server_id, password).map_err(ApiError::local)?;
        let server = self.server(server_id)?;
        let _g = self.login_lock.lock().await;
        let s = self.login(&server).await?;
        Ok(info(server_id, &s))
    }

    /// Forgets a server's session without calling the server (edited or removed).
    pub async fn forget(&self, server_id: &str) {
        self.sessions.lock().await.remove(server_id);
        secrets::clear_token(server_id);
    }

    /// Unauthenticated reachability check: any HTTP answer counts.
    pub async fn probe(&self, url: &str) -> ApiResult<u64> {
        let started = Instant::now();
        let base = format!("{}/admin/status", url.trim_end_matches('/'));
        self.http.get(base).timeout(Duration::from_secs(5)).send().await.map_err(|e| ApiError::from_reqwest(&e))?;
        Ok(started.elapsed().as_millis() as u64)
    }

    /// Status and buckets of a saved server for the All servers page: with its
    /// session if one is open, else a throwaway login that is logged out after.
    pub async fn overview(&self, server_id: &str) -> ApiResult<Value> {
        let server = self.server(server_id)?;
        let started = Instant::now();
        let open = self.sessions.lock().await.get(server_id).cloned();
        let (token, throwaway) = match open {
            Some(s) if s.expires_at - now() > RENEW_BEFORE => (s.token, false),
            _ => {
                let password = secrets::password(&server.id).ok_or_else(|| ApiError::new(401, "No saved password"))?;
                let v = self
                    .send(&server, None, Method::POST, "/login", &[], Some(&json!({"username": server.username, "password": password})), DEFAULT_TIMEOUT)
                    .await?;
                (v.get("token").and_then(Value::as_str).unwrap_or_default().to_string(), true)
            }
        };
        let status = self.send(&server, Some(&token), Method::GET, "/status", &[], None, DEFAULT_TIMEOUT).await;
        let ms = started.elapsed().as_millis() as u64;
        let buckets = self.send(&server, Some(&token), Method::GET, "/buckets", &[], None, DEFAULT_TIMEOUT).await;
        if throwaway {
            let _ = self.send(&server, Some(&token), Method::POST, "/logout", &[], None, Duration::from_secs(5)).await;
        }
        let status = status?;
        Ok(json!({"ms": ms, "status": status, "buckets": buckets.ok().and_then(|b| b.get("buckets").cloned()).unwrap_or(json!([]))}))
    }
}

fn info(server_id: &str, s: &Session) -> SessionInfo {
    SessionInfo { server_id: server_id.into(), username: s.username.clone(), expires_at: s.expires_at }
}

/// The login answer's expiry: `expires_in` seconds (preferred) or
/// `expires_at` (RFC 3339 or Unix seconds); 8 h when neither is there.
fn expiry(v: &Value) -> i64 {
    if let Some(n) = v.get("expires_in").and_then(Value::as_i64) {
        return now() + n;
    }
    match v.get("expires_at") {
        Some(Value::Number(n)) => n.as_i64().unwrap_or(0),
        Some(Value::String(s)) => time::OffsetDateTime::parse(s, &time::format_description::well_known::Rfc3339)
            .map(|t| t.unix_timestamp())
            .unwrap_or_else(|_| now() + 8 * 3600),
        _ => now() + 8 * 3600,
    }
}

pub fn method(m: &str) -> ApiResult<Method> {
    Method::from_bytes(m.to_ascii_uppercase().as_bytes()).map_err(|_| ApiError::local(format!("bad method {m}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expiry_prefers_expires_in() {
        let t = now();
        assert!((expiry(&json!({"expires_in": 3600})) - (t + 3600)).abs() <= 1);
        assert_eq!(expiry(&json!({"expires_at": "2030-01-01T00:00:00Z"})), 1_893_456_000);
        assert_eq!(expiry(&json!({"expires_at": 1_893_456_000})), 1_893_456_000);
        assert!(expiry(&json!({})) > t + 7 * 3600);
    }
}
