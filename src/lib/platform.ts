// The OS the app runs on (from the user agent; fine for layout decisions).

const ua = navigator.userAgent;
export const platform: 'windows' | 'macos' | 'linux' = /Windows/i.test(ua) ? 'windows' : /Mac OS|Macintosh/i.test(ua) ? 'macos' : 'linux';
/** Windows and macOS draw the app's own title bar; Linux keeps the system one. */
export const customTitleBar = platform !== 'linux';
/** "Ctrl" or "⌘" for shortcut labels. */
export const mod = platform === 'macos' ? '⌘' : 'Ctrl';
/** Ctrl on Windows/Linux, Cmd on macOS. */
export const isMod = (e: KeyboardEvent | MouseEvent) => (platform === 'macos' ? e.metaKey : e.ctrlKey);
