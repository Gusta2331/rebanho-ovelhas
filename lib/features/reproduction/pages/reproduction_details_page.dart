import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../models/monta.dart';
import '../models/reproducao.dart';
import '../models/reproducao_nascimento.dart';
import '../services/reproducao_service.dart';
import 'monta_form_page.dart';
import 'nascimento_form_page.dart';
import 'reproduction_edit_page.dart';

class ReproductionDetailsPage extends StatefulWidget {
  final Reproducao reproducao;

  const ReproductionDetailsPage({super.key, required this.reproducao});

  @override
  State<ReproductionDetailsPage> createState() => _ReproductionDetailsPageState();
}

class _ReproductionDetailsPageState extends State<ReproductionDetailsPage> {
  final _service = ReproducaoService();
  final _animalService = AnimalService();

  late Reproducao _reproducao;
  List<Monta> _montasLista = [];
  List<ReproducaoNascimento> _nascimentosLista = [];
  Map<String, Map<String, dynamic>> _animais = {};
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _reproducao = widget.reproducao;
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final dados = await Future.wait([
        _service.getReproducaoPorId(_reproducao.id),
        _service.getMontas(_reproducao.id),
        _service.getNascimentos(_reproducao.id),
        _animalService.getTodosAnimais(),
      ]);

      if (!mounted) return;

      final r = dados[0] as Reproducao?;
      if (r == null) throw Exception('A reprodução não foi encontrada.');

      final animais = dados[3] as List<Map<String, dynamic>>;

      setState(() {
        _reproducao = r;
        _montasLista = dados[1] as List<Monta>;
        _nascimentosLista = dados[2] as List<ReproducaoNascimento>;
        _animais = {
          for (final a in animais) a['id'].toString(): a,
        };
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = _msg(e);
      });
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  String _data(DateTime? d) {
    if (d == null) return 'Não informada';
    return d.day.toString().padLeft(2, '0') +
        '/' +
        d.month.toString().padLeft(2, '0') +
        '/' +
        d.year.toString();
  }

  String _animal(String id) {
    final a = _animais[id];
    if (a == null) return 'Animal não encontrado';

    final b = a['brinco'];
    final identificacao = b is num
        ? b.toInt().toString().padLeft(3, '0')
        : (b?.toString() ?? 'Sem brinco');

    final nome = a['nome']?.toString().trim();

    if (nome != null && nome.isNotEmpty) {
      return '$identificacao • $nome';
    }

    return 'Brinco $identificacao';
  }

