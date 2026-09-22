import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_service.dart';
import '../models/manejo.dart';
import '../services/manejo_service.dart';
import '../widgets/famacha_reference_widget.dart';
import '../widgets/manejo_animal_selector.dart';

class ManejoFormPage extends StatefulWidget {
  final Manejo? manejo;

  const ManejoFormPage({
    super.key,
    this.manejo,
  });

  @override
  State<ManejoFormPage> createState() => _ManejoFormPageState();
}

class _ManejoFormPageState extends State<ManejoFormPage> {
  final ManejoService _service = ManejoService();
  final AnimalService _animalService = AnimalService();
  final RebanhoService _rebanhoService = RebanhoService();

  final TextEditingController _observacoes = TextEditingController();
  final TextEditingController _vacinaLote = TextEditingController();
  final TextEditingController _outroNome = TextEditingController();
  final TextEditingController _peso = TextEditingController();
  final TextEditingController _doseManual = TextEditingController();

  List<Map<String, dynamic>> _rebanhos = [];
  List<Map<String, dynamic>> _animais = [];
  List<Map<String, dynamic>> _vacinas = [];
  List<Map<String, dynamic>> _vermifugos = [];
  List<Map<String, dynamic>> _medicamentos = [];

  String? _rebanhoId;
  String? _animalId;
  final Set<String> _animaisSelecionados = {};
  final Map<String, int> _famachaPorAnimal = {};
  final Map<String, double> _pesos = {};
  final Map<String, double> _dosesCalculadas = {};
  final Map<String, String> _pesoTextoPorAnimal = {};
  final Map<String, String> _doseTextoPorAnimal = {};
  String _doseBaseTexto = '';
  String _pesoReferenciaTexto = '1';
  String _unidadeDose = 'mL';
  String _viaAplicacao = '';
  String _carenciaTexto = '';
  int _doseEditorVersao = 0;

  TipoManejo _tipo = TipoManejo.vacinacao;
  DateTime _data = DateTime.now();
  DateTime? _validade;
  int? _famacha;

  Map<String, dynamic>? _vacinaSelecionada;
  Map<String, dynamic>? _vermifugoSelecionado;
  Map<String, dynamic>? _medicamentoSelecionado;
  bool _carregando = true;
  bool _carregandoAnimais = false;
  bool _salvando = false;
  bool _carregandoPesos = false;

  bool get _editando => widget.manejo != null;

  @override
  void initState() {
    super.initState();

    final manejo = widget.manejo;
    if (manejo != null) {
      _animalId = manejo.animalId;
      _tipo = manejo.tipo;
      _data = manejo.data;
      _famacha = manejo.famachaEscore;
      _observacoes.text = manejo.observacoes ?? '';
      _vacinaLote.text = manejo.vacinaLote ?? '';
      _outroNome.text = manejo.outroNome ?? '';
      if (manejo.pesoKg != null) _peso.text = manejo.pesoKg.toString();
      if (manejo.dose != null) {
        _doseManual.text = manejo.dose.toString();
        _doseBaseTexto = manejo.dose.toString();
      }
      if (manejo.pesoReferenciaKg != null) _pesoReferenciaTexto = manejo.pesoReferenciaKg.toString();
      if (manejo.doseUnidade != null && manejo.doseUnidade!.trim().isNotEmpty) _unidadeDose = manejo.doseUnidade!;
      _viaAplicacao = manejo.viaAplicacao ?? '';
      if (manejo.carenciaDias != null) _carenciaTexto = manejo.carenciaDias.toString();
    }

    _carregarDados();
  }

