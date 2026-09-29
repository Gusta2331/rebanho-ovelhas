import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/composicao_racial.dart';

class AnimalBreedCompositionCard extends StatelessWidget {
  final List<ComposicaoRacial> composicoes;
  final bool carregando;
  final String? erro;
  final VoidCallback? onRetry;

  const AnimalBreedCompositionCard({
    super.key,
    required this.composicoes,
    this.carregando = false,
    this.erro,
    this.onRetry,
  });

  String _percentual(double valor) {
    if (valor.roundToDouble() == valor) {
      return '\${valor.toStringAsFixed(0)}%';
    }
    return '\${valor.toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  @override
  Widget build(BuildContext context) {
    final total = composicoes.fold<double>(
      0,
      (soma, item) => soma + item.percentual,
    );
    final totalConhecido = total.clamp(0, 100).toDouble();
    final percentualDesconhecido =
        (100 - totalConhecido).clamp(0, 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.biotech_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Composição racial',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Calculada a partir da filiação cadastrada.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (carregando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (erro != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(erro!),
              trailing: IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
            )
          else if (composicoes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ainda não foi possível calcular a composição racial.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            )
          else ...[
            ...composicoes.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.racaNome,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ),
                        Text(
                          _percentual(item.percentual),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (item.percentual / 100).clamp(0, 1).toDouble(),
                        minHeight: 9,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.10),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 19, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Composição conhecida',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _percentual(totalConhecido),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (percentualDesconhecido > 0.1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0D48A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 19, color: Color(0xFF8A6814)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Parte da composição é desconhecida porque falta a filiação completa (\${_percentual(percentualDesconhecido)}).',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xFF6E571B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}