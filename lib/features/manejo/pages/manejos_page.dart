import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../models/manejo.dart';
import '../services/manejo_service.dart';
import 'manejo_form_page.dart';
import 'manejo_details_page.dart';

class ManejosPage extends StatefulWidget {
  const ManejosPage({super.key});

  @override
  State<ManejosPage> createState() => _ManejosPageState();
}

class _ManejosPageState extends State<ManejosPage> {
  final ManejoService _service = ManejoService();
  final AnimalService _animalService = AnimalService();
  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;
  List<Map<String, dynamic>> _manejos = [];
  bool _carregando = true;
  String? _erro;

  String _busca = '';
  TipoManejo? _tipoFiltro;
  String? _animalFiltro;
  DateTimeRange? _periodoFiltro;
  Set<String> _animalIdsDoLote = {};

  @override
  void initState() {
    super.initState();
    _rebanhoSelectionService.addListener(_onLoteChanged);
    _carregar();
  }

  @override
  void dispose() {
    _rebanhoSelectionService.removeListener(_onLoteChanged);
    super.dispose();
  }

  void _onLoteChanged() {
    if (!mounted) return;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final loteId = _rebanhoSelectionService.rebanhoSelecionadoId;
      final dados = await _service.getManejos();
      final animaisDoLote = loteId == null
          ? <Map<String, dynamic>>[]
          : await _animalService.getTodosAnimais(rebanhoId: loteId);
      final ids = animaisDoLote.map((animal) => animal['id'].toString()).toSet();
      final filtrados = loteId == null
          ? <Map<String, dynamic>>[]
          : dados.where((item) => ids.contains(item['animal_id']?.toString())).toList();

      if (!mounted) return;
      setState(() {
        _animalIdsDoLote = ids;
        _manejos = filtrados;
        _animalFiltro = null;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }


  List<Map<String, dynamic>> get _manejosFiltrados {
    return _manejos.where((registro) {
      final manejo = Manejo.fromMap(registro);
      final animal = registro['animais'];
      final textoAnimal = animal is Map
          ? (animal['brinco']?.toString() ?? '') + ' ' +
              (animal['nome']?.toString() ?? '').toLowerCase()
          : '';
      final busca = _busca.trim().toLowerCase();

      if (busca.isNotEmpty &&
          !textoAnimal.toLowerCase().contains(busca) &&
          !_tipo(manejo.tipo).toLowerCase().contains(busca) &&
          !(manejo.observacoes ?? '').toLowerCase().contains(busca) &&
          !(manejo.vacinaNome ?? '').toLowerCase().contains(busca) &&
          !(manejo.outroNome ?? '').toLowerCase().contains(busca)) {
        return false;
      }

      if (_tipoFiltro != null && manejo.tipo != _tipoFiltro) return false;
      if (_animalFiltro != null && manejo.animalId != _animalFiltro) return false;

      if (_periodoFiltro != null) {
        final data = DateTime(manejo.data.year, manejo.data.month, manejo.data.day);
        final inicio = DateTime(
          _periodoFiltro!.start.year,
          _periodoFiltro!.start.month,
          _periodoFiltro!.start.day,
        );
        final fim = DateTime(
          _periodoFiltro!.end.year,
          _periodoFiltro!.end.month,
          _periodoFiltro!.end.day,
          23,
          59,
          59,
        );
        if (data.isBefore(inicio) || data.isAfter(fim)) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _escolherPeriodo() async {
    final periodo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _periodoFiltro,
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione o período',
      saveText: 'Aplicar',
    );

    if (periodo != null && mounted) {
      setState(() => _periodoFiltro = periodo);
    }
  }

  void _limparFiltros() {
    setState(() {
      _busca = '';
      _tipoFiltro = null;
      _animalFiltro = null;
      _periodoFiltro = null;
    });
  }

  Widget _filtros() {
    final animais = <String, String>{};

    for (final registro in _manejos) {
      final id = registro['animal_id']?.toString();
      if (id != null && registro['animais'] is Map) {
        animais[id] = _animal(registro);
      }
    }

    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => _busca = value),
          decoration: InputDecoration(
            hintText: 'Buscar animal, tipo ou observação',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busca.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(() => _busca = ''),
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chipTipo(null, 'Todos'),
              ...TipoManejo.values.map(
                (tipo) => _chipTipo(tipo, _tipo(tipo)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final estreito = constraints.maxWidth < 430;
            final animalField = DropdownButtonFormField<String?>(
              value: _animalFiltro,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Animal',
                prefixIcon: Icon(Icons.pets_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos os animais'),
                ),
                ...animais.entries.map(
                  (entry) => DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _animalFiltro = value),
            );

            final periodoButton = OutlinedButton.icon(
              onPressed: _escolherPeriodo,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                _periodoFiltro == null
                    ? 'Período'
                    : _periodoFiltro!.start.day.toString().padLeft(2, '0') +
                        '/' +
                        _periodoFiltro!.start.month.toString().padLeft(2, '0') +
                        ' - ' +
                        _periodoFiltro!.end.day.toString().padLeft(2, '0') +
                        '/' +
                        _periodoFiltro!.end.month.toString().padLeft(2, '0'),
              ),
            );

            if (estreito) {
              return Column(
                children: [
                  animalField,
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: periodoButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: animalField),
                const SizedBox(width: 8),
                SizedBox(width: 112, child: periodoButton),
              ],
            );
          },
        ),
        if (_busca.isNotEmpty ||
            _tipoFiltro != null ||
            _animalFiltro != null ||
            _periodoFiltro != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _limparFiltros,
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpar filtros'),
            ),
          ),
      ],
    );
  }

  Widget _chipTipo(TipoManejo? tipo, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _tipoFiltro == tipo,
        onSelected: (_) => setState(() => _tipoFiltro = tipo),
      ),
    );
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Future<void> _novo() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManejoFormPage()),
    );
    if (resultado == true && mounted) await _carregar();
  }

  String _tipo(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao: return 'Vacinação';
      case TipoManejo.vermifugacao: return 'Vermifugação';
      case TipoManejo.tratamento: return 'Tratamento';
      case TipoManejo.tosquia: return 'Tosquia';
      case TipoManejo.pesagem: return 'Pesagem';
      case TipoManejo.famacha: return 'FAMACHA';
      case TipoManejo.outro: return 'Outro';
    }
  }

  IconData _icone(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao: return Icons.vaccines_outlined;
      case TipoManejo.vermifugacao: return Icons.medication_outlined;
      case TipoManejo.tratamento: return Icons.medical_services_outlined;
      case TipoManejo.tosquia: return Icons.content_cut_outlined;
      case TipoManejo.pesagem: return Icons.monitor_weight_outlined;
      case TipoManejo.famacha: return Icons.visibility_outlined;
      case TipoManejo.outro: return Icons.assignment_outlined;
    }
  }

  String _animal(Map<String, dynamic> registro) {
    final animal = registro['animais'];
    if (animal is! Map) return 'Animal não encontrado';

    final numero = int.tryParse(animal['brinco']?.toString() ?? '');
    final brinco = numero == null ? (animal['brinco']?.toString() ?? '') : numero.toString().padLeft(3, '0');
    final nome = animal['nome']?.toString().trim();
    return nome != null && nome.isNotEmpty ? brinco + ' • ' + nome : 'Brinco ' + brinco;
  }

  String _data(dynamic valor) {
    final data = DateTime.tryParse(valor?.toString() ?? '');
    if (data == null) return 'Data não informada';
    return data.day.toString().padLeft(2, '0') + '/' +
        data.month.toString().padLeft(2, '0') + '/' +
        data.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manejo'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _carregar,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _carregar, child: _body()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _carregando ? null : _novo,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo manejo'),
      ),
    );
  }

  Widget _body() {
    if (_carregando) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));

    if (_erro != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text('Não foi possível carregar os manejos', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_erro!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Center(child: FilledButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente'))),
        ],
      );
    }

    if (_rebanhoSelectionService.rebanhoSelecionado == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 120),
        children: [
          Icon(Icons.layers_outlined, size: 72, color: AppTheme.primaryColor.withValues(alpha: 0.65)),
          const SizedBox(height: 18),
          const Text('Selecione um lote', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Escolha o lote no início para visualizar os manejos dele.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4)),
        ],
      );
    }

    if (_manejos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 120),
        children: [
          Icon(Icons.assignment_outlined, size: 72, color: AppTheme.primaryColor.withValues(alpha: 0.65)),
          const SizedBox(height: 18),
          const Text('Nenhum manejo registrado', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Registre vacinação, vermifugação, FAMACHA e outros cuidados do rebanho.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 24),
          Center(child: FilledButton.icon(onPressed: _novo, icon: const Icon(Icons.add), label: const Text('Registrar primeiro manejo'))),
        ],
      );
    }

    final manejos = _manejosFiltrados;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: _filtros(),
        ),
        Expanded(
          child: manejos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhum manejo encontrado com os filtros selecionados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  itemCount: manejos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
                  final registro = manejos[index];
        final manejo = Manejo.fromMap(registro);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icone(manejo.tipo), color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manejo.tipo == TipoManejo.outro && manejo.outroNome != null
                            ? manejo.outroNome!
                            : _tipo(manejo.tipo),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(_animal(registro), style: const TextStyle(color: Colors.black54)),
                      if (manejo.tipo == TipoManejo.vacinacao &&
                          manejo.vacinaNome != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Vacina: ' + manejo.vacinaNome!,
                          style: const TextStyle(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(_data(registro['data']), style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                if (manejo.tipo == TipoManejo.famacha && manejo.famachaEscore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('F' + manejo.famachaEscore.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (acao) async {
                    if (acao == 'detalhes') {
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ManejoDetailsPage(manejoId: manejo.id),
                        ),
                      );
                    }

                    if (acao == 'editar') {
                      final resultado = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => ManejoFormPage(manejo: manejo),
                        ),
                      );
                      if (resultado == true && mounted) await _carregar();
                    }

                    if (acao == 'excluir') {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Excluir manejo?'),
                          content: const Text(
                            'Este registro será removido do histórico. Essa ação não pode ser desfeita.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );

                      if (confirmar != true || !mounted) return;

                      try {
                        await _service.excluirManejo(manejo.id);
                        if (!mounted) return;
                        _mensagem('Manejo excluído.');
                        await _carregar();
                      } catch (e) {
                        if (!mounted) return;
                        _mensagem(
                          e.toString().replaceFirst('Exception: ', ''),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'detalhes',
                      child: Text('Ver detalhes'),
                    ),
                    PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
                  },
                ),
        ),
      ],
    );
  }
}
