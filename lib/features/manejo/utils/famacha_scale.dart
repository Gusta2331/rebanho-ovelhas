import 'package:flutter/material.dart';

class FamachaScale {
  const FamachaScale._();

  static Color color(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFB71C1C);
      case 2:
        return const Color(0xFFE53935);
      case 3:
        return const Color(0xFFE57373);
      case 4:
        return const Color(0xFFF8B6B6);
      case 5:
        return const Color(0xFFF5EAEA);
      default:
        return Colors.grey;
    }
  }

  static String description(int score) {
    switch (score) {
      case 1:
        return 'Vermelho intenso';
      case 2:
        return 'Vermelho-rosado';
      case 3:
        return 'Rosa';
      case 4:
        return 'Rosa bem claro';
      case 5:
        return 'Muito pálido';
      default:
        return 'Não informado';
    }
  }

  static Color onColor(int score) => score <= 2 ? Colors.white : Colors.black87;
}
