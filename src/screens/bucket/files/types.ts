// What the object panel and menus can do with an object; FilesTab supplies
// the implementations (pickers, transfers, refresh). A missing entry means
// the server lacks the feature.

import type { ObjectInfo, S3Object } from '@/lib/api';

export interface ObjectActions {
  download?: (o: S3Object) => void;
  share: (o: S3Object) => void;
  rename?: (o: S3Object) => void;
  moveCopy?: (o: S3Object) => void;
  editMetadata?: (o: S3Object, info?: ObjectInfo | null) => void;
  versions?: (o: S3Object) => void;
  delete: (o: S3Object) => void;
}
