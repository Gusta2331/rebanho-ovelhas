import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'animal_photo_viewer.dart';

class AnimalPhoto extends StatelessWidget {
  final String? fotoPath;
  final double size;
  final double borderRadius;

  const AnimalPhoto({
    super.key,
    this.fotoPath,
    this.size = 80,
    this.borderRadius = 18,
  });

  bool get _temFoto {
    if (fotoPath == null || fotoPath!.isEmpty) {
      return false;
    }

    return File(fotoPath!).existsSync();
  }

  void _abrirFoto(BuildContext context) {
    if (!_temFoto) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AnimalPhotoViewer(fotoPath: fotoPath!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_temFoto) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          Icons.pets_rounded,
          size: size * 0.45,
          color: AppTheme.primaryColor,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _abrirFoto(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(fotoPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Icon(
                Icons.pets_rounded,
                size: size * 0.45,
                color: AppTheme.primaryColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
