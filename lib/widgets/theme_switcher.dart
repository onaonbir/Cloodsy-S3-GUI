import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class ThemeSwitcher extends StatefulWidget {
  final Widget child;

  const ThemeSwitcher({super.key, required this.child});

  static ThemeSwitcherState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ThemeSwitcherState>();
  }

  static ThemeSwitcherState of(BuildContext context) {
    return maybeOf(context)!;
  }

  @override
  State<ThemeSwitcher> createState() => ThemeSwitcherState();
}

class ThemeSwitcherState extends State<ThemeSwitcher>
    with TickerProviderStateMixin {
  final _boundaryKey = GlobalKey();

  // Double-buffered: we keep the raw bytes as a MemoryImage so there's
  // no async gap between "show overlay" and "it actually paints".
  ui.Image? _snapshot;
  Offset _origin = Offset.zero;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _snapshot?.dispose();
          _snapshot = null;
        });
      }
    });

  bool get _showOverlay => _snapshot != null;

  @override
  void dispose() {
    _reveal.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  Future<void> toggleTheme(Offset globalPosition, VoidCallback onSwitch) async {
    if (_showOverlay) return; // already animating

    // 1. Capture the current frame synchronously as possible
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) {
      onSwitch();
      return;
    }

    ui.Image image;
    try {
      image = boundary.toImageSync(pixelRatio: 1.0);
    } catch (_) {
      // toImageSync not available, fallback
      try {
        image = await boundary.toImage(pixelRatio: 1.0);
      } catch (_) {
        onSwitch();
        return;
      }
    }

    // 2. Mount the overlay with the captured image — same frame, no gap
    _origin = globalPosition;
    _snapshot = image;
    _reveal.value = 0.0;

    // Force a synchronous rebuild so the overlay is in the tree
    // BEFORE we change the theme.
    setState(() {});

    // 3. Use addPostFrameCallback to guarantee the overlay
    //    has been composited before we switch the theme.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // 4. Switch the theme — the snapshot covers everything,
      //    so the user sees nothing change yet.
      onSwitch();

      // 5. After the theme rebuild, start the reveal.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reveal.forward(from: 0.0);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: live content (will show new theme once switched)
        RepaintBoundary(
          key: _boundaryKey,
          child: widget.child,
        ),
        // Layer 2: old-theme snapshot with an expanding circular cut-out
        if (_showOverlay)
          Positioned.fill(
            child: _RevealOverlay(
              animation: _reveal,
              image: _snapshot!,
              origin: _origin,
            ),
          ),
      ],
    );
  }
}

/// Paints the captured screenshot with a growing circular hole
/// that reveals the new theme underneath.
class _RevealOverlay extends AnimatedWidget {
  final ui.Image image;
  final Offset origin;

  const _RevealOverlay({
    required Animation<double> animation,
    required this.image,
    required this.origin,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RevealPainter(
        image: image,
        origin: origin,
        progress: (listenable as Animation<double>).value,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RevealPainter extends CustomPainter {
  final ui.Image image;
  final Offset origin;
  final double progress;

  _RevealPainter({
    required this.image,
    required this.origin,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final maxRadius = _maxDistance(origin, size);
    final radius = maxRadius * Curves.easeInOutCubic.transform(progress);

    canvas.save();

    // Clip to everything OUTSIDE the circle
    final hole = Path()
      ..addOval(Rect.fromCircle(center: origin, radius: radius));
    final screen = Path()..addRect(Offset.zero & size);
    canvas.clipPath(
      Path.combine(PathOperation.difference, screen, hole),
    );

    // Draw old screenshot
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
    );

    canvas.restore();
  }

  static double _maxDistance(Offset origin, Size size) {
    return [
      origin.distance,
      (Offset(size.width, 0) - origin).distance,
      (Offset(0, size.height) - origin).distance,
      (Offset(size.width, size.height) - origin).distance,
    ].reduce(max);
  }

  @override
  bool shouldRepaint(_RevealPainter old) => progress != old.progress;
}
