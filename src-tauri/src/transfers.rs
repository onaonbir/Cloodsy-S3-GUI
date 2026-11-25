//! Uploads and downloads, streamed here so large files never pass through the
//! page. At most three run at once. Files above 64 MB go up as multipart
//! uploads (part size max(16 MB, size / 9000)) when the server has
//! `multipart`; without it, files above 5 GB are refused. A failed multipart
//! upload keeps its finished parts and resumes from them when retried with the
//! same id; a cancelled one is aborted on the server. Downloads are written to
//! `<dest>.part` and renamed when complete.
//!
//! The page hears `transfer` events: `{id, state, done, total, error?,
//! resume_parts?}` with state running | done | error | cancelled (progress is
//! sent at most ~10 times a second).

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use futures_util::StreamExt;
use reqwest::{Body, StatusCode};
use serde::Serialize;
use serde_json::{json, Value};
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};
use tokio::sync::{Mutex, Semaphore};
use tokio_util::sync::CancellationToken;

use crate::api::{Api, LONG_TIMEOUT};
use crate::error::{ApiError, ApiResult};

pub const MULTIPART_ABOVE: u64 = 64 << 20;
const MIN_PART: u64 = 16 << 20;
const MAX_PARTS: u64 = 9000;
const SINGLE_PUT_MAX: u64 = 5 << 30;
const CHUNK: usize = 256 << 10;

pub fn part_size(size: u64) -> u64 {
    MIN_PART.max(size.div_ceil(MAX_PARTS))
}

#[derive(Clone, Default)]
struct Resume {
    upload_id: String,
    part_size: u64,
    /// part number → etag
    parts: HashMap<u32, String>,
}

#[derive(Serialize, Clone)]
struct Event<'a> {
    id: &'a str,
    state: &'a str,
    done: u64,
    total: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    resume_parts: Option<usize>,
}

pub struct Transfers {
    api: Arc<Api>,
    app: AppHandle,
    slots: Semaphore,
    cancels: Mutex<HashMap<String, CancellationToken>>,
    resumes: Mutex<HashMap<String, Resume>>,
}

/// Emits progress, throttled.
struct Progress {
    app: AppHandle,
    id: String,
    total: u64,
    done: AtomicU64,
    last: std::sync::Mutex<Instant>,
}

impl Progress {
    fn add(&self, n: u64) {
        let done = self.done.fetch_add(n, Ordering::Relaxed) + n;
        let mut last = self.last.lock().unwrap();
        if last.elapsed() >= Duration::from_millis(100) || done >= self.total {
            *last = Instant::now();
            let _ = self.app.emit("transfer", Event { id: &self.id, state: "running", done, total: self.total, error: None, resume_parts: None });
        }
    }
    fn set(&self, v: u64) {
        self.done.store(v, Ordering::Relaxed);
        self.add(0);
    }
    fn emit(&self, state: &str, error: Option<String>, resume_parts: Option<usize>) {
        let done = self.done.load(Ordering::Relaxed);
        let _ = self.app.emit("transfer", Event { id: &self.id, state, done, total: self.total, error, resume_parts });
    }
}

/// A body that streams `data` in chunks and reports what went out.
fn counted_body(data: Vec<u8>, progress: Arc<Progress>) -> Body {
    let chunks: Vec<Vec<u8>> = data.chunks(CHUNK).map(<[u8]>::to_vec).collect();
    let stream = futures_util::stream::iter(chunks.into_iter().map(move |c| {
        progress.add(c.len() as u64);
        Ok::<_, std::io::Error>(c)
    }));
    Body::wrap_stream(stream)
}

fn object_url(base: &str, bucket: &str, suffix: &str) -> String {
    format!("{base}/buckets/{}{suffix}", urlencode(bucket))
}

pub fn urlencode(s: &str) -> String {
    crate::presign::aws_encode(s, false)
}

async fn read_json(res: reqwest::Response) -> ApiResult<Value> {
    let status = res.status();
    let bytes = res.bytes().await.map_err(|e| ApiError::from_reqwest(&e))?;
    let parsed: Option<Value> = if bytes.is_empty() { None } else { serde_json::from_slice(&bytes).ok() };
    if status.is_success() {
        Ok(parsed.unwrap_or_else(|| json!({})))
    } else {
        Err(ApiError::http(status.as_u16(), parsed))
    }
}

