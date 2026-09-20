import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/animal.dart';
import '../pages/animal_details_page.dart';
import 'animal_photo.dart';

class AnimalDescendants extends StatelessWidget {
  final Animal animal;
  final List<Animal> animais;

  const AnimalDescendants({
    super.key,
    required this.animal,
    required this.animais,
  });

  List<Animal> _filhos() {
    return animais.where((outro) {
      return outro.id != animal.id &&
          (outro.idMae == animal.id || outro.idPai == animal.id);
    }).toList();
  }

  String _sexo(Animal animal) {
    return animal.sexo == SexoAnimal.femea ? 'Fêmea' : 'Macho';
  }

  @override
  Widget build(BuildContext context) {
    final filhos = _filhos();

    return _buildSection(filhos, context);
  }

  Widget _buildSection(List<Animal> filhos, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.family_restroom_outlined,
                  color: AppTheme.primaryColor,
                  size: 21,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Reprodução',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
                if (filhos.isNotEmpty)
                  Text(
                    '${filhos.length} '
                    '${filhos.length == 1 ? 'filho' : 'filhos'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
          if (filhos.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Nenhum descendente cadastrado.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            )
          else
            ...filhos.map((filho) => _buildFilho(context, filho)),
        ],
      ),
    );
  }

  Widget _buildFilho(BuildContext context, Animal filho) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                AnimalDetailsPage(animal: filho, animais: animais),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Row(
          children: [
            AnimalPhoto(fotoPath: filho.fotoPath, size: 58, borderRadius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filho.nome?.trim().isNotEmpty == true
                        ? filho.nome!.trim()
                        : 'Animal ${filho.brinco}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Brinco ${filho.brinco}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${filho.raca} • ${_sexo(filho)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
