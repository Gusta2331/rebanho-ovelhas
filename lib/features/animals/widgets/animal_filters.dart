import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AnimalStatusFilter extends StatelessWidget {
  final String label;
  final int quantidade;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const AnimalStatusFilter({
    super.key,
    required this.label,
    required this.quantidade,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : const Color(0xFFE0E5DC),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : color),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textColor,
                ),
              ),
              const SizedBox(width: 6),
              _Quantidade(
                quantidade: quantidade,
                color: color,
                selected: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimalSexFilter extends StatelessWidget {
  final String label;
  final int quantidade;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const AnimalSexFilter({
    super.key,
    required this.label,
    required this.quantidade,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.primaryColor;

    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color : const Color(0xFFE0E5DC),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textColor,
                ),
              ),
              const SizedBox(width: 5),
              _Quantidade(
                quantidade: quantidade,
                color: color,
                selected: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimalAgeFilter extends StatelessWidget {
  final String label;
  final int quantidade;
  final bool selected;
  final VoidCallback onTap;

  const AnimalAgeFilter({
    super.key,
    required this.label,
    required this.quantidade,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.primaryColor;

    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color : const Color(0xFFE0E5DC),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cake_outlined,
                size: 17,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textColor,
                ),
              ),
              const SizedBox(width: 5),
              _Quantidade(
                quantidade: quantidade,
                color: color,
                selected: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Quantidade extends StatelessWidget {
  final int quantidade;
  final Color color;
  final bool selected;

  const _Quantidade({
    required this.quantidade,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.20)
            : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$quantidade',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : color,
        ),
      ),
    );
  }
}
