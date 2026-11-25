// Esc for this tab's own overlays (object panel dialog, image viewer, PDF
// viewer). Every Modal listens on window in the capture phase, so Esc only
// closes an overlay when it is the topmost thing on the page (nothing was
// teleported to <body> after it, e.g. a dialog opened from it) and no menu
// or dialog listener has stopped the event already.

import { onBeforeUnmount, onMounted, type Ref } from 'vue';

export function useTopmostEsc(root: Ref<HTMLElement | null>, close: () => void) {
  function onKey(e: KeyboardEvent) {
    if (e.key !== 'Escape' || !root.value) return;
    // A menu or a dialog registered earlier already handled it.
    if (e.cancelBubble) return;
    if (document.body.lastElementChild !== root.value) return;
    e.stopPropagation();
    e.preventDefault();
    close();
  }
  onMounted(() => window.addEventListener('keydown', onKey, true));
  onBeforeUnmount(() => window.removeEventListener('keydown', onKey, true));
}
