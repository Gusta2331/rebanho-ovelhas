import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FamachaInfoPage extends StatelessWidget {
  const FamachaInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre a FAMACHA'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _cabecalho(),
          const SizedBox(height: 16),
          _secao(
            titulo: 'O que a FAMACHA avalia?',
            icone: Icons.visibility_outlined,
            texto:
                'A FAMACHA usa a cor da mucosa da pálpebra inferior para estimar o grau de anemia do animal. Ela é uma ferramenta de monitoramento e não um diagnóstico completo.',
          ),
          const SizedBox(height: 12),
          _escala(),
          const SizedBox(height: 12),
          _secao(
            titulo: 'Por que a mucosa pode ficar pálida?',
            icone: Icons.help_outline,
            texto:
                'Uma causa importante em ovinos é a perda de sangue associada a parasitas, especialmente o Haemonchus contortus. Porém, anemia pode ter outras causas. Por isso, o escore não deve ser interpretado sozinho.',
          ),
          const SizedBox(height: 12),
          _secao(
            titulo: 'O que observar junto?',
            icone: Icons.checklist_outlined,
            texto:
                'Use o FAMACHA junto com a observação geral do animal, condição corporal, fezes, pelagem e outros sinais de saúde. Registre as avaliações para acompanhar mudanças ao longo do tempo.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.25),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Importante',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'A imagem do aplicativo é apenas uma referência educativa. Para a avaliação prática, observe a mucosa diretamente, em boa iluminação, e utilize um cartão FAMACHA apropriado. Em caso de animal muito pálido, abatido ou com outros sinais de doença, procure orientação veterinária.',
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'A Fazenda Baixinha registra o escore para facilitar o acompanhamento histórico do rebanho.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: AppTheme.primaryColor,
            size: 36,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'FAMACHA é uma ferramenta de acompanhamento da anemia em ovinos e caprinos.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secao({
    required String titulo,
    required IconData icone,
    required String texto,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(texto, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _escala() {
    const itens = [
      ('1', 'Vermelho', 'Sem sinal visual de anemia importante.'),
      ('2', 'Vermelho/rosado', 'Faixa geralmente aceitável.'),
      ('3', 'Rosa', 'Faixa intermediária, merece acompanhamento.'),
      ('4', 'Rosa muito claro', 'Anemia importante, requer atenção.'),
      ('5', 'Muito pálido', 'Anemia grave, requer atenção imediata.'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escala de referência',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...itens.map((item) {
              final escore = int.parse(item.$1);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _cor(escore),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            item.$3,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

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
}
