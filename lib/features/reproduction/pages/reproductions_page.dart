import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../models/reproducao.dart';
import '../services/reproducao_service.dart';
import 'reproduction_details_page.dart';
import 'reproduction_help_page.dart';
import 'reproduction_form_page.dart';

class ReproductionsPage extends StatefulWidget {
  const ReproductionsPage({super.key});

  @override
  State<ReproductionsPage> createState() => _ReproductionsPageState();
}

class _ReproductionsPageState extends State<ReproductionsPage> {
  final ReproducaoService _service = ReproducaoService();
  final AnimalService _animalService = AnimalService();
  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;

  Map<String, Map<String, dynamic>> _animais = {};

  List<Reproducao> _reproducoes = [];

  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _rebanhoSelectionService.addListener(_onLoteChanged);
    _carregarReproducoes();
  }

  @override
  void dispose() {
    _rebanhoSelectionService.removeListener(_onLoteChanged);
    super.dispose();
  }

  void _onLoteChanged() {
    if (!mounted) return;
    _carregarReproducoes();
  }

  Future<void> _carregarReproducoes() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final loteId = _rebanhoSelectionService.rebanhoSelecionadoId;
      if (loteId == null) {
        if (!mounted) return;
        setState(() {
          _reproducoes = [];
          _animais = {};
          _carregando = false;
        });
        return;
      }

      final reproducoesTodas = await _service.getReproducoes();
      final animaisDoLote = await _animalService.getTodosAnimais(rebanhoId: loteId);
      final idsDoLote = animaisDoLote.map((animal) => animal['id'].toString()).toSet();
      final reproducoes = reproducoesTodas
          .where((item) => idsDoLote.contains(item.maeId))
          .toList();
      final ids = <String>{
        for (final reproducao in reproducoes) ...[
          reproducao.maeId,
          if (reproducao.paiId != null) reproducao.paiId!,
        ],
      };
      final animais = await _animalService.getAnimaisPorIds(ids.toList());

      if (!mounted) {
        return;
      }

      setState(() {
        _reproducoes = reproducoes;
        _animais = {for (final animal in animais) animal['id'].toString(): animal};
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
        _erro = _mensagemErro(e);
      });
    }
  }

  String _mensagemErro(Object erro) {
    final mensagem = erro.toString();

    if (mensagem.startsWith('Exception: ')) {
      return mensagem.substring(11);
    }

    return mensagem;
  }

  String _formatarData(DateTime? data) {
    if (data == null) {
      return 'Não informada';
    }

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  String _nomeStatus(StatusReproducao status) {
    switch (status) {
      case StatusReproducao.planejada:
        return 'Planejada';

      case StatusReproducao.coberta:
        return 'Coberta';

      case StatusReproducao.prenhe:
        return 'Prenhe';

      case StatusReproducao.naoPrenhe:
        return 'Não prenhe';

      case StatusReproducao.abortou:
        return 'Abortou';

      case StatusReproducao.partoRealizado:
        return 'Parto realizado';

      case StatusReproducao.encerrada:
        return 'Encerrada';
    }
  }

  Color _corStatus(StatusReproducao status) {
    switch (status) {
      case StatusReproducao.planejada:
        return Colors.blueGrey;

      case StatusReproducao.coberta:
        return Colors.blue;

      case StatusReproducao.prenhe:
        return Colors.green;

      case StatusReproducao.naoPrenhe:
        return Colors.orange;

      case StatusReproducao.abortou:
        return Colors.red;

      case StatusReproducao.partoRealizado:
        return Colors.teal;

      case StatusReproducao.encerrada:
        return Colors.grey;
    }
  }

  Future<void> _abrirFormulario() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReproductionFormPage()),
    );

    if (resultado == true && mounted) {
      await _carregarReproducoes();
    }
  }

  Future<void> _abrirDetalhes(Reproducao reproducao) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReproductionDetailsPage(reproducao: reproducao),
      ),
    );

    if (mounted) {
      await _carregarReproducoes();
    }
  }

  void _abrirAjuda() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ReproductionHelpPage()));
  }

  Future<void> _atualizar() async {
    await _carregarReproducoes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reprodução'),
        actions: [
          IconButton(
            onPressed: _abrirAjuda,
            tooltip: 'Ajuda',
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            onPressed: _carregando ? null : _atualizar,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _atualizar, child: _buildConteudo()),
      floatingActionButton: FloatingActionButton(
        onPressed: _carregando ? null : _abrirFormulario,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return _buildErro();
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
          const Text('Escolha o lote no início para visualizar a reprodução dele.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4)),
        ],
      );
    }

    if (_reproducoes.isEmpty) {
      return _buildSemReproducoes();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildResumo(),
        const SizedBox(height: 20),
        ..._reproducoes.map(_buildCardReproducao),
      ],
    );
  }

  Widget _buildResumo() {
    final planejadas = _reproducoes
        .where((item) => item.status == StatusReproducao.planejada)
        .length;

    final prenhes = _reproducoes
        .where((item) => item.status == StatusReproducao.prenhe)
        .length;

    final partos = _reproducoes
        .where((item) => item.status == StatusReproducao.partoRealizado)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo reprodutivo',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildResumoItem(
                  valor: _reproducoes.length.toString(),
                  legenda: 'Total',
                  icone: Icons.pets,
                ),
              ),
              Expanded(
                child: _buildResumoItem(
                  valor: planejadas.toString(),
                  legenda: 'Planejadas',
                  icone: Icons.event_note,
                ),
              ),
              Expanded(
                child: _buildResumoItem(
                  valor: prenhes.toString(),
                  legenda: 'Prenhes',
                  icone: Icons.favorite,
                ),
              ),
              Expanded(
                child: _buildResumoItem(
                  valor: partos.toString(),
                  legenda: 'Partos',
                  icone: Icons.child_friendly,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItem({
    required String valor,
    required String legenda,
    required IconData icone,
  }) {
    return Column(
      children: [
        Icon(icone, size: 22, color: AppTheme.primaryColor),
        const SizedBox(height: 6),
        Text(
          valor,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          legenda,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildCardReproducao(Reproducao reproducao) {
    final corStatus = _corStatus(reproducao.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _abrirDetalhes(reproducao);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.pets, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reprodução',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Mãe: ${_identificador(reproducao.maeId)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: corStatus.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _nomeStatus(reproducao.status),
                      style: TextStyle(
                        color: corStatus,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              if (reproducao.dataCobertura != null)
                _buildInformacao(
                  icone: Icons.calendar_today,
                  titulo: 'Cobertura',
                  valor: _formatarData(reproducao.dataCobertura),
                ),
              if (reproducao.dataPrevisaoParto != null) ...[
                const SizedBox(height: 10),
                _buildInformacao(
                  icone: Icons.event,
                  titulo: 'Previsão de parto',
                  valor: _formatarData(reproducao.dataPrevisaoParto),
                ),
              ],
              if (reproducao.dataParto != null) ...[
                const SizedBox(height: 10),
                _buildInformacao(
                  icone: Icons.child_friendly,
                  titulo: 'Parto realizado',
                  valor: _formatarData(reproducao.dataParto),
                ),
              ],
              if (reproducao.dataCobertura == null &&
                  reproducao.dataPrevisaoParto == null &&
                  reproducao.dataParto == null) ...[
                _buildInformacao(
                  icone: Icons.hourglass_empty,
                  titulo: 'Próximo passo',
                  valor: 'Registrar a cobertura',
                ),
              ],
              const SizedBox(height: 10),
              _buildInformacao(
                icone: Icons.male,
                titulo: 'Pai',
                valor: reproducao.paiId == null
                    ? 'Ainda não definido'
                    : _identificador(reproducao.paiId!),
              ),
              if (reproducao.observacoes != null &&
                  reproducao.observacoes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  reproducao.observacoes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ver detalhes',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformacao({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Row(
      children: [
        Icon(icone, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          '$titulo: ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSemReproducoes() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.pets_outlined, size: 72, color: Colors.grey.shade400),
        const SizedBox(height: 20),
        Text(
          'Nenhuma reprodução registrada',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Quando você cadastrar uma reprodução, '
          'ela aparecerá aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildErro() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
        const SizedBox(height: 20),
        Text(
          'Não foi possível carregar as reproduções',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          _erro ?? 'Erro desconhecido.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: _carregarReproducoes,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }

  String _identificador(String id) {
    final animal = _animais[id];

    if (animal == null) {
      return 'Animal não encontrado';
    }

    final brinco = animal['brinco'];
    final identificacao = brinco is num
        ? brinco.toInt().toString().padLeft(3, '0')
        : (brinco?.toString() ?? 'Sem brinco');
    final nome = animal['nome']?.toString().trim();

    if (nome != null && nome.isNotEmpty) {
      return '$identificacao • $nome';
    }

    return 'Brinco $identificacao';
  }
}
