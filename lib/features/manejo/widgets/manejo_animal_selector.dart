import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ManejoAnimalSelector extends StatelessWidget {
  final List<Map<String, dynamic>> rebanhos;
  final String? rebanhoId;
  final List<Map<String, dynamic>> animais;
  final Set<String> selecionados;
  final bool carregando;
  final bool enabled;
  final bool multiSelecao;
  final String titulo;
  final ValueChanged<String?> onRebanhoChanged;
  final ValueChanged<String> onToggleAnimal;
  final VoidCallback onSelecionarTodos;
  final VoidCallback onLimpar;

  const ManejoAnimalSelector({
    super.key,
    required this.rebanhos,
    required this.rebanhoId,
    required this.animais,
    required this.selecionados,
    required this.carregando,
    required this.enabled,
    required this.multiSelecao,
    required this.titulo,
    required this.onRebanhoChanged,
    required this.onToggleAnimal,
    required this.onSelecionarTodos,
    required this.onLimpar,
  });

  String _animalTexto(Map<String, dynamic> animal) {
    final numero = int.tryParse(animal['brinco']?.toString() ?? '');
    final brinco = numero == null
        ? (animal['brinco']?.toString() ?? '')
        : numero.toString().padLeft(3, '0');
    final nome = animal['nome']?.toString().trim();

    return nome != null && nome.isNotEmpty
        ? '$brinco • $nome'
        : 'Brinco $brinco';
  }

  @override
  Widget build(BuildContext context) {
    final todos = animais.isNotEmpty &&
        animais.every((animal) => selecionados.contains(animal['id']?.toString()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: rebanhoId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Lote',
            prefixIcon: Icon(Icons.groups_outlined),
            border: OutlineInputBorder(),
          ),
          hint: const Text('Todos os lotes'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos os lotes'),
            ),
            ...rebanhos.map((rebanho) {
              final id = rebanho['id']?.toString();
              if (id == null) return null;
              final quantidade = rebanho['quantidade_animais'];
              return DropdownMenuItem<String?>(
                value: id,
                child: Text(
                  quantidade is num
                      ? rebanho['nome'].toString() + ' • ' + quantidade.toInt().toString() + ' animais'
                      : rebanho['nome']?.toString() ?? 'Lote',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).whereType<DropdownMenuItem<String?>>(),
          ],
          onChanged: enabled ? onRebanhoChanged : null,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final estreito = constraints.maxWidth < 360;
                    final tituloWidget = Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    );

                    if (estreito && multiSelecao) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          tituloWidget,
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: !enabled || carregando
                                  ? null
                                  : todos
                                      ? onLimpar
                                      : onSelecionarTodos,
                              child: Text(todos ? 'Limpar' : 'Selecionar todas'),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: tituloWidget),
                        if (multiSelecao)
                          TextButton(
                            onPressed: !enabled || carregando
                                ? null
                                : todos
                                    ? onLimpar
                                    : onSelecionarTodos,
                            child: Text(todos ? 'Limpar' : 'Selecionar todas'),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    multiSelecao
                        ? selecionados.length.toString() + ' animal(is) selecionado(s)'
                        : animais.length.toString() + ' animal(is) no lote',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ),
              const Divider(height: 1),
              if (carregando)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                )
              else if (animais.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nenhum animal ativo encontrado para o lote selecionado.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...animais.map((animal) {
                  final id = animal['id']?.toString();
                  if (id == null) return const SizedBox.shrink();

                  final selecionado = selecionados.contains(id);

                  return CheckboxListTile(
                    value: selecionado,
                    onChanged: enabled
                        ? (_) => onToggleAnimal(id)
                        : null,
                    title: Text(_animalTexto(animal)),
                    secondary: const Icon(Icons.pets_outlined),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
