import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../models/monta.dart';
import '../models/reproducao.dart';
import '../models/reproducao_nascimento.dart';
import '../services/reproducao_service.dart';

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
  List<Monta> _montas = [];
  List<ReproducaoNascimento> _nascimentos = [];
  Map<String, Map<String, dynamic>> _animais = {};
  bool _carregando = true;
  String? _erro;

  @override
  void initState() { super.initState(); _reproducao = widget.reproducao; _carregar(); }

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final dados = await Future.wait([
        _service.getReproducaoPorId(_reproducao.id),
        _service.getMontas(_reproducao.id),
        _service.getNascimentos(_reproducao.id),
        _animalService.getTodosAnimais(),
      ]);
      if (!mounted) return;
      final reproducao = dados[0] as Reproducao?;
      if (reproducao == null) throw Exception('A reprodução não foi encontrada.');
      final animais = dados[3] as List<Map<String, dynamic>>;
      setState(() {
        _reproducao = reproducao;
        _montas = dados[1] as List<Monta>;
        _nascimentos = dados[2] as List<ReproducaoNascimento>;
        _animais = {for (final a in animais) a['id'].toString(): a};
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _carregando = false; _erro = _mensagemErro(e); });
    }
  }

  String _mensagemErro(Object erro) {
    final m = erro.toString();
    return m.startsWith('Exception: ') ? m.substring(11) : m;
  }

  String _data(DateTime? d) => d == null ? 'Não informada' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _animal(String id) {
    final a = _animais[id];
    if (a == null) return 'Animal não encontrado';
    if (a['brinco'] != null) return 'Brinco ' + a['brinco'].toString();
    final nome = a['nome']?.toString().trim();
    if (nome != null && nome.isNotEmpty) return nome;
    return 'Animal';
  }

  String _status(StatusReproducao s) {
    switch (s) {
      case StatusReproducao.planejada: return 'Planejada';
      case StatusReproducao.coberta: return 'Coberta';
      case StatusReproducao.prenhe: return 'Prenhe';
      case StatusReproducao.naoPrenhe: return 'Não prenhe';
      case StatusReproducao.abortou: return 'Abortou';
      case StatusReproducao.partoRealizado: return 'Parto realizado';
      case StatusReproducao.encerrada: return 'Encerrada';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes da reprodução'), actions: [IconButton(onPressed: _carregando ? null : _carregar, icon: const Icon(Icons.refresh))]),
    body: _body(),
  );

  Widget _body() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_erro!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente'))])));
    return RefreshIndicator(onRefresh: _carregar, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [_cabecalho(), const SizedBox(height: 16), _dados(), const SizedBox(height: 16), _montasWidget(), const SizedBox(height: 16), _nascimentosWidget(), if (_reproducao.observacoes?.trim().isNotEmpty == true) ...[const SizedBox(height: 16), _observacoes()]]));
  }

  Widget _cabecalho() => Card(child: ListTile(leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withValues(alpha: .1), child: const Icon(Icons.favorite_outline, color: AppTheme.primaryColor)), title: const Text('Reprodução', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(_status(_reproducao.status))));

  Widget _dados() => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Dados da reprodução', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 16), _info('Mãe', _animal(_reproducao.maeId)), _info('Pai', _reproducao.paiId == null ? 'Não definido' : _animal(_reproducao.paiId!)), _info('Data da cobertura', _data(_reproducao.dataCobertura)), _info('Previsão de parto', _data(_reproducao.dataPrevisaoParto)), _info('Data do parto', _data(_reproducao.dataParto))])));
  Widget _info(String titulo, String valor) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(titulo, style: TextStyle(color: Colors.grey.shade600))), Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)))]));

  Widget _montasWidget() => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Montas / coberturas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 12), if (_montas.isEmpty) _vazio('Nenhuma monta registrada.') else ..._montas.map((m) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.male, color: AppTheme.primaryColor), title: Text(_animal(m.carneiroId)), subtitle: Text('Data: ' + _data(m.dataMonta))))])));
  Widget _nascimentosWidget() => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Nascimentos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 12), if (_nascimentos.isEmpty) _vazio('Nenhum nascimento registrado.') else ..._nascimentos.map((n) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.pets_outlined, color: AppTheme.primaryColor), title: Text(_animal(n.animalId)), subtitle: Text((n.sexo == SexoNascimento.femea ? 'Fêmea' : 'Macho') + ' • ' + _data(n.dataNascimento))))])));
  Widget _observacoes() => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Observações', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Text(_reproducao.observacoes!)])));
  Widget _vazio(String texto) => Text(texto, style: TextStyle(color: Colors.grey.shade600));
}