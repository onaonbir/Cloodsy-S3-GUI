import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../models/bucket.dart';
import '../../models/server_connection.dart';
import '../../models/server_status.dart';
import '../../state/navigation_controller.dart';
import '../../state/server_admin_controllers.dart';
import '../../state/servers_controller.dart';
import '../../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../widgets/bar_chart.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

Widget serverPage(ServerPage page) => switch (page) {
      ServerPage.sessions => const SessionsScreen(),
      ServerPage.logs => const LogsScreen(),
      ServerPage.metrics => const MetricsScreen(),
      ServerPage.maintenance => const MaintenanceScreen(),
      ServerPage.config => const ConfigScreen(),
      ServerPage.servers => const AllServersScreen(),
    };

ApiClient _api(BuildContext c) => c.read<SessionController>().api;

// ============================================================ Sessions

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => SessionsController(_api(c))..load(),
        child: const _SessionsView(),
      );
}

class _SessionsView extends StatelessWidget {
  const _SessionsView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SessionsController>();
    final session = context.read<SessionController>();
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    Widget body;
    if (!ctrl.loadedOnce) {
      body = const LoadingView();
    } else if (ctrl.error != null && ctrl.sessions.isEmpty) {
      body = ErrorState(ctrl.error!, onRetry: ctrl.load);
    } else {
      body = Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < ctrl.sessions.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              Builder(builder: (context) {
                final s = ctrl.sessions[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                  child: Row(
                    children: [
                      IconBadge(
                          _deviceIcon(s.userAgent),
                          tone: s.current ? Tone.primary : Tone.neutral,
                          size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(s.username, style: t.titleSmall),
                                if (s.current)
                                  Pill(tr('This app'), tone: Tone.primary),
                              ],
                            ),
                            Text(
                              '${s.ip.isEmpty ? tr('unknown IP') : s.ip} · '
                              '${_agent(s.userAgent)}',
                              style: t.bodyMedium,
                            ),
                            Text(
                              tr('Active {a} · signed in {s} · expires {e}', {
                                'a': formatRelative(s.lastSeenAt),
                                's': formatDateTime(s.createdAt),
                                'e': formatDateTime(s.expiresAt),
                              }),
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await confirm(context,
                              title: tr('End session'),
                              message: s.current
                                  ? tr('End your own session? You will be disconnected.')
                                  : tr('Sign “{u}” out on that device?', {'u': s.username}),
                              confirmLabel: tr('End session'));
                          if (!ok || !context.mounted) return;
                          if (s.current) {
                            await session.disconnect();
                          } else {
                            await runAction(context, () => ctrl.revoke(s.id),
                                success: 'Session ended');
                          }
                        },
                        child: Text(tr('End')),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );
    }

    return PageScaffold(
      title: tr('Sessions'),
      subtitle: tr('Admin API sign-ins on this server.'),
      maxWidth: 960,
      actions: [
        IconButton(
          tooltip: tr('Refresh'),
          onPressed: ctrl.loading ? null : ctrl.load,
          icon: ctrl.loading
              ? const ButtonSpinner()
              : const Icon(LucideIcons.refreshCw, size: 16),
        ),
      ],
      body: body,
    );
  }

  static IconData _deviceIcon(String ua) {
    final u = ua.toLowerCase();
    if (u.contains('dart') || u.contains('cloodsy')) return LucideIcons.monitor;
    if (u.contains('curl') || u.contains('python') || u.contains('go-http')) {
      return LucideIcons.terminal;
    }
    if (u.contains('mozilla')) return LucideIcons.globe;
    return LucideIcons.keyRound;
  }

  static String _agent(String ua) {
    if (ua.isEmpty) return 'unknown client';
    final u = ua.toLowerCase();
    if (u.startsWith('dart')) return 'Cloodsy S3 GUI';
    return ua.length > 60 ? '${ua.substring(0, 60)}…' : ua;
  }
}

// ============================================================ Logs

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => LogsController(_api(c))..start(),
        child: const _LogsView(),
      );
}

