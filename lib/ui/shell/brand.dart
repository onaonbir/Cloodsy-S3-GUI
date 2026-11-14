import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The Cloodsy cloud mark: brand gradient tile with a cloud glyph. Drawn
/// instead of the raster logo so it stays crisp at title-bar sizes.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF38D5FF), Color(0xFF2A7BFF)],
        ),
      ),
      child: Icon(LucideIcons.cloud, size: size * 0.6, color: Colors.white),
    );
  }
}
