import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../models/server_connection.dart';
import '../../state/servers_controller.dart';
import '../../state/session_controller.dart';
import '../dialogs/server_dialog.dart';
import '../shell/brand.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// Shown while no session is active: pick, add or manage servers.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _connect(BuildContext context, ServerConnection s) async {
    await context.read<SessionController>().connect(s);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final servers = context.watch<ServersController>().servers;
    final session = context.watch<SessionController>();

    return ColoredBox(
      color: c.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandMark(size: 52)),
                const SizedBox(height: 18),
                Text(tr('Cloodsy S3'),
                    textAlign: TextAlign.center, style: t.displaySmall),
                const SizedBox(height: 6),
                Text(
                  servers.isEmpty
                      ? tr('Add your first server to start managing buckets.')
                      : tr('Choose a server to connect to.'),
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: c.muted),
                ),
                const SizedBox(height: 28),
                if (session.error != null) ...[
                  Callout(
                    session.error!,
                    tone: Tone.danger,
                    action: IconButton(
                      tooltip: tr('Dismiss'),
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: session.clearError,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (servers.isEmpty)
                  Center(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final s = await showServerDialog(context);
                        if (s != null && context.mounted) {
                          await _connect(context, s);
                        }
                      },
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(tr('Add server')),
                    ),
                  )
                else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: AppRadius.xlAll,
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < servers.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: c.border),
                          _ServerRow(
                            server: servers[i],
                            connecting: session.connectingId == servers[i].id,
                            disabled: session.isConnecting,
                            onConnect: () => _connect(context, servers[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => showServerDialog(context),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(tr('Add another server')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerRow extends StatefulWidget {
  final ServerConnection server;
  final bool connecting;
  final bool disabled;
  final VoidCallback onConnect;

  const _ServerRow({
    required this.server,
    required this.connecting,
    required this.disabled,
    required this.onConnect,
  });

  @override
  State<_ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<_ServerRow> {
  bool _hover = false;

  /// Reachability probe: an unauthenticated GET of /admin/status answers
  /// 401 from a live Cloodsy S3 admin listener. Null while probing.
  bool? _up;
  int? _ms;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final sw = Stopwatch()..start();
    final client = http.Client();
    try {
      await client
          .get(Uri.parse('${widget.server.url}/admin/status'))
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _up = true;
          _ms = sw.elapsedMilliseconds;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _up = false);
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final s = widget.server;
    final uri = Uri.tryParse(s.url);
    final secure = uri?.scheme == 'https';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.disabled ? null : widget.onConnect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              const IconBadge(LucideIcons.server, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(s.name, style: t.titleSmall)),
                        const SizedBox(width: 8),
                        if (_up == null)
                          const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5))
                        else
                          Pill(
                            _up! ? '${tr('Online')} · $_ms ms' : tr('Unreachable'),
                            tone: _up! ? Tone.success : Tone.danger,
                            dot: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(secure ? LucideIcons.lock : LucideIcons.lockOpen,
                            size: 11,
                            color: secure ? c.success : c.warning),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${uri?.host ?? s.url}${uri?.hasPort == true ? ':${uri!.port}' : ''} · ${s.username}',
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.connecting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: ButtonSpinner(),
                )
              else ...[
                AnimatedOpacity(
                  duration: AppDuration.fast,
                  opacity: _hover ? 1 : 0,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: tr('Edit'),
                        icon: const Icon(LucideIcons.pencil, size: 15),
                        onPressed: () =>
                            showServerDialog(context, existing: s),
                      ),
                      IconButton(
                        tooltip: tr('Remove'),
                        icon: Icon(LucideIcons.trash2,
                            size: 15, color: c.danger),
                        onPressed: () async {
                          final ok = await confirm(
                            context,
                            title: tr('Remove server'),
                            message:
                                tr('Remove “{name}” and its saved password from this computer? The server itself is not affected.', {'name': s.name}),
                            confirmLabel: tr('Remove'),
                          );
                          if (ok && context.mounted) {
                            await context
                                .read<ServersController>()
                                .remove(s.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 18, color: c.subtle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
