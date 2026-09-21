import 'package:flutter/material.dart';

import '../../animals/services/animal_service.dart';
import '../models/reproducao.dart';
import '../services/reproducao_service.dart';

class ReproductionFormPage extends StatefulWidget {
  const ReproductionFormPage({super.key});

  @override
  State<ReproductionFormPage> createState() => _ReproductionFormPageState();
}

class _ReproductionFormPageState extends State<ReproductionFormPage> {
  final ReproducaoService _reproducaoService = ReproducaoService();

  final AnimalService _animalService = AnimalService();

  final TextEditingController _observacoesController = TextEditingController();

  List<Map<String, dynamic>> _femeas = [];
  List<Map<String, dynamic>> _machos = [];

  String? _maeId;
  String? _paiId;

  DateTime? _dataCobertura;
  DateTime? _dataPrevisaoParto;

  StatusReproducao _status = StatusReproducao.planejada;

  bool _carregandoAnimais = true;
  bool _salvando = false;

  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarAnimais();
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _carregarAnimais() async {
    try {
      final animais = await _animalService.getAnimaisAtivos();

      if (!mounted) {
        return;
      }

      final femeas = animais
          .where((animal) => animal['sexo']?.toString() == 'femea')
          .toList();

      final machos = animais
          .where((animal) => animal['sexo']?.toString() == 'macho')
          .toList();

      setState(() {
        _femeas = femeas;
        _machos = machos;
        _carregandoAnimais = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregandoAnimais = false;
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

  String _identificarAnimal(Map<String, dynamic> animal) {
    final brinco = animal['brinco'];

    String identificacao;

    if (brinco is int) {
      identificacao = brinco.toString().padLeft(3, '0');
    } else if (brinco is num) {
      identificacao = brinco.toInt().toString().padLeft(3, '0');
    } else {
      identificacao = brinco?.toString() ?? 'Sem brinco';
    }

    final nome = animal['nome']?.toString().trim();

    if (nome != null && nome.isNotEmpty) {
      return '$identificacao • $nome';
    }

    return 'Brinco $identificacao';
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

  String _statusParaBanco(StatusReproducao status) {
    switch (status) {
      case StatusReproducao.planejada:
        return 'planejada';

      case StatusReproducao.coberta:
        return 'coberta';

      case StatusReproducao.prenhe:
        return 'prenhe';

      case StatusReproducao.naoPrenhe:
        return 'nao_prenhe';

      case StatusReproducao.abortou:
        return 'abortou';

      case StatusReproducao.partoRealizado:
        return 'parto_realizado';

      case StatusReproducao.encerrada:
        return 'encerrada';
    }
  }

  String _formatarData(DateTime? data) {
    if (data == null) {
      return 'Selecionar data';
    }

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  Future<void> _selecionarDataCobertura() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _dataCobertura ?? hoje,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (data == null) {
      return;
    }

    setState(() {
      _dataCobertura = data;

      _dataPrevisaoParto = data.add(const Duration(days: 150));
    });
  }

  Future<void> _selecionarPrevisaoParto() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate:
          _dataPrevisaoParto ??
          _dataCobertura?.add(const Duration(days: 150)) ??
          hoje,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (data == null) {
      return;
    }

    setState(() {
      _dataPrevisaoParto = data;
    });
  }

  Future<void> _salvar() async {
    if (_maeId == null) {
      _mostrarMensagem('Selecione a ovelha mãe.');
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      await _reproducaoService.criarReproducao(
        maeId: _maeId!,
        paiId: _paiId,
        dataCobertura: _dataCobertura,
        dataPrevisaoParto: _dataPrevisaoParto,
        status: _statusParaBanco(_status),
        observacoes: _observacoesController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _mostrarMensagem(_mensagemErro(e), erro: true);
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: erro ? Colors.red : null,
        ),
      );
  }

  Widget _buildSeletorAnimal({
    required String titulo,
    required String? valor,
    required List<Map<String, dynamic>> animais,
    required ValueChanged<String?> onChanged,
    required IconData icone,
    String? textoVazio,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: titulo, prefixIcon: Icon(icone)),
      items: [
        if (textoVazio != null)
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              textoVazio,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ...animais.map((animal) {
          final id = animal['id']?.toString();

          if (id == null) {
            return const DropdownMenuItem<String>(
              value: '',
              child: Text('Animal inválido'),
            );
          }

          return DropdownMenuItem<String>(
            value: id,
            child: Text(
              _identificarAnimal(animal),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildDataCampo({
    required String titulo,
    required DateTime? valor,
    required VoidCallback onTap,
    required IconData icone,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: titulo, prefixIcon: Icon(icone)),
        child: Text(
          _formatarData(valor),
          style: TextStyle(color: valor == null ? Colors.grey.shade600 : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova reprodução')),
      body: _buildBody(),
      bottomNavigationBar: _buildBotaoSalvar(),
    );
  }

  Widget _buildBody() {
    if (_carregandoAnimais) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                'Não foi possível carregar os animais.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _carregarAnimais,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_femeas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Nenhuma ovelha ativa encontrada.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Cadastre uma fêmea ativa no rebanho '
                'antes de criar uma reprodução.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dados da reprodução',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Informe a mãe e os dados iniciais. '
            'O pai pode ser definido posteriormente.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 24),

          _buildSeletorAnimal(
            titulo: 'Ovelha mãe *',
            valor: _maeId,
            animais: _femeas,
            onChanged: (valor) {
              setState(() {
                _maeId = valor;
              });
            },
            icone: Icons.female,
          ),

          const SizedBox(height: 16),

          _buildSeletorAnimal(
            titulo: 'Carneiro / pai',
            valor: _paiId,
            animais: _machos,
            onChanged: (valor) {
              setState(() {
                _paiId = valor;
              });
            },
            icone: Icons.male,
            textoVazio: 'Pai ainda não definido',
          ),

          const SizedBox(height: 16),

          _buildDataCampo(
            titulo: 'Data da cobertura',
            valor: _dataCobertura,
            onTap: _selecionarDataCobertura,
            icone: Icons.calendar_today,
          ),

          const SizedBox(height: 16),

          _buildDataCampo(
            titulo: 'Previsão de parto',
            valor: _dataPrevisaoParto,
            onTap: _selecionarPrevisaoParto,
            icone: Icons.event,
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<StatusReproducao>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: StatusReproducao.values
                .map(
                  (status) => DropdownMenuItem<StatusReproducao>(
                    value: status,
                    child: Text(_nomeStatus(status)),
                  ),
                )
                .toList(),
            onChanged: (valor) {
              if (valor == null) {
                return;
              }

              setState(() {
                _status = valor;
              });
            },
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _observacoesController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observações',
              hintText: 'Ex.: primeira cobertura da temporada...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 70),
                child: Icon(Icons.notes_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoSalvar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_salvando ? 'Salvando...' : 'Salvar reprodução'),
          ),
        ),
      ),
    );
  }
}
