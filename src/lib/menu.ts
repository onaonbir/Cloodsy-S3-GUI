// Context and "⋯" menus: openMenu(event, items); MenuHost renders them.

import { shallowRef, type Component } from 'vue';

export interface MenuItem {
  label: string;
  icon?: Component;
  shortcut?: string;
  danger?: boolean;
  disabled?: boolean;
  checked?: boolean;
  action?: () => void;
}
/** A separator. */
export const SEP = { label: '-' } as MenuItem;

export const menu = shallowRef<{ x: number; y: number; items: MenuItem[] } | null>(null);

/** Opens at the mouse (context menu) or under the clicked element. */
export function openMenu(e: MouseEvent, items: MenuItem[]) {
  e.preventDefault();
  e.stopPropagation();
  let x = e.clientX;
  let y = e.clientY;
  if (e.type === 'click' && e.currentTarget instanceof HTMLElement) {
    const r = e.currentTarget.getBoundingClientRect();
    x = r.right;
    y = r.bottom + 4;
  }
  menu.value = { x, y, items: items.filter((i, idx, all) => !(i.label === '-' && (idx === 0 || all[idx - 1].label === '-'))) };
}

export function closeMenu() {
  menu.value = null;
}
