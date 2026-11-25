// File icons by extension (2.0 files_tab.dart fileIcon).

import type { Component } from 'vue';
import { File, FileArchive, FileCode, FileHeadphone, FileImage, FileSpreadsheet, FileText, FileVideoCamera } from 'lucide-vue-next';
import { extOf } from './helpers';

const groups: [Component, string[]][] = [
  [FileImage, ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'avif', 'bmp', 'ico']],
  [FileText, ['pdf', 'txt', 'md', 'log', 'rtf', 'doc', 'docx']],
  [FileVideoCamera, ['mp4', 'mov', 'avi', 'mkv', 'webm']],
  [FileHeadphone, ['mp3', 'wav', 'flac', 'ogg', 'm4a']],
  [FileArchive, ['zip', 'tar', 'gz', 'rar', '7z', 'bz2', 'xz']],
  [FileCode, ['json', 'xml', 'yaml', 'yml', 'js', 'ts', 'dart', 'go', 'py', 'html', 'css', 'sh']],
  [FileSpreadsheet, ['csv', 'xls', 'xlsx']],
];
const byExt = new Map<string, Component>(groups.flatMap(([icon, exts]) => exts.map((e) => [e, icon] as [string, Component])));

export function fileIcon(key: string): Component {
  return byExt.get(extOf(key)) ?? File;
}
