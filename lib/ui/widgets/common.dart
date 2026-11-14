import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../../core/i18n.dart';

// ============================================================ Page layout

/// Standard content page: a header (title, subtitle, actions) above a
/// scrollable or custom body, both constrained to a readable max width.
class PageScaffold extends StatelessWidget {
  final String title;
  final Widget? titleTrailing;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget body;
  final bool scrollable;
  final double maxWidth;
  final Widget? below; // e.g. a TabBar under the header

  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.titleTrailing,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.scrollable = true,
    this.maxWidth = 1240,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final gutter = narrow ? AppSpace.lg : AppSpace.page;

    // Fill the available width up to maxWidth (a bare ConstrainedBox under
    // Align shrink-wraps, which centred the header instead of aligning it
    // with the content).
    Widget constrain(Widget w) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: w),
          ),
        );

    final titleBlock = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(title,
                              style: t.headlineSmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (titleTrailing != null) ...[
                          const SizedBox(width: 10),
                          titleTrailing!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: t.bodyMedium,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          );

    final actionsBlock = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    // Title left, actions right; on narrow widths the actions move below.
    final header = Padding(
      padding: EdgeInsets.fromLTRB(gutter, narrow ? 16 : 26, gutter, 16),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  actionsBlock,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                      alignment: Alignment.centerLeft, child: titleBlock),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  actionsBlock,
                ],
              ],
            ),
    );

    final content = Padding(
      padding: EdgeInsets.fromLTRB(gutter, 4, gutter, gutter + 8),
      child: body,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        constrain(header),
        if (below != null) constrain(Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: below!,
        )),
        Expanded(
          child: scrollable
              ? SingleChildScrollView(child: constrain(content))
              : constrain(content),
        ),
      ],
    );
  }
}

/// Bordered card with an optional title row.
class Panel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Panel({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg + 2),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 0),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: c.muted),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: t.titleSmall),
                        if (subtitle != null)
                          Text(subtitle!, style: t.bodySmall),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

// ============================================================ Badges

enum Tone { neutral, primary, success, warning, danger }

class Pill extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dot;

  const Pill(this.label,
      {super.key, this.tone = Tone.neutral, this.icon, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = switch (tone) {
      Tone.neutral => (c.muted, c.hover),
      Tone.primary => (c.primary, c.primarySoft),
      Tone.success => (c.success, c.successSoft),
      Tone.warning => (c.warning, c.warningSoft),
      Tone.danger => (c.danger, c.dangerSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: tone == Tone.neutral ? Border.all(color: c.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }
}

/// Rounded square holding an icon; used as a list/tile leading.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final double size;
  const IconBadge(this.icon,
      {super.key, this.tone = Tone.primary, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = switch (tone) {
      Tone.neutral => (c.muted, c.hover),
      Tone.primary => (c.primary, c.primarySoft),
      Tone.success => (c.success, c.successSoft),
      Tone.warning => (c.warning, c.warningSoft),
      Tone.danger => (c.danger, c.dangerSoft),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
      child: Icon(icon, size: size * 0.48, color: fg),
    );
  }
}

/// Thin usage bar. With [warn] (quota usage) it turns amber above 75 % and
/// red above 90 %; without it (relative size comparisons) it stays primary.
class UsageBar extends StatelessWidget {
  final double value;
  final double height;
  final bool warn;
  const UsageBar(this.value, {super.key, this.height = 6, this.warn = true});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = value.clamp(0.0, 1.0);
    final color = !warn
        ? c.primary
        : v > 0.9
            ? c.danger
            : v > 0.75
                ? c.warning
                : c.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: v,
        minHeight: height,
        color: color,
        backgroundColor: c.border,
      ),
    );
  }
}

// ============================================================ Menus

/// "⋯" button whose menu opens below it, right-aligned to the button, so it
/// never runs off the right edge of the window from a table's last column.
class MoreMenu extends StatelessWidget {
  final List<Widget> children;
  final String tooltip;
  final double iconSize;
  static const double width = 220;