impl Transfers {
    pub fn new(api: Arc<Api>, app: AppHandle) -> Self {
        Self { api, app, slots: Semaphore::new(3), cancels: Mutex::new(HashMap::new()), resumes: Mutex::new(HashMap::new()) }
    }

    async fn token_for(&self, id: &str) -> CancellationToken {
        let t = CancellationToken::new();
        self.cancels.lock().await.insert(id.to_string(), t.clone());
        t
    }

    pub async fn cancel(&self, id: &str) {
        if let Some(t) = self.cancels.lock().await.get(id) {
            t.cancel();
        }
    }

    pub async fn cancel_all(&self) {
        for t in self.cancels.lock().await.values() {
            t.cancel();
        }
    }

    /// Sends a request built by `build(token)`; renews the session once on 401.
    async fn send(&self, server_id: &str, build: impl Fn(&str) -> reqwest::RequestBuilder) -> ApiResult<reqwest::Response> {
        let (_, token) = self.api.auth(server_id).await?;
        let res = build(&token).send().await.map_err(|e| ApiError::from_reqwest(&e))?;
        if res.status() != StatusCode::UNAUTHORIZED {
            return Ok(res);
        }
        let token = self.api.reauth(server_id).await?;
        build(&token).send().await.map_err(|e| ApiError::from_reqwest(&e))
    }

