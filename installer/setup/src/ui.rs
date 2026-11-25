//! The setup window: a frameless 720×500 page (src-setup/). The page asks
//! for `info`, starts the work with `start_install` / `start_uninstall`, and
//! follows it through the `setup-step` and `setup-done` events.

use std::path::PathBuf;
use std::sync::Mutex;

use serde::Serialize;
use tauri::{Emitter, Manager, State, WebviewUrl, WebviewWindowBuilder};

use crate::args::Args;
use crate::install::{self, Existing, Options, Paths, Step};
use crate::system::{self, Machine};
use crate::Mode;
use cloodsy_s3_gui_pack::Payload;

pub struct Context {
    pub mode: Mode,
    pub args: Args,
    pub exe: PathBuf,
    pub payload: Option<Payload>,
    pub stub: Vec<u8>,
    pub paths: Paths,
    pub existing: Option<Existing>,
    pub version: String,
    pub sys: Machine,
}

struct Shared {
    ctx: Mutex<Context>,
    busy: Mutex<bool>,
}

#[derive(Serialize)]
struct Info {
    mode: Mode,
    version: String,
    installed: Option<String>,
    dir: String,
    default_dir: String,
    /// The folder is fixed (an update goes where the app is).
    dir_locked: bool,
    desktop: bool,
    /// Straight to installing (an updater asked).
    auto_start: bool,
    /// A trial run (`/SANDBOX`): the window says so.
    trial: bool,
    log: String,
    /// The installed app's language, when it has chosen one: the window
    /// starts in it.
    language: Option<String>,
}

#[derive(Serialize, Clone)]
struct Done {
    ok: bool,
    /// A message key (`error.<key>` in the page).
    message: String,
    detail: String,
    step: Option<install::StepId>,
}

#[tauri::command]
fn info(shared: State<Shared>) -> Info {
    let c = shared.ctx.lock().unwrap();
    let lnk = Paths::shortcut_name();
    Info {
        mode: c.mode,
        version: c.version.clone(),
        installed: c.existing.as_ref().map(|e| e.version.clone()).filter(|v| !v.is_empty()),
        dir: c.paths.install.display().to_string(),
        default_dir: system::default_dir(c.args.sandbox.as_deref()).display().to_string(),
        dir_locked: c.existing.is_some(),
        desktop: c.args.desktop.unwrap_or_else(|| c.existing.is_none() || c.paths.desktop.as_ref().is_some_and(|d| d.join(&lnk).exists())),
        auto_start: c.args.update && c.mode != Mode::Uninstall,
        trial: c.args.sandbox.is_some(),
        log: system::log_path().display().to_string(),
        language: c.paths.data.first().and_then(|d| install::app_language(d)),
    }
}

fn emit_step(app: &tauri::AppHandle, s: Step) {
    crate::log(&format!("{:?} {:?} {}", s.id, s.state, s.detail));
    let _ = app.emit("setup-step", s);
}

fn finish(app: &tauri::AppHandle, result: Result<(), install::Failure>) {
    let done = match result {
        Ok(()) => Done { ok: true, message: String::new(), detail: String::new(), step: None },
        Err(f) => {
            crate::log(&format!("failed: {} ({})", f.message, f.detail));
            Done { ok: false, message: f.message, detail: f.detail, step: Some(f.step) }
        }
    };
    *app.state::<Shared>().busy.lock().unwrap() = false;
    let _ = app.emit("setup-done", done);
}

/// Installs (or updates) on a worker thread.
#[tauri::command]
fn start_install(app: tauri::AppHandle, shared: State<Shared>, dir: Option<String>, desktop: bool, language: Option<String>) -> Result<(), String> {
    {
        let mut busy = shared.busy.lock().unwrap();
        if *busy {
            return Err("already installing".into());
        }
        *busy = true;
    }
    {
        let mut c = shared.ctx.lock().unwrap();
        // A new folder only for a fresh install.
        if let Some(d) = dir.filter(|d| !d.trim().is_empty() && c.existing.is_none()) {
            c.paths = system::paths(PathBuf::from(d.trim()), c.args.sandbox.as_deref());
        }
    }
    std::thread::spawn(move || {
        let shared = app.state::<Shared>();
        let mut c = shared.ctx.lock().unwrap();
        let Context { payload, stub, paths, sys, .. } = &mut *c;
        let result = match payload.as_mut() {
            Some(p) => install::install(p, stub, paths, Options { desktop }, &*sys, &mut |s| emit_step(&app, s)),
            None => Err(install::Failure { step: install::StepId::Prepare, message: "payload".into(), detail: "no payload".into() }),
        };
        // The language picked in this window becomes the app's.
        if let (Ok(()), Some(lang), Some(data)) = (&result, language.as_deref(), paths.data.first()) {
            if let Err(e) = install::set_app_language(data, lang) {
                crate::log(&format!("language not saved: {e}"));
            }
        }
        drop(c);
        finish(&app, result);
    });
    Ok(())
}

