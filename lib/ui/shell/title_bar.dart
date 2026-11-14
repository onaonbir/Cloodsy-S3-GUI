import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform.dart';
import '../../state/session_controller.dart';
import '../../state/theme_controller.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'brand.dart';
import '../../core/i18n.dart';

/// Custom title bar for the frameless desktop window. On macOS the native
/// traffic lights stay visible (title bar style "hidden"), so only space is
/// reserved for them; Windows and Linux get drawn caption buttons.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<SessionController>();
    final server = session.server;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.titleBar,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  SizedBox(width: isMacOS ? 80 : 14),
                  const BrandMark(size: 20),
                  const SizedBox(width: 8),
                  Text(tr('Cloodsy S3'),
                      style: Theme.of(context).textTheme.titleSmall),
                  if (server != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(LucideIcons.chevronRight,
                          size: 14, color: c.subtle),
                    ),
                    Flexible(
                      child: Text(
                        server.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: c.muted),
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 6),
          if (!isMacOS) const _CaptionButtons(),
          if (isMacOS) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Light/dark quick toggle with a menu for "System".
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final brightness = Theme.of(context).brightness;
    return MenuAnchor(
      alignmentOffset: const Offset(-120, 4),
      menuChildren: [
        for (final m in ThemeMode.values)
          MenuItemButton(
            leadingIcon: Icon(
              switch (m) {
                ThemeMode.light => LucideIcons.sun,
                ThemeMode.dark => LucideIcons.moon,
                ThemeMode.system => LucideIcons.monitor,
              },
              size: 16,
            ),
            trailingIcon: theme.mode == m
                ? const Icon(LucideIcons.check, size: 16)
                : null,
            onPressed: () => theme.setMode(m),
            child: Text(tr(ThemeController.label(m))),
          ),
      ],
      builder: (context, menu, _) => GestureDetector(
        onSecondaryTap: menu.open,
        onLongPress: menu.open,
        child: IconButton(
          tooltip: tr('Theme: {mode} (right-click for options)',
              {'mode': tr(ThemeController.label(theme.mode))}),
          icon: Icon(
              brightness == Brightness.dark
                  ? LucideIcons.moon
                  : LucideIcons.sun,
              size: 16),
          onPressed: () => theme.toggle(brightness),
        ),
      ),
    );
  }
}

class _CaptionButtons extends StatefulWidget {
  const _CaptionButtons();

  @override
  State<_CaptionButtons> createState() => _CaptionButtonsState();
}

class _CaptionButtonsState extends State<_CaptionButtons> {
  Window? _window;
  ListenerId? _listener;
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    _window = WindowManager.instance.getCurrent();
    _maximized = _window?.isMaximized ?? false;
    // The window can also be maximized by double-clicking the title bar,
    // Windows snap or keyboard shortcuts; follow the native state.
    _listener = _window?.addListener((event) {
      if (event is WindowMaximizedEvent ||
          event is WindowRestoredEvent ||
          event is WindowResizedEvent) {
        final now = _window?.isMaximized ?? false;
        if (mounted && now != _maximized) {
          setState(() => _maximized = now);
        }
      }
    });
  }

  @override
  void dispose() {
    final id = _listener;
    if (id != null) _window?.removeListener(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = _window;
    return Row(
      children: [
        _CaptionButton(
          icon: LucideIcons.minus,
          onPressed: () => w?.minimize(),
        ),
        MaximizeButtonArea(
          child: _CaptionButton(
            icon: _maximized ? LucideIcons.copy : LucideIcons.square,
            iconSize: _maximized ? 13 : 12,
            onPressed: () {
              if (w == null) return;
              _maximized ? w.unmaximize() : w.maximize();
            },
          ),
        ),
        _CaptionButton(
          icon: LucideIcons.x,
          close: true,
          onPressed: () => unawaited(Future(() => w?.close())),
        ),
      ],
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final bool close;

  const _CaptionButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 15,
    this.close = false,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = !_hover
        ? Colors.transparent
        : widget.close
            ? const Color(0xFFE81123)
            : c.hover;
    final fg = _hover && widget.close ? Colors.white : c.muted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: 46,
          height: TitleBar.height,
          color: bg,
          child: Icon(widget.icon, size: widget.iconSize, color: fg),
        ),
      ),
    );
  }
}