  @override
  void dispose() {
    _observacoes.dispose();
    _vacinaLote.dispose();
    _outroNome.dispose();
    _peso.dispose();
    _doseManual.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      final resultados = await Future.wait([
        _rebanhoService.getRebanhos(somenteAtivos: true),
        _service.getVacinas(),
        _service.getVermifugos(),
        _service.getMedicamentos(),
      ]);

      if (!mounted) return;

      setState(() {
        _rebanhos = List<Map<String, dynamic>>.from(resultados[0] as List);
        _vacinas = List<Map<String, dynamic>>.from(resultados[1] as List);
        _vermifugos = List<Map<String, dynamic>>.from(resultados[2] as List);
        _medicamentos = List<Map<String, dynamic>>.from(resultados[3] as List);
        _carregando = false;
      });

      if (_editando) {
        final animais = await _animalService.getAnimaisAtivos();
        if (!mounted) return;
        setState(() {
          _animais = animais;
          _animaisSelecionados.add(_animalId!);
        });
        if (widget.manejo?.vermifugoId != null) _vermifugoSelecionado = _findItem(_vermifugos, widget.manejo!.vermifugoId);
        if (widget.manejo?.medicamentoId != null) _medicamentoSelecionado = _findItem(_medicamentos, widget.manejo!.medicamentoId);
        await _carregarPesos();
      } else {
        await _carregarAnimais();
      }

      if (widget.manejo?.vacinaId != null) {
        for (final vacina in _vacinas) {
          if (vacina['id']?.toString() == widget.manejo!.vacinaId) {
            if (mounted) setState(() => _vacinaSelecionada = vacina);
            break;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Map<String, dynamic>? _findItem(List<Map<String, dynamic>> lista, String? id) {
    if (id == null) return null;
    for (final item in lista) {
      if (item['id']?.toString() == id) return item;
    }
    return null;
  }

  Future<void> _carregarPesos() async {
    if (_animaisSelecionados.isEmpty) return;
    setState(() => _carregandoPesos = true);
    for (final id in _animaisSelecionados) {
      final peso = await _service.getUltimoPeso(id);
      if (peso != null) {
        _pesos[id] = peso;
        _pesoTextoPorAnimal[id] = peso.toString();
      }
    }
    if (!mounted) return;
    setState(() => _carregandoPesos = false);
    _calcularDoses();
  }

  dynamic _campo(Map<String, dynamic>? mapa, String chave) {
    if (mapa == null) return null;
    return mapa[chave];
  }

  double? _numero(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  void _calcularDoses() {
    final doseBase = _numero(_doseBaseTexto);
    final referencia = _numero(_pesoReferenciaTexto);
    if (doseBase == null || doseBase <= 0 || referencia == null || referencia <= 0) {
      setState(() => _dosesCalculadas.clear());
      return;
    }
    final calculadas = <String, double>{};
    for (final id in _animaisSelecionados) {
      final peso = _numero(_pesoTextoPorAnimal[id]) ?? _pesos[id];
      if (peso != null && peso > 0) calculadas[id] = peso / referencia * doseBase;
    }
    setState(() => _dosesCalculadas
      ..clear()
      ..addAll(calculadas));
  }

  void _atualizarPesoAnimal(String id, String valor) {
    _pesoTextoPorAnimal[id] = valor;
    final peso = _numero(valor);
    if (peso != null && peso > 0) {
      _pesos[id] = peso;
    } else {
      _pesos.remove(id);
    }
    _calcularDoses();
  }

  void _atualizarDoseAnimal(String id, String valor) {
    _doseTextoPorAnimal[id] = valor;
    final dose = _numero(valor);
    if (dose == null || dose < 0) {
      _dosesCalculadas.remove(id);
    } else {
      _dosesCalculadas[id] = dose;
    }
    setState(() {});
  }

  void _aplicarRegraDoseTodos() {
    final doseBase = _numero(_doseBaseTexto);
    final referencia = _numero(_pesoReferenciaTexto);
    if (doseBase == null || doseBase <= 0 || referencia == null || referencia <= 0) {
      _mensagem('Informe a dose base e o peso de referência.');
      return;
    }
    final calculadas = <String, double>{};
    for (final id in _animaisSelecionados) {
      final peso = _numero(_pesoTextoPorAnimal[id]) ?? _pesos[id];
      if (peso != null && peso > 0) calculadas[id] = peso / referencia * doseBase;
    }
    if (calculadas.length != _animaisSelecionados.length) {
      _mensagem('Informe o peso de cada animal antes de aplicar a dose em lote.');
      return;
    }
    setState(() {
      _dosesCalculadas
        ..clear()
        ..addAll(calculadas);
      _doseEditorVersao++;
      for (final entry in calculadas.entries) {
        _doseTextoPorAnimal[entry.key] = entry.value.toStringAsFixed(2);
      }
    });
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
        _animaisSelecionados.removeWhere((id) => !ids.contains(id));
        _famachaPorAnimal.removeWhere((id, _) => !ids.contains(id));

        if (_animalId != null && !ids.contains(_animalId)) {
          _animalId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoAnimais = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _adicionarVacina() async {
    String nome = '';
    String fabricante = '';

    final dados = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova vacina'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                onChanged: (value) => nome = value,
                decoration: const InputDecoration(labelText: 'Nome da vacina'),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => fabricante = value,
                decoration: const InputDecoration(labelText: 'Fabricante'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (nome.trim().isEmpty) return;
              Navigator.of(dialogContext).pop({'nome': nome.trim(), 'fabricante': fabricante.trim()});
            },
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );
    if (dados == null || !mounted) return;
    try {
      final vacina = await _service.criarVacina(nome: dados['nome']!, fabricante: dados['fabricante']);
      setState(() {
        _vacinas = [..._vacinas, vacina]
          ..sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));
        _vacinaSelecionada = vacina;
      });
    } catch (e) {
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _produtoField({
    required String titulo,
    required List<Map<String, dynamic>> itens,
    required Map<String, dynamic>? selecionado,
    required ValueChanged<Map<String, dynamic>?> onChanged,
    required VoidCallback onAdicionar,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.14))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selecionado?['id']?.toString(), isExpanded: true,
          decoration: InputDecoration(labelText: 'Selecionar ' + titulo, prefixIcon: const Icon(Icons.medical_services_outlined), border: const OutlineInputBorder()),
          items: itens.map((item) {
            final id = item['id']?.toString(); if (id == null) return null;
            final nome = item['nome']?.toString() ?? titulo;
            final principio = item['principio_ativo']?.toString().trim();
            return DropdownMenuItem<String>(value: id, child: Text(principio == null || principio.isEmpty ? nome : '$nome • $principio', overflow: TextOverflow.ellipsis));
          }).whereType<DropdownMenuItem<String>>().toList(),
          onChanged: _salvando ? null : (id) {
            final item = id == null ? null : itens.firstWhere((x) => x['id']?.toString() == id);
            onChanged(item);
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: _salvando ? null : onAdicionar, icon: const Icon(Icons.add), label: Text('Cadastrar novo ' + titulo.toLowerCase())),
      ]),
    );
  }

  Future<void> _adicionarVermifugoCompleto() async {
    String nome = ''; String principio = '';
    final dados = await showDialog<Map<String, String>>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Novo vermífugo'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(autofocus: true, onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: 'Nome do produto')),
        const SizedBox(height: 12),
        TextField(onChanged: (v) => principio = v, decoration: const InputDecoration(labelText: 'Princípio ativo')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () { if (nome.trim().isEmpty) return; Navigator.of(dialogContext).pop({'nome': nome.trim(), 'principio': principio.trim()}); }, child: const Text('Cadastrar')),
      ],
    ));
    if (dados == null || !mounted) return;
    try {
      final item = await _service.criarVermifugo(nome: dados['nome']!, principioAtivo: dados['principio']);
      setState(() { _vermifugos = [..._vermifugos, item]; _vermifugoSelecionado = item; });
    } catch (e) { _mensagem(e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _adicionarMedicamentoCompleto() async {
    String nome = ''; String principio = '';
    final dados = await showDialog<Map<String, String>>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Novo medicamento'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(autofocus: true, onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: 'Nome do medicamento')),
        const SizedBox(height: 12),
        TextField(onChanged: (v) => principio = v, decoration: const InputDecoration(labelText: 'Princípio ativo')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () { if (nome.trim().isEmpty) return; Navigator.of(dialogContext).pop({'nome': nome.trim(), 'principio': principio.trim()}); }, child: const Text('Cadastrar')),
      ],
    ));
    if (dados == null || !mounted) return;
    try {
      final item = await _service.criarMedicamento(nome: dados['nome']!, principioAtivo: dados['principio']);
      setState(() { _medicamentos = [..._medicamentos, item]; _medicamentoSelecionado = item; });
    } catch (e) { _mensagem(e.toString().replaceFirst('Exception: ', '')); }
  }
  void _selecionarTodos() {
    setState(() {
      _animaisSelecionados
        ..clear()
        ..addAll(_animais.map((animal) => animal['id']?.toString()).whereType<String>());
    });
    if (_tipo == TipoManejo.vacinacao || _tipo == TipoManejo.vermifugacao || _tipo == TipoManejo.tratamento) {
      _carregarPesos();
    }
  }

  void _limparSelecao() {
    setState(() {
      _animaisSelecionados.clear();
      _famachaPorAnimal.clear();
      _pesos.clear();
      _dosesCalculadas.clear();
      _pesoTextoPorAnimal.clear();
      _doseTextoPorAnimal.clear();
    });
  }

  void _alternarAnimal(String id) {
    setState(() {
      if (_animaisSelecionados.contains(id)) {
        _animaisSelecionados.remove(id);
        _famachaPorAnimal.remove(id);
        _pesoTextoPorAnimal.remove(id);
        _doseTextoPorAnimal.remove(id);
        _pesos.remove(id);
        _dosesCalculadas.remove(id);
      } else {
        _animaisSelecionados.add(id);
      }

      if (_tipo != TipoManejo.famacha && _animaisSelecionados.isEmpty) {
        _animalId = null;
      }
    });

    if (_animaisSelecionados.contains(id) &&
        (_tipo == TipoManejo.vacinacao ||
            _tipo == TipoManejo.vermifugacao ||
            _tipo == TipoManejo.tratamento)) {
      _carregarPesos();
    }
  }

  void _definirFamacha(String animalId, int escore) {
    setState(() => _famachaPorAnimal[animalId] = escore);
  }

  Future<void> _salvar() async {
    if (_editando) {
      await _salvarEdicao();
      return;
    }

    if (_animaisSelecionados.isEmpty) {
      _mensagem('Selecione pelo menos um animal.');
      return;
    }

    if (_tipo == TipoManejo.famacha) {
      final faltando = _animaisSelecionados.where(
        (id) => _famachaPorAnimal[id] == null,
      );
      if (faltando.isNotEmpty) {
        _mensagem('Informe o FAMACHA de todos os animais selecionados.');
        return;
      }
    }

    if (_tipo == TipoManejo.vacinacao && _vacinaSelecionada == null) {
      _mensagem('Selecione a vacina aplicada.');
      return;
    }

    final tipoSanitario = _tipo == TipoManejo.vacinacao ||
        _tipo == TipoManejo.vermifugacao ||
        _tipo == TipoManejo.tratamento;

    if (tipoSanitario) {
      final faltando = _animaisSelecionados.where((id) {
        final peso = _numero(_pesoTextoPorAnimal[id]) ?? _pesos[id];
        final dose = _numero(_doseTextoPorAnimal[id]) ?? _dosesCalculadas[id];
        return peso == null || peso <= 0 || dose == null || dose < 0;
      });

      if (faltando.isNotEmpty) {
        _mensagem('Informe peso e dose de cada animal. Use "Aplicar a mesma dose por kg a todas" se quiser calcular em lote.');
        return;
      }
    }

    setState(() => _salvando = true);

    try {
      final vacinaId = _tipo == TipoManejo.vacinacao
          ? _campo(_vacinaSelecionada, 'id')?.toString()
          : null;
      final vacinaNome = _tipo == TipoManejo.vacinacao
          ? _campo(_vacinaSelecionada, 'nome')?.toString()
          : null;
      final vacinaFabricante = _tipo == TipoManejo.vacinacao
          ? _campo(_vacinaSelecionada, 'fabricante')?.toString()
          : null;

      final pesosParaSalvar = <String, double>{};
      final dosesParaSalvar = <String, double>{};

      for (final id in _animaisSelecionados) {
        final peso = _numero(_pesoTextoPorAnimal[id]) ?? _pesos[id];
        final dose = _numero(_doseTextoPorAnimal[id]) ?? _dosesCalculadas[id];
        if (peso != null) pesosParaSalvar[id] = peso;
        if (dose != null) dosesParaSalvar[id] = dose;
      }

      await _service.criarManejosEmLote(
        animalIds: _animaisSelecionados.toList(),
        data: _data,
        tipo: _tipo,
        famachaPorAnimal: _famachaPorAnimal,
        observacoes: _observacoes.text,
        vacinaId: vacinaId,
        vacinaNome: vacinaNome,
        vacinaFabricante: vacinaFabricante,
        vacinaLote: _tipo == TipoManejo.vacinacao
            ? _vacinaLote.text
            : null,
        outroNome: _tipo == TipoManejo.outro ? _outroNome.text : null,
        pesoPorAnimal: pesosParaSalvar,
        dosePorAnimal: dosesParaSalvar,
        dose: _numero(_doseBaseTexto),
        doseUnidade: _unidadeDose,
        pesoReferenciaKg: _numero(_pesoReferenciaTexto),
        viaAplicacao: _viaAplicacao.trim().isEmpty ? null : _viaAplicacao.trim(),
        carenciaDias: int.tryParse(_carenciaTexto.trim()),
        validade: _validade,
        vermifugoId: _tipo == TipoManejo.vermifugacao ? _campo(_vermifugoSelecionado, 'id')?.toString() : null,
        vermifugoNome: _tipo == TipoManejo.vermifugacao ? _campo(_vermifugoSelecionado, 'nome')?.toString() : null,
        vermifugoPrincipioAtivo: _tipo == TipoManejo.vermifugacao ? _campo(_vermifugoSelecionado, 'principio_ativo')?.toString() : null,
        medicamentoId: _tipo == TipoManejo.tratamento ? _campo(_medicamentoSelecionado, 'id')?.toString() : null,
        medicamentoNome: _tipo == TipoManejo.tratamento ? _campo(_medicamentoSelecionado, 'nome')?.toString() : null,
        medicamentoPrincipioAtivo: _tipo == TipoManejo.tratamento ? _campo(_medicamentoSelecionado, 'principio_ativo')?.toString() : null,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _salvarEdicao() async {
    if (_animalId == null) {
      _mensagem('Selecione o animal.');
      return;
    }

    if (_tipo == TipoManejo.famacha && _famacha == null) {
      _mensagem('Selecione a classificação FAMACHA.');
      return;
    }

    if (_tipo == TipoManejo.vacinacao && _vacinaSelecionada == null) {
      _mensagem('Selecione a vacina aplicada.');
      return;
    }

    setState(() => _salvando = true);

    try {
      final vacinaId = _tipo == TipoManejo.vacinacao
          ? _campo(_vacinaSelecionada, 'id')?.toString()
          : null;
      final vacinaNome = _tipo == TipoManejo.vacinacao
          ? _campo(_vacinaSelecionada, 'nome')?.toString()
          : null;
      final vacinaFabricante = _tipo == TipoManejo.vacinacao
          ? _campo(_vacinaSelecionada, 'fabricante')?.toString()
          : null;

      await _service.atualizarManejo(
        id: widget.manejo!.id,
        animalId: _animalId!,
        tipo: _tipo,
        data: _data,
        famachaEscore: _tipo == TipoManejo.famacha ? _famacha : null,
        observacoes: _observacoes.text,
        vacinaId: vacinaId,
        vacinaNome: vacinaNome,
        vacinaFabricante: vacinaFabricante,
        vacinaLote: _tipo == TipoManejo.vacinacao ? _vacinaLote.text : null,
        outroNome: _tipo == TipoManejo.outro ? _outroNome.text : null,
        pesoKg: _tipo == TipoManejo.pesagem ? _numero(_peso.text) : _pesos[_animalId],
        dose: _dosesCalculadas[_animalId] ?? _numero(_doseManual.text),
        doseUnidade: _unidadeDose,
        pesoReferenciaKg: _numero(_pesoReferenciaTexto),
        viaAplicacao: _viaAplicacao.trim().isEmpty ? null : _viaAplicacao.trim(),
        carenciaDias: int.tryParse(_carenciaTexto.trim()),
        vermifugoId: _tipo == TipoManejo.vermifugacao ? _campo(_vermifugoSelecionado, 'id')?.toString() : null,
        vermifugoNome: _tipo == TipoManejo.vermifugacao ? _campo(_vermifugoSelecionado, 'nome')?.toString() : null,
        vermifugoPrincipioAtivo: _tipo == TipoManejo.vermifugacao ? _campo(_vermifugoSelecionado, 'principio_ativo')?.toString() : null,
        medicamentoId: _tipo == TipoManejo.tratamento ? _campo(_medicamentoSelecionado, 'id')?.toString() : null,
        medicamentoNome: _tipo == TipoManejo.tratamento ? _campo(_medicamentoSelecionado, 'nome')?.toString() : null,
        medicamentoPrincipioAtivo: _tipo == TipoManejo.tratamento ? _campo(_medicamentoSelecionado, 'principio_ativo')?.toString() : null,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (escolhida != null && mounted) {
      setState(() => _data = escolhida);
    }
  }

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

  Map<String, dynamic>? _animalPorId(String id) {
    for (final animal in _animais) {
      if (animal['id']?.toString() == id) return animal;
    }
    return null;
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

  Color _corFamacha(int escore) {
    switch (escore) {
      case 1:
        return const Color(0xFFB71C1C);
      case 2:
        return const Color(0xFFE53935);
      case 3:
        return const Color(0xFFE57373);
      case 4:
        return const Color(0xFFF8B6B6);
      case 5:
        return const Color(0xFFF5EAEA);
      default:
        return Colors.grey;
    }
  }

  String _descricaoFamacha(int escore) {
    switch (escore) {
      case 1:
        return 'Vermelho intenso';
      case 2:
        return 'Vermelho/rosado';
      case 3:
        return 'Rosa';
      case 4:
        return 'Rosa bem claro';
      case 5:
        return 'Muito pálido';
      default:
        return '';
    }
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto.replaceFirst('Exception: ', ''))),
    );
  }

  void _mostrarInformativoFamacha() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informativo FAMACHA',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A FAMACHA usa a cor da mucosa da pálpebra inferior para estimar o grau de anemia do animal.',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 16),
                _infoLinha('1', 'Vermelho', 'Sem sinal visual de anemia importante.'),
                _infoLinha('2', 'Vermelho/rosado', 'Faixa geralmente aceitável.'),
                _infoLinha('3', 'Rosa', 'Faixa intermediária, merece acompanhamento.'),
                _infoLinha('4', 'Rosa muito claro', 'Anemia importante, requer atenção.'),
                _infoLinha('5', 'Muito pálido', 'Anemia grave, requer atenção imediata.'),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Importante: FAMACHA não identifica sozinha a causa da anemia. Parasitas que causam perda de sangue, como o Haemonchus contortus, são uma causa importante, mas outros problemas também podem estar envolvidos. Não use o escore como diagnóstico isolado.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Para uma avaliação correta, observe a mucosa diretamente, em boa iluminação, e compare com um cartão FAMACHA apropriado. O aplicativo serve como apoio de registro.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.45),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoLinha(String escore, String titulo, String descricao) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _corFamacha(int.parse(escore)),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
            ),
            child: Text(escore, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(descricao, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar manejo' : 'Novo manejo')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth < 420 ? 14.0 : 20.0;
                  final maxWidth = constraints.maxWidth > 760 ? 720.0 : constraints.maxWidth;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
                        children: [
                _intro(),
                const SizedBox(height: 20),
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
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _tipo = value;
                            _animaisSelecionados.clear();
                            _famachaPorAnimal.clear();
                            _famacha = null;
                            if (value != TipoManejo.vacinacao) {
                              _vacinaSelecionada = null;
                              _vacinaLote.clear();
                            }
                            if (value != TipoManejo.vermifugacao) {
                              _vermifugoSelecionado = null;
                            }
                            if (value != TipoManejo.tratamento) {
                              _medicamentoSelecionado = null;
                            }
                            _dosesCalculadas.clear();
                            if (value != TipoManejo.outro) {
                              _outroNome.clear();
                            }
                          });
                        },
                ),
                const SizedBox(height: 16),
                if (_editando)
                  _animalEdicao()
                else
                  ManejoAnimalSelector(
                    rebanhos: _rebanhos,
                    rebanhoId: _rebanhoId,
                    animais: _animais,
                    selecionados: _animaisSelecionados,
                    carregando: _carregandoAnimais,
                    enabled: !_salvando,
                    multiSelecao: true,
                    titulo: _tipo == TipoManejo.famacha
                        ? 'Ovelhas avaliadas'
                        : 'Animais do manejo',
                    onRebanhoChanged: (id) {
                      setState(() {
                        _rebanhoId = id;
                        _animaisSelecionados.clear();
                        _famachaPorAnimal.clear();
                        _pesos.clear();
                        _dosesCalculadas.clear();
                      });
                      _carregarAnimais();
                    },
                    onToggleAnimal: _alternarAnimal,
                    onSelecionarTodos: _selecionarTodos,
                    onLimpar: _limparSelecao,
                  ),
                if (_tipo == TipoManejo.vacinacao) ...[
                  const SizedBox(height: 16),
                  _produtoField(
                    titulo: 'Vacina',
                    itens: _vacinas,
                    selecionado: _vacinaSelecionada,
                    onChanged: (item) => setState(() => _vacinaSelecionada = item),
                    onAdicionar: _adicionarVacina,
                  ),
                  _doseCalculadora(),
                ],
                if (_tipo == TipoManejo.vermifugacao) ...[
                  const SizedBox(height: 16),
                  _produtoField(
                    titulo: 'Vermífugo',
                    itens: _vermifugos,
                    selecionado: _vermifugoSelecionado,
                    onChanged: (item) => setState(() => _vermifugoSelecionado = item),
                    onAdicionar: _adicionarVermifugoCompleto,
                  ),
                  _doseCalculadora(),
                ],
                if (_tipo == TipoManejo.tratamento) ...[
                  const SizedBox(height: 16),
                  _produtoField(
                    titulo: 'Medicamento',
                    itens: _medicamentos,
                    selecionado: _medicamentoSelecionado,
                    onChanged: (item) => setState(() => _medicamentoSelecionado = item),
                    onAdicionar: _adicionarMedicamentoCompleto,
                  ),
                  _doseCalculadora(),
                ],
                if (_tipo == TipoManejo.pesagem) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _peso,
                    enabled: !_salvando,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Peso do animal (kg)',
                      hintText: 'Ex.: 47,5',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_tipo == TipoManejo.outro) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _outroNome,
                    enabled: !_salvando,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nome do manejo',
                      hintText: 'Ex.: Corte de cascos, limpeza do curral',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_tipo == TipoManejo.famacha) ...[
                  const SizedBox(height: 16),
                  if (_editando)
                    _famachaField()
                  else
                    _avaliacaoLote(),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: _salvando ? null : _escolherData,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _data.day.toString().padLeft(2, '0') +
                          '/' +
                          _data.month.toString().padLeft(2, '0') +
                          '/' +
                          _data.year.toString(),
                    ),
                  ),
                ),
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
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _salvando
                          ? 'Salvando...'
                          : _editando
                              ? 'Salvar alterações'
                              : 'Salvar manejo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      },
    ),
  );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_outlined, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registro de manejo', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _editando
                      ? 'Edite o registro deste animal sem alterar seu histórico.'
                      : 'Selecione um rebanho e registre o mesmo manejo para vários animais de uma vez.',
                  style: const TextStyle(height: 1.4),
                ),
                if (_tipo == TipoManejo.famacha) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _mostrarInformativoFamacha,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Entenda a FAMACHA'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animalEdicao() {
    return DropdownButtonFormField<String>(
      value: _animalId,
      decoration: const InputDecoration(
        labelText: 'Animal',
        prefixIcon: Icon(Icons.pets_outlined),
        border: OutlineInputBorder(),
      ),
      items: _animais.map((animal) {
        final id = animal['id']?.toString();
        if (id == null) return null;
        return DropdownMenuItem<String>(
          value: id,
          child: Text(_animalTexto(animal), overflow: TextOverflow.ellipsis),
        );
      }).whereType<DropdownMenuItem<String>>().toList(),
      onChanged: _salvando ? null : (value) => setState(() => _animalId = value),
    );
  }

  Widget _dosePorAnimalEditor() {
    if (_animaisSelecionados.isEmpty) return const SizedBox.shrink();
    final sanitario = _tipo == TipoManejo.vacinacao ||
        _tipo == TipoManejo.vermifugacao ||
        _tipo == TipoManejo.tratamento;
    if (!sanitario) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dose deste manejo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text(
            'A regra é definida aqui e não fica presa ao cadastro do produto. Cada animal recebe peso e dose próprios.',
            style: TextStyle(color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final largura = constraints.maxWidth < 430 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: largura,
                    child: TextFormField(
                      initialValue: _doseBaseTexto,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) { _doseBaseTexto = v; },
                      decoration: const InputDecoration(labelText: 'Dose base', hintText: 'Ex.: 1', prefixIcon: Icon(Icons.medication_outlined), border: OutlineInputBorder()),
                    ),
                  ),
                  SizedBox(
                    width: largura,
                    child: TextFormField(
                      initialValue: _pesoReferenciaTexto,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) { _pesoReferenciaTexto = v; },
                      decoration: const InputDecoration(labelText: 'Para quantos kg?', hintText: 'Ex.: 10', prefixIcon: Icon(Icons.monitor_weight_outlined), border: OutlineInputBorder()),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final largura = constraints.maxWidth < 430 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: largura,
                    child: TextFormField(
                      initialValue: _viaAplicacao,
                      onChanged: (v) => _viaAplicacao = v,
                      decoration: const InputDecoration(
                        labelText: 'Via de aplicação',
                        hintText: 'Ex.: Subcutânea',
                        prefixIcon: Icon(Icons.route_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: largura,
                    child: TextFormField(
                      initialValue: _carenciaTexto,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _carenciaTexto = v,
                      decoration: const InputDecoration(
                        labelText: 'Carência (dias)',
                        hintText: 'Ex.: 7',
                        prefixIcon: Icon(Icons.schedule_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _unidadeDose,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unidade da dose', prefixIcon: Icon(Icons.straighten_outlined), border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'mL', child: Text('mL')),
              DropdownMenuItem(value: 'mg', child: Text('mg')),
              DropdownMenuItem(value: 'g', child: Text('g')),
              DropdownMenuItem(value: 'comprimido', child: Text('Comprimido')),
              DropdownMenuItem(value: 'aplicação', child: Text('Aplicação')),
            ],
            onChanged: _salvando ? null : (value) {
              if (value != null) setState(() => _unidadeDose = value);
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _salvando ? null : _aplicarRegraDoseTodos,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Aplicar a mesma dose por kg a todas'),
            ),
          ),
          const SizedBox(height: 14),
          if (_carregandoPesos) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          ..._animaisSelecionados.map(_animalPorId).whereType<Map<String, dynamic>>().map(_itemDoseAnimal),
        ],
      ),
    );
  }

  Widget _itemDoseAnimal(Map<String, dynamic> animal) {
    final id = animal['id']?.toString() ?? '';
    final peso = _pesoTextoPorAnimal[id] ?? '';
    final dose = _doseTextoPorAnimal[id] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estreito = constraints.maxWidth < 380;
          final pesoField = TextFormField(
            initialValue: peso,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => _atualizarPesoAnimal(id, v),
            decoration: const InputDecoration(labelText: 'Peso (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined), border: OutlineInputBorder()),
          );
          final doseField = TextFormField(
            key: ValueKey('dose-$id-$_doseEditorVersao'),
            initialValue: dose,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => _atualizarDoseAnimal(id, v),
            decoration: InputDecoration(labelText: 'Dose aplicada ($_unidadeDose)', prefixIcon: const Icon(Icons.medication_outlined), border: const OutlineInputBorder()),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_animalTexto(animal), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (estreito)
                Column(children: [pesoField, const SizedBox(height: 10), doseField])
              else
                Row(children: [Expanded(child: pesoField), const SizedBox(width: 12), Expanded(child: doseField)]),
            ],
          );
        },
      ),
    );
  }

  Widget _doseCalculadora() => _dosePorAnimalEditor();

  Widget _avaliacaoLote() {
    final selecionados = _animaisSelecionados
        .map(_animalPorId)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (selecionados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Selecione as ovelhas acima. Depois, informe o FAMACHA de cada uma.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

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
            'FAMACHA de cada animal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cada animal recebe seu próprio escore.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          ...selecionados.map(_itemAvaliacaoAnimal),
        ],
      ),
    );
  }

  Widget _itemAvaliacaoAnimal(Map<String, dynamic> animal) {
    final id = animal['id'].toString();
    final escore = _famachaPorAnimal[id];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: escore == null
              ? Colors.black12
              : AppTheme.primaryColor.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_animalTexto(animal), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(5, (index) {
              final valor = index + 1;
              final ativo = escore == valor;

              return SizedBox(
                width: 54,
                child: OutlinedButton(
                  onPressed: _salvando ? null : () => _definirFamacha(id, valor),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: ativo ? AppTheme.primaryColor : Colors.white,
                    foregroundColor: ativo ? Colors.white : AppTheme.textColor,
                    side: BorderSide(
                      color: ativo ? AppTheme.primaryColor : Colors.black12,
                      width: ativo ? 2 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _corFamacha(valor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(valor.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _famachaField() {
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
          const Text('Classificação FAMACHA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FamachaReferenceWidget(selecionado: _famacha),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(5, (index) {
              final escore = index + 1;
              final selecionado = _famacha == escore;

              return SizedBox(
                width: 54,
                child: OutlinedButton(
                  onPressed: _salvando ? null : () => setState(() => _famacha = escore),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selecionado ? AppTheme.primaryColor : Colors.white,
                    foregroundColor: selecionado ? Colors.white : AppTheme.textColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(escore.toString()),
                ),
              );
            }),
          ),
          if (_famacha != null) ...[
            const SizedBox(height: 10),
            Text(
              'Selecionado: FAMACHA ' + _famacha.toString() + ' • ' + _descricaoFamacha(_famacha!),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
