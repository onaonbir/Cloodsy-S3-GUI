//! Installing, updating and removing Cloodsy S3 GUI, step by step.
//!
//! The steps only touch the system through `System` (registry, shortcuts,
//! processes), so they are tested on any machine. Files are written as
//! `.new` and checked; only when every one is in hand do they take the old
//! ones' place: a failure leaves the installed version as it was.

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use cloodsy_s3_gui_pack::{Entry, Payload};
use serde::Serialize;

pub const PRODUCT_NAME: &str = "Cloodsy S3 GUI";
#[cfg_attr(not(windows), allow(dead_code))]
pub const PUBLISHER: &str = "OnaOnbir";
pub const MAIN_EXE: &str = "cloodsy-s3.exe";
pub const UNINSTALLER: &str = "uninstall.exe";
/// The installed files, one per line (what the uninstaller removes).
pub const FILE_LIST: &str = "installed-files.txt";

/// Where things go on this machine.
#[derive(Debug, Clone)]
pub struct Paths {
    pub install: PathBuf,
    pub start_menu: Option<PathBuf>,
    pub desktop: Option<PathBuf>,
    /// The app's data folders (%APPDATA%\<id>: saved servers and settings;
    /// %LOCALAPPDATA%\<id>: the web view's data). Removed only on request.
    pub data: Vec<PathBuf>,
}

impl Paths {
    pub fn shortcut_name() -> String {
        format!("{PRODUCT_NAME}.lnk")
    }
}

/// What is installed already.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Existing {
    pub dir: PathBuf,
    pub version: String,
}

/// What the registry entry says.
#[derive(Debug, Clone)]
#[cfg_attr(not(windows), allow(dead_code))]
pub struct Registration {
    pub dir: PathBuf,
    pub version: String,
    pub size_kb: u64,
}

