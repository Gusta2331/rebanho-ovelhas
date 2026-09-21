import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/manejo.dart';
import '../services/manejo_service.dart';
import 'manejo_form_page.dart';

class ManejosPage extends StatefulWidget {
  const ManejosPage({super.key});

  @override
  State<ManejosPage> createState() => _ManejosPageState();
}

class _ManejosPageState extends State<ManejosPage> {
  final ManejoService _service = ManejoService();
  List<Map<String, dynamic>> _manejos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final dados = await _service.getManejos();
      if (!mounted) return;
      setState(() {
        _manejos = dados;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _novo() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManejoFormPage()),
    );
    if (resultado == true && mounted) await _carregar();
  }

  String _tipo(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao: return 'Vacinação';
      case TipoManejo.vermifugacao: return 'Vermifugação';
      case TipoManejo.tratamento: return 'Tratamento';
      case TipoManejo.tosquia: return 'Tosquia';
      case TipoManejo.pesagem: return 'Pesagem';
      case TipoManejo.famacha: return 'FAMACHA';
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
      case TipoManejo.outro: return Icons.assignment_outlined;
    }
  }

  String _animal(Map<String, dynamic> registro) {
    final animal = registro['animais'];
    if (animal is! Map) return 'Animal não encontrado';

    final numero = int.tryParse(animal['brinco']?.toString() ?? '');
    final brinco = numero == null ? (animal['brinco']?.toString() ?? '') : numero.toString().padLeft(3, '0');
    final nome = animal['nome']?.toString().trim();
    return nome != null && nome.isNotEmpty ? brinco + ' • ' + nome : 'Brinco ' + brinco;
  }

  String _data(dynamic valor) {
    final data = DateTime.tryParse(valor?.toString() ?? '');
    if (data == null) return 'Data não informada';
    return data.day.toString().padLeft(2, '0') + '/' +
        data.month.toString().padLeft(2, '0') + '/' +
        data.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manejo'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _carregar,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _carregar, child: _body()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _carregando ? null : _novo,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo manejo'),
      ),
    );
  }

  Widget _body() {
    if (_carregando) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));

    if (_erro != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text('Não foi possível carregar os manejos', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_erro!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Center(child: FilledButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente'))),
        ],
      );
    }

    if (_manejos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 120),
        children: [
          Icon(Icons.assignment_outlined, size: 72, color: AppTheme.primaryColor.withValues(alpha: 0.65)),
          const SizedBox(height: 18),
          const Text('Nenhum manejo registrado', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Registre vacinação, vermifugação, FAMACHA e outros cuidados do rebanho.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 24),
          Center(child: FilledButton.icon(onPressed: _novo, icon: const Icon(Icons.add), label: const Text('Registrar primeiro manejo'))),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: _manejos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final registro = _manejos[index];
        final manejo = Manejo.fromMap(registro);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icone(manejo.tipo), color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tipo(manejo.tipo), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(_animal(registro), style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(_data(registro['data']), style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                if (manejo.tipo == TipoManejo.famacha && manejo.famachaEscore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('F' + manejo.famachaEscore.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