#[tauri::command]
fn start_uninstall(app: tauri::AppHandle, shared: State<Shared>, wipe: bool) -> Result<(), String> {
    {
        let mut busy = shared.busy.lock().unwrap();
        if *busy {
            return Err("already removing".into());
        }
        *busy = true;
    }
    std::thread::spawn(move || {
        let shared = app.state::<Shared>();
        let c = shared.ctx.lock().unwrap();
        let result = install::uninstall(&c.paths, wipe, &c.sys, &mut |s| emit_step(&app, s));
        drop(c);
        finish(&app, result);
    });
    Ok(())
}

#[tauri::command]
async fn pick_dir(app: tauri::AppHandle, current: String, title: String) -> Option<String> {
    use tauri_plugin_dialog::DialogExt;
    let (tx, rx) = std::sync::mpsc::channel();
    app.dialog().file().set_directory(current).set_title(title).pick_folder(move |p| {
        let _ = tx.send(p.and_then(|p| p.into_path().ok()));
    });
    tauri::async_runtime::spawn_blocking(move || rx.recv().ok().flatten()).await.ok().flatten().map(|p| {
        // A folder chosen for the app gets its own subfolder.
        let p: PathBuf = p;
        if p.file_name().is_some_and(|n| n == install::PRODUCT_NAME) { p } else { p.join(install::PRODUCT_NAME) }.display().to_string()
    })
}

/// Opens the installed app and closes the setup.
#[tauri::command]
fn launch(app: tauri::AppHandle, shared: State<Shared>) {
    let (exe, trial) = {
        let mut c = shared.ctx.lock().unwrap();
        c.args.launch = false; // started here, not again at exit
        (c.paths.install.join(install::MAIN_EXE), c.args.sandbox.is_some())
    };
    // A trial's app would share the real install's data folders and meet a
    // real copy's single-instance lock: it is not started.
    if !trial {
        let _ = system::spawn(&exe, &[]);
    }
    app.exit(0);
}

#[tauri::command]
fn open_log() {
    let _ = system::spawn(std::path::Path::new(if cfg!(windows) { "notepad.exe" } else { "xdg-open" }), &[system::log_path().display().to_string()]);
}

#[tauri::command]
fn minimize(window: tauri::WebviewWindow) {
    let _ = window.minimize();
}

/// Closes the setup (not while it works).
#[tauri::command]
fn close(app: tauri::AppHandle, shared: State<Shared>) {
    if *shared.busy.lock().unwrap() {
        return;
    }
    let (uninstall_copy, exe) = {
        let c = shared.ctx.lock().unwrap();
        (c.mode == Mode::Uninstall && c.args.from.is_some(), c.exe.clone())
    };
    if uninstall_copy {
        system::delete_later(&exe);
    }
    app.exit(0);
}

pub fn run(ctx: Context) {
    let title = match (ctx.mode == Mode::Uninstall, system::turkish()) {
        (true, true) => "Cloodsy S3 GUI Kaldırma",
        (true, false) => "Uninstall Cloodsy S3 GUI",
        (false, true) => "Cloodsy S3 GUI Kurulum",
        (false, false) => "Cloodsy S3 GUI Setup",
    };
    // The window's web view keeps its data in a temporary folder, removed after.
    let data = std::env::temp_dir().join(format!("cloodsy-s3-gui-setup-webview-{}", std::process::id()));
    let data_for_window = data.clone();
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(Shared { ctx: Mutex::new(ctx), busy: Mutex::new(false) })
        .invoke_handler(tauri::generate_handler![info, start_install, start_uninstall, pick_dir, launch, open_log, minimize, close])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                if *window.app_handle().state::<Shared>().busy.lock().unwrap() {
                    api.prevent_close();
                }
            }
        })
        .setup(move |app| {
            WebviewWindowBuilder::new(app, "setup", WebviewUrl::App("index.html".into()))
                .title(title)
                .inner_size(720.0, 500.0)
                .resizable(false)
                .maximizable(false)
                .decorations(false)
                .shadow(true)
                .center()
                .background_color(tauri::window::Color(0x16, 0x1b, 0x29, 0xff))
                .data_directory(data_for_window.clone())
                .build()?;
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("the setup window could not open")
        .run(move |app, event| {
            if let tauri::RunEvent::Exit = event {
                let _ = std::fs::remove_dir_all(&data);
                // "/LAUNCH" or "/R": the updater wants the app running again.
                let shared = app.state::<Shared>();
                let c = shared.ctx.lock().unwrap();
                if c.args.launch && c.args.sandbox.is_none() && c.mode != Mode::Uninstall && c.paths.install.join(install::MAIN_EXE).exists() && !*shared.busy.lock().unwrap() {
                    let _ = system::spawn(&c.paths.install.join(install::MAIN_EXE), &[]);
                }
            }
        });
}
