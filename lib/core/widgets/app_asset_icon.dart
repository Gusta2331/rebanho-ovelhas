import 'package:flutter/material.dart';

class AppAssetIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color? color;
  final BoxFit fit;

  const AppAssetIcon({
    super.key,
    required this.assetPath,
    this.size = 28,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
      color: color,
      errorBuilder: (_, __, ___) {
        return Icon(
          Icons.image_not_supported_outlined,
          size: size,
          color: color ?? Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}
