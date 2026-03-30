import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

class WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String? serverName;
  final Widget? leading;

  const WindowTitleBar({super.key, this.serverName, this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 40,
        color: theme.colorScheme.surface,
        child: Row(
          children: [
            if (leading != null) leading!,
            const SizedBox(width: 12),
            Icon(LucideIcons.cloud,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Cloodsy S3',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            if (serverName != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: TextStyle(color: theme.colorScheme.outline)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  serverName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const Spacer(),
            // Window controls
            _WindowButton(
              icon: LucideIcons.minus,
              onPressed: () => windowManager.minimize(),
              hoverColor: theme.colorScheme.surfaceContainerHighest,
            ),
            _MaximizeButton(isDark: isDark),
            _WindowButton(
              icon: LucideIcons.x,
              onPressed: () => windowManager.close(),
              hoverColor: const Color(0xFFE81123),
              hoverIconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  final bool isDark;
  const _MaximizeButton({required this.isDark});

  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _WindowButton(
      icon: _isMaximized ? LucideIcons.copy : LucideIcons.square,
      iconSize: _isMaximized ? 13 : 15,
      onPressed: () async {
        if (_isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
        _checkMaximized();
      },
      hoverColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  const _WindowButton({
    required this.icon,
    this.iconSize = 15,
    required this.onPressed,
    required this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = _hovering && widget.hoverIconColor != null
        ? widget.hoverIconColor!
        : theme.colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 40,
          color: _hovering ? widget.hoverColor : Colors.transparent,
          child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
        ),
      ),
    );
  }
}

bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
