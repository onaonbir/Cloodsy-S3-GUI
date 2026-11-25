//! Cloodsy S3 GUI: a desktop admin for Cloodsy S3 servers.
//!
//! The window is a Vue page with no file system, shell or network access of its
//! own. Everything that leaves the machine (the Admin REST API, uploads and
//! downloads) or touches secrets (the system keychain) happens here, behind
//! the commands registered below.

mod api;
mod desktop;
mod error;
mod presign;
mod secrets;
mod settings;
mod transfers;

use std::path::PathBuf;
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tauri::{Manager, State};
use tauri_plugin_opener::OpenerExt;

use api::{Api, SessionInfo, DEFAULT_TIMEOUT, LONG_TIMEOUT};
use error::{ApiError, ApiResult};
use settings::{Server, Settings, Store};
use transfers::Transfers;

struct App {
    settings: Arc<Store>,
    api: Arc<Api>,
    transfers: Arc<Transfers>,
}

#[derive(Serialize)]
struct AppInfo {
    name: String,
    version: String,
    os: &'static str,
    arch: &'static str,
    updates_installable: bool,
}

#[tauri::command]
fn app_info(app: tauri::AppHandle) -> AppInfo {
    let pkg = app.package_info();
    AppInfo {
        name: pkg.name.clone(),
        version: pkg.version.to_string(),
        os: std::env::consts::OS,
        arch: std::env::consts::ARCH,
        // Release builds update themselves; a dev build would replace itself
        // with a release.
        updates_installable: !cfg!(debug_assertions),
    }
}

// ---- settings and servers ------------------------------------------------

#[tauri::command]
fn settings_get(s: State<App>) -> Settings {
    s.settings.get()
}

#[tauri::command]
fn pref_set(s: State<App>, key: String, value: Option<String>) -> Result<(), String> {
    s.settings.update(|st| match value {
        Some(v) => {
            st.prefs.insert(key, v);
        }
        None => {
            st.prefs.remove(&key);
        }
    })
}