    #[allow(clippy::too_many_arguments)]
    pub async fn upload(
        self: Arc<Self>,
        id: String,
        server_id: String,
        bucket: String,
        key: String,
        path: PathBuf,
        content_type: String,
        multipart: bool,
    ) {
        let cancel = self.token_for(&id).await;
        let total = tokio::fs::metadata(&path).await.map(|m| m.len()).unwrap_or(0);
        let progress = Arc::new(Progress { app: self.app.clone(), id: id.clone(), total, done: AtomicU64::new(0), last: std::sync::Mutex::new(Instant::now()) });
        let _slot = tokio::select! {
            s = self.slots.acquire() => s.ok(),
            _ = cancel.cancelled() => { progress.emit("cancelled", None, None); return; }
        };
        progress.emit("running", None, None);
        let work = self.clone().upload_inner(&id, &server_id, &bucket, &key, &path, &content_type, multipart, total, progress.clone());
        let result = tokio::select! {
            r = work => r,
            _ = cancel.cancelled() => Err(ApiError::cancelled()),
        };
        self.cancels.lock().await.remove(&id);
        match result {
            Ok(()) => {
                self.resumes.lock().await.remove(&id);
                progress.set(total);
                progress.emit("done", None, None);
            }
            Err(e) if e.status == -1 => {
                if let Some(r) = self.resumes.lock().await.remove(&id) {
                    let _ = self
                        .send(&server_id, |t| {
                            self.api.http.delete(object_url(&base_of(&self.api, &server_id), &bucket, &format!("/uploads/{}", urlencode(&r.upload_id)))).bearer_auth(t)
                        })
                        .await;
                }
                progress.emit("cancelled", None, None);
            }
            Err(e) => {
                let parts = self.resumes.lock().await.get(&id).map(|r| r.parts.len()).filter(|n| *n > 0);
                progress.emit("error", Some(e.message), parts);
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    async fn upload_inner(
        self: Arc<Self>,
        id: &str,
        server_id: &str,
        bucket: &str,
        key: &str,
        path: &Path,
        content_type: &str,
        multipart: bool,
        total: u64,
        progress: Arc<Progress>,
    ) -> ApiResult<()> {
        let base = base_of(&self.api, server_id);
        if !(multipart && total > MULTIPART_ABOVE) {
            if total > SINGLE_PUT_MAX {
                return Err(ApiError::local("This server cannot take files over 5 GB (no multipart upload). Update the server."));
            }
            // Streamed from the file (a server without multipart may take up to 5 GB).
            let file = std::fs::File::open(path).map_err(|e| ApiError::local(format!("File error: {e} ({})", path.display())))?;
            let res = self
                .send(server_id, |t| {
                    progress.set(0);
                    let body = match file.try_clone().and_then(|mut f| std::io::Seek::seek(&mut f, std::io::SeekFrom::Start(0)).map(|_| f)) {
                        Ok(f) => {
                            let p = progress.clone();
                            let stream = tokio_util::io::ReaderStream::with_capacity(tokio::fs::File::from_std(f), CHUNK).map(move |r| {
                                if let Ok(b) = &r {
                                    p.add(b.len() as u64);
                                }
                                r
                            });
                            Body::wrap_stream(stream)
                        }
                        Err(_) => Body::from(Vec::new()),
                    };
                    self.api
                        .http
                        .put(object_url(&base, bucket, "/object"))
                        .query(&[("key", key)])
                        .bearer_auth(t)
                        .header("Content-Type", content_type)
                        .header("Content-Length", total)
                        .timeout(Duration::from_secs(3600 * 6))
                        .body(body)
                })
                .await?;
            read_json(res).await?;
            return Ok(());
        }

        // Multipart: resume a previous attempt with the same id if there is one.
        let mut resume = self.resumes.lock().await.get(id).cloned().unwrap_or_default();
        if resume.upload_id.is_empty() {
            let res = self
                .send(server_id, |t| {
                    self.api.http.post(object_url(&base, bucket, "/uploads")).query(&[("key", key)]).bearer_auth(t).header("Content-Type", content_type)
                })
                .await?;
            let v = read_json(res).await?;
            resume.upload_id = v.get("upload_id").and_then(Value::as_str).unwrap_or_default().to_string();
            if resume.upload_id.is_empty() {
                return Err(ApiError::local("The server did not start the upload"));
            }
            resume.part_size = part_size(total);
            self.resumes.lock().await.insert(id.into(), resume.clone());
        }
        let part_size = resume.part_size;
        let count = total.div_ceil(part_size).max(1) as u32;
        let already: u64 = resume.parts.keys().map(|n| part_len(*n, part_size, total)).sum();
        progress.set(already);

        let mut file = tokio::fs::File::open(path).await.map_err(|e| ApiError::local(format!("File error: {e} ({})", path.display())))?;
        for n in 1..=count {
            if resume.parts.contains_key(&n) {
                continue;
            }
            let len = part_len(n, part_size, total);
            let mut buf = vec![0u8; len as usize];
            file.seek(std::io::SeekFrom::Start((n as u64 - 1) * part_size)).await.map_err(|e| ApiError::local(e.to_string()))?;
            file.read_exact(&mut buf).await.map_err(|e| ApiError::local(format!("File error: {e}")))?;
            let before = progress.done.load(Ordering::Relaxed);
            let url = object_url(&base, bucket, &format!("/uploads/{}/parts/{n}", urlencode(&resume.upload_id)));
            let res = self
                .send(server_id, |t| {
                    progress.set(before);
                    self.api
                        .http
                        .put(&url)
                        .bearer_auth(t)
                        .header("Content-Length", buf.len())
                        .timeout(Duration::from_secs(3600))
                        .body(counted_body(buf.clone(), progress.clone()))
                })
                .await?;
            let v = read_json(res).await?;
            let etag = v.get("etag").and_then(Value::as_str).unwrap_or_default().to_string();
            resume.parts.insert(n, etag);
            self.resumes.lock().await.insert(id.into(), resume.clone());
        }
        let mut parts: Vec<_> = resume.parts.iter().map(|(n, e)| json!({"part_number": n, "etag": e})).collect();
        parts.sort_by_key(|p| p["part_number"].as_u64());
        let url = object_url(&base, bucket, &format!("/uploads/{}/complete", urlencode(&resume.upload_id)));
        let body = json!({ "parts": parts });
        let res = self.send(server_id, |t| self.api.http.post(&url).bearer_auth(t).json(&body).timeout(LONG_TIMEOUT)).await?;
        read_json(res).await?;
        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    pub async fn download(self: Arc<Self>, id: String, server_id: String, bucket: String, key: String, version_id: Option<String>, dest: PathBuf, size: u64) {
        let cancel = self.token_for(&id).await;
        let progress = Arc::new(Progress { app: self.app.clone(), id: id.clone(), total: size, done: AtomicU64::new(0), last: std::sync::Mutex::new(Instant::now()) });
        let _slot = tokio::select! {
            s = self.slots.acquire() => s.ok(),
            _ = cancel.cancelled() => { progress.emit("cancelled", None, None); return; }
        };
        progress.emit("running", None, None);
        let part = PathBuf::from(format!("{}.part", dest.display()));
        let work = self.clone().download_inner(&server_id, &bucket, &key, version_id.as_deref(), &part, progress.clone());
        let result = tokio::select! {
            r = work => r,
            _ = cancel.cancelled() => Err(ApiError::cancelled()),
        };
        self.cancels.lock().await.remove(&id);
        match result.and_then(|_| std::fs::rename(&part, &dest).map_err(|e| ApiError::local(format!("File error: {e} ({})", dest.display())))) {
            Ok(()) => progress.emit("done", None, None),
            Err(e) => {
                let _ = std::fs::remove_file(&part);
                progress.emit(if e.status == -1 { "cancelled" } else { "error" }, (e.status != -1).then_some(e.message), None);
            }
        }
    }

    async fn download_inner(self: Arc<Self>, server_id: &str, bucket: &str, key: &str, version_id: Option<&str>, part: &Path, progress: Arc<Progress>) -> ApiResult<()> {
        let base = base_of(&self.api, server_id);
        let mut q = vec![("key", key.to_string())];
        if let Some(v) = version_id {
            q.push(("versionId", v.to_string()));
        }
        let res = self.send(server_id, |t| self.api.http.get(object_url(&base, bucket, "/object")).query(&q).bearer_auth(t).timeout(Duration::from_secs(3600 * 6))).await?;
        if !res.status().is_success() {
            return read_json(res).await.map(|_| ());
        }
        if let Some(dir) = part.parent() {
            tokio::fs::create_dir_all(dir).await.map_err(|e| ApiError::local(format!("File error: {e} ({})", dir.display())))?;
        }
        let mut out = tokio::fs::File::create(part).await.map_err(|e| ApiError::local(format!("File error: {e} ({})", part.display())))?;
        let mut stream = res.bytes_stream();
        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| ApiError::from_reqwest(&e))?;
            out.write_all(&chunk).await.map_err(|e| ApiError::local(format!("File error: {e}")))?;
            progress.add(chunk.len() as u64);
        }
        out.flush().await.map_err(|e| ApiError::local(e.to_string()))?;
        Ok(())
    }

    /// Reads an object (or its first `max` bytes with a Range request) for a
    /// preview. Answers the bytes and whether they are cut short.
    pub async fn read(&self, server_id: &str, bucket: &str, key: &str, max: Option<u64>) -> ApiResult<(Vec<u8>, bool)> {
        let base = base_of(&self.api, server_id);
        let res = self
            .send(server_id, |t| {
                let mut r = self.api.http.get(object_url(&base, bucket, "/object")).query(&[("key", key), ("inline", "1")]).bearer_auth(t).timeout(Duration::from_secs(120));
                if let Some(m) = max {
                    r = r.header("Range", format!("bytes=0-{}", m - 1));
                }
                r
            })
            .await?;
        let status = res.status();
        if !status.is_success() {
            return read_json(res).await.map(|_| (Vec::new(), false));
        }
        let total = res
            .headers()
            .get("Content-Range")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.rsplit('/').next())
            .and_then(|s| s.parse::<u64>().ok());
        let bytes = res.bytes().await.map_err(|e| ApiError::from_reqwest(&e))?.to_vec();
        let truncated = match (max, total) {
            (Some(m), Some(t)) => t > m,
            (Some(m), None) => status != StatusCode::PARTIAL_CONTENT && bytes.len() as u64 > m,
            _ => false,
        };
        let bytes = match max {
            Some(m) if bytes.len() as u64 > m => bytes[..m as usize].to_vec(),
            _ => bytes,
        };
        Ok((bytes, truncated))
    }
}

fn part_len(n: u32, part_size: u64, total: u64) -> u64 {
    let start = (n as u64 - 1) * part_size;
    part_size.min(total.saturating_sub(start))
}

fn base_of(api: &Api, server_id: &str) -> String {
    api.base_url(server_id).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parts_cover_the_file_exactly() {
        for size in [MULTIPART_ABOVE + 1, 1 << 30, (200u64 << 30) + 12345] {
            let ps = part_size(size);
            assert!(ps >= MIN_PART);
            let count = size.div_ceil(ps);
            assert!(count <= MAX_PARTS, "{size}: {count} parts");
            let sum: u64 = (1..=count as u32).map(|n| part_len(n, ps, size)).sum();
            assert_eq!(sum, size);
        }
        assert_eq!(part_size(100 << 20), MIN_PART);
    }
}
