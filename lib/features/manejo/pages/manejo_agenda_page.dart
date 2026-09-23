import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_service.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../models/manejo.dart';
import '../services/manejo_programado_service.dart';
import '../services/manejo_service.dart';
import '../widgets/manejo_animal_selector.dart';

class ManejoAgendaPage extends StatefulWidget {
  const ManejoAgendaPage({super.key});

  @override
  State<ManejoAgendaPage> createState() => _ManejoAgendaPageState();
}

class _ManejoAgendaPageState extends State<ManejoAgendaPage> {
  final ManejoProgramadoService _service = ManejoProgramadoService();
  final AnimalService _animalService = AnimalService();
  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;
  List<Map<String, dynamic>> _itens = [];
  bool _carregando = true;

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
    setState(() => _carregando = true);
    try {
      final loteId = _rebanhoSelectionService.rebanhoSelecionadoId;
      if (loteId == null) {
        if (!mounted) return;
        setState(() {
          _itens = [];
          _carregando = false;
        });
        return;
      }

      final dados = await _service.getProgramados();
      final animais = await _animalService.getAnimaisAtivos(rebanhoId: loteId);
      final idsDoLote = animais.map((animal) => animal['id'].toString()).toSet();
      final filtrados = dados.where((item) {
        final lista = item['manejos_programados_animais'];
        if (lista is! List) return false;
        return lista.any((vinculo) {
          final id = vinculo is Map ? vinculo['animal_id']?.toString() : null;
          return id != null && idsDoLote.contains(id);
        });
      }).toList();

      if (mounted) {
        setState(() {
          _itens = filtrados;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        _msg(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String _tipo(String? valor) {
    switch (Manejo.tipoFromString(valor)) {
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
      case TipoManejo.outro:
        return 'Outro';
    }
  }

  IconData _icone(String? valor) {
    switch (Manejo.tipoFromString(valor)) {
      case TipoManejo.vacinacao:
        return Icons.vaccines_outlined;
      case TipoManejo.vermifugacao:
        return Icons.medication_outlined;
      case TipoManejo.tratamento:
        return Icons.medical_services_outlined;
      case TipoManejo.tosquia:
        return Icons.content_cut_outlined;
      case TipoManejo.pesagem:
        return Icons.monitor_weight_outlined;
      case TipoManejo.famacha:
        return Icons.visibility_outlined;
      case TipoManejo.outro:
        return Icons.assignment_outlined;
    }
  }

  DateTime _data(Map<String, dynamic> item) {
    return DateTime.tryParse(item['data_programada']?.toString() ?? '') ??
        DateTime.now();
  }

  String _dataTexto(DateTime d) {
    return d.day.toString().padLeft(2, '0') +
        '/' +
        d.month.toString().padLeft(2, '0') +
        '/' +
        d.year.toString();
  }

  String _status(Map<String, dynamic> item) {
    if (item['concluido'] == true) return 'Realizado';

    final hoje = DateTime.now();
    final d = _data(item);
    final a = DateTime(hoje.year, hoje.month, hoje.day);
    final b = DateTime(d.year, d.month, d.day);

    if (b.isBefore(a)) return 'Atrasado';
    if (b == a) return 'Hoje';
    return 'Programado';
  }

  Color _cor(String status) {
    if (status == 'Atrasado') return Colors.red;
    if (status == 'Hoje') return Colors.orange;
    if (status == 'Realizado') return Colors.green;
    return AppTheme.primaryColor;
  }

  String _animais(Map<String, dynamic> item) {
    final lista = item['manejos_programados_animais'];
    if (lista is! List || lista.isEmpty) return 'Nenhum animal';

    final nomes = lista.map((x) {
      final animal = x is Map ? x['animais'] : null;
      if (animal is! Map) return 'Animal';

      final brinco = animal['brinco']?.toString() ?? '';
      final nome = animal['nome']?.toString().trim();

      return nome != null && nome.isNotEmpty
          ? '$brinco • $nome'
          : 'Brinco $brinco';
    }).toList();

    return nomes.length <= 3
        ? nomes.join(', ')
        : nomes.take(3).join(', ') +
            ' + ' +
            (nomes.length - 3).toString() +
            ' outros';
  }

  void _msg(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto)),
      );
    }
  }

  Future<void> _novo() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManejoAgendaFormPage()),
    );
    if (resultado == true && mounted) {
      await _carregar();
    }
  }

  Future<void> _concluir(Map<String, dynamic> item) async {
    try {
      await _service.concluir(item['id'].toString());
      if (!mounted) return;
      _msg('Manejo marcado como realizado.');
      await _carregar();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _reprogramar(Map<String, dynamic> item) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data(item).isBefore(DateTime.now())
          ? DateTime.now()
          : _data(item),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (d == null) return;

    try {
      await _service.reprogramar(item['id'].toString(), d);
      if (!mounted) return;
      _msg('Manejo reprogramado.');
      await _carregar();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _excluir(Map<String, dynamic> item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir programação'),
        content: const Text('Deseja excluir este manejo programado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _service.excluir(item['id'].toString());
      if (!mounted) return;
      _msg('Programação excluída.');
      await _carregar();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda de manejo')),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _body(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _carregando ? null : _novo,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Programar manejo'),
      ),
    );
  }

  Widget _body() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_itens.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.event_note_outlined, size: 64),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Nenhum manejo programado.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Programe cuidados para uma ou várias ovelhas.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _itens[index];
        final status = _status(item);
        final cor = _cor(status);
        final tipo = Manejo.tipoFromString(item['tipo']?.toString());

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.10),
                      child: Icon(
                        _icone(item['tipo']?.toString()),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _tipo(item['tipo']?.toString()),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Data: ' + _dataTexto(_data(item))),
                const SizedBox(height: 8),
                Text('Animais: ' + _animais(item)),
                if (tipo == TipoManejo.outro &&
                    (item['outro_nome']?.toString().trim().isNotEmpty == true)) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Manejo: ' + item['outro_nome'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                if (tipo == TipoManejo.vacinacao &&
                    (item['vacina_nome']?.toString().trim().isNotEmpty == true)) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Vacina: ' + item['vacina_nome'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                if ((item['observacoes']?.toString() ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item['observacoes'].toString(),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (status != 'Realizado')
                      FilledButton.icon(
                        onPressed: () => _concluir(item),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Realizar'),
                      ),
                    if (status != 'Realizado')
                      OutlinedButton.icon(
                        onPressed: () => _reprogramar(item),
                        icon: const Icon(
                          Icons.edit_calendar_outlined,
                          size: 18,
                        ),
                        label: const Text('Reprogramar'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _excluir(item),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Excluir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ManejoAgendaFormPage extends StatefulWidget {
  const ManejoAgendaFormPage({super.key});

  @override
  State<ManejoAgendaFormPage> createState() => _ManejoAgendaFormPageState();
}

class _ManejoAgendaFormPageState extends State<ManejoAgendaFormPage> {
  final ManejoProgramadoService _service = ManejoProgramadoService();
  final ManejoService _manejoService = ManejoService();
  final AnimalService _animalService = AnimalService();
  final RebanhoService _rebanhoService = RebanhoService();
  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;

  final TextEditingController _observacoes = TextEditingController();
  final TextEditingController _outroNome = TextEditingController();

  List<Map<String, dynamic>> _rebanhos = [];
  List<Map<String, dynamic>> _animais = [];
  List<Map<String, dynamic>> _vacinas = [];

  final Set<String> _selecionados = {};
  String? _rebanhoId;
  Map<String, dynamic>? _vacinaSelecionada;

  TipoManejo _tipo = TipoManejo.vacinacao;
  DateTime _data = DateTime.now().add(const Duration(days: 1));

  bool _carregando = true;
  bool _carregandoAnimais = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _rebanhoId = _rebanhoSelectionService.rebanhoSelecionadoId;
    _carregar();
  }

  @override
  void dispose() {
    _observacoes.dispose();
    _outroNome.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final resultados = await Future.wait([
        _rebanhoService.getRebanhos(somenteAtivos: true),
        _manejoService.getVacinas(),
      ]);

      if (!mounted) return;

      setState(() {
        final todosRebanhos = List<Map<String, dynamic>>.from(resultados[0] as List);
        final loteId = _rebanhoSelectionService.rebanhoSelecionadoId;
        _rebanhos = loteId == null
            ? <Map<String, dynamic>>[]
            : todosRebanhos.where((item) => item['id']?.toString() == loteId).toList();
        _rebanhoId = loteId;
        _vacinas = List<Map<String, dynamic>>.from(resultados[1] as List);
        _carregando = false;
      });

      await _carregarAnimais();
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _carregarAnimais() async {
    setState(() => _carregandoAnimais = true);
    try {
      final animais = await _animalService.getAnimaisAtivos(
        rebanhoId: _rebanhoId,
      );

      if (!mounted) return;

      setState(() {
        _animais = animais;
        _carregandoAnimais = false;
        final ids = animais.map((a) => a['id']?.toString()).whereType<String>().toSet();
        _selecionados.removeWhere((id) => !ids.contains(id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoAnimais = false);
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _adicionarVacina() async {
    String nome = '';
    String fabricante = '';

    final dados = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova vacina'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => nome = value,
              decoration: const InputDecoration(
                labelText: 'Nome da vacina',
                hintText: 'Ex.: Vacina contra clostridioses',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => fabricante = value,
              decoration: const InputDecoration(
                labelText: 'Fabricante',
                hintText: 'Opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nome.trim().isEmpty) return;
              Navigator.of(dialogContext).pop({
                'nome': nome.trim(),
                'fabricante': fabricante.trim(),
              });
            },
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );

    if (dados == null || !mounted) return;

    try {
      final vacina = await _manejoService.criarVacina(
        nome: dados['nome']!,
        fabricante: dados['fabricante'],
      );
      setState(() {
        _vacinas = [..._vacinas, vacina]
          ..sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));
        _vacinaSelecionada = vacina;
      });
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _salvar() async {
    if (_selecionados.isEmpty) {
      _msg('Selecione pelo menos um animal.');
      return;
    }

    if (_tipo == TipoManejo.outro && _outroNome.text.trim().isEmpty) {
      _msg('Informe o nome do manejo.');
      return;
    }

    if (_tipo == TipoManejo.vacinacao && _vacinaSelecionada == null) {
      _msg('Selecione a vacina programada.');
      return;
    }

    setState(() => _salvando = true);

    try {
      await _service.criar(
        tipo: _tipo,
        dataProgramada: _data,
        animalIds: _selecionados.toList(),
        observacoes: _observacoes.text,
        vacinaId: _tipo == TipoManejo.vacinacao
            ? _vacinaSelecionada == null ? null : _vacinaSelecionada!['id']?.toString()
            : null,
        vacinaNome: _tipo == TipoManejo.vacinacao
            ? _vacinaSelecionada == null ? null : _vacinaSelecionada!['nome']?.toString()
            : null,
        vacinaFabricante: _tipo == TipoManejo.vacinacao
            ? _vacinaSelecionada == null ? null : _vacinaSelecionada!['fabricante']?.toString()
            : null,
        outroNome: _tipo == TipoManejo.outro ? _outroNome.text.trim() : null,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _dataPicker() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (d != null && mounted) {
      setState(() => _data = d);
    }
  }

  void _toggleAnimal(String id) {
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
      } else {
        _selecionados.add(id);
      }
    });
  }

  void _selecionarTodos() {
    setState(() {
      _selecionados
        ..clear()
        ..addAll(
          _animais.map((a) => a['id']?.toString()).whereType<String>(),
        );
    });
  }

  void _limpar() {
    setState(() => _selecionados.clear());
  }

  String _tipoTexto(TipoManejo tipo) {
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
      case TipoManejo.outro:
        return 'Outro';
    }
  }

  String _dataTexto(DateTime d) {
    return d.day.toString().padLeft(2, '0') +
        '/' +
        d.month.toString().padLeft(2, '0') +
        '/' +
        d.year.toString();
  }

  void _msg(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programar manejo')),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                DropdownButtonFormField<TipoManejo>(
                  value: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de manejo',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: TipoManejo.values.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(_tipoTexto(tipo)),
                    );
                  }).toList(),
                  onChanged: _salvando
                      ? null
                      : (tipo) {
                          if (tipo == null) return;
                          setState(() {
                            _tipo = tipo;
                            _vacinaSelecionada = null;
                          });
                        },
                ),
                if (_tipo == TipoManejo.outro) ...[
                  TextField(
                    controller: _outroNome,
                    enabled: !_salvando,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nome do manejo',
                      hintText: 'Ex.: Revisão de casco',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: _salvando ? null : _dataPicker,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data programada',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_dataTexto(_data)),
                  ),
                ),
                const SizedBox(height: 16),
                ManejoAnimalSelector(
                  rebanhos: _rebanhos,
                  rebanhoId: _rebanhoId,
                  animais: _animais,
                  selecionados: _selecionados,
                  carregando: _carregandoAnimais,
                  enabled: !_salvando,
                  multiSelecao: true,
                  titulo: 'Animais do manejo',
                  onRebanhoChanged: (id) {
                    setState(() {
                      _rebanhoId = id;
                      _selecionados.clear();
                    });
                    _carregarAnimais();
                  },
                  onToggleAnimal: _toggleAnimal,
                  onSelecionarTodos: _selecionarTodos,
                  onLimpar: _limpar,
                ),
                if (_tipo == TipoManejo.vacinacao) ...[
                  const SizedBox(height: 16),
                  _vacinaField(),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _observacoes,
                  enabled: !_salvando,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.event_available_outlined),
                    label: Text(
                      _salvando ? 'Salvando...' : 'Programar manejo',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _vacinaField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vacina programada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _vacinaSelecionada == null ? null : _vacinaSelecionada!['id']?.toString(),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Nome da vacina',
              prefixIcon: Icon(Icons.vaccines_outlined),
              border: OutlineInputBorder(),
            ),
            hint: const Text('Selecione a vacina'),
            items: _vacinas.map((vacina) {
              final id = vacina['id']?.toString();
              if (id == null) return null;
              final fabricante = vacina['fabricante']?.toString().trim();
              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  fabricante == null || fabricante.isEmpty
                      ? vacina['nome'].toString()
                      : vacina['nome'].toString() + ' • ' + fabricante,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).whereType<DropdownMenuItem<String>>().toList(),
            onChanged: _salvando
                ? null
                : (id) {
                    if (id == null) return;
                    setState(() {
                      _vacinaSelecionada = _vacinas.firstWhere(
                        (item) => item['id']?.toString() == id,
                      );
                    });
                  },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _salvando ? null : _adicionarVacina,
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar nova vacina'),
          ),
        ],
      ),
    );
  }
}