/// Adds (empty id) or updates a server. A new password goes to the keychain;
/// none keeps the saved one. Changing the URL or username drops the session.
#[tauri::command]
async fn server_save(s: State<'_, App>, mut server: Server, password: Option<String>) -> Result<Server, String> {
    server.url = server.url.trim().trim_end_matches('/').to_string();
    if server.id.is_empty() {
        server.id = format!("{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_micros()).unwrap_or(0));
    }
    if let Some(pw) = password.filter(|p| !p.is_empty()) {
        secrets::set_password(&server.id, &pw)?;
    }
    let previous = s.settings.server(&server.id);
    if previous.as_ref().is_some_and(|p| p.url != server.url || p.username != server.username) {
        s.api.forget(&server.id).await;
    }
    let saved = server.clone();
    s.settings.update(move |st| match st.servers.iter_mut().find(|x| x.id == server.id) {
        Some(x) => *x = server,
        None => st.servers.push(server),
    })?;
    Ok(saved)
}

#[tauri::command]
async fn server_remove(s: State<'_, App>, id: String) -> Result<(), String> {
    s.api.forget(&id).await;
    secrets::forget(&id);
    s.settings.update(|st| st.servers.retain(|x| x.id != id))
}

#[tauri::command]
fn server_has_password(id: String) -> bool {
    secrets::password(&id).is_some()
}

#[tauri::command]
async fn server_probe(s: State<'_, App>, url: String) -> ApiResult<u64> {
    s.api.probe(&url).await
}

#[tauri::command]
async fn server_overview(s: State<'_, App>, id: String) -> ApiResult<Value> {
    s.api.overview(&id).await
}

// ---- sessions ------------------------------------------------------------

#[tauri::command]
async fn session_connect(s: State<'_, App>, id: String) -> ApiResult<Value> {
    let (info, status) = s.api.connect(&id).await?;
    Ok(json!({"session": info, "status": status}))
}

#[tauri::command]
async fn session_disconnect(s: State<'_, App>, id: String) -> Result<(), ()> {
    s.transfers.cancel_all().await;
    s.api.disconnect(&id).await;
    Ok(())
}

#[tauri::command]
async fn session_info(s: State<'_, App>, id: String) -> Result<Option<SessionInfo>, ()> {
    Ok(s.api.session_info(&id).await)
}

#[tauri::command]
async fn session_password_changed(s: State<'_, App>, id: String, password: String) -> ApiResult<SessionInfo> {
    s.api.own_password_changed(&id, &password).await
}

// ---- Admin API -----------------------------------------------------------

/// Any Admin API call: `path` is below `/admin` and already encoded.
#[tauri::command]
async fn api(
    s: State<'_, App>,
    server: String,
    method: String,
    path: String,
    query: Option<Vec<(String, String)>>,
    body: Option<Value>,
    long: Option<bool>,
    timeout_secs: Option<u64>,
) -> ApiResult<Value> {
    let timeout = match timeout_secs {
        Some(s) => std::time::Duration::from_secs(s.clamp(1, 3600)),
        None if long.unwrap_or(false) => LONG_TIMEOUT,
        None => DEFAULT_TIMEOUT,
    };
    s.api.request(&server, api::method(&method)?, &path, &query.unwrap_or_default(), body.as_ref(), timeout).await
}

// ---- objects and transfers ----------------------------------------------

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct UploadArgs {
    id: String,
    server: String,
    bucket: String,
    key: String,
    path: String,
    content_type: String,
    multipart: bool,
}

#[tauri::command]
fn upload_start(s: State<App>, args: UploadArgs) {
    let t = s.transfers.clone();
    tauri::async_runtime::spawn(t.upload(args.id, args.server, args.bucket, args.key, PathBuf::from(args.path), args.content_type, args.multipart));
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct DownloadArgs {
    id: String,
    server: String,
    bucket: String,
    key: String,
    version_id: Option<String>,
    dest: String,
    size: u64,
}

#[tauri::command]
fn download_start(s: State<App>, args: DownloadArgs) {
    let t = s.transfers.clone();
    tauri::async_runtime::spawn(t.download(args.id, args.server, args.bucket, args.key, args.version_id, PathBuf::from(args.dest), args.size));
}

#[tauri::command]
async fn transfer_cancel(s: State<'_, App>, id: String) -> Result<(), ()> {
    s.transfers.cancel(&id).await;
    Ok(())
}

#[tauri::command]
async fn transfer_cancel_all(s: State<'_, App>) -> Result<(), ()> {
    s.transfers.cancel_all().await;
    Ok(())
}

/// The object's bytes (the first `max` with a Range request) for a preview.
#[tauri::command]
async fn object_read(s: State<'_, App>, server: String, bucket: String, key: String, max: Option<u64>) -> ApiResult<tauri::ipc::Response> {
    let (bytes, _) = s.transfers.read(&server, &bucket, &key, max).await?;
    Ok(tauri::ipc::Response::new(bytes))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PresignArgs {
    endpoint: String,
    bucket: String,
    key: String,
    access_key: String,
    secret_key: String,
    region: String,
    expires_secs: u64,
    extra_query: Vec<(String, String)>,
}

#[tauri::command]
fn presign_url(args: PresignArgs) -> ApiResult<String> {
    let u = url::Url::parse(args.endpoint.trim_end_matches('/')).map_err(|_| ApiError::local("The S3 endpoint is not a valid URL"))?;
    let host = u.host_str().ok_or_else(|| ApiError::local("The S3 endpoint has no host"))?;
    let mut segments: Vec<String> = u.path_segments().map(|s| s.filter(|x| !x.is_empty()).map(|x| x.to_string()).collect()).unwrap_or_default();
    segments.push(args.bucket.clone());
    segments.extend(args.key.split('/').map(str::to_string));
    Ok(presign::presign(&presign::Presign {
        scheme: u.scheme(),
        host,
        port: u.port_or_known_default(),
        segments,
        access_key: &args.access_key,
        secret_key: &args.secret_key,
        region: &args.region,
        method: "GET",
        expires_secs: args.expires_secs,
        now: api::now(),
        extra_query: args.extra_query,
    }))
}

/// The latest release of a GitHub repository (None when it has none).
#[tauri::command]
async fn github_latest(s: State<'_, App>, repo: String, timeout_secs: u64) -> ApiResult<Option<Value>> {
    let res = s
        .api
        .http
        .get(format!("https://api.github.com/repos/{repo}/releases/latest"))
        .header("Accept", "application/vnd.github+json")
        .timeout(std::time::Duration::from_secs(timeout_secs.clamp(1, 30)))
        .send()
        .await
        .map_err(|e| ApiError::from_reqwest(&e))?;
    if res.status() == reqwest::StatusCode::NOT_FOUND {
        return Ok(None);
    }
    if !res.status().is_success() {
        return Err(ApiError::transport(format!("GitHub answered {}", res.status().as_u16())));
    }
    let v: Value = res.json().await.map_err(|e| ApiError::from_reqwest(&e))?;
    let tag = v.get("tag_name").and_then(Value::as_str).unwrap_or_default().trim_start_matches('v').to_string();
    if tag.is_empty() {
        return Ok(None);
    }
    Ok(Some(json!({
        "tag": tag,
        "url": v.get("html_url").and_then(Value::as_str).unwrap_or_default(),
        "notes": v.get("body").and_then(Value::as_str).unwrap_or_default(),
    })))
}

// ---- desktop --------------------------------------------------------------

#[tauri::command]
fn files_walk(paths: Vec<String>) -> Vec<desktop::LocalFile> {
    desktop::walk(&paths)
}

#[tauri::command]
fn preview_path(name: String) -> Result<String, String> {
    desktop::preview_path(&name)
}

#[tauri::command]
fn local_path(server_url: String, host_os: String, hostname: String, wsl_distro: String, path: String) -> Option<String> {
    desktop::local_path(&server_url, &host_os, &hostname, &wsl_distro, &path)
}

#[tauri::command]
fn path_exists(path: String) -> bool {
    std::path::Path::new(&path).exists()
}

#[tauri::command]
fn open_path(app: tauri::AppHandle, path: String) -> Result<(), String> {
    app.opener().open_path(path, None::<&str>).map_err(|e| e.to_string())
}

#[tauri::command]
fn reveal_path(app: tauri::AppHandle, path: String) -> Result<(), String> {
    app.opener().reveal_item_in_dir(path).map_err(|e| e.to_string())
}

pub fn run() {
    tauri::Builder::default()
        // A second launch brings the open window forward instead; the Windows
        // setup starts `cloodsy-s3 --quit` to close a running copy before it
        // replaces the files.
        .plugin(tauri_plugin_single_instance::init(|app, args, _cwd| {
            if args.iter().any(|a| a == "--quit") {
                app.exit(0);
                return;
            }
            if let Some(w) = app.get_webview_window("main") {
                let _ = w.unminimize();
                let _ = w.show();
                let _ = w.set_focus();
            }
        }))
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .setup(|app| {
            let dir = app.path().app_config_dir().expect("config dir");
            let settings = Arc::new(Store::open(&dir));
            let api = Arc::new(Api::new(settings.clone(), Some(app.handle().clone())));
            let transfers = Arc::new(Transfers::new(api.clone(), app.handle().clone()));
            app.manage(App { settings, api, transfers });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            app_info,
            settings_get,
            pref_set,
            server_save,
            server_remove,
            server_has_password,
            server_probe,
            server_overview,
            session_connect,
            session_disconnect,
            session_info,
            session_password_changed,
            api,
            upload_start,
            download_start,
            transfer_cancel,
            transfer_cancel_all,
            object_read,
            presign_url,
            github_latest,
            files_walk,
            preview_path,
            local_path,
            path_exists,
            open_path,
            reveal_path,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Cloodsy S3 GUI");
}
