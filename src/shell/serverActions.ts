// Actions on the connected server shared by the sidebar and Settings.

import { confirm } from '@/lib/dialogs';
import { t } from '@/lib/i18n';
import { disconnect, server } from '@/stores/session';
import { removeServer } from '@/stores/servers';
import { toastError } from '@/stores/toasts';

/** Asks, disconnects and forgets the current server and its saved password. */
export async function removeCurrentServer() {
  const s = server.value;
  if (!s) return;
  const ok = await confirm({
    title: t('Remove server'),
    message: t('Remove {name} and its saved password from this computer?', { name: s.name }),
    confirmLabel: t('Remove'),
    danger: true,
  });
  if (!ok) return;
  await disconnect();
  await removeServer(s.id).catch(toastError);
}
