import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_service.dart';
import '../models/manejo.dart';
import '../widgets/manejo_animal_selector.dart';
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
  final List<TipoManejo> _procedimentos = [];

  String? _rebanhoId;
  DateTime _data = DateTime.now();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _carregarAnimais() async {
    setState(() => _carregandoAnimais = true);
    try {
      final animais = await _animalService.getAnimaisAtivos(rebanhoId: _rebanhoId);
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
    if (escolhida != null && mounted) setState(() => _data = escolhida);
  }

  void _alternarProcedimento(TipoManejo tipo) {
    setState(() {
      if (_procedimentos.contains(tipo)) {
        _procedimentos.remove(tipo);
      } else {
        _procedimentos.add(tipo);
      }
    });
  }

  void _selecionarTodosAnimais() {
    setState(() {
      _animaisSelecionados
        ..clear()
        ..addAll(_animais.map((a) => a['id']?.toString()).whereType<String>());
    });
  }

  void _limparAnimais() => setState(() => _animaisSelecionados.clear());

  Future<void> _iniciarOperacao() async {
    if (_animaisSelecionados.isEmpty) {
      _mensagem('Selecione pelo menos um animal.');
      return;
    }
    if (_procedimentos.isEmpty) {
      _mensagem('Selecione pelo menos um procedimento.');
      return;
    }

    setState(() => _iniciando = true);
    var concluidos = 0;
    final operacaoId = const Uuid().v4();

    for (final tipo in List<TipoManejo>.from(_procedimentos)) {
      if (!mounted) return;

      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ManejoFormPage(
            tipoInicial: tipo,
            dataInicial: _data,
            animalIdsIniciais: _animaisSelecionados.toList(),
            selecaoAnimaisBloqueada: true,
            operacaoId: operacaoId,
          ),
        ),
      );

      if (resultado != true) {
        if (!mounted) return;
        setState(() => _iniciando = false);
        final restantes = _procedimentos.length - concluidos;
        final continuar = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Operação incompleta'),
            content: Text(
              concluidos.toString() +
                  ' procedimento(s) foram salvos. Ainda faltam ' +
                  restantes.toString() +
                  '.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Encerrar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (continuar == true && mounted) {
          setState(() => _iniciando = true);
          continue;
        }
        if (mounted && concluidos > 0) {
          _mensagem(
            'Operação encerrada com ' +
                concluidos.toString() +
                ' procedimento(s) salvo(s).',
          );
        }
        return;
      }
      concluidos++;
    }

    if (!mounted) return;
    setState(() => _iniciando = false);
    _mensagem('Operação de manejo registrada com sucesso.');
    Navigator.of(context).pop(true);
  }

  String _tipoTexto(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao: return 'Vacinação';
      case TipoManejo.vermifugacao: return 'Vermifugação';
      case TipoManejo.tratamento: return 'Tratamento';
      case TipoManejo.tosquia: return 'Tosquia';
      case TipoManejo.pesagem: return 'Pesagem';
      case TipoManejo.famacha: return 'FAMACHA';
      case TipoManejo.denticao: return 'Dentição';
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
      case TipoManejo.denticao: return Icons.health_and_safety_outlined;
      case TipoManejo.outro: return Icons.assignment_outlined;
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
            Text('Nova operação de manejo'),
          ],
        ),
      ),
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
                          const SizedBox(height: 18),
                          ManejoAnimalSelector(
                            rebanhos: _rebanhos,
                            rebanhoId: _rebanhoId,
                            animais: _animais,
                            selecionados: _animaisSelecionados,
                            carregando: _carregandoAnimais,
                            enabled: !_iniciando,
                            multiSelecao: true,
                            titulo: 'Animais da operação',
                            onRebanhoChanged: (id) {
                              setState(() {
                                _rebanhoId = id;
                                _animaisSelecionados.clear();
                              });
                              _carregarAnimais();
                            },
                            onToggleAnimal: (id) {
                              setState(() {
                                if (_animaisSelecionados.contains(id)) {
                                  _animaisSelecionados.remove(id);
                                } else {
                                  _animaisSelecionados.add(id);
                                }
                              });
                            },
                            onSelecionarTodos: _selecionarTodosAnimais,
                            onLimpar: _limparAnimais,
                          ),
                          const SizedBox(height: 18),
                          _secaoProcedimentos(),
                          const SizedBox(height: 18),
                          InkWell(
                            onTap: _iniciando ? null : _escolherData,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data da operação',
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
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _iniciando ? null : _iniciarOperacao,
                              icon: _iniciando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward),
                              label: Text(
                                _iniciando
                                    ? 'Configurando operação...'
                                    : 'Configurar e registrar procedimentos',
                              ),
                            ),
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
            Icons.playlist_add_check_circle_outlined,
            color: AppTheme.primaryColor,
            size: 30,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uma ida ao curral, vários procedimentos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 5),
                Text(
                  'Selecione os animais e tudo o que será feito. O OviGestão abrirá a configuração de cada procedimento na sequência, mantendo os registros separados no histórico.',
                  style: TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoProcedimentos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Procedimentos desta operação',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'Marque todos os procedimentos que serão realizados nos animais selecionados.',
            style: TextStyle(color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TipoManejo.values.map((tipo) {
              final selecionado = _procedimentos.contains(tipo);
              return FilterChip(
                selected: selecionado,
                avatar: Icon(
                  _icone(tipo),
                  size: 19,
                  color: selecionado ? Colors.white : AppTheme.primaryColor,
                ),
                label: Text(_tipoTexto(tipo)),
                onSelected: _iniciando ? null : (_) => _alternarProcedimento(tipo),
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          if (_procedimentos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _procedimentos.length.toString() +
                  ' procedimento(s) selecionado(s): ' +
                  _procedimentos.map(_tipoTexto).join(', '),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
