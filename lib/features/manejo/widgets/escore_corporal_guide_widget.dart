import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Guia educativo offline para auxiliar a palpação do escore corporal ovino.
class EscoreCorporalGuideWidget extends StatelessWidget {
  const EscoreCorporalGuideWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      elevation: 0,
      color: AppTheme.primaryColor.withValues(alpha: 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        leading: const Icon(Icons.menu_book_outlined),
        title: const Text(
          'Guia visual: como avaliar',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: const Text('Ilustrações disponíveis sem internet'),
        children: [
          const Text(
            '1. Localize a região lombar: atrás da última costela e antes dos ossos do quadril.',
            style: TextStyle(fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 8),
          const _RegiaoLombarIllustration(),
          const SizedBox(height: 6),
          const Text(
            '2. Apalpe a linha central da coluna e as pontas ósseas laterais. '
            'Avalie quanto músculo e gordura cobrem os ossos. Não use apenas a aparência.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 14),
          const Text(
            'Referência dos escores',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final item in _referencias) ...[
            _EscoreReferenceRow(item: item),
            const SizedBox(height: 8),
          ],
          const Divider(),
          const Text(
            'As notas 1,5; 2,5; 3,5 e 4,5 são intermediárias. Use-as quando '
            'a condição estiver entre duas descrições. O escore é uma avaliação '
            'por palpação e deve ser interpretado junto da fase produtiva e do histórico.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fontes técnicas consultadas:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, height: 1.35),
          ),
          const SizedBox(height: 4),
          const SelectableText(
            'Embrapa: embrapa.br/en/web/caprinos-e-ovinos/paratec-controle-integrado-verminoses/vermes/caprinos-ovinos/escore-condicao-corporal',
            style: TextStyle(fontSize: 10, color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 4),
          const SelectableText(
            'Oregon State University Extension (EC 1433): extension.oregonstate.edu/catalog/ec-1433-body-condition-scoring-sheep',
            style: TextStyle(fontSize: 10, color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _EscoreReference {
  final int score;
  final String title;
  final String description;

  const _EscoreReference(this.score, this.title, this.description);
}

const _referencias = <_EscoreReference>[
  _EscoreReference(
    1,
    'Muito magra',
    'Coluna e pontas laterais muito salientes e afiadas; quase não há cobertura de músculo ou gordura.',
  ),
  _EscoreReference(
    2,
    'Magra',
    'A coluna é fácil de sentir; há pouca gordura e as pontas laterais ainda são perceptíveis.',
  ),
  _EscoreReference(
    3,
    'Condição intermediária',
    'A coluna fica arredondada; os ossos individuais são sentidos com pressão e há cobertura muscular.',
  ),
  _EscoreReference(
    4,
    'Gorda',
    'A coluna é sentida como uma linha dura apenas com pressão; as pontas laterais ficam difíceis de sentir.',
  ),
  _EscoreReference(
    5,
    'Muito gorda',
    'Os ossos ficam difíceis de identificar ao toque, com cobertura muito espessa de gordura.',
  ),
];

class _EscoreReferenceRow extends StatelessWidget {
  final _EscoreReference item;

  const _EscoreReferenceRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Column(
              children: [
                SizedBox(
                  height: 66,
                  width: 70,
                  child: CustomPaint(
                    painter: _EscoreLombarPainter(score: item.score),
                  ),
                ),
                Text(
                  'Escore ${item.score}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(item.description, style: const TextStyle(fontSize: 12, height: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegiaoLombarIllustration extends StatelessWidget {
  const _RegiaoLombarIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomPaint(painter: _RegiaoLombarPainter()),
    );
  }
}

class _RegiaoLombarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 320;
    canvas.save();
    canvas.scale(scale, scale);
    final body = Paint()..color = const Color(0xFFE9E0D0);
    final outline = Paint()
      ..color = const Color(0xFF756B5D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final highlight = Paint()..color = const Color(0xFF83B98A).withValues(alpha: 0.75);
    canvas.drawOval(const Rect.fromLTWH(18, 28, 284, 78), body);
    canvas.drawOval(const Rect.fromLTWH(18, 28, 284, 78), outline);
    // Costelas, coluna e quadril em vista superior simplificada.
    final ribs = Paint()
      ..color = const Color(0xFFB3A48E)
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final x = 68.0 + i * 17;
      canvas.drawLine(Offset(x, 42), Offset(x - 5, 91), ribs);
    }
    canvas.drawOval(const Rect.fromLTWH(145, 35, 56, 64), highlight);
    final spine = Paint()
      ..color = const Color(0xFF66594B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(36, 67), const Offset(283, 67), spine);
    final textStyle = const TextStyle(
      fontSize: 10,
      color: Color(0xFF3E493E),
      fontWeight: FontWeight.w600,
    );
    _drawLabel(canvas, 'Costelas', const Offset(28, 10), textStyle);
    _drawLabel(canvas, 'Região lombar', const Offset(130, 10), textStyle);
    _drawLabel(canvas, 'Quadril', const Offset(247, 10), textStyle);
    final arrow = Paint()
      ..color = const Color(0xFF38834A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(174, 21), const Offset(174, 34), arrow);
    canvas.drawLine(const Offset(169, 29), const Offset(174, 34), arrow);
    canvas.drawLine(const Offset(179, 29), const Offset(174, 34), arrow);
    _drawLabel(canvas, 'Vista superior simplificada', const Offset(87, 111),
        const TextStyle(fontSize: 9, color: Color(0xFF6D6D6D)));
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EscoreLombarPainter extends CustomPainter {
  final int score;

  _EscoreLombarPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final bodyRect = Rect.fromCenter(
      center: Offset(centerX, 34),
      width: 52,
      height: 48,
    );
    final fatThickness = (score - 1) * 2.5;
    final fat = Paint()..color = const Color(0xFFE9C98F);
    final muscle = Paint()..color = const Color(0xFFC98D72);
    final bone = Paint()
      ..color = const Color(0xFF71675E)
      ..strokeWidth = score <= 2 ? 3.2 : score == 3 ? 2.4 : 1.7
      ..strokeCap = StrokeCap.round;
    final outline = Paint()
      ..color = const Color(0xFF8D7A66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bodyRect.inflate(fatThickness),
        Radius.circular(11 + score * 1.5),
      ),
      fat,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bodyRect.deflate(3),
        Radius.circular(9 + score),
      ),
      muscle,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bodyRect.inflate(fatThickness),
        Radius.circular(11 + score * 1.5),
      ),
      outline,
    );

    // Vértebras e processos laterais esquemáticos: a gordura crescente
    // cobre progressivamente as estruturas ósseas.
    final visibility = score <= 2 ? 1.0 : score == 3 ? 0.85 : score == 4 ? 0.45 : 0.18;
    bone.color = bone.color.withValues(alpha: visibility);
    canvas.drawLine(Offset(centerX, 13), Offset(centerX, 55), bone);
    for (var i = 0; i < 3; i++) {
      final y = 22.0 + i * 12;
      final reach = score <= 2 ? 15.0 : score == 3 ? 11.0 : score == 4 ? 6.0 : 3.0;
      canvas.drawLine(Offset(centerX - reach, y), Offset(centerX + reach, y), bone);
    }
    final label = TextPainter(
      text: TextSpan(
        text: score <= 2 ? 'Pouca cobertura' : score == 3 ? 'Moderada' : score == 4 ? 'Alta' : 'Muito alta',
        style: const TextStyle(fontSize: 7.5, color: Color(0xFF62564A)),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    label.paint(canvas, Offset((size.width - label.width) / 2, 61));
  }

  @override
  bool shouldRepaint(covariant _EscoreLombarPainter oldDelegate) => oldDelegate.score != score;
}
