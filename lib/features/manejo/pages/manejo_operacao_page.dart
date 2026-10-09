import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../../core/widgets/contextual_help.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_service.dart';
import '../models/manejo.dart';
import 'manejo_form_page.dart';

const String _chaveRascunhoManejo = 'manejo_operacao_rascunho_v1';

class ManejoOperacaoPage extends StatefulWidget {
  const ManejoOperacaoPage({super.key});

  @override
  State<ManejoOperacaoPage> createState() => _ManejoOperacaoPageState();
}

class _ManejoOperacaoPageState extends State<ManejoOperacaoPage> {
  final AnimalService _animalService = AnimalService();
  final RebanhoService _rebanhoService = RebanhoService();

  List<Map<String, dynamic>> _rebanhos = [];
  List<Map<String, dynamic>> _animais = [];
  final Set<String> _animaisSelecionados = {};

  String? _rebanhoId;
  DateTime _data = DateTime.now();
  String _busca = '';
  String _sexoFiltro = 'Todos';
  bool _carregando = true;
  bool _carregandoAnimais = false;
  bool _iniciando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final resultados = await Future.wait([
        _rebanhoService.getRebanhos(somenteAtivos: true),
        _animalService.getAnimaisAtivos(),
      ]);
      if (!mounted) return;
      setState(() {
        _rebanhos = List<Map<String, dynamic>>.from(resultados[0] as List);
        _animais = List<Map<String, dynamic>>.from(resultados[1] as List);
        _carregando = false;
      });
      await _oferecerRetomarRascunho();
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _oferecerRetomarRascunho() async {
    final preferencias = await SharedPreferences.getInstance();
    final texto = preferencias.getString(_chaveRascunhoManejo);
    if (texto == null || texto.isEmpty || !mounted) return;
    Map<String, dynamic> rascunho;
    try {
      rascunho = Map<String, dynamic>.from(jsonDecode(texto) as Map);
    } catch (_) {
      await preferencias.remove(_chaveRascunhoManejo);
      return;
    }
    final animaisSalvos = rascunho['animais'];
    if (animaisSalvos is! List || animaisSalvos.isEmpty) {
      await preferencias.remove(_chaveRascunhoManejo);
      return;
    }
    final escolha = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manejo em andamento'),
        content: const Text('Existe uma operação de manejo salva neste aparelho. Você pode retomá-la de onde parou ou descartá-la e iniciar uma nova.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('descartar'), child: const Text('Descartar rascunho')),
          FilledButton.icon(onPressed: () => Navigator.of(dialogContext).pop('retomar'), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Retomar manejo')),
        ],
      ),
    );
    if (!mounted || escolha == null) return;
    if (escolha == 'descartar') {
      await preferencias.remove(_chaveRascunhoManejo);
      if (mounted) _mensagem('Rascunho descartado. Você pode iniciar uma nova operação.');
      return;
    }
    try {
      final animais = animaisSalvos.map((animal) => Map<String, dynamic>.from(animal as Map)).toList();
      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ManejoOperacaoAnimaisPage(
          animais: animais,
          data: DateTime.parse(rascunho['data'] as String),
          operacaoId: rascunho['operacaoId'] as String,
          rascunho: rascunho,
        )),
      );
      if (!mounted) return;
      if (resultado == true) {
        _mensagem('Operação de manejo encerrada.');
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      await preferencias.remove(_chaveRascunhoManejo);
      if (mounted) _mensagem('Não foi possível recuperar o rascunho. Inicie uma nova operação.');
    }
  }

  Future<void> _carregarAnimais() async {
    setState(() => _carregandoAnimais = true);
    try {
      final animais =
          await _animalService.getAnimaisAtivos(rebanhoId: _rebanhoId);
      if (!mounted) return;
      setState(() {
        _animais = animais;
        _carregandoAnimais = false;
        final ids = animais
            .map((animal) => animal['id']?.toString())
            .whereType<String>()
            .toSet();
        _animaisSelecionados.removeWhere((id) => !ids.contains(id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoAnimais = false);
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

  List<Map<String, dynamic>> get _animaisVisiveis {
    final termo = _busca.trim().toLowerCase();
    return _animais.where((animal) {
      final sexo = (animal['sexo']?.toString() ?? '').toLowerCase();
      final brinco = (animal['brinco']?.toString() ?? '').toLowerCase();
      final nome = (animal['nome']?.toString() ?? '').toLowerCase();
      final buscaOk = termo.isEmpty || brinco.contains(termo) || nome.contains(termo);
      final feminino = sexo == 'fêmea' || sexo == 'femea' || sexo == 'f' || sexo.contains('fêmea') || sexo.contains('femea');
      final masculino = sexo == 'macho' || sexo == 'm' || sexo.contains('macho');
      final sexoOk = _sexoFiltro == 'Todos' || (_sexoFiltro == 'Fêmeas' && feminino) || (_sexoFiltro == 'Machos' && masculino);
      return buscaOk && sexoOk;
    }).toList();
  }

  String _nomeAnimal(Map<String, dynamic> animal) {
    final nome = animal['nome']?.toString().trim() ?? '';
    final brinco = animal['brinco']?.toString().trim() ?? '---';
    return nome.isEmpty ? 'Brinco $brinco' : nome;
  }

  String _sexoAnimal(Map<String, dynamic> animal) {
    final sexo = animal['sexo']?.toString().toLowerCase() ?? '';
    if (sexo.contains('fêmea') || sexo.contains('femea') || sexo == 'f') return 'Fêmea';
    if (sexo.contains('macho') || sexo == 'm') return 'Macho';
    return animal['sexo']?.toString() ?? 'Sexo não informado';
  }

  Widget _selecaoAnimaisCard() {
    final visiveis = _animaisVisiveis;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Selecione os animais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Escolha quem vai passar pelo manejo. Você pode selecionar vários.', style: TextStyle(color: Colors.black54, height: 1.35)),
      if (_rebanhos.isNotEmpty) ...[
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          value: _rebanhoId, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Rebanho ou lote', prefixIcon: Icon(Icons.groups_outlined), border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Todos os animais ativos')),
            ..._rebanhos.map((rebanho) {
              final id = rebanho['id']?.toString();
              final nome = rebanho['nome']?.toString() ?? rebanho['nome_lote']?.toString() ?? 'Rebanho';
              return DropdownMenuItem<String?>(value: id, child: Text(nome, overflow: TextOverflow.ellipsis));
            }),
          ],
          onChanged: _iniciando ? null : (id) {
            setState(() { _rebanhoId = id; _animaisSelecionados.clear(); });
            _carregarAnimais();
          },
        ),
      ],
      const SizedBox(height: 14),
      TextField(
        onChanged: (value) => setState(() => _busca = value),
        decoration: InputDecoration(
          hintText: 'Buscar por brinco ou nome', prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _busca.isEmpty ? null : IconButton(tooltip: 'Limpar busca', onPressed: () => setState(() => _busca = ''), icon: const Icon(Icons.close_rounded)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: ['Todos', 'Fêmeas', 'Machos'].map((filtro) => ChoiceChip(
        label: Text(filtro), selected: _sexoFiltro == filtro,
        onSelected: _iniciando ? null : (_) => setState(() => _sexoFiltro = filtro),
      )).toList()),
      const SizedBox(height: 10),
      if (_carregandoAnimais)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (visiveis.isEmpty)
        Container(
          width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14)),
          child: const Column(children: [
            Icon(Icons.search_off_rounded, size: 32, color: Colors.black45), SizedBox(height: 8),
            Text('Nenhum animal encontrado'), SizedBox(height: 4),
            Text('Tente mudar a busca ou o filtro.', style: TextStyle(color: Colors.black54, fontSize: 12), textAlign: TextAlign.center),
          ]),
        )
      else
        ...visiveis.map((animal) {
          final id = animal['id']?.toString();
          if (id == null) return const SizedBox.shrink();
          final selecionado = _animaisSelecionados.contains(id);
          final brinco = animal['brinco']?.toString() ?? '---';
          final raca = animal['raca']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selecionado ? AppTheme.primaryColor.withValues(alpha: 0.08) : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _iniciando ? null : () => setState(() {
                  if (selecionado) { _animaisSelecionados.remove(id); } else { _animaisSelecionados.add(id); }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(
                    color: selecionado ? AppTheme.primaryColor : Colors.black.withValues(alpha: 0.08), width: selecionado ? 1.5 : 1)),
                  child: Row(children: [
                    Container(width: 46, height: 46,
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: AppAssetIcon(assetPath: 'assets/images/icon_ovino_femea.png', size: 32))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_nomeAnimal(animal), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text('Brinco ' + brinco + (raca.isEmpty ? '' : ' • ' + raca), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(_sexoAnimal(animal), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ])),
                    const SizedBox(width: 8),
                    Icon(selecionado ? Icons.check_circle_rounded : Icons.circle_outlined, color: selecionado ? AppTheme.primaryColor : Colors.black26, size: 24),
                  ]),
                ),
              ),
            ),
          );
        }),
      if (!_carregandoAnimais && visiveis.isNotEmpty)
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: _iniciando ? null : () => setState(() {
            final ids = visiveis.map((a) => a['id']?.toString()).whereType<String>();
            final todos = ids.isNotEmpty && ids.every(_animaisSelecionados.contains);
            if (todos) { _animaisSelecionados.removeAll(ids); } else { _animaisSelecionados.addAll(ids); }
          }),
          icon: const Icon(Icons.done_all_rounded, size: 18), label: const Text('Selecionar/limpar exibidos'),
        )),
    ]);
  }

  Future<void> _iniciarOperacao() async {
    if (_animaisSelecionados.isEmpty) {
      _mensagem('Selecione pelo menos um animal.');
      return;
    }

    setState(() => _iniciando = true);
    final operacaoId = const Uuid().v4();

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManejoOperacaoAnimaisPage(
          animais: _animais
              .where(
                (animal) =>
                    _animaisSelecionados.contains(animal['id']?.toString()),
              )
              .toList(),
          data: _data,
          operacaoId: operacaoId,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _iniciando = false);

    if (resultado == true) {
      _mensagem('Operação de manejo registrada com sucesso.');
      Navigator.of(context).pop(true);
    }
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto.replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(assetPath: 'assets/images/icon_manejo.png', size: 26),
            SizedBox(width: 8),
            Flexible(child: Text('Nova operação')),
          ],
        ),
        actions: const [
          ContextualHelpButton(
            title: 'Nova operação de manejo',
            introduction:
                'Uma operação representa uma ida ao curral. Você escolhe os animais e depois registra, um animal por vez, tudo o que foi feito nele.',
            topics: [
              HelpTopic(
                title: 'Como funciona',
                description:
                    'Selecione os animais e a data. Depois, o aplicativo abrirá cada animal separadamente para você registrar os procedimentos realizados nele.',
              ),
              HelpTopic(
                title: 'Vários procedimentos no mesmo animal',
                description:
                    'Você pode pesar, vacinar, vermifugar, tratar ou registrar outros cuidados no mesmo animal antes de passar para o próximo.',
              ),
              HelpTopic(
                title: 'Procedimentos diferentes',
                description:
                    'Cada animal pode ter procedimentos diferentes. O que você registrar em um animal não obriga os próximos a receberem a mesma coisa.',
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _carregando ? null : SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
          ),
          child: Row(children: [
            Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_animaisSelecionados.length} selecionado(s)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Text('Toque nos animais para marcar', style: TextStyle(color: Colors.black54, fontSize: 11)),
            ])),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _iniciando || _animaisSelecionados.isEmpty ? null : _iniciarOperacao,
              icon: _iniciando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward_rounded),
              label: Text(_iniciando ? 'Abrindo...' : 'Continuar'),
            ),
          ]),
        ),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth < 420 ? 14.0 : 20.0;
                  final maxWidth =
                      constraints.maxWidth > 760 ? 720.0 : constraints.maxWidth;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          16,
                          horizontal,
                          32,
                        ),
                        children: [
                          _intro(),
                          const SizedBox(height: 18),
                          _dataCard(),
                          const SizedBox(height: 20),
                          _selecaoAnimaisCard(),
                          const SizedBox(height: 18),
                          _resumo(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.groups_2_outlined,
            color: AppTheme.primaryColor,
            size: 30,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maneje um animal por vez',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                SizedBox(height: 6),
                Text(
                  'Exemplo: pese a ovelha, registre a vacina e depois passe para a próxima. Cada animal pode receber procedimentos diferentes.',
                  style: TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCard() {
    final texto = _data.day.toString().padLeft(2, '0') +
        '/' +
        _data.month.toString().padLeft(2, '0') +
        '/' +
        _data.year.toString();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: _iniciando ? null : _escolherData,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data da operação',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pode ser alterada antes de começar.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                texto,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resumo() {
    final quantidade = _animaisSelecionados.length;
    return Card(
      margin: EdgeInsets.zero,
      color: quantidade == 0
          ? Colors.grey.shade50
          : AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              quantidade == 0
                  ? Icons.info_outline
                  : Icons.check_circle_outline,
              color: quantidade == 0
                  ? Colors.black45
                  : AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                quantidade == 0
                    ? 'Nenhum animal selecionado.'
                    : '$quantidade animal(is) selecionado(s). Na próxima etapa, você fará o manejo de cada um individualmente.',
                style: TextStyle(
                  color: quantidade == 0
                      ? Colors.black54
                      : AppTheme.primaryColor,
                  fontWeight:
                      quantidade == 0 ? FontWeight.normal : FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManejoOperacaoAnimaisPage extends StatefulWidget {
  final List<Map<String, dynamic>> animais;
  final DateTime data;
  final String operacaoId;
  final Map<String, dynamic>? rascunho;

  const ManejoOperacaoAnimaisPage({
    super.key,
    required this.animais,
    required this.data,
    required this.operacaoId,
    this.rascunho,
  });

  @override
  State<ManejoOperacaoAnimaisPage> createState() =>
      _ManejoOperacaoAnimaisPageState();
}

class _ManejoOperacaoAnimaisPageState
    extends State<ManejoOperacaoAnimaisPage> {
  final Map<String, List<TipoManejo>> _procedimentosPorAnimal = {};
  final Map<String, Set<String>> _procedimentosConcluidosPorAnimal = {};
  late List<Map<String, dynamic>> _animaisOrdenados;
  final Set<String> _animaisConcluidos = {};
  int _indiceAtual = 0;
  bool _processando = false;
  bool _finalizado = false;

  Map<String, dynamic> get _animalAtual => _animaisOrdenados[_indiceAtual];

  @override
  void initState() {
    super.initState();
    _animaisOrdenados = List<Map<String, dynamic>>.from(widget.animais);
    _restaurarRascunho();
    if (widget.rascunho == null) _salvarRascunho();
  }

  void _restaurarRascunho() {
    final rascunho = widget.rascunho;
    if (rascunho == null) return;
    _indiceAtual = (rascunho['indiceAtual'] as num?)?.toInt() ?? 0;
    if (_indiceAtual < 0) _indiceAtual = 0;
    if (_indiceAtual >= _animaisOrdenados.length) _indiceAtual = _animaisOrdenados.length - 1;
    final concluidos = rascunho['animaisConcluidos'];
    if (concluidos is List) _animaisConcluidos.addAll(concluidos.map((item) => item.toString()));
    final procedimentos = rascunho['procedimentosPorAnimal'];
    if (procedimentos is Map) {
      for (final entrada in procedimentos.entries) {
        if (entrada.value is List) {
          _procedimentosPorAnimal[entrada.key.toString()] = (entrada.value as List)
              .map((item) {
                final encontrados = TipoManejo.values.where((tipo) => tipo.name == item.toString()).toList();
                return encontrados.isEmpty ? null : encontrados.first;
              })
              .whereType<TipoManejo>()
              .toList();
        }
      }
    }
    final procedimentosConcluidos = rascunho['procedimentosConcluidosPorAnimal'];
    if (procedimentosConcluidos is Map) {
      for (final entrada in procedimentosConcluidos.entries) {
        if (entrada.value is List) {
          _procedimentosConcluidosPorAnimal[entrada.key.toString()] = (entrada.value as List).map((item) => item.toString()).toSet();
        }
      }
    }
    _finalizado = rascunho['finalizado'] == true;
  }

  Future<void> _salvarRascunho() async {
    if (_animaisOrdenados.isEmpty) return;
    final preferencias = await SharedPreferences.getInstance();
    final dados = <String, dynamic>{
      'data': widget.data.toIso8601String(),
      'operacaoId': widget.operacaoId,
      'animais': _animaisOrdenados,
      'indiceAtual': _indiceAtual,
      'animaisConcluidos': _animaisConcluidos.toList(),
      'procedimentosPorAnimal': _procedimentosPorAnimal.map((id, tipos) => MapEntry(id, tipos.map((tipo) => tipo.name).toList())),
      'procedimentosConcluidosPorAnimal': _procedimentosConcluidosPorAnimal.map((id, tipos) => MapEntry(id, tipos.toList())),
      'finalizado': _finalizado,
    };
    await preferencias.setString(_chaveRascunhoManejo, jsonEncode(dados));
  }

  Future<void> _limparRascunho() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_chaveRascunhoManejo);
  }

  String _animalId(Map<String, dynamic> animal) =>
      animal['id']?.toString() ?? '';

  String _animalNome(Map<String, dynamic> animal) {
    final brinco = animal['brinco']?.toString() ?? '---';
    final nome = animal['nome']?.toString().trim();
    if (nome != null && nome.isNotEmpty) {
      return '$brinco • $nome';
    }
    return 'Brinco $brinco';
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
      case TipoManejo.denticao:
        return 'Dentição';
      case TipoManejo.outro:
        return 'Outro';
    }
  }

  IconData _icone(TipoManejo tipo) {
    switch (tipo) {
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
      case TipoManejo.denticao:
        return Icons.health_and_safety_outlined;
      case TipoManejo.outro:
        return Icons.assignment_outlined;
    }
  }

  void _alternarProcedimento(TipoManejo tipo) {
    final id = _animalId(_animalAtual);
    final lista =
        _procedimentosPorAnimal.putIfAbsent(id, () => <TipoManejo>[]);
    setState(() {
      if (lista.contains(tipo)) {
        lista.remove(tipo);
        _procedimentosConcluidosPorAnimal[id]?.remove(tipo.name);
      } else {
        lista.add(tipo);
      }
    });
    _salvarRascunho();
  }

  Future<void> _registrarAnimal() async {
    final id = _animalId(_animalAtual);
    final procedimentos =
        List<TipoManejo>.from(_procedimentosPorAnimal[id] ?? const []);

    if (procedimentos.isEmpty) {
      _mensagem('Escolha pelo menos um procedimento para este animal.');
      return;
    }

    setState(() => _processando = true);

    var indiceProcedimento = 0;
    final concluidos = _procedimentosConcluidosPorAnimal.putIfAbsent(id, () => <String>{});
    while (indiceProcedimento < procedimentos.length) {
      if (concluidos.contains(procedimentos[indiceProcedimento].name)) {
        indiceProcedimento++;
        continue;
      }
      if (!mounted) return;

      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ManejoFormPage(
            tipoInicial: procedimentos[indiceProcedimento],
            dataInicial: widget.data,
            animalIdsIniciais: [id],
            selecaoAnimaisBloqueada: true,
            operacaoId: widget.operacaoId,
          ),
        ),
      );

      if (resultado == true) {
        concluidos.add(procedimentos[indiceProcedimento].name);
        await _salvarRascunho();
        indiceProcedimento++;
        continue;
      }

      if (!mounted) return;
      setState(() => _processando = false);

      final restantes = procedimentos.length - indiceProcedimento;
      final continuar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Registro não concluído'),
          content: Text(
            'O procedimento "${_tipoTexto(procedimentos[indiceProcedimento])}" '
            'do animal ${_animalNome(_animalAtual)} não foi salvo. '
            'Ainda há $restantes procedimento(s) pendente(s).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Deixar para depois'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );

      if (continuar != true || !mounted) return;

      // Mantém o mesmo índice para reabrir o procedimento que não foi salvo.
      setState(() => _processando = true);
    }

    if (!mounted) return;

    _animaisConcluidos.add(id);
    await _salvarRascunho();

    if (_indiceAtual >= _animaisOrdenados.length - 1) {
      setState(() {
        _processando = false;
        _finalizado = true;
      });
      return;
    }

    setState(() {
      _processando = false;
      _indiceAtual++;
    });
  }

  void _voltarAnimal() {
    if (_indiceAtual == 0 || _processando) return;
    setState(() => _indiceAtual--);
    _salvarRascunho();
  }

  Future<void> _abrirListaAnimais() async {
    if (_processando) return;

    final novoIndice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Animais da operação',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Toque em um animal para ir até ele. Segure o ícone para reorganizar.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: _animaisOrdenados.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _animaisOrdenados.removeAt(oldIndex);
                        _animaisOrdenados.insert(newIndex, item);
                        if (_indiceAtual == oldIndex) {
                          _indiceAtual = newIndex;
                        } else if (oldIndex < _indiceAtual &&
                            newIndex >= _indiceAtual) {
                          _indiceAtual--;
                        } else if (oldIndex > _indiceAtual &&
                            newIndex <= _indiceAtual) {
                          _indiceAtual++;
                        }
                      });
                      _salvarRascunho();
                    },
                    itemBuilder: (context, index) {
                      final animal = _animaisOrdenados[index];
                      final id = _animalId(animal);
                      final ativo = index == _indiceAtual;
                      final concluido = _animaisConcluidos.contains(id);
                      return Card(
                        key: ValueKey(id),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          onTap: () =>
                              Navigator.of(sheetContext).pop(index),
                          leading: CircleAvatar(
                            backgroundColor: concluido
                                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                                : Colors.black12,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: concluido
                                    ? AppTheme.primaryColor
                                    : Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            _animalNome(animal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            concluido
                                ? 'Concluído'
                                : ativo
                                    ? 'Animal atual'
                                    : 'Pendente',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (concluido)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryColor,
                                  size: 21,
                                ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || novoIndice == null) return;
    setState(() {
      _indiceAtual = novoIndice;
    });
    _salvarRascunho();
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto.replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _finalizar() async {
    if (_processando) return;

    final pendentes = _animaisOrdenados.length - _indiceAtual;
    if (!_finalizado && pendentes > 0) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finalizar operação?'),
          content: const Text(
            'Os animais que ainda não foram registrados ficarão para depois. Os procedimentos já salvos não serão perdidos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continuar no manejo'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    if (_finalizado) {
      await _limparRascunho();
    } else {
      await _salvarRascunho();
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final animal = _animalAtual;
    final id = _animalId(animal);
    final selecionados = _procedimentosPorAnimal[id] ?? const <TipoManejo>[];
    final concluido = _finalizado ||
        _animaisConcluidos.contains(_animalId(animal));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar manejo'),
        actions: const [
          ContextualHelpButton(
            title: 'Registrar por animal',
            introduction:
                'Nesta tela você trabalha com um animal de cada vez. Escolha tudo o que foi feito nele e registre os procedimentos na ordem que preferir.',
            topics: [
              HelpTopic(
                title: 'Um animal, vários procedimentos',
                description:
                    'Exemplo: escolha Pesagem e Vacinação. Primeiro registre a pesagem e depois a vacina. Ao terminar, o próximo animal será aberto.',
              ),
              HelpTopic(
                title: 'Procedimentos diferentes',
                description:
                    'Você pode escolher uma combinação diferente para cada animal. O aplicativo não exige que todos recebam os mesmos cuidados.',
              ),
              HelpTopic(
                title: 'Dose da vacina',
                description:
                    'Quando houver peso e regra de dose cadastrada, o aplicativo calcula a quantidade individual. A dose aplicada pode ser ajustada antes de salvar.',
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth < 420 ? 14.0 : 20.0;
            final maxWidth =
                constraints.maxWidth > 760 ? 720.0 : constraints.maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    16,
                    horizontal,
                    32,
                  ),
                  children: [
                    _progresso(),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _processando ? null : _abrirListaAnimais,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Trocar animal / organizar ordem'),
                    ),
                    const SizedBox(height: 14),
                    _animalCard(animal, concluido),
                    const SizedBox(height: 18),
                    _procedimentosCard(selecionados),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            _processando || _finalizado ? null : _registrarAnimal,
                        icon: _processando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _indiceAtual == _animaisOrdenados.length - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                        label: Text(
                          _processando
                              ? 'Salvando...'
                              : _indiceAtual == _animaisOrdenados.length - 1
                                  ? 'Concluir animal'
                                  : 'Registrar e próximo animal',
                        ),
                      ),
                    ),
                    if (_finalizado) ...[
                      const SizedBox(height: 12),
                      Card(
                        color:
                            AppTheme.primaryColor.withValues(alpha: 0.08),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryColor,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Todos os animais desta operação foram registrados.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_indiceAtual > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _processando ? null : _voltarAnimal,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Animal anterior'),
                            ),
                          ),
                        if (_indiceAtual > 0 && !_finalizado)
                          const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processando ? null : _finalizar,
                            icon: Icon(
                              _finalizado
                                  ? Icons.done_all
                                  : Icons.stop_circle_outlined,
                            ),
                            label: Text(
                              _finalizado
                                  ? 'Fechar operação'
                                  : 'Finalizar depois',
                            ),
                          ),
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
    );
  }

  Widget _progresso() {
    final total = _animaisOrdenados.length;
    final atual = _indiceAtual + 1;
    final concluidos = _animaisConcluidos.length;
    final valor = total == 0 ? 0.0 : concluidos / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Animais da operação',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              '$concluidos de $total concluídos • animal $atual',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: valor,
            minHeight: 8,
            backgroundColor: Colors.black12,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _animalCard(Map<String, dynamic> animal, bool concluido) {
    final nome = _animalNome(animal);
    final sexo = animal['sexo']?.toString();
    final raca = animal['raca']?.toString();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Center(
                child: AppAssetIcon(
                  assetPath: 'assets/images/icon_ovino_femea.png',
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (raca != null && raca.isNotEmpty) raca,
                      if (sexo != null && sexo.isNotEmpty) sexo,
                    ].join(' • '),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (concluido) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 17,
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Pronto',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _procedimentosCard(List<TipoManejo> selecionados) {
    final id = _animalId(_animalAtual);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O que será feito neste animal?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Selecione os procedimentos e arraste-os para definir a ordem em que serão registrados.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: TipoManejo.values.map((tipo) {
                final selecionado = selecionados.contains(tipo);
                return FilterChip(
                  selected: selecionado,
                  avatar: Icon(
                    _icone(tipo),
                    size: 19,
                    color: selecionado ? Colors.white : AppTheme.primaryColor,
                  ),
                  label: Text(_tipoTexto(tipo)),
                  onSelected: _processando || _finalizado
                      ? null
                      : (_) => _alternarProcedimento(tipo),
                  selectedColor: AppTheme.primaryColor,
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
            if (selecionados.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ordem dos procedimentos',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  Text(
                    '${selecionados.length} selecionado(s)',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Segure o ícone ☰ e arraste para reorganizar.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: selecionados.length,
                onReorder: _processando || _finalizado
                    ? (_, __) {}
                    : (oldIndex, newIndex) {
                        setState(() {
                          final lista = _procedimentosPorAnimal.putIfAbsent(
                            id,
                            () => <TipoManejo>[],
                          );
                          if (newIndex > oldIndex) newIndex--;
                          final tipo = lista.removeAt(oldIndex);
                          lista.insert(newIndex, tipo);
                        });
                        _salvarRascunho();
                      },
                itemBuilder: (context, index) {
                  final tipo = selecionados[index];
                  return Container(
                    key: ValueKey('procedimento_${id}_${tipo.name}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.16),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      leading: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        _tipoTexto(tipo),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(index == 0 ? 'Será registrado primeiro' : 'Posição ${index + 1}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Remover procedimento',
                            onPressed: _processando || _finalizado
                                ? null
                                : () => _alternarProcedimento(tipo),
                            icon: const Icon(Icons.close_rounded),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
