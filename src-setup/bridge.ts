// The setup window's link to its Rust side (installer/setup/src/ui.rs). In a
// plain browser (design work, screenshots) a stand-in answers:
// ?mode=install|update|reinstall|downgrade|uninstall&scene=options|done|error&fail=<step>&trial&auto
import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';

export type Mode = 'install' | 'update' | 'reinstall' | 'downgrade' | 'uninstall';
export type StepId = 'prepare' | 'files' | 'register' | 'close' | 'remove' | 'clean';
export type StepState = 'running' | 'done' | 'failed' | 'skipped';
export interface Info {
  mode: Mode;
  version: string;
  installed: string | null;
  dir: string;
  default_dir: string;
  dir_locked: boolean;
  desktop: boolean;
  auto_start: boolean;
  trial: boolean;
  log: string;
  /** The installed app's language, when it has chosen one. */
  language: 'en' | 'tr' | null;
}
export interface Step {
  id: StepId;
  state: StepState;
  detail: string;
}
export interface Done {
  ok: boolean;
  message: string;
  detail: string;
  step: StepId | null;
}

const inTauri = '__TAURI_INTERNALS__' in window;
const q = new URLSearchParams(location.search);

const mock = {
  info(): Info {
    const mode = (q.get('mode') as Mode) || 'install';
    const dir = 'C:\\Users\\Deniz\\AppData\\Local\\Programs\\Cloodsy S3 GUI';
    return {
      mode,
      version: '3.0.1',
      installed: mode === 'install' ? null : mode === 'reinstall' ? '3.0.1' : mode === 'downgrade' ? '3.1.0' : '3.0.0',
      dir,
      default_dir: dir,
      dir_locked: mode !== 'install',
      desktop: true,
      auto_start: q.has('auto'),
      trial: q.has('trial'),
      log: 'C:\\Users\\Deniz\\AppData\\Local\\Temp\\cloodsy-s3-gui-setup.log',
      language: (q.get('lang') as 'en' | 'tr' | null) ?? null,
    };
  },
  onStep: null as ((s: Step) => void) | null,
  onDone: null as ((d: Done) => void) | null,
  run(ids: StepId[]) {
    const fail = q.get('fail');
    ids.forEach((id, i) => {
      setTimeout(() => this.onStep?.({ id, state: 'running', detail: '' }), 500 * i);
      setTimeout(
        () => {
          if (fail === id) {
            this.onStep?.({ id, state: 'failed', detail: '' });
            this.onDone?.({ ok: false, message: 'swap', detail: 'cloodsy-s3.exe: Access is denied. (os error 5)', step: id });
            return;
          }
          this.onStep?.({ id, state: id === 'clean' ? 'skipped' : 'done', detail: id === 'files' ? '9.8 MB' : id === 'clean' ? 'kept' : '' });
          if (i === ids.length - 1) setTimeout(() => this.onDone?.({ ok: true, message: '', detail: '', step: null }), 200);
        },
        500 * i + 400,
      );
    });
  },
};

export const bridge = {
  info: () => (inTauri ? invoke<Info>('info') : Promise.resolve(mock.info())),
  install: (dir: string | null, desktop: boolean, language: 'en' | 'tr' | null) =>
    inTauri ? invoke<void>('start_install', { dir, desktop, language }) : Promise.resolve(mock.run(['prepare', 'files', 'register'])),
  uninstall: (wipe: boolean) => (inTauri ? invoke<void>('start_uninstall', { wipe }) : Promise.resolve(mock.run(['close', 'remove', 'clean']))),
  pickDir: (current: string, title: string) => (inTauri ? invoke<string | null>('pick_dir', { current, title }) : Promise.resolve(null)),
  launch: () => (inTauri ? invoke<void>('launch') : Promise.resolve()),
  openLog: () => (inTauri ? invoke<void>('open_log') : Promise.resolve()),
  minimize: () => (inTauri ? invoke<void>('minimize') : Promise.resolve()),
  close: () => (inTauri ? invoke<void>('close') : Promise.resolve()),
  async onStep(h: (s: Step) => void): Promise<UnlistenFn> {
    if (!inTauri) {
      mock.onStep = h;
      return () => {};
    }
    return listen<Step>('setup-step', (e) => h(e.payload));
  },
  async onDone(h: (d: Done) => void): Promise<UnlistenFn> {
    if (!inTauri) {
      mock.onDone = h;
      return () => {};
    }
    return listen<Done>('setup-done', (e) => h(e.payload));
  },
};
