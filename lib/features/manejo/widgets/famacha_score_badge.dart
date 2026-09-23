import 'package:flutter/material.dart';

import '../utils/famacha_scale.dart';

class FamachaScoreBadge extends StatelessWidget {
  const FamachaScoreBadge({
    super.key,
    required this.score,
    this.showLabel = true,
  });

  final int score;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = FamachaScale.color(score);

    return Semantics(
      label: 'FAMACHA $score, ${FamachaScale.description(score)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.65)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'F$score',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (showLabel) ...[
              const SizedBox(width: 5),
              Text('· ${FamachaScale.description(score)}'),
            ],
          ],
        ),
      ),
    );
  }
}
