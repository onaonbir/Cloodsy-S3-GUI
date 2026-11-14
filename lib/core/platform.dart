import 'dart:io';

import 'package:flutter/foundation.dart';

bool get isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

bool get isMacOS => !kIsWeb && Platform.isMacOS;

/// Whether the app draws its own title bar. Not on Linux: window_manager's
/// native backend can't move a window from Flutter widgets there yet
/// (DragToMoveArea is unimplemented), so Linux keeps the system title bar.
bool get useCustomTitleBar =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS);
