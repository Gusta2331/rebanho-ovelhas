import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';

class ManejoAnimalSelector extends StatefulWidget {
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

  @override
  State<ManejoAnimalSelector> createState() => _ManejoAnimalSelectorState();
}

class _ManejoAnimalSelectorState extends State<ManejoAnimalSelector> {
  final TextEditingController _buscaController = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String _texto(dynamic valor) => valor?.toString().trim() ?? '';

  String _normalizar(String valor) => valor
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  String _brinco(Map<String, dynamic> animal) {
    final valor = _texto(animal['brinco']);
    final numero = int.tryParse(valor);
    return numero == null ? valor : numero.toString().padLeft(3, '0');
  }

  String _animalTexto(Map<String, dynamic> animal) {
    final brinco = _brinco(animal);
    final nome = _texto(animal['nome']);
    if (nome.isNotEmpty) return '$brinco • $nome';
    return brinco.isNotEmpty ? 'Brinco $brinco' : 'Animal sem nome';
  }

  bool _corresponde(Map<String, dynamic> animal) {
    final busca = _normalizar(_busca.trim());
    if (busca.isEmpty) return true;
    final campos = [
      _texto(animal['nome']),
      _texto(animal['brinco']),
      _texto(animal['id']),
      _texto(animal['raca']),
      _texto(animal['sexo']),
    ];
    return campos.any((campo) => _normalizar(campo).contains(busca));
  }

  IconData _iconeSexo(Map<String, dynamic> animal) {
    final sexo = _normalizar(_texto(animal['sexo']));
    if (sexo.contains('macho') || sexo == 'm') return Icons.male_rounded;
    if (sexo.contains('femea') || sexo == 'f') return Icons.female_rounded;
    return Icons.pets_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final animaisFiltrados = widget.animais.where(_corresponde).toList();
    final todos = widget.animais.isNotEmpty &&
        widget.animais.every(
          (animal) => widget.selecionados.contains(animal['id']?.toString()),
        );
    final theme = Theme.of(context);
    final borda = theme.colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: widget.rebanhoId,
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
            ...widget.rebanhos.map((rebanho) {
              final id = rebanho['id']?.toString();
              if (id == null) return null;
              final quantidade = rebanho['quantidade_animais'];
              return DropdownMenuItem<String?>(
                value: id,
                child: Text(
                  quantidade is num
                      ? '${rebanho['nome']} • ${quantidade.toInt()} animais'
                      : _texto(rebanho['nome']).isEmpty
                          ? 'Lote'
                          : _texto(rebanho['nome']),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).whereType<DropdownMenuItem<String?>>(),
          ],
          onChanged: widget.enabled ? widget.onRebanhoChanged : null,
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borda),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                color: AppTheme.primaryColor.withValues(alpha: 0.07),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.pets_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.titulo,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.multiSelecao
                                    ? '${widget.selecionados.length} selecionado(s) de ${widget.animais.length}'
                                    : '${widget.animais.length} animal(is) disponível(is)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.multiSelecao)
                          IconButton(
                            tooltip: todos ? 'Limpar seleção' : 'Selecionar todos do lote',
                            onPressed: !widget.enabled || widget.carregando
                                ? null
                                : todos
                                    ? widget.onLimpar
                                    : widget.onSelecionarTodos,
                            icon: Icon(
                              todos ? Icons.deselect_rounded : Icons.done_all_rounded,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _buscaController,
                      enabled: widget.enabled && !widget.carregando,
                      onChanged: (value) => setState(() => _busca = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome, brinco/ID ou raça',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _busca.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar busca',
                                onPressed: () {
                                  _buscaController.clear();
                                  setState(() => _busca = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borda),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borda),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.carregando)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              else if (widget.animais.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.pets_outlined, size: 34, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Nenhum animal ativo encontrado para este lote.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else if (animaisFiltrados.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 34, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text(
                        'Nenhum animal corresponde à busca.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          _buscaController.clear();
                          setState(() => _busca = '');
                        },
                        child: const Text('Limpar busca'),
                      ),
                    ],
                  ),
                )
              else
                ...animaisFiltrados.asMap().entries.map((entry) {
                  final animal = entry.value;
                  final id = animal['id']?.toString();
                  if (id == null) return const SizedBox.shrink();

                  final selecionado = widget.selecionados.contains(id);
                  final nomeRaca = _texto(animal['raca']);
                  final nomeSexo = _texto(animal['sexo']);
                  return Column(
                    children: [
                      if (entry.key > 0) Divider(height: 1, color: borda),
                      Material(
                        color: selecionado
                            ? AppTheme.primaryColor.withValues(alpha: 0.06)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: !widget.enabled
                              ? null
                              : () => widget.onToggleAnimal(id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                if (widget.multiSelecao)
                                  Checkbox(
                                    value: selecionado,
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: widget.enabled
                                        ? (_) => widget.onToggleAnimal(id)
                                        : null,
                                  )
                                else
                                  const SizedBox(width: 8),
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: AppAssetIcon(
                                    assetPath: 'assets/images/icon_animais.png',
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _animalTexto(animal),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (nomeRaca.isNotEmpty)
                                            _tag(nomeRaca, Icons.bookmark_outline, theme),
                                          if (nomeSexo.isNotEmpty)
                                            _tag(nomeSexo, _iconeSexo(animal), theme),
                                          _tag('ID: ${id.length > 8 ? id.substring(0, 8) : id}', Icons.tag_rounded, theme),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (selecionado)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              if (!widget.carregando && widget.animais.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _busca.isEmpty
                              ? 'Toque em um animal para selecioná-lo.'
                              : '${animaisFiltrados.length} resultado(s) para sua busca.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tag(String texto, IconData icone, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            texto,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
