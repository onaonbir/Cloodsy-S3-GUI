// Any dialog component as a promise: openDialog(Comp, props) mounts it (in
// OverlayHost) with an extra `done` prop; calling done(value) closes it and
// resolves the promise (null when dismissed).
//
//   const name = await openDialog<string>(CreateBucketDialog, {});
//   // in the dialog: defineProps<{ done: (v: string | null) => void }>()

import { markRaw, shallowRef, type Component } from 'vue';

interface Overlay { id: number; component: Component; props: Record<string, unknown>; resolve: (v: unknown) => void }

export const overlays = shallowRef<Overlay[]>([]);
let next = 1;

export function openDialog<T>(component: Component, props: Record<string, unknown> = {}): Promise<T | null> {
  return new Promise((resolve) => {
    const id = next++;
    const o: Overlay = {
      id,
      component: markRaw(component),
      props: {
        ...props,
        done: (v: T | null) => {
          overlays.value = overlays.value.filter((x) => x.id !== id);
          resolve(v ?? null);
        },
      },
      resolve: resolve as (v: unknown) => void,
    };
    overlays.value = [...overlays.value, o];
  });
}

/** Closes every open dialog (session ended). */
export function closeAllDialogs() {
  for (const o of overlays.value) o.resolve(null);
  overlays.value = [];
}
