import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../../core/widgets/contextual_help.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_service.dart';
import '../models/manejo.dart';
import 'manejo_form_page.dart';

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
  bool _carregando = true;
  bool _carregandoAnimais = false;
  bool _iniciando = false;
  String _busca = '';
  String _sexoFiltro = 'Todos';

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
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

  void _selecionarTodosAnimais() {
    setState(() {
      _animaisSelecionados
        ..clear()
        ..addAll(
          _animais.map((a) => a['id']?.toString()).whereType<String>(),
        );
    });
  }

  void _limparAnimais() {
    setState(() => _animaisSelecionados.clear());
  }

  Future<void> _iniciarOperacao() async {
    if (_animaisSelecionados.isEmpty) {
      _mensagem('Selecione pelo menos um animal.');
      return;
    }

    setState(() => _iniciando = true);
    final operacaoId = const Uuid().v4();

    final animaisSelecionados = _animais
        .where(
          (animal) =>
              _animaisSelecionados.contains(animal['id']?.toString()),
        )
        .toList();

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManejoOperacaoOrganizarPage(
          animais: animaisSelecionados,
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


  List<Map<String, dynamic>> get _animaisFiltrados {
    final termo = _busca.trim().toLowerCase();

    return _animais.where((animal) {
      final sexo = animal['sexo']?.toString().toLowerCase() ?? '';
      final correspondeSexo = _sexoFiltro == 'Todos' ||
          (_sexoFiltro == 'Fêmeas' && sexo.contains('fem')) ||
          (_sexoFiltro == 'Machos' && sexo.contains('masc'));

      if (!correspondeSexo) return false;
      if (termo.isEmpty) return true;

      final brinco = animal['brinco']?.toString().toLowerCase() ?? '';
      final nome = animal['nome']?.toString().toLowerCase() ?? '';
      final raca = animal['raca']?.toString().toLowerCase() ?? '';

      return brinco.contains(termo) ||
          nome.contains(termo) ||
          raca.contains(termo);
    }).toList();
  }

  String _animalNome(Map<String, dynamic> animal) {
    final brinco = animal['brinco']?.toString() ?? '---';
    final nome = animal['nome']?.toString().trim();
    return nome != null && nome.isNotEmpty
        ? '$brinco • $nome'
        : 'Brinco $brinco';
  }

  String _sexoTexto(Map<String, dynamic> animal) {
    final sexo = animal['sexo']?.toString().toLowerCase() ?? '';
    if (sexo.contains('fem')) return 'Fêmea';
    if (sexo.contains('masc')) return 'Macho';
    return 'Sexo não informado';
  }

  String _dataTexto(DateTime data) {
    return data.day.toString().padLeft(2, '0') +
        '/' +
        data.month.toString().padLeft(2, '0') +
        '/' +
        data.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo manejo'),
        actions: const [
          ContextualHelpButton(
            title: 'Novo manejo',
            introduction:
                'Escolha os animais, organize a ordem e depois registre cada procedimento.',
            topics: [
              HelpTopic(
                title: 'Seleção',
                description:
                    'Busque por brinco, nome ou raça e use os filtros para encontrar os animais rapidamente.',
              ),
              HelpTopic(
                title: 'Procedimentos diferentes',
                description:
                    'Cada animal pode receber uma combinação diferente de procedimentos.',
              ),
            ],
          ),
        ],
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth =
                      constraints.maxWidth > 760 ? 720.0 : constraints.maxWidth;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                        children: [
                          const Text(
                            '1. Selecione os animais',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _animaisSelecionados.isEmpty
                                ? 'Nenhum animal selecionado'
                                : _animaisSelecionados.length.toString() +
                                    ' selecionado(s)',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _dataCardProfissional(),
                          const SizedBox(height: 12),
                          _rebanhoCardProfissional(),
                          const SizedBox(height: 16),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _busca = value),
                            decoration: InputDecoration(
                              hintText: 'Buscar por brinco, nome ou raça',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _filtrosSexo(),
                          const SizedBox(height: 12),
                          _listaAnimaisProfissional(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: const Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _animaisSelecionados.length.toString() + ' selecionado(s)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Próxima etapa: organizar ordem',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _iniciando ? null : _iniciarOperacao,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataCardProfissional() {
    return _box(
      child: InkWell(
        onTap: _iniciando ? null : _escolherData,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _iconBox(Icons.calendar_today_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data do manejo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Data em que os procedimentos foram realizados',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _dataTexto(_data),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rebanhoCardProfissional() {
    return _box(
      child: DropdownButtonFormField<String?>(
        value: _rebanhoId,
        decoration: const InputDecoration(
          labelText: 'Lote / rebanho',
          prefixIcon: Icon(Icons.groups_outlined),
          border: InputBorder.none,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Todos os animais ativos'),
          ),
          ..._rebanhos.map(
            (rebanho) => DropdownMenuItem<String?>(
              value: rebanho['id']?.toString(),
              child: Text(
                rebanho['nome']?.toString() ??
                    rebanho['descricao']?.toString() ??
                    'Lote',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: _carregandoAnimais
            ? null
            : (value) {
                setState(() {
                  _rebanhoId = value;
                  _animaisSelecionados.clear();
                });
                _carregarAnimais();
              },
      ),
    );
  }

  Widget _filtrosSexo() {
    return Row(
      children: [
        for (final filtro in const ['Todos', 'Fêmeas', 'Machos'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filtro),
              selected: _sexoFiltro == filtro,
              onSelected: (_) => setState(() => _sexoFiltro = filtro),
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.16),
              labelStyle: TextStyle(
                color: _sexoFiltro == filtro
                    ? AppTheme.primaryColor
                    : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Spacer(),
        PopupMenuButton<String>(
          tooltip: 'Seleção',
          onSelected: (valor) {
            final ids = _animaisFiltrados
                .map((animal) => animal['id']?.toString())
                .whereType<String>()
                .toSet();

            setState(() {
              if (valor == 'todos') {
                _animaisSelecionados.addAll(ids);
              } else {
                _animaisSelecionados.removeWhere(ids.contains);
              }
            });
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'todos',
              child: Text('Selecionar visíveis'),
            ),
            PopupMenuItem(
              value: 'limpar',
              child: Text('Limpar visíveis'),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }

  Widget _listaAnimaisProfissional() {
    if (_carregandoAnimais) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final animais = _animaisFiltrados;

    if (animais.isEmpty) {
      return _box(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 42, color: Colors.black38),
              SizedBox(height: 9),
              Text(
                'Nenhum animal encontrado',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 3),
              Text(
                'Altere a busca ou os filtros.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final animal in animais) ...[
          _animalItemProfissional(animal),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _animalItemProfissional(Map<String, dynamic> animal) {
    final id = animal['id']?.toString() ?? '';
    final selecionado = _animaisSelecionados.contains(id);
    final sexo = animal['sexo']?.toString().toLowerCase() ?? '';
    final asset = sexo.contains('masc')
        ? 'assets/images/icon_ovino_macho.png'
        : 'assets/images/icon_ovino_femea.png';

    return InkWell(
      onTap: () {
        setState(() {
          if (selecionado) {
            _animaisSelecionados.remove(id);
          } else {
            _animaisSelecionados.add(id);
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? AppTheme.primaryColor.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado
                ? AppTheme.primaryColor.withValues(alpha: 0.45)
                : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: AppAssetIcon(assetPath: asset, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _animalNome(animal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if ((animal['raca']?.toString().trim() ?? '').isNotEmpty)
                        animal['raca'].toString(),
                      _sexoTexto(animal),
                    ].join(' • '),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selecionado
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selecionado
                  ? AppTheme.primaryColor
                  : Colors.black26,
              size: 27,
            ),
          ],
        ),
      ),
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppTheme.primaryColor),
    );
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O que foi feito neste animal?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Marque os procedimentos realizados. Eles serão registrados na ordem em que você selecionar.',
              style: TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
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
                    color: selecionado
                        ? Colors.white
                        : AppTheme.primaryColor,
                  ),

class ManejoOperacaoOrganizarPage extends StatefulWidget {
  final List<Map<String, dynamic>> animais;
  final DateTime data;
  final String operacaoId;

  const ManejoOperacaoOrganizarPage({
    super.key,
    required this.animais,
    required this.data,
    required this.operacaoId,
  });

  @override
  State<ManejoOperacaoOrganizarPage> createState() =>
      _ManejoOperacaoOrganizarPageState();
}

class _ManejoOperacaoOrganizarPageState
    extends State<ManejoOperacaoOrganizarPage> {
  late List<Map<String, dynamic>> _animais;
  bool _abrindo = false;

  @override
  void initState() {
    super.initState();
    _animais = List<Map<String, dynamic>>.from(widget.animais);
  }

  String _animalNome(Map<String, dynamic> animal) {
    final brinco = animal['brinco']?.toString() ?? '---';
    final nome = animal['nome']?.toString().trim();
    return nome != null && nome.isNotEmpty ? '$brinco • $nome' : 'Brinco $brinco';
  }

  Future<void> _começar() async {
    if (_abrindo) return;
    setState(() => _abrindo = true);
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManejoOperacaoAnimaisPage(
          animais: _animais,
          data: widget.data,
          operacaoId: widget.operacaoId,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _abrindo = false);
    if (resultado == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordem dos animais'),
        actions: const [
          ContextualHelpButton(
            title: 'Ordem dos animais',
            introduction: 'Defina a sequência em que os animais serão manejados.',
            topics: [
              HelpTopic(
                title: 'Arrastar',
                description: 'Segure o ícone de arrastar e mova o animal para cima ou para baixo.',
              ),
              HelpTopic(
                title: 'Pode mudar depois',
                description: 'Durante o manejo você também poderá trocar de animal e reorganizar a ordem.',
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2. Organize a ordem',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _animais.length.toString() + ' animais selecionados',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.drag_indicator_rounded, color: AppTheme.primaryColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Arraste os animais para definir quem será atendido primeiro.',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                itemCount: _animais.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _animais.removeAt(oldIndex);
                    _animais.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final animal = _animais[index];
                  final id = animal['id']?.toString() ?? index.toString();
                  return Container(
                    key: ValueKey(id),
                    margin: const EdgeInsets.only(bottom: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.10),
                        foregroundColor: AppTheme.primaryColor,
                        child: Text(
                          (index + 1).toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        _animalNome(animal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        animal['raca']?.toString() ?? 'Raça não informada',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _abrindo ? null : () => Navigator.of(context).pop(),
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _abrindo ? null : _começar,
                  icon: _abrindo
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Começar manejo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManejoOperacaoAnimaisPage extends StatefulWidget {
  final List<Map<String, dynamic>> animais;
  final DateTime data;
  final String operacaoId;

  const ManejoOperacaoAnimaisPage({
    super.key,
    required this.animais,
    required this.data,
    required this.operacaoId,
  });

  @override
  State<ManejoOperacaoAnimaisPage> createState() =>
      _ManejoOperacaoAnimaisPageState();
}

class _ManejoOperacaoAnimaisPageState
    extends State<ManejoOperacaoAnimaisPage> {
  final Map<String, List<TipoManejo>> _procedimentosPorAnimal = {};
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
      } else {
        lista.add(tipo);
      }
    });
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

    for (var i = 0; i < procedimentos.length; i++) {
      if (!mounted) return;

      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ManejoFormPage(
            tipoInicial: procedimentos[i],
            dataInicial: widget.data,
            animalIdsIniciais: [id],
            selecaoAnimaisBloqueada: true,
            operacaoId: widget.operacaoId,
          ),
        ),
      );

      if (resultado != true) {
        if (!mounted) return;
        setState(() => _processando = false);

        final restantes = procedimentos.length - i;
        final continuar = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Registro não concluído'),
            content: Text(
              'O animal ' +
                  _animalNome(_animalAtual) +
                  ' ainda tem ' +
                  restantes.toString() +
                  ' procedimento(s) pendente(s).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Deixar para depois'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );

        if (continuar == true && mounted) {
          setState(() => _processando = true);
          i--;
          continue;
        }
        return;
      }
    }

    if (!mounted) return;

    _animaisConcluidos.add(id);

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

    Navigator.of(context).pop(true);
  }


  @override
  Widget build(BuildContext context) {
    final animal = _animalAtual;
    final id = _animalId(animal);
    final selecionados =
        _procedimentosPorAnimal[id] ?? const <TipoManejo>[];
    final total = _animaisOrdenados.length;
    final concluidos = _animaisConcluidos.length;
    final progresso = total == 0 ? 0.0 : concluidos / total;
    final ultimo = _indiceAtual == total - 1;
    final podeRegistrar =
        !_processando &&
        !_finalizado &&
        selecionados.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manejo'),
        actions: [
          const ContextualHelpButton(
            title: 'Registrar por animal',
            introduction:
                'Cada animal pode receber procedimentos diferentes. Escolha o que foi feito e avance quando terminar.',
            topics: [
              HelpTopic(
                title: 'Vários procedimentos',
                description:
                    'Você pode registrar pesagem, vacinação, vermifugação, tratamento e outros cuidados no mesmo animal.',
              ),
              HelpTopic(
                title: 'Peso e dose',
                description:
                    'Quando houver peso e uma regra de dose cadastrada, o aplicativo calcula a quantidade individual. A dose pode ser ajustada antes de salvar.',
              ),
              HelpTopic(
                title: 'Trocar animal',
                description:
                    'Use o botão Animais para ir diretamente a outro animal e reorganizar a sequência.',
              ),
            ],
          ),
          IconButton(
            onPressed: _processando ? null : _abrirListaAnimais,
            tooltip: 'Animais',
            icon: const Icon(Icons.groups_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth > 720 ? 680.0 : constraints.maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                  children: [
                    _progresso(),
                    const SizedBox(height: 16),
                    _animalCard(animal, _animaisConcluidos.contains(id)),
                    const SizedBox(height: 20),
                    _procedimentosCard(selecionados),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: const Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: OutlinedButton(
                  onPressed:
                      _processando || _indiceAtual == 0 ? null : _voltarAnimal,
                  child: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: podeRegistrar ? _registrarAnimal : null,
                  icon: _processando
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          ultimo
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    _processando
                        ? 'Salvando...'
                        : ultimo
                            ? 'Concluir animal'
                            : 'Salvar e próximo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: OutlinedButton(
                  onPressed: _processando ? null : _abrirListaAnimais,
                  child: const Icon(Icons.groups_outlined),
                ),
              ),
            ],
          ),
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
    final asset = (sexo ?? '').toLowerCase().contains('masc')
        ? 'assets/images/icon_ovino_macho.png'
        : 'assets/images/icon_ovino_femea.png';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
            ),
            alignment: Alignment.center,
            child: AppAssetIcon(assetPath: asset, size: 46),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Animal atual',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (raca != null && raca.trim().isNotEmpty) raca,
                    if (sexo != null && sexo.trim().isNotEmpty) sexo,
                  ].join(' • '),
                  style: const TextStyle(color: Colors.black54),
                ),
                if (concluido) ...[
                  const SizedBox(height: 7),
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Animal concluído',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
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
    );
  }


  Widget _procedimentosCard(List<TipoManejo> selecionados) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'O que foi feito?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Selecione os procedimentos realizados neste animal.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final colunas = constraints.maxWidth >= 600 ? 4 : 2;
            final largura =
                (constraints.maxWidth - ((colunas - 1) * 9)) / colunas;

            return Wrap(
              spacing: 9,
              runSpacing: 9,
              children: TipoManejo.values.map((tipo) {
                final selecionado = selecionados.contains(tipo);

                return SizedBox(
                  width: largura,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _processando || _finalizado
                          ? null
                          : () => _alternarProcedimento(tipo),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        constraints: const BoxConstraints(minHeight: 88),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: selecionado
                              ? AppTheme.primaryColor.withValues(alpha: 0.10)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selecionado
                                ? AppTheme.primaryColor.withValues(alpha: 0.60)
                                : Colors.black12,
                            width: selecionado ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _icone(tipo),
                                  color: AppTheme.primaryColor,
                                  size: 25,
                                ),
                                const Spacer(),
                                if (selecionado)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 21,
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              _tipoTexto(tipo),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (selecionados.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ordem do registro',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (var i = 0; i < selecionados.length; i++)
                      Chip(
                        avatar: CircleAvatar(
                          radius: 10,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            (i + 1).toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        label: Text(_tipoTexto(selecionados[i])),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: _processando || _finalizado
                            ? null
                            : () => _alternarProcedimento(selecionados[i]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

}