  String _status(StatusReproducao s) {
    switch (s) {
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

  Color _statusColor(StatusReproducao s) {
    switch (s) {
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

  Future<void> _editar() async {
    final resultado = await Navigator.of(context).push<Reproducao>(
      MaterialPageRoute(
        builder: (_) => ReproductionEditPage(reproducao: _reproducao),
      ),
    );

    if (resultado != null && mounted) {
      await _carregar();
    }
  }

  Future<void> _adicionarMonta() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MontaFormPage(reproducaoId: _reproducao.id),
      ),
    );

    if (resultado == true && mounted) {
      await _carregar();
    }
  }

  Future<void> _editarMonta(Monta monta) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MontaFormPage(
          reproducaoId: _reproducao.id,
          monta: monta,
        ),
      ),
    );

    if (resultado == true && mounted) {
      await _carregar();
    }
  }

  Future<void> _excluirMonta(Monta monta) async {
    final confirmar = await _confirmar(
      titulo: 'Excluir monta?',
      mensagem: 'O registro desta cobertura será removido.',
      textoBotao: 'Excluir',
    );

    if (confirmar != true) return;

    try {
      await _service.excluirMonta(
        montaId: monta.id,
        reproducaoId: _reproducao.id,
      );
      if (mounted) {
        _snack('Monta excluída.');
        await _carregar();
      }
    } catch (e) {
      if (mounted) _snack(_msg(e), erro: true);
    }
  }

  Future<void> _adicionarNascimento() async {
    final resultado = await Navigator.of(context).push<ReproducaoNascimento>(
      MaterialPageRoute(
        builder: (_) => NascimentoFormPage(reproducaoId: _reproducao.id),
      ),
    );

    if (resultado != null && mounted) {
      await _carregar();
      _snack('Nascimento registrado e animal criado.');
    }
  }

  Future<void> _excluirNascimento(ReproducaoNascimento nascimento) async {
    final confirmar = await _confirmar(
      titulo: 'Desvincular nascimento?',
      mensagem:
          'O nascimento será removido da reprodução, mas o animal não será apagado do rebanho.',
      textoBotao: 'Desvincular',
    );

    if (confirmar != true) return;

    try {
      await _service.excluirNascimento(
        nascimentoId: nascimento.id,
        reproducaoId: _reproducao.id,
      );
      if (mounted) {
        _snack('Nascimento desvinculado.');
        await _carregar();
      }
    } catch (e) {
      if (mounted) _snack(_msg(e), erro: true);
    }
  }

  Future<void> _excluirReproducao() async {
    final confirmar = await _confirmar(
      titulo: 'Excluir reprodução?',
      mensagem:
          'A reprodução só poderá ser excluída se não possuir montas ou nascimentos.',
      textoBotao: 'Excluir',
    );

    if (confirmar != true) return;

    try {
      await _service.excluirReproducao(_reproducao.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _snack(_msg(e), erro: true);
    }
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String mensagem,
    required String textoBotao,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(textoBotao),
          ),
        ],
      ),
    );
  }

  void _snack(String texto, {bool erro = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: erro ? Colors.red : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da reprodução'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _editar,
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (valor) {
              if (valor == 'excluir') _excluirReproducao();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir reprodução'),
              ),
            ],
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _cabecalho(),
          const SizedBox(height: 16),
          _dados(),
          const SizedBox(height: 16),
          _montas(),
          const SizedBox(height: 16),
          _nascimentos(),
          if (_reproducao.observacoes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _observacoes(),
          ],
        ],
      ),
    );
  }

  Widget _cabecalho() {
    final cor = _statusColor(_reproducao.status);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: .10),
          child: const Icon(Icons.favorite_outline, color: AppTheme.primaryColor),
        ),
        title: const Text(
          'Reprodução',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_status(_reproducao.status)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _status(_reproducao.status),
            style: TextStyle(color: cor, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _dados() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dados da reprodução',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _info('Mãe', _animal(_reproducao.maeId)),
            _info(
              'Pai',
              _reproducao.paiId == null
                  ? 'Não definido'
                  : _animal(_reproducao.paiId!),
            ),
            _info('Data da cobertura', _data(_reproducao.dataCobertura)),
            _info('Previsão de parto', _data(_reproducao.dataPrevisaoParto)),
            _info('Data do parto', _data(_reproducao.dataParto)),
          ],
        ),
      ),
    );
  }

  Widget _info(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              titulo,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _montas() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Montas / coberturas',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _adicionarMonta,
                  tooltip: 'Adicionar monta',
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_montasLista.isEmpty)
              _vazio('Nenhuma monta registrada.')
            else
              ..._montasLista.map(
                (m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.male, color: AppTheme.primaryColor),
                  title: Text(_animal(m.carneiroId)),
                  subtitle: Text(
                    'Data: ' + _data(m.dataMonta) +
                        (m.observacoes?.trim().isNotEmpty == true
                            ? '\n' + m.observacoes!.trim()
                            : ''),
                  ),
                  isThreeLine: m.observacoes?.trim().isNotEmpty == true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'editar') _editarMonta(m);
                      if (v == 'excluir') _excluirMonta(m);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nascimentos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nascimentos',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _adicionarNascimento,
                  tooltip: 'Registrar nascimento',
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_nascimentosLista.isEmpty)
              _vazio('Nenhum nascimento registrado.')
            else
              ..._nascimentosLista.map(
                (n) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.pets_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(_animal(n.animalId)),
                  subtitle: Text(
                    (n.sexo == SexoNascimento.femea ? 'Fêmea' : 'Macho') +
                        ' • ' +
                        _data(n.dataNascimento),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'excluir') _excluirNascimento(n);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'excluir',
                        child: Text('Desvincular'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _observacoes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Observações',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(_reproducao.observacoes!),
          ],
        ),
      ),
    );
  }

  Widget _vazio(String texto) {
    return Text(
      texto,
      style: TextStyle(color: Colors.grey.shade600),
    );
  }
}
