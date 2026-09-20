import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/animal.dart';
import 'animal_photo.dart';

class AnimalListItem extends StatelessWidget {
  final Animal animal;
  final String sexoLabel;
  final IconData sexoIcon;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AnimalListItem({
    super.key,
    required this.animal,
    required this.sexoLabel,
    required this.sexoIcon,
    required this.statusColor,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E9E1)),
          ),
          child: Row(
            children: [
              AnimalPhoto(
                fotoPath: animal.fotoPath,
                size: 58,
                borderRadius: 16,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.nome ?? 'Sem nome',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Brinco ${animal.brinco}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${animal.raca} • $sexoLabel',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyAnimalsState extends StatelessWidget {
  final StatusAnimal status;
  final String search;

  const EmptyAnimalsState({
    super.key,
    required this.status,
    required this.search,
  });

  String _statusTexto() {
    switch (status) {
      case StatusAnimal.ativo:
        return 'ativos';

      case StatusAnimal.vendido:
        return 'vendidos';

      case StatusAnimal.morto:
        return 'mortos';

      case StatusAnimal.descartado:
        return 'descartados';
    }
  }

  @override
  Widget build(BuildContext context) {
    final buscando = search.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: AppTheme.primaryColor,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              buscando
                  ? 'Nenhum animal encontrado'
                  : 'Nenhum animal ${_statusTexto()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              buscando
                  ? 'Tente buscar por outro brinco, nome ou raça.'
                  : status == StatusAnimal.ativo
                  ? 'Adicione um animal para começar o cadastro do rebanho.'
                  : 'Quando um animal receber este status, ele aparecerá aqui.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
