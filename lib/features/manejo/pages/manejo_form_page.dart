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

  TipoManejo _tipo = TipoManejo.vacinacao;
  DateTime _data = DateTime.now();
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
      if (manejo.dose != null) _doseManual.text = manejo.dose.toString();
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
      if (peso != null) _pesos[id] = peso;
    }
    if (!mounted) return;
    setState(() => _carregandoPesos = false);
    _calcularDoses();
  }

  double? _numero(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  Map<String, dynamic>? _produtoAtual() {
    if (_tipo == TipoManejo.vacinacao) return _vacinaSelecionada;
    if (_tipo == TipoManejo.vermifugacao) return _vermifugoSelecionado;
    if (_tipo == TipoManejo.tratamento) return _medicamentoSelecionado;
    return null;
  }

  void _calcularDoses() {
    final produto = _produtoAtual();
    final dose = _numero(produto?['dose']);
    final referencia = _numero(produto?['peso_referencia_kg']);
    if (dose == null || referencia == null || referencia <= 0) {
      setState(() => _dosesCalculadas.clear());
      return;
    }
    final calculadas = <String, double>{};
    for (final id in _animaisSelecionados) {
      final peso = _pesos[id];
      if (peso != null && peso > 0) calculadas[id] = peso / referencia * dose;
    }
    setState(() {
      _dosesCalculadas
        ..clear()
        ..addAll(calculadas);
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
      builder: (dialogContext) {
        return AlertDialog(
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
        );
      },
    );

    if (dados == null || !mounted) return;

    try {
      final vacina = await _service.criarVacina(
        nome: dados['nome']!,
        fabricante: dados['fabricante'],
      );

      setState(() {
        _vacinas = [..._vacinas, vacina]
          ..sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));
        _vacinaSelecionada = vacina;
      });
    } catch (e) {
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _selecionarTodos() {
    setState(() {
      _animaisSelecionados
        ..clear()
        ..addAll(
          _animais
              .map((animal) => animal['id']?.toString())
              .whereType<String>(),
        );
    });
  }

  void _limparSelecao() {
    setState(() {
      _animaisSelecionados.clear();
      _famachaPorAnimal.clear();
    });
  }

  void _alternarAnimal(String id) {
    setState(() {
      if (_animaisSelecionados.contains(id)) {
        _animaisSelecionados.remove(id);
        _famachaPorAnimal.remove(id);
      } else {
        _animaisSelecionados.add(id);
      }

      if (_tipo != TipoManejo.famacha && _animaisSelecionados.isEmpty) {
        _animalId = null;
      }
    });
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

    setState(() => _salvando = true);

    try {
      await _service.criarManejosEmLote(
        animalIds: _animaisSelecionados.toList(),
        data: _data,
        tipo: _tipo,
        famachaPorAnimal: _famachaPorAnimal,
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
        vacinaLote: _tipo == TipoManejo.vacinacao
            ? _vacinaLote.text
            : null,
        outroNome: _tipo == TipoManejo.outro ? _outroNome.text : null,
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
      await _service.atualizarManejo(
        id: widget.manejo!.id,
        animalId: _animalId!,
        tipo: _tipo,
        data: _data,
        famachaEscore: _tipo == TipoManejo.famacha ? _famacha : null,
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
        vacinaLote: _tipo == TipoManejo.vacinacao ? _vacinaLote.text : null,
        outroNome: _tipo == TipoManejo.outro ? _outroNome.text : null,
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                      });
                      _carregarAnimais();
                    },
                    onToggleAnimal: _alternarAnimal,
                    onSelecionarTodos: _selecionarTodos,
                    onLimpar: _limparSelecao,
                  ),
                if (_tipo == TipoManejo.vacinacao) ...[
                  const SizedBox(height: 16),
                  _vacinaField(),
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
          const Text('Vacina aplicada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    final vacina = _vacinas.firstWhere(
                      (item) => item['id']?.toString() == id,
                    );
                    setState(() => _vacinaSelecionada = vacina);
                  },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _salvando ? null : _adicionarVacina,
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar nova vacina'),
          ),
          TextField(
            controller: _vacinaLote,
            enabled: !_salvando,
            decoration: const InputDecoration(
              labelText: 'Lote',
              prefixIcon: Icon(Icons.qr_code_2_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
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
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selecionado?['id']?.toString(),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: titulo,
              prefixIcon: const Icon(Icons.medical_services_outlined),
              border: const OutlineInputBorder(),
            ),
            items: itens.map((item) {
              final id = item['id']?.toString();
              if (id == null) return null;
              return DropdownMenuItem<String>(
                value: id,
                child: Text(item['nome'].toString(), overflow: TextOverflow.ellipsis),
              );
            }).whereType<DropdownMenuItem<String>>().toList(),
            onChanged: _salvando ? null : (id) {
              final item = id == null ? null : itens.firstWhere((x) => x['id']?.toString() == id);
              onChanged(item);
              _calcularDoses();
            },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _salvando ? null : onAdicionar,
            icon: const Icon(Icons.add),
            label: Text('Cadastrar novo ' + titulo.toLowerCase()),
          ),
          if (selecionado != null && selecionado['dose'] != null && selecionado['peso_referencia_kg'] != null)
            Text(
              'Bula cadastrada: ' + selecionado['dose'].toString() + ' ' +
                  (selecionado['dose_unidade'] ?? '').toString() + ' por ' +
                  selecionado['peso_referencia_kg'].toString() + ' kg',
              style: const TextStyle(color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _doseCalculadora() {
    final produto = _produtoAtual();
    if (produto == null) return const SizedBox.shrink();
    final regra = _numero(produto['dose']);
    final referencia = _numero(produto['peso_referencia_kg']);
    final unidade = produto['dose_unidade']?.toString() ?? '';
    if (regra == null || referencia == null || referencia <= 0) {
      return _info('Cadastre na ficha do produto a dose da bula e o peso de referência para ativar a calculadora automática.');
    }
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calculadora de dose', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Regra: ' + regra.toString() + ' ' + unidade + ' para cada ' + referencia.toString() + ' kg'),
            if (_carregandoPesos) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            ..._dosesCalculadas.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text(_animalTexto(_animalPorId(entry.key) ?? {}))),
                  Text(entry.value.toStringAsFixed(2) + ' ' + unidade, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )),
            if (!_carregandoPesos && _dosesCalculadas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Não encontrei peso registrado no histórico para calcular automaticamente.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _adicionarVermifugoCompleto() async {
    String nome = '';
    String principio = '';
    String dose = '';
    String unidade = 'mL';
    String referencia = '';
    String via = '';
    String carencia = '';
    final dados = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo vermífugo'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(autofocus: true, onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: 'Nome do produto')),
          TextField(onChanged: (v) => principio = v, decoration: const InputDecoration(labelText: 'Princípio ativo')),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text('Dose conforme bula', style: TextStyle(fontWeight: FontWeight.bold))),
          Row(children: [
            Expanded(child: TextField(keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => dose = v, decoration: const InputDecoration(labelText: 'Dose'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(onChanged: (v) => unidade = v, decoration: const InputDecoration(labelText: 'Unidade'))),
          ]),
          TextField(keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => referencia = v, decoration: const InputDecoration(labelText: 'Para quantos kg?')),
          TextField(onChanged: (v) => via = v, decoration: const InputDecoration(labelText: 'Via')),
          TextField(keyboardType: TextInputType.number, onChanged: (v) => carencia = v, decoration: const InputDecoration(labelText: 'Carência (dias)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (nome.trim().isEmpty) return;
            Navigator.of(dialogContext).pop({'nome': nome.trim(), 'principio': principio.trim(), 'dose': dose, 'unidade': unidade, 'referencia': referencia, 'via': via, 'carencia': carencia});
          }, child: const Text('Cadastrar')),
        ],
      ),
    );
    if (dados == null || !mounted) return;
    try {
      final item = await _service.criarVermifugo(
        nome: dados['nome']!,
        principioAtivo: dados['principio'],
        dose: _numero(dados['dose']),
        doseUnidade: dados['unidade'],
        pesoReferenciaKg: _numero(dados['referencia']),
        viaAplicacao: dados['via'],
        carenciaDias: int.tryParse(dados['carencia'] ?? ''),
      );
      setState(() {
        _vermifugos = [..._vermifugos, item];
        _vermifugoSelecionado = item;
      });
      _calcularDoses();
    } catch (e) { _mensagem(e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _adicionarMedicamentoCompleto() async {
    String nome = '';
    String principio = '';
    final dados = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo medicamento'),
        content: TextField(autofocus: true, onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: 'Nome do medicamento')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (nome.trim().isEmpty) return;
            Navigator.of(dialogContext).pop({'nome': nome.trim(), 'principio': principio});
          }, child: const Text('Cadastrar')),
        ],
      ),
    );
    if (dados == null || !mounted) return;
    try {
      final item = await _service.criarMedicamento(nome: dados['nome']!, principioAtivo: dados['principio']);
      setState(() {
        _medicamentos = [..._medicamentos, item];
        _medicamentoSelecionado = item;
      });
      _calcularDoses();
    } catch (e) { _mensagem(e.toString().replaceFirst('Exception: ', '')); }
  }

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
          Row(
            children: List.generate(5, (index) {
              final valor = index + 1;
              final ativo = escore == valor;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: valor == 5 ? 0 : 5),
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
          Row(
            children: List.generate(5, (index) {
              final escore = index + 1;
              final selecionado = _famacha == escore;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: escore == 5 ? 0 : 6),
                  child: OutlinedButton(
                    onPressed: _salvando ? null : () => setState(() => _famacha = escore),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selecionado ? AppTheme.primaryColor : Colors.white,
                      foregroundColor: selecionado ? Colors.white : AppTheme.textColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(escore.toString()),
                  ),
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