class _LogsView extends StatefulWidget {
  const _LogsView();
  @override
  State<_LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<_LogsView> {
  final _scroll = ScrollController();
  final _query = TextEditingController();
  Timer? _debounce;
  bool _follow = true;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final atEnd =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 24;
      if (atEnd != _follow) setState(() => _follow = atEnd);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Color _levelColor(BuildContext context, String level) {
    final c = context.colors;
    return switch (level) {
      'ERROR' => c.danger,
      'WARN' || 'WARNING' => c.warning,
      'DEBUG' => c.subtle,
      _ => c.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LogsController>();
    final c = context.colors;
    final entries = ctrl.entries;

    if (entries.length != _lastCount) {
      _lastCount = entries.length;
      if (_follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    }

    return PageScaffold(
      title: tr('Activity log'),
      subtitle: tr('Live server log (last {n} lines).', {'n': LogsController.maxEntries}),
      scrollable: false,
      maxWidth: 1400,
      actions: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'DEBUG', label: Text(tr('All'))),
            ButtonSegment(value: 'INFO', label: Text(tr('Info+'))),
            ButtonSegment(value: 'WARN', label: Text(tr('Warn+'))),
            ButtonSegment(value: 'ERROR', label: Text(tr('Errors'))),
          ],
          selected: {ctrl.level},
          onSelectionChanged: (s) => ctrl.setFilter(level: s.first),
        ),
        SearchField(
          hint: tr('Search log'),
          width: 200,
          controller: _query,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400),
                () => ctrl.setFilter(query: v.trim()));
          },
        ),
        IconButton(
          tooltip: ctrl.paused ? 'Resume' : 'Pause',
          icon: Icon(ctrl.paused ? LucideIcons.play : LucideIcons.pause,
              size: 16),
          onPressed: () => ctrl.setPaused(!ctrl.paused),
        ),
        IconButton(
          tooltip: tr('Copy visible lines'),
          icon: const Icon(LucideIcons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(
                text: entries
                    .map((e) =>
                        '${e.time} ${e.level} ${e.message} ${e.attrs.entries.map((a) => '${a.key}=${a.value}').join(' ')}')
                    .join('\n')));
            showToast(context, tr('{n} lines copied', {'n': entries.length}));
          },
        ),
        IconButton(
          tooltip: tr('Clear view'),
          icon: const Icon(LucideIcons.eraser, size: 16),
          onPressed: ctrl.clear,
        ),
      ],
      body: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: !ctrl.loadedOnce
            ? const LoadingView()
            : ctrl.error != null && entries.isEmpty
                ? ErrorState(ctrl.error!)
                : entries.isEmpty
                    ? EmptyState(
                        icon: LucideIcons.scrollText,
                        title: tr('No log lines yet'),
                        compact: true)
                    : Stack(
                        children: [
                          SelectionArea(
                            child: ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: entries.length,
                              itemExtent: 24,
                              itemBuilder: (context, i) {
                                final e = entries[i];
                                final time = parseServerDate(e.time);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          time == null
                                              ? ''
                                              : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                              fontFamily: AppFonts.mono,
                                              fontSize: 12,
                                              color: c.subtle),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 52,
                                        child: Text(e.level,
                                            style: TextStyle(
                                                fontFamily: AppFonts.mono,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: _levelColor(
                                                    context, e.level))),
                                      ),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(children: [
                                            TextSpan(
                                                text: e.message,
                                                style: TextStyle(
                                                    color: c.foreground)),
                                            for (final a in e.attrs.entries)
                                              TextSpan(
                                                  text: '  ${a.key}=',
                                                  style: TextStyle(
                                                      color: c.subtle),
                                                  children: [
                                                    TextSpan(
                                                        text: a.value,
                                                        style: TextStyle(
                                                            color: c.muted)),
                                                  ]),
                                          ]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontFamily: AppFonts.mono,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (!_follow)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: FilledButton.icon(
                                onPressed: () {
                                  setState(() => _follow = true);
                                  _scroll.jumpTo(
                                      _scroll.position.maxScrollExtent);
                                },
                                icon: const Icon(LucideIcons.arrowDown,
                                    size: 15),
                                label: Text(tr('Follow')),
                              ),
                            ),
                          if (ctrl.paused)
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Pill(tr('Paused'), tone: Tone.warning,
                                  icon: LucideIcons.pause),
                            ),
                        ],
                      ),
      ),
    );
  }
}

