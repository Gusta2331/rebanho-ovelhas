import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/rebanho.dart';

class RebanhoCard extends StatelessWidget {
  final Rebanho rebanho;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onAlterarStatus;

  const RebanhoCard({
    super.key,
    required this.rebanho,
    required this.onTap,
    required this.onEditar,
    required this.onAlterarStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusTexto = rebanho.ativo ? 'Ativo' : 'Inativo';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E9E1)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rebanho.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${rebanho.quantidadeAnimais} '
                      '${rebanho.quantidadeAnimais == 1 ? 'animal' : 'animais'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    if (rebanho.localizacao != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        rebanho.localizacao!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: rebanho.ativo
                            ? Colors.green.withValues(alpha: 0.10)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusTexto,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: rebanho.ativo
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'editar') {
                    onEditar();
                  }

                  if (value == 'status') {
                    onAlterarStatus();
                  }
                },
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'status',
                      child: Row(
                        children: [
                          Icon(
                            rebanho.ativo
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          const SizedBox(width: 10),
                          Text(rebanho.ativo ? 'Inativar' : 'Ativar'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