  const MoreMenu({
    super.key,
    required this.children,
    this.tooltip = 'More',
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
      ),
      alignmentOffset: const Offset(-width, 4),
      menuChildren: children,
      builder: (context, menu, _) => IconButton(
        tooltip: tr(tooltip),
        icon: Icon(LucideIcons.ellipsis, size: iconSize),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

// ============================================================ States

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 28 : 56, horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: AppRadius.xlAll,
                  border: Border.all(color: c.border),
                ),
                child: Icon(icon, size: 22, color: c.subtle),
              ),
              const SizedBox(height: 14),
              Text(title, style: t.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!,
                    style: t.bodyMedium, textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final ApiException error;
  final VoidCallback? onRetry;
  const ErrorState(this.error, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: error.isConnectionError
          ? LucideIcons.wifiOff
          : LucideIcons.triangleAlert,
      title: error.isConnectionError
          ? tr('Server unreachable')
          : tr('Something went wrong'),
      message: error.message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: Text(tr('Try again')),
            ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      );
}

/// Inline warning/info strip.
class Callout extends StatelessWidget {
  final String text;
  final Tone tone;
  final IconData? icon;
  final Widget? action;
  const Callout(this.text,
      {super.key, this.tone = Tone.warning, this.icon, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = switch (tone) {
      Tone.danger => (c.danger, c.dangerSoft),
      Tone.success => (c.success, c.successSoft),
      Tone.primary => (c.primary, c.primarySoft),
      Tone.neutral => (c.muted, c.hover),
      Tone.warning => (c.warning, c.warningSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
              icon ??
                  (tone == Tone.danger
                      ? LucideIcons.circleAlert
                      : LucideIcons.info),
              size: 16,
              color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.foreground)),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}

// ============================================================ Inputs

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.width = 240,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: tr(hint),
          prefixIcon: const Icon(LucideIcons.search, size: 16),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

/// Monospace value with a copy button and optional reveal toggle.
class CopyValue extends StatefulWidget {
  final String label;
  final String value;
  final bool secret;

  const CopyValue({
    super.key,
    required this.label,
    required this.value,
    this.secret = false,
  });

  @override
  State<CopyValue> createState() => _CopyValueState();
}

class _CopyValueState extends State<CopyValue> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final hidden = widget.secret && !_revealed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: t.labelMedium),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  hidden ? '•' * 24 : widget.value,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 12.5,
                    color: c.foreground,
                  ),
                ),
              ),
              if (widget.secret)
                IconButton(
                  tooltip: hidden ? tr('Show') : tr('Hide'),
                  icon: Icon(hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 15),
                  onPressed: () => setState(() => _revealed = !_revealed),
                ),
              IconButton(
                tooltip: tr('Copy'),
                icon: const Icon(LucideIcons.copy, size: 15),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.value));
                  showToast(context, tr('{label} copied', {'label': widget.label}));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================ Feedback

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(error ? LucideIcons.circleAlert : LucideIcons.circleCheck,
              size: 16,
              color: error ? const Color(0xFFF87171) : const Color(0xFF4ADE80)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      duration: Duration(seconds: error ? 6 : 3),
    ));
}

/// Runs a server call, showing [success] or the server's error as a toast.
/// Returns true when it succeeded.
Future<bool> runAction(BuildContext context, Future<void> Function() action,
    {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showToast(context, success);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return false;
  }
}

/// Generic dialog frame with consistent width and actions.
class AppDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Tone iconTone;
  final Widget? content;
  final List<Widget> actions;
  final double width;

  const AppDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconTone = Tone.primary,
    this.content,
    this.actions = const [],
    this.width = 440,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    IconBadge(icon!, tone: iconTone, size: 38),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleLarge),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!, style: t.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (content != null) ...[
                const SizedBox(height: 20),
                Flexible(child: SingleChildScrollView(child: content!)),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small inline spinner for buttons.
class ButtonSpinner extends StatelessWidget {
  final Color? color;
  const ButtonSpinner({super.key, this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

/// Confirmation dialog. When [typeToConfirm] is set, the confirm button is
/// enabled only after the user types that exact text.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = true,
  String? typeToConfirm,
  String? detail,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel ?? tr('Delete'),
      destructive: destructive,
      typeToConfirm: typeToConfirm,
      detail: detail,
    ),
  );
  return ok == true;
}

class _ConfirmDialog extends StatefulWidget {
  final String title, message, confirmLabel;
  final bool destructive;
  final String? typeToConfirm, detail;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    this.typeToConfirm,
    this.detail,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _enabled =>
      widget.typeToConfirm == null || _ctrl.text == widget.typeToConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return AppDialog(
      title: widget.title,
      icon: widget.destructive ? LucideIcons.trash2 : LucideIcons.info,
      iconTone: widget.destructive ? Tone.danger : Tone.primary,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: t.bodyLarge?.copyWith(color: c.muted)),
          if (widget.detail != null) ...[
            const SizedBox(height: 10),
            Text(widget.detail!,
                style: TextStyle(
                    fontFamily: AppFonts.mono, fontSize: 12, color: c.subtle)),
          ],
          if (widget.typeToConfirm != null) ...[
            const SizedBox(height: 16),
            Text.rich(TextSpan(
              style: t.bodyMedium,
              children: [
                TextSpan(text: tr('Type ')),
                TextSpan(
                    text: widget.typeToConfirm,
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontWeight: FontWeight.w600,
                        color: c.foreground)),
                TextSpan(text: tr(' to confirm.')),
              ],
            )),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_enabled) Navigator.pop(context, true);
              },
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          autofocus: widget.typeToConfirm == null,
          onPressed: _enabled ? () => Navigator.pop(context, true) : null,
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: c.danger, foregroundColor: Colors.white)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Single text input dialog (new folder name, …).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String initial = '',
  String? confirmLabel,
  IconData icon = LucideIcons.pencil,
  String? Function(String)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      hint: hint,
      initial: initial,
      confirmLabel: confirmLabel ?? tr('Save'),
      icon: icon,
      validator: validator,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  final String title, label, initial, confirmLabel;
  final String? hint;
  final IconData icon;
  final String? Function(String)? validator;

  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
    required this.icon,
    this.hint,
    this.validator,
  });

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    final err = v.isEmpty ? tr('{label} is required', {'label': widget.label}) : widget.validator?.call(v);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      icon: widget.icon,
      width: 400,
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
            labelText: widget.label, hintText: widget.hint, errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Label + value row used in detail panels.
class InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final double labelWidth;
  const InfoRow(this.label, this.value, {super.key, this.labelWidth = 130});

  factory InfoRow.text(String label, String value, {bool mono = false}) =>
      InfoRow(
        label,
        Builder(
          builder: (context) => Text(
            value,
            style: mono
                ? TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 12.5,
                    color: context.colors.foreground)
                : Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}
