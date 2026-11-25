//! Errors as the page sees them: an HTTP-like status and a message a user can
//! act on (the 2.0 client's wording), plus the server's JSON body when there
//! was one. Status 0 is a transport failure, -1 a cancelled request.

use serde::Serialize;
use serde_json::Value;

#[derive(Debug, Clone, Serialize, thiserror::Error)]
#[error("{message}")]
pub struct ApiError {
    pub status: i32,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

pub type ApiResult<T> = Result<T, ApiError>;

impl ApiError {
    pub fn new(status: i32, message: impl Into<String>) -> Self {
        Self { status, message: message.into(), data: None }
    }
    pub fn transport(message: impl Into<String>) -> Self {
        Self::new(0, message)
    }
    pub fn cancelled() -> Self {
        Self::new(-1, "Cancelled")
    }
    pub fn local(message: impl Into<String>) -> Self {
        Self::new(0, message)
    }
    pub fn is_unauthorized(&self) -> bool {
        self.status == 401
    }

    /// An HTTP error status with the server's body (if any).
    pub fn http(status: u16, body: Option<Value>) -> Self {
        let status = status as i32;
        Self { status, message: message_for(status, body.as_ref()), data: body }
    }

    /// Maps a reqwest failure to a message a user can act on.
    pub fn from_reqwest(e: &reqwest::Error) -> Self {
        if e.is_timeout() {
            return Self::transport("Connection timed out");
        }
        let chain = error_chain(e);
        let lower = chain.to_lowercase();
        if lower.contains("certificate") || lower.contains("tls") || lower.contains("handshake") {
            return Self::transport(
                "TLS handshake failed: the server certificate is not trusted (self-signed?). Install the CA certificate on this machine or use a certificate from a trusted authority.",
            );
        }
        if e.is_connect() {
            return Self::transport(format!("Cannot reach server: {chain}"));
        }
        Self::transport(format!("Connection failed: {chain}"))
    }
}

fn error_chain(e: &dyn std::error::Error) -> String {
    let mut parts = vec![e.to_string()];
    let mut cur = e.source();
    while let Some(s) = cur {
        let t = s.to_string();
        if !parts.iter().any(|p| p.contains(&t)) {
            parts.push(t);
        }
        cur = s.source();
    }
    parts.join(": ")
}

/// Prefers the server's own `error` text; falls back to a clear message for
/// status codes the server may return without a JSON body.
pub fn message_for(status: i32, body: Option<&Value>) -> String {
    let server = body.and_then(|b| b.get("error")).and_then(Value::as_str).filter(|s| !s.is_empty());
    match status {
        401 => {
            return match server {
                Some(m) if m != "unauthorized" => m.to_string(),
                _ => "Session expired or invalid credentials".into(),
            }
        }
        413 => return server.map(str::to_string).unwrap_or_else(|| "Request too large (server limit exceeded)".into()),
        429 => return "Too many failed login attempts. Try again in 15 minutes.".into(),
        _ => {}
    }
    if let Some(m) = server {
        return m.to_string();
    }
    match status {
        400 => "Invalid request".into(),
        403 => "Forbidden".into(),
        404 => "Not found".into(),
        409 => "Conflict".into(),
        500 => "Server error".into(),
        502..=504 => format!("Server unavailable ({status})"),
        _ => format!("Request failed ({status})"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn server_text_wins_except_where_2_0_did_not() {
        assert_eq!(message_for(404, Some(&json!({"error": "bucket not found"}))), "bucket not found");
        assert_eq!(message_for(404, None), "Not found");
        assert_eq!(message_for(401, Some(&json!({"error": "unauthorized"}))), "Session expired or invalid credentials");
        assert_eq!(message_for(401, Some(&json!({"error": "invalid credentials"}))), "invalid credentials");
        assert_eq!(message_for(429, Some(&json!({"error": "x"}))), "Too many failed login attempts. Try again in 15 minutes.");
        assert_eq!(message_for(503, None), "Server unavailable (503)");
        assert_eq!(message_for(418, None), "Request failed (418)");
    }
}