// ============================================================ Metrics

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => MetricsController(_api(c))..start(),
        child: const _MetricsView(),
      );
}

class _MetricsView extends StatelessWidget {
  const _MetricsView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MetricsController>();
    final m = ctrl.metrics;

    if (m == null) {
      return ctrl.error != null
          ? ErrorState(ctrl.error!, onRetry: ctrl.load)
          : const LoadingView();
    }

    String hm(String iso) {
      final d = parseServerDate(iso);
      if (d == null) return '';
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    final labels = m.series.map((p) => hm(p.time)).toList();
    final errRate =
        m.requests == 0 ? 0.0 : (m.errors4xx + m.errors5xx) / m.requests;

    Widget tile(String label, String value, String caption) => Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(caption, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    Widget chart(String title, List<double> v, String Function(double) f) =>
        Panel(
          title: title,
          subtitle: tr('Per minute, last 60 minutes'),
          child: MiniBarChart(values: v, labels: labels, format: f),
        );

    return PageScaffold(
      title: tr('Metrics'),
      subtitle: tr('S3 API traffic since {t} (refreshes every 10 s).', {'t': formatDateTime(m.since)}),
      actions: [
        IconButton(
          tooltip: tr('Refresh'),
          onPressed: ctrl.loading ? null : ctrl.load,
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
      ],
      body: LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 900 ? 4 : 2;
        final w = (box.maxWidth - 14 * (cols - 1)) / cols;
        final half = box.maxWidth > 900 ? (box.maxWidth - 14) / 2 : box.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
                width: w,
                child: tile(tr('Requests'), formatCount(m.requests),
                    m.byMethod.entries.map((e) => '${e.key} ${formatCount(e.value)}').join(' · '))),
            SizedBox(
                width: w,
                child: tile(tr('Errors'), '${(errRate * 100).toStringAsFixed(1)}%',
                    '${formatCount(m.errors4xx)} 4xx · ${formatCount(m.errors5xx)} 5xx')),
            SizedBox(
                width: w,
                child: tile(tr('Uploaded'), formatBytes(m.bytesIn), 'request bodies')),
            SizedBox(
                width: w,
                child: tile(tr('Downloaded'), formatBytes(m.bytesOut), 'response bodies')),
            SizedBox(
                width: half,
                child: chart(tr('Requests'),
                    m.series.map((p) => p.requests.toDouble()).toList(),
                    (v) => tr('{n} requests', {'n': v.round()}))),
            SizedBox(
                width: half,
                child: chart(tr('Errors'),
                    m.series.map((p) => p.errors.toDouble()).toList(),
                    (v) => tr('{n} errors', {'n': v.round()}))),
            SizedBox(
                width: half,
                child: chart(tr('Uploaded'),
                    m.series.map((p) => p.bytesIn.toDouble()).toList(),
                    (v) => formatBytes(v.round()))),
            SizedBox(
                width: half,
                child: chart(tr('Downloaded'),
                    m.series.map((p) => p.bytesOut.toDouble()).toList(),
                    (v) => formatBytes(v.round()))),
          ],
        );
      }),
    );
  }
}

// ============================================================ Maintenance

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => MaintenanceController(_api(c)),
        child: const _MaintenanceView(),
      );
}

class _MaintenanceView extends StatelessWidget {
  const _MaintenanceView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MaintenanceController>();
    final r = ctrl.report;
    final t = Theme.of(context).textTheme;
    final c = context.colors;

