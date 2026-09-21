import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../flock/models/rebanho.dart';

class RebanhoSelector extends StatelessWidget {
  final bool loading;
  final List<Rebanho> rebanhos;
  final Rebanho? rebanhoSelecionado;
  final ValueChanged<Rebanho> onChanged;
  final VoidCallback onGerenciar;
  final VoidCallback onCriar;

  const RebanhoSelector({
    super.key,
    required this.loading,
    required this.rebanhos,
    required this.rebanhoSelecionado,
    required this.onChanged,
    required this.onGerenciar,
    required this.onCriar,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _buildCarregando();
    }

    if (rebanhos.isEmpty) {
      return _buildSemRebanhos();
    }

    return _buildLista();
  }

  Widget _buildCarregando() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9E1)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando rebanhos...',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSemRebanhos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhum rebanho cadastrado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Crie um rebanho para começar a organizar os animais.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCriar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar rebanho'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Rebanho>(
                value: rebanhoSelecionado,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primaryColor,
                ),
                items: rebanhos.map((rebanho) {
                  return DropdownMenuItem<Rebanho>(
                    value: rebanho,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rebanho.nome,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        Text(
                          '${rebanho.quantidadeAnimais} animais ativos',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (rebanho) {
                  if (rebanho != null) {
                    onChanged(rebanho);
                  }
                },
              ),
            ),
          ),
          IconButton(
            onPressed: onGerenciar,
            tooltip: 'Gerenciar rebanhos',
            icon: const Icon(
              Icons.settings_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
