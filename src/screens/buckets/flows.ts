// Bucket create and delete, shared by the dashboard, the bucket table, the
// bucket screen and the command palette (2.0 buckets_screen.dart).

import { confirm } from '@/lib/dialogs';
import { openDialog } from '@/lib/overlay';
import type { ApiError } from '@/lib/ipc';
import { t } from '@/lib/i18n';
import { buckets, loadBuckets, useApi } from '@/stores/session';
import { forgetBucket, goBucket } from '@/stores/nav';
import { toast, toastError } from '@/stores/toasts';
import CreateBucketDialog from './CreateBucketDialog.vue';
import { isBusyMessage } from './logic';

/** The create dialog; on success refreshes the list and opens the new bucket. */
export async function createBucketFlow(): Promise<string | null> {
  const name = await openDialog<string>(CreateBucketDialog);
  if (!name) return null;
  toast(t('Bucket “{name}” created', { name }));
  await loadBuckets();
  goBucket(name, 'overview');
  return name;
}

/**
 * Deletes after a confirmation. When the server refuses with 409 because
 * objects, versions or delete markers remain (not because the bucket is busy),
 * offers "Delete everything": type the name, then a forced delete (long
 * timeout). Answers true when the bucket is gone.
 */
export async function deleteBucketFlow(name: string): Promise<boolean> {
  const ok = await confirm({
    title: t('Delete bucket'),
    message: t('Delete the bucket “{name}”? The server refuses if it still contains objects.', { name }),
    confirmLabel: t('Delete'),
    danger: true,
  });
  if (!ok) return false;
  const api = useApi();
  try {
    await api.deleteBucket(name);
  } catch (e) {
    const err = e as ApiError;
    if (err.status === -1) return false;
    if (err.status !== 409 || isBusyMessage(err.message)) {
      toastError(err);
      return false;
    }
    const force = await confirm({
      title: t('Bucket is not empty'),
      message: t('Delete anyway removes every object, all versions and delete markers together with the bucket. This cannot be undone.'),
      detail: err.message,
      confirmLabel: t('Delete everything'),
      typeToConfirm: name,
      danger: true,
    });
    if (!force) return false;
    try {
      await api.deleteBucket(name, true);
    } catch (e2) {
      if ((e2 as ApiError).status !== -1) toastError(e2);
      return false;
    }
  }
  forgetBucket(name);
  buckets.value = buckets.value.filter((b) => b.name !== name);
  toast(t('Bucket “{name}” deleted', { name }));
  void loadBuckets();
  return true;
}