    Widget list<T>(String title, String explain, IconData icon, List<T> items,
            Widget Function(T) row, {List<Widget> actions = const []}) =>
        Panel(
          title: '$title (${items.length})',
          subtitle: explain,
          icon: icon,
          actions: actions,
          child: items.isEmpty
              ? Row(children: [
                  Icon(LucideIcons.circleCheck, size: 15, color: c.success),
                  const SizedBox(width: 8),
                  Text(tr('Nothing found'), style: t.bodyMedium),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final i in items.take(200)) row(i)],
                ),
        );

    Widget mono(String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SelectableText(s,
              style: TextStyle(
                  fontFamily: AppFonts.mono, fontSize: 12, color: c.foreground)),
        );

    return PageScaffold(
      title: tr('Maintenance'),
      subtitle: tr('Check that the database and the files on disk agree.'),
      maxWidth: 1000,
      actions: [
        FilledButton.icon(
          onPressed: ctrl.loading ? null : ctrl.scan,
          icon: ctrl.loading
              ? const ButtonSpinner()
              : const Icon(LucideIcons.scanSearch, size: 16),
          label: Text(r == null ? 'Run scan' : 'Scan again'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ctrl.error != null) ...[
            Callout(ctrl.error!.message, tone: Tone.danger),
            const SizedBox(height: 16),
          ],
          if (r == null && !ctrl.loading)
            Panel(
              child: EmptyState(
                compact: true,
                icon: LucideIcons.scanSearch,
                title: tr('No scan yet'),
                message: tr('The scan is read-only. It lists leftover bucket '
                    'folders, objects whose file is missing and files no '
                    'object points to.'),
              ),
            ),
          if (r != null) ...[
            Callout(
              r.clean
                  ? tr('All {n} objects are consistent with the disk.', {'n': formatCount(r.scannedObjects)})
                  : tr('Scanned {n} objects at {t}.', {'n': formatCount(r.scannedObjects), 't': formatDateTime(ctrl.scannedAt!.toUtc().toIso8601String())}) +
                      (r.truncated ? ' ${tr('Lists are capped; fix and scan again to see more.')}' : ''),
              tone: r.clean ? Tone.success : Tone.warning,
            ),
            const SizedBox(height: 16),
            list(
              tr('Orphan folders'),
              'Bucket-named folders with no bucket in the database (e.g. left over after a delete).',
              LucideIcons.folderX,
              r.orphanDirs,
              (d) => Row(children: [
                Expanded(child: mono(d.path)),
                Text(formatBytes(d.bytes), style: t.bodySmall),
              ]),
              actions: [
                if (r.orphanDirs.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final ok = await confirm(context,
                          title: tr('Delete orphan folders'),
                          message:
                              tr('Permanently delete {n} folder(s) ({size}) from the server disk? The server re-checks each path first.', {
                                'n': r.orphanDirs.length,
                                'size': formatBytes(r.orphanDirs.fold(0, (s, d) => s + d.bytes)),
                              }),
                          typeToConfirm: 'delete');
                      if (!ok || !context.mounted) return;
                      try {
                        final res = await ctrl.deleteOrphanDirs(
                            r.orphanDirs.map((d) => d.path).toList());
                        if (!context.mounted) return;
                        showToast(
                            context,
                            res.failed.isEmpty
                                ? tr('{n} folder(s) deleted', {'n': res.deleted})
                                : '${tr('{ok} deleted, {failed} failed', {'ok': res.deleted, 'failed': res.failed.length})}: ${res.failed.first}',
                            error: res.failed.isNotEmpty);
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          showToast(context, e.message, error: true);
                        }
                      }
                    },
                    child: Text(tr('Delete all…')),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            list(
              tr('Missing files'),
              'Objects in the database whose file is gone. Downloads of these fail.',
              LucideIcons.fileX,
              r.missingFiles,
              (m) => mono(
                  '${m.bucket}/${m.key}${m.versionId.isNotEmpty ? '  (version ${m.versionId})' : ''}'),
            ),
            const SizedBox(height: 14),
            list(
              tr('Untracked files'),
              'Files inside bucket folders that no object points to. They use space but are invisible to clients.',
              LucideIcons.fileQuestionMark,
              r.untrackedFiles,
              (u) => Row(children: [
                Expanded(child: mono(u.path)),
                Text(formatBytes(u.bytes), style: t.bodySmall),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================ Config

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => ConfigController(_api(c))..load(),
        child: const _ConfigView(),
      );
}

class _ConfigView extends StatelessWidget {
  const _ConfigView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ConfigController>();
    final cfg = ctrl.config;

    return PageScaffold(
      title: tr('Configuration'),
      subtitle: tr('Effective server settings (read-only, secrets masked). '
          'Change them in config.yaml on the server and restart it.'),
      maxWidth: 1000,
      actions: [
        if (cfg != null)
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: const JsonEncoder.withIndent('  ').convert(cfg)));
              showToast(context, tr('Configuration copied as JSON'));
            },
            icon: const Icon(LucideIcons.copy, size: 15),
            label: Text(tr('Copy JSON')),
          ),
      ],
      body: cfg == null
          ? (ctrl.error != null
              ? ErrorState(ctrl.error!, onRetry: ctrl.load)
              : const LoadingView())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in cfg.entries) ...[
                  Panel(
                    title: e.key,
                    icon: LucideIcons.settings2,
                    child: _ConfigNode(value: e.value),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

/// One level of the configuration tree. Nested sections are indented by
/// [_indent]; their label column shrinks by the same amount, so every value
/// starts at the same x however deep it sits.
class _ConfigNode extends StatelessWidget {
  final Object? value;
  final int depth;
  const _ConfigNode({required this.value, this.depth = 0});

  static const _indent = 14.0;
  static const _labelWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final v = value;
    if (v is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in v.entries)
            if (e.value is Map && (e.value as Map).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key}', style: t.labelLarge),
                    Padding(
                      padding: const EdgeInsets.only(left: _indent, top: 2),
                      child: _ConfigNode(value: e.value, depth: depth + 1),
                    ),
                  ],
                ),
              )
            else
              InfoRow(
                '${e.key}',
                _ConfigNode(value: e.value, depth: depth + 1),
                labelWidth: _labelWidth - _indent * depth,
              ),
        ],
      );
    }
    final text = switch (v) {
      null => '—',
      List() when v.isEmpty => '[]',
      List() => v.join(', '),
      String() when v.isEmpty => '""',
      _ => '$v',
    };
    // Plain mono text for every value, booleans included (green true, muted
    // false): a pill is taller than a text line and pushed its row out of
    // line with the label and with the rows around it.
    final color = switch (v) {
      true => c.success,
      false => c.muted,
      _ when text == '••••' => c.subtle,
      _ => c.foreground,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: SelectableText(text,
          style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 12.5,
              fontWeight: v == true ? FontWeight.w600 : null,
              color: color)),
    );
  }
}

