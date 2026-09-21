import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FamachaReferenceWidget extends StatelessWidget {
  final int? selecionado;

  const FamachaReferenceWidget({
    super.key,
    this.selecionado,
  });

  Color _cor(int escore) {
    switch (escore) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 19,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Referência visual FAMACHA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Ilustração para ajudar na comparação da mucosa.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final escore = index + 1;
              final ativo = selecionado == escore;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: escore == 5 ? 0 : 5),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ativo
                                ? AppTheme.primaryColor
                                : Colors.black12,
                            width: ativo ? 2 : 1,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _OlhoFamachaPainter(
                            mucosaColor: _cor(escore),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        escore.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ativo
                              ? AppTheme.primaryColor
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: Text(
                  '1  •  mais vermelho',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
              Text(
                '5  •  mais pálido',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Use esta ilustração apenas como apoio. A avaliação deve ser feita diretamente na mucosa do animal, de preferência com boa iluminação e seguindo o cartão FAMACHA apropriado.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _OlhoFamachaPainter extends CustomPainter {
  final Color mucosaColor;

  const _OlhoFamachaPainter({
    required this.mucosaColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final olho = Rect.fromCenter(
      center: centro,
      width: size.width * 0.72,
      height: size.height * 0.50,
    );

    final contorno = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final branco = Paint()
      ..color = const Color(0xFFFFFCF7)
      ..style = PaintingStyle.fill;

    final mucosa = Paint()
      ..color = mucosaColor
      ..style = PaintingStyle.fill;

    canvas.drawOval(olho, branco);
    canvas.drawOval(olho, contorno);

    final mucosaRect = Rect.fromCenter(
      center: Offset(centro.dx, centro.dy + size.height * 0.10),
      width: size.width * 0.42,
      height: size.height * 0.22,
    );

    canvas.drawOval(mucosaRect, mucosa);

    final pupila = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centro.dx, centro.dy - size.height * 0.03),
        width: size.width * 0.10,
        height: size.height * 0.13,
      ),
      pupila,
    );
  }

  @override
  bool shouldRepaint(covariant _OlhoFamachaPainter oldDelegate) {
    return oldDelegate.mucosaColor != mucosaColor;
  }
}
