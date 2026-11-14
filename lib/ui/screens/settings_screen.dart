import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app.dart' show appVersion;
import '../../core/desktop.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../state/gui_update_controller.dart';
import '../../state/prefs_controller.dart';
import '../../state/server_controller.dart';
import '../../state/session_controller.dart';
import '../../state/theme_controller.dart';
import '../dialogs/server_dialog.dart';
import '../shell/brand.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final prefs = context.watch<PrefsController>();
    final updates = context.watch<GuiUpdateController>();
    final session = context.watch<SessionController>();
    final status = context.watch<ServerController>().status;
    final server = session.server;
    final t = Theme.of(context).textTheme;

    Widget row(String label, Widget control, {String? hint}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.bodyLarge),
                    if (hint != null) Text(hint, style: t.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              control,
            ],
          ),
        );

    return PageScaffold(
      title: tr('Settings'),
      maxWidth: 820,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (updates.available) ...[
            Callout(
              tr('Cloodsy S3 GUI {v} is available (you have {c}).',
                  {'v': updates.latest!, 'c': appVersion}),
              tone: Tone.primary,
              icon: LucideIcons.sparkles,
              action: FilledButton(
                onPressed: () => Desktop.openUrl(updates.releaseUrl),
                child: Text(tr('Download')),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Panel(
            title: tr('Appearance'),
            icon: LucideIcons.palette,
            child: Column(
              children: [
                row(
                  tr('Theme'),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(LucideIcons.sun, size: 14),
                          label: Text(tr('Light'))),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(LucideIcons.moon, size: 14),
                          label: Text(tr('Dark'))),
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: const Icon(LucideIcons.monitor, size: 14),
                          label: Text(tr('System'))),
                    ],
                    selected: {theme.mode},
                    onSelectionChanged: (s) => theme.setMode(s.first),
                  ),
                ),
                row(
                  tr('Language'),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'en', label: Text(tr('English'))),
                      ButtonSegment(value: 'tr', label: Text(tr('Türkçe'))),
                      ButtonSegment(value: 'system', label: Text(tr('System'))),
                    ],
                    selected: {prefs.locale ?? 'system'},
                    onSelectionChanged: (s) =>
                        prefs.setLocale(s.first == 'system' ? null : s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: tr('Transfers'),
            icon: LucideIcons.arrowDownUp,
            child: Column(
              children: [
                row(
                  tr('Notify when transfers finish'),
                  Switch(
                      value: prefs.notifications,
                      onChanged: prefs.setNotifications),
                  hint: tr('System notification after a batch of uploads or downloads'),
                ),
                row(
                  tr('Download folder'),
                  Text(prefs.downloadDir ?? tr('Asks every time'),
                      style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 12,
                          color: context.colors.muted)),
                  hint: tr('The last folder you saved to is suggested next time'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (server != null)
            Panel(
              title: tr('Connection'),
              icon: LucideIcons.plug,
              actions: [
                TextButton.icon(
                  onPressed: () => showServerDialog(context, existing: server),
                  icon: const Icon(LucideIcons.pencil, size: 14),
                  label: Text(tr('Edit')),
                ),
              ],
              child: Column(
                children: [
                  InfoRow.text(tr('Server'), server.name),
                  InfoRow.text(tr('Admin API'), server.url, mono: true),
                  if (server.s3Url.isNotEmpty)
                    InfoRow.text(tr('S3 endpoint'), server.s3Url, mono: true),
                  InfoRow.text(tr('Signed in as'), session.username ?? '—'),
                  if (session.expiresAt != null)
                    InfoRow.text(
                        tr('Session'),
                        tr('Renews automatically · current token valid until {t}', {
                          't': formatDateTime(
                              session.expiresAt!.toUtc().toIso8601String())
                        })),
                  if (status != null)
                    InfoRow.text(tr('Server version'),
                        status.version.isEmpty ? '—' : 'v${status.version}'),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: session.disconnect,
                      icon: const Icon(LucideIcons.logOut, size: 15),
                      label: Text(tr('Disconnect')),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Panel(
            title: tr('Keyboard shortcuts'),
            icon: LucideIcons.keyboard,
            child: Column(
              children: [
                for (final (keys, what) in [
                  ('Ctrl+K', tr('Command palette: jump to any page, bucket or action')),
                  ('Ctrl+F', tr('Search files')),
                  ('Ctrl+U', tr('Upload files')),
                  ('Ctrl+A', tr('Select all files in the folder')),
                  ('↑ ↓ / Space', tr('Move between files / select')),
                  ('Enter', tr('Download the highlighted file')),
                  ('F2', tr('Rename')),
                  ('Delete', tr('Delete selected files')),
                  ('Backspace', tr('Up one folder')),
                  ('F5', tr('Refresh')),
                  ('Esc', tr('Clear selection / close details')),
                ])
                  InfoRow(
                    keys,
                    Text(what, style: t.bodyMedium),
                    labelWidth: 130,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: tr('About'),
            icon: LucideIcons.info,
            child: Row(
              children: [
                const BrandMark(size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Cloodsy S3 GUI'), style: t.titleSmall),
                      Text(
                          '${tr('Version')} $appVersion · OnaOnbir'
                          '${updates.checkedAt != null && !updates.available && updates.error == null ? ' · ${tr('up to date')}' : ''}',
                          style: t.bodySmall),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: updates.checking ? null : updates.check,
                  child: updates.checking
                      ? const ButtonSpinner()
                      : Text(tr('Check for updates')),
                ),
                TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Cloodsy S3 GUI',
                    applicationVersion: appVersion,
                  ),
                  child: Text(tr('Licenses')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
