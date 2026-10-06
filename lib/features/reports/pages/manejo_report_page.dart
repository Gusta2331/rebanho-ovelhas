import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../manejo/models/manejo.dart';
import '../../manejo/services/manejo_service.dart';

class ManejoReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const ManejoReportPage({super.key, required this.onBack});

  @override
  State<ManejoReportPage> createState() => _ManejoReportPageState();
}

class _ManejoReportPageState extends State<ManejoReportPage> {
  final _service = ManejoService();
  final _search = TextEditingController();

  List<_ManejoItem> _items = [];
  bool _loading = true;
  String? _error;
  String _tipo = 'Todos';
  DateTime? _from;
  DateTime? _to;
  final Set<String> _selectedManejoIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _service.getManejos();
      final items = rows.map(_ManejoItem.fromMap).toList();

      if (!mounted) return;

      setState(() {
        _items = items;
        _selectedManejoIds.removeWhere(
          (id) => !items.any((item) => item.manejo.id == id),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<_ManejoItem> get _filtered {
    final query = _search.text.trim().toLowerCase();

    return _items.where((item) {
      final manejo = item.manejo;
      final matchesTipo =
          _tipo == 'Todos' || _tipoFromLabel(manejo.tipo) == _tipo;

      final data = DateTime(manejo.data.year, manejo.data.month, manejo.data.day);
      final matchesFrom = _from == null || !data.isBefore(_dateOnly(_from!));
      final matchesTo = _to == null || !data.isAfter(_dateOnly(_to!));

      final detail = _detail(manejo);
      final matchesSearch = query.isEmpty ||
          item.brinco.toLowerCase().contains(query) ||
          (item.nome?.toLowerCase().contains(query) ?? false) ||
          _tipoFromLabel(manejo.tipo).toLowerCase().contains(query) ||
          (detail?.toLowerCase().contains(query) ?? false);

      return matchesTipo && matchesFrom && matchesTo && matchesSearch;
    }).toList();
  }

  List<_ManejoItem> get _selectedManejos => _items
      .where((item) => _selectedManejoIds.contains(item.manejo.id))
      .toList();

  bool _isSelected(_ManejoItem item) =>
      _selectedManejoIds.contains(item.manejo.id);

  void _toggleSelection(_ManejoItem item) {
    setState(() {
      if (_selectedManejoIds.contains(item.manejo.id)) {
        _selectedManejoIds.remove(item.manejo.id);
      } else {
        _selectedManejoIds.add(item.manejo.id);
      }
    });
  }

  void _selectAllFiltered() {
    setState(() {
      _selectedManejoIds.addAll(
        _filtered.map((item) => item.manejo.id),
      );
    });
  }

  void _clearSelection() {
    setState(() => _selectedManejoIds.clear());
  }

  bool get _allFilteredSelected =>
      _filtered.isNotEmpty &&
      _filtered.every((item) => _selectedManejoIds.contains(item.manejo.id));

  String _tipoFromLabel(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao:
        return 'Vacinação';
      case TipoManejo.vermifugacao:
        return 'Vermifugação';
      case TipoManejo.tratamento:
        return 'Tratamento';
      case TipoManejo.tosquia:
        return 'Tosquia';
      case TipoManejo.pesagem:
        return 'Pesagem';
      case TipoManejo.famacha:
        return 'FAMACHA';
      case TipoManejo.denticao:
        return 'Dentição';
      case TipoManejo.outro:
        return 'Outro';
    }
  }

  String? _detail(Manejo manejo) {
    switch (manejo.tipo) {
      case TipoManejo.vacinacao:
        return manejo.vacinaNome;
      case TipoManejo.vermifugacao:
        return manejo.vermifugoNome;
      case TipoManejo.tratamento:
        if (manejo.medicamentoNome != null && manejo.enfermidade != null) {
          return manejo.medicamentoNome! + ' · ' + manejo.enfermidade!;
        }
        return manejo.medicamentoNome ?? manejo.enfermidade;
      case TipoManejo.pesagem:
        return manejo.pesoKg == null ? null : _number(manejo.pesoKg!) + ' kg';
      case TipoManejo.famacha:
        return manejo.famachaEscore == null
            ? null
            : 'Escore ' + manejo.famachaEscore.toString();
      case TipoManejo.denticao:
        return manejo.denticao;
      case TipoManejo.outro:
        return manejo.outroNome;
      case TipoManejo.tosquia:
        return null;
    }
  }

  String _number(double value) {
    final text = value.toStringAsFixed(2);
    if (text.endsWith('00')) return text.substring(0, text.length - 3);
    return text.replaceFirst(RegExp(r'0$'), '');
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _date(DateTime value) =>
      value.day.toString().padLeft(2, '0') +
      '/' +
      value.month.toString().padLeft(2, '0') +
      '/' +
      value.year.toString();

  Future<void> _pickFrom() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _from = selected;
      if (_to != null && _to!.isBefore(selected)) _to = selected;
    });
  }

