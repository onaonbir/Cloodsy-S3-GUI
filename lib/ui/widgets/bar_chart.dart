import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../../core/i18n.dart';

/// Single-series column chart for a short time series (one value per
/// minute). One axis, thin columns with a 2px gap and rounded data ends,
/// recessive axis text, and a hover tooltip per column. The chart's title
/// (outside) names the series, so there is no legend.
class MiniBarChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels; // tooltip label per column (e.g. time)
  final String Function(double) format;
  final double height;

  const MiniBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    this.height = 120,
  });

  @override
  State<MiniBarChart> createState() => _MiniBarChartState();
}

class _MiniBarChartState extends State<MiniBarChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final v = widget.values;
    final max = v.isEmpty ? 0.0 : v.reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(builder: (context, box) {
      final n = v.isEmpty ? 1 : v.length;
      final slot = box.maxWidth / n;
      final hover = _hover;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: MouseRegion(
              onHover: (e) {
                final i = (e.localPosition.dx / slot).floor();
                if (i >= 0 && i < v.length && i != _hover) {
                  setState(() => _hover = i);
                }
              },
              onExit: (_) => setState(() => _hover = null),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BarsPainter(
                        values: v,
                        max: max,
                        color: c.primary,
                        dim: c.primary.withValues(alpha: 0.45),
                        grid: c.border,
                        hover: hover,
                      ),
                    ),
                  ),
                  if (hover != null && hover < v.length)
                    Positioned(
                      left: (slot * hover + slot / 2 - 70)
                          .clamp(0.0, box.maxWidth - 140),
                      top: -6,
                      child: IgnorePointer(
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: AppRadius.mdAll,
                            border: Border.all(color: c.border),
                            boxShadow: const [
                              BoxShadow(
                                  blurRadius: 10,
                                  color: Color(0x22000000),
                                  offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.format(v[hover]),
                                  style: t.labelLarge),
                              Text(widget.labels[hover], style: t.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(widget.labels.isEmpty ? '' : widget.labels.first,
                  style: t.bodySmall),
              const Spacer(),
              Text(tr('peak {v}', {'v': widget.format(max)}), style: t.bodySmall),
              const Spacer(),
              Text(widget.labels.isEmpty ? '' : widget.labels.last,
                  style: t.bodySmall),
            ],
          ),
        ],
      );
    });
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final double max;
  final Color color, dim, grid;
  final int? hover;

  _BarsPainter({
    required this.values,
    required this.max,
    required this.color,
    required this.dim,
    required this.grid,
    required this.hover,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5), base);
    if (values.isEmpty || max <= 0) return;

    final slot = size.width / values.length;
    const gap = 2.0;
    final w = (slot - gap).clamp(1.0, 18.0);
    for (var i = 0; i < values.length; i++) {
      final h = values[i] / max * (size.height - 4);
      if (h <= 0) continue;
      final x = i * slot + (slot - w) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, size.height - 1 - h, w, h),
        topLeft: Radius.circular(w >= 6 ? 3 : 1),
        topRight: Radius.circular(w >= 6 ? 3 : 1),
      );
      canvas.drawRRect(
          rect,
          Paint()
            ..color = hover == null || hover == i ? color : dim);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values || old.hover != hover || old.color != color;
}
