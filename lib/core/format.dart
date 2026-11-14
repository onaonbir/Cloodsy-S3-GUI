/// Display formatting shared by every screen.
library;

String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes B';
  final fixed = value.toStringAsFixed(value >= 100 ? 0 : decimals);
  return '$fixed ${units[unit]}';
}

/// 1234567 → "1,234,567".
String formatCount(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

DateTime? parseServerDate(String iso) {
  if (iso.isEmpty) return null;
  return DateTime.tryParse(iso)?.toLocal();
}

String _two(int v) => v.toString().padLeft(2, '0');

/// "2026-11-14".
String formatDate(String iso) {
  final dt = parseServerDate(iso);
  if (dt == null) return iso.isEmpty ? '—' : iso;
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
}

/// "2026-11-14 09:05".
String formatDateTime(String iso) {
  final dt = parseServerDate(iso);
  if (dt == null) return iso.isEmpty ? '—' : iso;
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}';
}

/// "just now", "5 min ago", "3 h ago", "2 days ago", else the date.
String formatRelative(String iso, {DateTime? now}) {
  final dt = parseServerDate(iso);
  if (dt == null) return iso.isEmpty ? '—' : iso;
  final diff = (now ?? DateTime.now()).difference(dt);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) {
    return diff.inDays == 1 ? 'yesterday' : '${diff.inDays} days ago';
  }
  return formatDate(iso);
}

/// 93784 → "1d 2h 3m".
String formatUptime(int seconds) {
  if (seconds <= 0) return '—';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h ${m}m';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Compares dotted versions numerically ("1.10.0" > "1.9.2"). Pre-release
/// suffixes are ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .replaceFirst(RegExp(r'^v'), '')
      .split('-')
      .first
      .split('.')
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final ap = parts(a), bp = parts(b);
  final n = ap.length > bp.length ? ap.length : bp.length;
  for (var i = 0; i < n; i++) {
    final av = i < ap.length ? ap[i] : 0;
    final bv = i < bp.length ? bp[i] : 0;
    if (av != bv) return av < bv ? -1 : 1;
  }
  return 0;
}

/// Parses "10", "1.5 GB", "512mb" into bytes; null when invalid.
int? parseSize(String input, {String defaultUnit = 'GB'}) {
  final m = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]*)\s*$')
      .firstMatch(input);
  if (m == null) return null;
  final value = double.parse(m.group(1)!);
  final unit = (m.group(2)!.isEmpty ? defaultUnit : m.group(2)!).toUpperCase();
  const mult = {
    'B': 1,
    'K': 1024,
    'KB': 1024,
    'M': 1024 * 1024,
    'MB': 1024 * 1024,
    'G': 1024 * 1024 * 1024,
    'GB': 1024 * 1024 * 1024,
    'T': 1024 * 1024 * 1024 * 1024,
    'TB': 1024 * 1024 * 1024 * 1024,
  };
  final f = mult[unit];
  if (f == null) return null;
  return (value * f).round();
}

/// Lower-cased extension without the dot, or ''.
String fileExtension(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0 || i == name.length - 1) return '';
  return name.substring(i + 1).toLowerCase();
}

/// Best-effort content type from a file name, for uploads.
String guessContentType(String name) {
  const types = {
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'log': 'text/plain',
    'html': 'text/html',
    'htm': 'text/html',
    'css': 'text/css',
    'js': 'text/javascript',
    'mjs': 'text/javascript',
    'json': 'application/json',
    'xml': 'application/xml',
    'yaml': 'application/yaml',
    'yml': 'application/yaml',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'gz': 'application/gzip',
    'tar': 'application/x-tar',
    '7z': 'application/x-7z-compressed',
    'rar': 'application/vnd.rar',
    'wasm': 'application/wasm',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'avif': 'image/avif',
    'svg': 'image/svg+xml',
    'ico': 'image/x-icon',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'flac': 'audio/flac',
    'ogg': 'audio/ogg',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'ttf': 'font/ttf',
  };
  return types[fileExtension(name)] ?? 'application/octet-stream';
}