  Future<void> _pickTo() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _to ?? _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _to = selected;
      if (_from != null && _from!.isAfter(selected)) _from = selected;
    });
  }

  void _clearDates() {
    setState(() {
      _from = null;
      _to = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(
              assetPath: 'assets/images/icon_manejo.png',
              size: 26,
            ),
            SizedBox(width: 8),
            Text('Relatório de manejo'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Summary(
                        total: _items.length,
                        filtered: filtered.length,
                        selected: _selectedManejos.length,
                        types: filtered
                            .map((item) => item.manejo.tipo)
                            .toSet()
                            .length,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          labelText: 'Buscar manejo',
                          hintText: 'Animal, tipo ou informação',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _search.clear,
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _dropdown(
                        label: 'Tipo de manejo',
                        value: _tipo,
                        values: const [
                          'Todos',
                          'Vacinação',
                          'Vermifugação',
                          'Tratamento',
                          'Tosquia',
                          'Pesagem',
                          'FAMACHA',
                          'Dentição',
                          'Outro',
                        ],
                        onChanged: (value) => setState(() => _tipo = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFrom,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                _from == null ? 'Data inicial' : _date(_from!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTo,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                _to == null ? 'Data final' : _date(_to!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_from != null || _to != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _clearDates,
                            icon: const Icon(Icons.clear),
                            label: const Text('Limpar datas'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _SelectionCard(
                        filteredCount: filtered.length,
                        selectedCount: _selectedManejos.length,
                        allSelected: _allFilteredSelected,
                        onSelectAll: _selectAllFiltered,
                        onClear: _clearSelection,
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum manejo corresponde aos filtros.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...filtered.map(
                          (item) => _ManejoCard(
                            item: item,
                            selected: _isSelected(item),
                            onSelected: () => _toggleSelection(item),
                            typeLabel: _tipoFromLabel(item.manejo.tipo),
                            detail: _detail(item.manejo),
                            date: _date(item.manejo.data),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : values.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ManejoItem {
  final Manejo manejo;
  final String brinco;
  final String? nome;

  const _ManejoItem({
    required this.manejo,
    required this.brinco,
    required this.nome,
  });

  factory _ManejoItem.fromMap(Map<String, dynamic> map) {
    final animal = map['animais'];
    String brinco = 'Animal';
    String? nome;

    if (animal is Map) {
      final rawBrinco = animal['brinco']?.toString().trim();
      final rawNome = animal['nome']?.toString().trim();

      if (rawBrinco != null && rawBrinco.isNotEmpty) brinco = rawBrinco;
      if (rawNome != null && rawNome.isNotEmpty) nome = rawNome;
    }

    return _ManejoItem(
      manejo: Manejo.fromMap(map),
      brinco: brinco,
      nome: nome,
    );
  }
}

class _Summary extends StatelessWidget {
  final int total;
  final int filtered;
  final int selected;
  final int types;

  const _Summary({
    required this.total,
    required this.filtered,
    required this.selected,
    required this.types,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard(
          value: total.toString(),
          label: 'Manejos',
          iconAsset: 'assets/images/icon_manejo.png',
        ),
        _SummaryCard(
          value: filtered.toString(),
          label: 'Filtrados',
          iconAsset: 'assets/images/icon_lotes.png',
        ),
        _SummaryCard(
          value: selected.toString(),
          label: 'Selecionados',
          iconAsset: 'assets/images/icon_manejo.png',
        ),
        _SummaryCard(
          value: types.toString(),
          label: 'Tipos',
          iconAsset: 'assets/images/icon_relatorios.png',
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final String iconAsset;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AppAssetIcon(assetPath: iconAsset, size: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final int filteredCount;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  const _SelectionCard({
    required this.filteredCount,
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const AppAssetIcon(
              assetPath: 'assets/images/icon_manejo.png',
              size: 24,
            ),
            Text(
              selectedCount.toString() + ' manejo(s) selecionado(s)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: filteredCount == 0 || allSelected ? null : onSelectAll,
              child: const Text('Selecionar todos'),
            ),
            TextButton(
              onPressed: selectedCount == 0 ? null : onClear,
              child: const Text('Limpar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManejoCard extends StatelessWidget {
  final _ManejoItem item;
  final bool selected;
  final VoidCallback onSelected;
  final String typeLabel;
  final String? detail;
  final String date;

  const _ManejoCard({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.typeLabel,
    required this.detail,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelected,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: .10),
            child: const AppAssetIcon(
              assetPath: 'assets/images/icon_manejo.png',
              size: 24,
            ),
          ),
          title: Text(
            item.nome?.trim().isNotEmpty == true
                ? item.nome! + ' · ' + item.brinco
                : 'Brinco ' + item.brinco,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              detail == null || detail!.isEmpty
                  ? typeLabel + ' · ' + date
                  : typeLabel + ' · ' + date + ' · ' + detail!,
            ),
          ),
          trailing: Checkbox(
            value: selected,
            onChanged: (_) => onSelected(),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