pub trait System {
    fn existing(&self) -> Option<Existing>;
    /// Whether the app at `exe` runs.
    fn running(&self, exe: &Path) -> bool;
    /// Asks the running app to quit properly (`cloodsy-s3.exe --quit`).
    fn ask_quit(&self, exe: &Path);
    fn shortcut(&self, target: &Path, lnk: &Path) -> Result<(), String>;
    fn register(&self, r: &Registration) -> Result<(), String>;
    /// The uninstall entry.
    fn unregister(&self);
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum StepId {
    Prepare,
    Files,
    Register,
    Close,
    Remove,
    Clean,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum StepState {
    Running,
    Done,
    Failed,
    Skipped,
}

#[derive(Debug, Clone, Serialize)]
pub struct Step {
    pub id: StepId,
    pub state: StepState,
    pub detail: String,
}

#[derive(Debug, Clone, Copy)]
pub struct Options {
    pub desktop: bool,
}

/// A failed step: what went wrong as a message key the window translates
/// (`error.<key>`), and the technical detail.
#[derive(Debug, Clone, Serialize)]
pub struct Failure {
    pub step: StepId,
    pub message: String,
    pub detail: String,
}

type Emit<'a> = &'a mut dyn FnMut(Step);

fn step(emit: Emit, id: StepId, state: StepState, detail: impl Into<String>) {
    emit(Step { id, state, detail: detail.into() });
}

fn fail(emit: Emit, id: StepId, message: &str, detail: impl ToString) -> Failure {
    let detail = detail.to_string();
    step(emit, id, StepState::Failed, "");
    Failure { step: id, message: message.into(), detail }
}

/// Closes a running copy and waits (up to 20 s) for it.
fn close_running(sys: &dyn System, exe: &Path) -> bool {
    if !sys.running(exe) {
        return true;
    }
    sys.ask_quit(exe);
    let deadline = Instant::now() + Duration::from_secs(20);
    while Instant::now() < deadline {
        if !sys.running(exe) {
            // Let Windows release the files.
            std::thread::sleep(Duration::from_millis(300));
            return true;
        }
        std::thread::sleep(Duration::from_millis(250));
    }
    false
}

fn new_name(p: &Path) -> PathBuf {
    let mut s = p.as_os_str().to_owned();
    s.push(".new");
    PathBuf::from(s)
}

fn old_name(p: &Path) -> PathBuf {
    let mut s = p.as_os_str().to_owned();
    s.push(".old");
    PathBuf::from(s)
}

fn write_new(payload: &mut Payload, dir: &Path, e: &Entry) -> Result<PathBuf, String> {
    let target = dir.join(&e.path);
    if let Some(parent) = target.parent() {
        std::fs::create_dir_all(parent).map_err(|err| format!("{}: {err}", parent.display()))?;
    }
    let data = payload.extract(e)?;
    let tmp = new_name(&target);
    std::fs::write(&tmp, &data).map_err(|err| format!("{}: {err}", tmp.display()))?;
    Ok(target)
}

/// Puts the checked `.new` files in place; a running file is moved aside
/// (Windows allows renaming an open exe) and removed when it can be.
fn swap(targets: &[PathBuf]) -> Result<(), String> {
    for t in targets {
        let old = old_name(t);
        let _ = std::fs::remove_file(&old);
        if t.exists() {
            std::fs::rename(t, &old).map_err(|e| format!("{}: {e}", t.display()))?;
        }
        std::fs::rename(new_name(t), t).map_err(|e| format!("{}: {e}", t.display()))?;
        let _ = std::fs::remove_file(&old);
    }
    Ok(())
}

fn dir_size_kb(dir: &Path) -> u64 {
    fn walk(d: &Path) -> u64 {
        std::fs::read_dir(d)
            .map(|r| r.flatten().map(|e| {
                let p = e.path();
                if p.is_dir() { walk(&p) } else { e.metadata().map(|m| m.len()).unwrap_or(0) }
            }).sum())
            .unwrap_or(0)
    }
    walk(dir) / 1024
}

/// The app's language in its settings (`prefs.locale` in settings.json in its
/// data folder), when it has chosen one.
pub fn app_language(data_dir: &Path) -> Option<String> {
    let v: serde_json::Value = serde_json::from_slice(&std::fs::read(data_dir.join("settings.json")).ok()?).ok()?;
    v.get("prefs")?.get("locale")?.as_str().filter(|l| matches!(*l, "en" | "tr")).map(str::to_owned)
}

/// Sets the app's language (`en` or `tr`) to the one picked in the setup,
/// keeping everything else in its settings.
pub fn set_app_language(data_dir: &Path, lang: &str) -> std::io::Result<()> {
    if !matches!(lang, "en" | "tr") {
        return Ok(());
    }
    let path = data_dir.join("settings.json");
    let mut v: serde_json::Value = std::fs::read(&path).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default();
    if !v.is_object() {
        v = serde_json::json!({});
    }
    let prefs = v.as_object_mut().unwrap().entry("prefs").or_insert_with(|| serde_json::json!({}));
    if !prefs.is_object() {
        *prefs = serde_json::json!({});
    }
    prefs.as_object_mut().unwrap().insert("locale".into(), lang.into());
    std::fs::create_dir_all(data_dir)?;
    std::fs::write(&path, serde_json::to_vec_pretty(&v)?)
}

/// Installs or updates from `payload` into `paths.install`. `stub` is the
/// setup exe without its payload: it becomes the uninstaller.
pub fn install(payload: &mut Payload, stub: &[u8], paths: &Paths, opts: Options, sys: &dyn System, emit: Emit) -> Result<(), Failure> {
    let dir = &paths.install;
    let exe = dir.join(MAIN_EXE);
    step(emit, StepId::Prepare, StepState::Running, "");
    std::fs::create_dir_all(dir).map_err(|e| fail(emit, StepId::Prepare, "folder", format!("{}: {e}", dir.display())))?;
    if !close_running(sys, &exe) {
        return Err(fail(emit, StepId::Prepare, "running", "Cloodsy S3 GUI did not quit within 20 seconds"));
    }
    step(emit, StepId::Prepare, StepState::Done, "");

    // The app's files: all written as .new first, then swapped in.
    step(emit, StepId::Files, StepState::Running, "");
    let entries = payload.list.files.clone();
    let mut targets = Vec::new();
    let cleanup = |targets: &[PathBuf]| targets.iter().for_each(|t| drop(std::fs::remove_file(new_name(t))));
    let mut bytes = 0;
    for e in &entries {
        match write_new(payload, dir, e) {
            Ok(t) => {
                bytes += e.size;
                targets.push(t);
            }
            Err(err) => {
                cleanup(&targets);
                return Err(fail(emit, StepId::Files, "write", err));
            }
        }
    }
    if let Err(err) = swap(&targets) {
        cleanup(&targets);
        return Err(fail(emit, StepId::Files, "swap", err));
    }
    step(emit, StepId::Files, StepState::Done, format!("{:.1} MB", bytes as f64 / 1_048_576.0));

    // Shortcuts, the uninstaller and the Windows entry.
    step(emit, StepId::Register, StepState::Running, "");
    let reg = (|| -> Result<(), String> {
        let uninstaller = dir.join(UNINSTALLER);
        let tmp = new_name(&uninstaller);
        std::fs::write(&tmp, stub).map_err(|e| format!("{}: {e}", tmp.display()))?;
        swap(std::slice::from_ref(&uninstaller))?;
        let mut list: Vec<String> = entries.iter().map(|e| e.path.clone()).collect();
        list.push(UNINSTALLER.into());
        std::fs::write(dir.join(FILE_LIST), list.join("\n") + "\n").map_err(|e| e.to_string())?;
        if let Some(menu) = &paths.start_menu {
            std::fs::create_dir_all(menu).map_err(|e| e.to_string())?;
            sys.shortcut(&exe, &menu.join(Paths::shortcut_name()))?;
        }
        if let Some(desk) = &paths.desktop {
            let lnk = desk.join(Paths::shortcut_name());
            if opts.desktop {
                sys.shortcut(&exe, &lnk)?;
            } else {
                let _ = std::fs::remove_file(lnk);
            }
        }
        sys.register(&Registration { dir: dir.clone(), version: payload.list.version.clone(), size_kb: dir_size_kb(dir) })
    })();
    if let Err(err) = reg {
        return Err(fail(emit, StepId::Register, "register", err));
    }
    step(emit, StepId::Register, StepState::Done, "");
    Ok(())
}

/// Removes Cloodsy S3 GUI. Nothing on the servers is touched; `wipe` also
/// removes the app's data on this computer (saved servers, settings, caches).
pub fn uninstall(paths: &Paths, wipe: bool, sys: &dyn System, emit: Emit) -> Result<(), Failure> {
    let dir = &paths.install;
    let exe = dir.join(MAIN_EXE);
    step(emit, StepId::Close, StepState::Running, "");
    if !close_running(sys, &exe) {
        return Err(fail(emit, StepId::Close, "running", "Cloodsy S3 GUI did not quit within 20 seconds"));
    }
    step(emit, StepId::Close, StepState::Done, "");

    step(emit, StepId::Remove, StepState::Running, "");
    // The list this setup wrote; without one, the files it always installs.
    let listed = std::fs::read_to_string(dir.join(FILE_LIST)).unwrap_or_default();
    let mut files: Vec<String> = listed.lines().map(str::trim).filter(|l| cloodsy_s3_gui_pack::safe_path(l)).map(String::from).collect();
    if files.is_empty() {
        files = vec![MAIN_EXE.into(), UNINSTALLER.into()];
    }
    files.push(FILE_LIST.into());
    for f in &files {
        let p = dir.join(f);
        let _ = std::fs::remove_file(&p);
        let _ = std::fs::remove_file(old_name(&p));
    }
    let _ = std::fs::remove_dir_all(dir.join("licenses"));
    let _ = std::fs::remove_dir(dir); // only if empty: the user's own files stay
    for lnk in [&paths.start_menu, &paths.desktop].into_iter().flatten() {
        let _ = std::fs::remove_file(lnk.join(Paths::shortcut_name()));
    }
    sys.unregister();
    step(emit, StepId::Remove, StepState::Done, "");

    step(emit, StepId::Clean, StepState::Running, "");
    if wipe {
        for d in &paths.data {
            let _ = std::fs::remove_dir_all(d);
        }
        step(emit, StepId::Clean, StepState::Done, "");
    } else {
        step(emit, StepId::Clean, StepState::Skipped, "kept");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    #[test]
    fn app_language_is_set_and_the_rest_kept() {
        let dir = std::env::temp_dir().join(format!("cloodsy-s3-gui-setup-lang-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        // No settings yet: the file is made.
        assert_eq!(app_language(&dir), None);
        set_app_language(&dir, "tr").unwrap();
        assert_eq!(app_language(&dir).as_deref(), Some("tr"));
        // Existing settings: servers and other preferences stay.
        std::fs::write(dir.join("settings.json"), r#"{"servers":[{"id":"a"}],"prefs":{"theme_mode":"dark","locale":"tr"},"imported_v2":true}"#).unwrap();
        set_app_language(&dir, "en").unwrap();
        let v: serde_json::Value = serde_json::from_slice(&std::fs::read(dir.join("settings.json")).unwrap()).unwrap();
        assert_eq!(v["servers"][0]["id"], "a");
        assert_eq!(v["prefs"]["theme_mode"], "dark");
        assert_eq!(v["prefs"]["locale"], "en");
        assert_eq!(v["imported_v2"], true);
        // Anything else is ignored.
        set_app_language(&dir, "de").unwrap();
        assert_eq!(app_language(&dir).as_deref(), Some("en"));
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[derive(Default)]
    struct Fake {
        running: RefCell<u32>,
        quit_asked: RefCell<bool>,
        links: RefCell<Vec<PathBuf>>,
        registered: RefCell<Option<String>>,
    }

    impl System for Fake {
        fn existing(&self) -> Option<Existing> {
            None
        }
        fn running(&self, _exe: &Path) -> bool {
            let mut n = self.running.borrow_mut();
            if *n > 0 {
                *n -= 1;
                true
            } else {
                false
            }
        }
        fn ask_quit(&self, _exe: &Path) {
            *self.quit_asked.borrow_mut() = true;
        }
        fn shortcut(&self, _target: &Path, lnk: &Path) -> Result<(), String> {
            std::fs::write(lnk, b"lnk").map_err(|e| e.to_string())?;
            self.links.borrow_mut().push(lnk.to_path_buf());
            Ok(())
        }
        fn register(&self, r: &Registration) -> Result<(), String> {
            *self.registered.borrow_mut() = Some(r.version.clone());
            Ok(())
        }
        fn unregister(&self) {
            *self.registered.borrow_mut() = None;
        }
    }

    fn setup_exe(root: &Path, version: &str, exe_body: &[u8]) -> PathBuf {
        let src = root.join(format!("src-{version}"));
        std::fs::create_dir_all(src.join("licenses")).unwrap();
        std::fs::write(src.join(MAIN_EXE), exe_body).unwrap();
        std::fs::write(src.join("licenses/LICENSE.txt"), "licence").unwrap();
        let stub = root.join("stub.exe");
        std::fs::write(&stub, b"MZ stub").unwrap();
        let out = root.join(format!("setup-{version}.exe"));
        let files = vec![(MAIN_EXE.to_string(), src.join(MAIN_EXE)), ("licenses/LICENSE.txt".to_string(), src.join("licenses/LICENSE.txt"))];
        cloodsy_s3_gui_pack::build(&stub, &files, "cloodsy-s3-gui", version, &out).unwrap();
        out
    }

    fn paths(root: &Path) -> Paths {
        std::fs::create_dir_all(root.join("Desktop")).unwrap();
        Paths {
            install: root.join("Programs").join(PRODUCT_NAME),
            start_menu: Some(root.join("Start Menu")),
            desktop: Some(root.join("Desktop")),
            data: vec![root.join("Roaming/com.onaonbir.cloodsys3gui"), root.join("Local/com.onaonbir.cloodsys3gui")],
        }
    }

    #[test]
    fn installs_updates_over_a_running_copy_and_uninstalls() {
        let root = std::env::temp_dir().join(format!("cloodsy-s3-gui-setup-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).unwrap();
        let p = paths(&root);
        let sys = Fake::default();
        let mut steps = Vec::new();
        let mut emit = |s: Step| steps.push(s);

        let mut payload = Payload::open(&setup_exe(&root, "3.0.0", b"v1")).unwrap().unwrap();
        install(&mut payload, b"MZ stub", &p, Options { desktop: true }, &sys, &mut emit).unwrap();
        assert_eq!(std::fs::read(p.install.join(MAIN_EXE)).unwrap(), b"v1");
        assert_eq!(std::fs::read(p.install.join(UNINSTALLER)).unwrap(), b"MZ stub");
        assert!(p.install.join("licenses/LICENSE.txt").exists());
        assert!(p.start_menu.as_ref().unwrap().join(Paths::shortcut_name()).exists());
        assert!(p.desktop.as_ref().unwrap().join(Paths::shortcut_name()).exists());
        assert_eq!(sys.registered.borrow().as_deref(), Some("3.0.0"));
        assert!(steps.iter().all(|s| s.state != StepState::Failed));
        assert_eq!(steps.last().map(|s| (s.id, s.state)), Some((StepId::Register, StepState::Done)));

        // Update while it runs: asked to quit, files replaced, no desktop link now.
        *sys.running.borrow_mut() = 2;
        let mut payload = Payload::open(&setup_exe(&root, "3.0.1", b"v2")).unwrap().unwrap();
        let mut emit = |_s: Step| {};
        install(&mut payload, b"MZ stub", &p, Options { desktop: false }, &sys, &mut emit).unwrap();
        assert!(*sys.quit_asked.borrow());
        assert_eq!(std::fs::read(p.install.join(MAIN_EXE)).unwrap(), b"v2");
        assert_eq!(sys.registered.borrow().as_deref(), Some("3.0.1"));
        assert!(!p.desktop.as_ref().unwrap().join(Paths::shortcut_name()).exists());
        assert!(!p.install.join(format!("{MAIN_EXE}.new")).exists());
        assert!(!p.install.join(format!("{MAIN_EXE}.old")).exists());

        // The user's own file in the folder and the app's data survive a plain uninstall.
        std::fs::write(p.install.join("notes.txt"), "mine").unwrap();
        for d in &p.data {
            std::fs::create_dir_all(d).unwrap();
        }
        std::fs::write(p.data[0].join("settings.json"), "{}").unwrap();
        let mut steps = Vec::new();
        let mut emit = |s: Step| steps.push(s);
        uninstall(&p, false, &sys, &mut emit).unwrap();
        assert!(!p.install.join(MAIN_EXE).exists() && !p.install.join(UNINSTALLER).exists() && !p.install.join(FILE_LIST).exists());
        assert!(!p.install.join("licenses").exists());
        assert!(p.install.join("notes.txt").exists());
        assert!(p.data[0].join("settings.json").exists() && p.data[1].exists());
        assert!(sys.registered.borrow().is_none());
        assert!(!p.start_menu.as_ref().unwrap().join(Paths::shortcut_name()).exists());
        assert!(steps.iter().any(|s| s.id == StepId::Clean && s.state == StepState::Skipped && s.detail == "kept"));
        // With "also remove my data": both data folders go.
        uninstall(&p, true, &sys, &mut |_s: Step| {}).unwrap();
        assert!(p.data.iter().all(|d| !d.exists()));
        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn a_broken_payload_leaves_the_old_version() {
        let root = std::env::temp_dir().join(format!("cloodsy-s3-gui-setup-broken-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).unwrap();
        let p = paths(&root);
        let sys = Fake::default();
        let mut emit = |_s: Step| {};
        let mut payload = Payload::open(&setup_exe(&root, "3.0.0", b"v1")).unwrap().unwrap();
        install(&mut payload, b"MZ stub", &p, Options { desktop: false }, &sys, &mut emit).unwrap();

        let exe = setup_exe(&root, "3.0.1", b"v2 bigger body");
        let mut bytes = std::fs::read(&exe).unwrap();
        let list = cloodsy_s3_gui_pack::find(&bytes).unwrap();
        let last = list.files.last().unwrap();
        bytes[last.offset as usize + 2] ^= 0xff;
        std::fs::write(&exe, &bytes).unwrap();
        let mut payload = Payload::open(&exe).unwrap().unwrap();
        let err = install(&mut payload, b"MZ stub", &p, Options { desktop: false }, &sys, &mut emit).unwrap_err();
        assert_eq!(err.step, StepId::Files);
        assert_eq!(std::fs::read(p.install.join(MAIN_EXE)).unwrap(), b"v1", "the old app must stay");
        assert!(!p.install.join(format!("{MAIN_EXE}.new")).exists());
        std::fs::remove_dir_all(root).ok();
    }
}