// ============================================================ All servers

/// Status of every saved server, fetched with each server's saved
/// credentials through a separate, short-lived session.
class AllServersScreen extends StatefulWidget {
  const AllServersScreen({super.key});

  @override
  State<AllServersScreen> createState() => _AllServersScreenState();
}

class _ServerSnapshot {
  ServerStatus? status;
  List<Bucket> buckets = const [];
  String? error;
  int? latencyMs;
  bool loading = true;
}

class _AllServersScreenState extends State<AllServersScreen> {
  final Map<String, _ServerSnapshot> _snap = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final servers = context.read<ServersController>();
    final list = servers.servers;
    setState(() {
      for (final s in list) {
        _snap[s.id] = _ServerSnapshot();
      }
    });
    await Future.wait(list.map((s) => _probe(servers, s)));
  }

  Future<void> _probe(ServersController servers, ServerConnection s) async {
    final snap = _snap[s.id]!;
    final api = ApiClient(baseUrl: s.url);
    final sw = Stopwatch()..start();
    try {
      // Reuse a saved token when possible; otherwise a throwaway login.
      var token = await servers.token(s.id);
      var ownLogin = false;
      if (token != null) {
        api.token = token;
        try {
          await api.get('/status');
        } on ApiException catch (e) {
          if (!e.isUnauthorized) rethrow;
          token = null;
        }
      }
      if (token == null) {
        final pw = await servers.password(s.id);
        if (pw == null) throw const ApiException(0, 'No saved password');
        final r = await api.post('/login',
            body: {'username': s.username, 'password': pw});
        api.token = r['token'] as String?;
        ownLogin = true;
      }
      final res = await Future.wait([api.get('/status'), api.get('/buckets')]);
      snap.latencyMs = sw.elapsedMilliseconds;
      snap.status = ServerStatus.fromJson(res[0]);
      snap.buckets = ((res[1]['buckets'] as List?) ?? const [])
          .map((b) => Bucket.fromJson(b as Map<String, dynamic>))
          .toList();
      if (ownLogin) {
        try {
          await api.post('/logout');
        } catch (_) {}
      }
    } on ApiException catch (e) {
      snap.error = e.message;
    } finally {
      snap.loading = false;
      api.dispose();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServersController>().servers;
    final session = context.watch<SessionController>();
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    return PageScaffold(
      title: tr('All servers'),
      subtitle: tr('Every saved server at a glance.'),
      actions: [
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(LucideIcons.refreshCw, size: 15),
          label: Text(tr('Refresh')),
        ),
      ],
      body: LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 1000 ? 3 : box.maxWidth > 640 ? 2 : 1;
        final w = (box.maxWidth - 14 * (cols - 1)) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final s in servers)
              SizedBox(
                width: w,
                child: Builder(builder: (context) {
                  final snap = _snap[s.id];
                  final st = snap?.status;
                  final usage =
                      snap?.buckets.fold<int>(0, (a, b) => a + b.usageBytes) ?? 0;
                  final objects =
                      snap?.buckets.fold<int>(0, (a, b) => a + b.objects) ?? 0;
                  final current = s.id == session.serverId;
                  return Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const IconBadge(LucideIcons.server, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: t.titleSmall),
                                  Text(Uri.tryParse(s.url)?.authority ?? s.url,
                                      style: t.bodySmall),
                                ],
                              ),
                            ),
                            if (snap == null || snap.loading)
                              const ButtonSpinner()
                            else if (snap.error != null)
                              Pill(tr('Offline'),
                                  tone: Tone.danger, dot: true)
                            else
                              Pill('${tr('Online')} · ${snap.latencyMs} ms',
                                  tone: Tone.success, dot: true),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (snap?.error != null)
                          Text(snap!.error!,
                              style: t.bodySmall?.copyWith(color: c.danger))
                        else if (st != null) ...[
                          InfoRow.text(tr('Version'),
                              st.version.isEmpty ? '—' : 'v${st.version}',
                              ),
                          InfoRow.text(tr('Buckets'), '${snap!.buckets.length}'),
                          InfoRow.text(tr('Objects'), formatCount(objects)),
                          InfoRow.text(tr('Stored'), formatBytes(usage)),
                          if (st.storage?.hasDiskStats ?? false) ...[
                            const SizedBox(height: 6),
                            UsageBar(st.storage!.usedFraction, height: 5),
                            const SizedBox(height: 4),
                            Text(
                                tr('{free} free of {total}', {'free': formatBytes(st.storage!.freeBytes), 'total': formatBytes(st.storage!.totalBytes)}),
                                style: t.bodySmall),
                          ],
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: current
                              ? Pill(tr('Connected'), tone: Tone.primary)
                              : OutlinedButton(
                                  onPressed: () => session.connect(s),
                                  child: Text(tr('Switch to')),
                                ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
          ],
        );
      }),
    );
  }
}
