import 'package:material_ui/material_ui.dart';

/// The Cloodsy mark on S3 GUI's signal cyan tile: the cloud with a command
/// prompt (docs/brand/README.md). Drawn instead of a raster so it stays crisp
/// at title-bar sizes; the same paths as the app icon.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _ground = Color(0xFF2EC8F0);
  static const _cloud = Color(0xFF161B29);
  static const _prompt = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    // Under 24 px the two dots go and the cloud grows a little (brand rule).
    final small = size.shortestSide < 24;
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(24)),
      Paint()..color = _ground,
    );
    if (small) {
      canvas
        ..translate(50, 50)
        ..scale(1.1)
        ..translate(-50, -50);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cloud = Path()
      ..moveTo(33, 70)
      ..lineTo(69, 70)
      ..arcToPoint(const Offset(70.5, 42.2), radius: const Radius.circular(14), clockwise: false)
      ..arcToPoint(const Offset(32.6, 38.6), radius: const Radius.circular(20), clockwise: false)
      ..arcToPoint(const Offset(33, 70), radius: const Radius.circular(15.8), clockwise: false)
      ..close();
    canvas.drawPath(cloud, stroke..color = _cloud..strokeWidth = 8);
    final prompt = Path()
      ..moveTo(40, 46.5)
      ..lineTo(46.5, 53)
      ..lineTo(40, 59.5)
      ..moveTo(51.5, 59.5)
      ..lineTo(62.5, 59.5);
    canvas.drawPath(prompt, stroke..color = _prompt..strokeWidth = 6);
    if (!small) {
      final dot = Paint()..color = _prompt;
      canvas
        ..drawCircle(const Offset(22, 22), 5, dot)
        ..drawCircle(const Offset(80, 80), 6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
