// Open modals in opening order: Esc belongs to the topmost one only.

const stack: number[] = [];
let next = 1;

export function pushModal(): number {
  const id = next++;
  stack.push(id);
  return id;
}

export function popModal(id: number) {
  const i = stack.indexOf(id);
  if (i >= 0) stack.splice(i, 1);
}

export function isTopModal(id: number): boolean {
  return stack[stack.length - 1] === id;
}

/** Whether any modal is open (e.g. to ignore page shortcuts and drops). */
export function anyModalOpen(): boolean {
  return stack.length > 0;
}
