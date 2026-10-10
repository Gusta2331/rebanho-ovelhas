import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/manejo.dart';
import '../services/manejo_service.dart';
import 'manejo_details_page.dart';
import 'manejo_form_page.dart';

class ManejoOperacaoDetailsPage extends StatefulWidget {
  final List<Map<String, dynamic>> registros;

  const ManejoOperacaoDetailsPage({
    super.key,
    required this.registros,
  });

  @override
  State<ManejoOperacaoDetailsPage> createState() =>
      _ManejoOperacaoDetailsPageState();
}

class _ManejoOperacaoDetailsPageState extends State<ManejoOperacaoDetailsPage> {
  final ManejoService _service = ManejoService();
  late List<Map<String, dynamic>> _registros;

  @override
  void initState() {
    super.initState();
    _registros = widget.registros
        .map((registro) => Map<String, dynamic>.from(registro))
        .toList();
  }

  String _tipo(TipoManejo tipo) {
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

  String _titulo(Map<String, dynamic> registro) {
    final manejo = Manejo.fromMap(registro);
    return manejo.tipo == TipoManejo.outro && manejo.outroNome != null
        ? manejo.outroNome!
        : _tipo(manejo.tipo);
  }

  String _data(dynamic valor) {
    final data = DateTime.tryParse(valor?.toString() ?? '');
    if (data == null) return 'Data não informada';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String _animal(Map<String, dynamic> registro) {
    final animal = registro['animais'];
    if (animal is! Map) return 'Animal não encontrado';
    final numero = int.tryParse(animal['brinco']?.toString() ?? '');
    final brinco = numero == null
        ? (animal['brinco']?.toString() ?? '')
        : numero.toString().padLeft(3, '0');
    final nome = animal['nome']?.toString().trim();
    return nome != null && nome.isNotEmpty
        ? '$brinco • $nome'
        : 'Brinco $brinco';
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

  String _resumo(Map<String, dynamic> registro) {
    final manejo = Manejo.fromMap(registro);
    final partes = <String>[];
    if (manejo.tipo == TipoManejo.vacinacao && manejo.vacinaNome != null) {
      partes.add('Vacina: ${manejo.vacinaNome}');
    }
    if (manejo.tipo == TipoManejo.vermifugacao &&
        manejo.vermifugoNome != null) {
      partes.add('Vermífugo: ${manejo.vermifugoNome}');
    }
    if (manejo.tipo == TipoManejo.tratamento &&
        manejo.medicamentoNome != null) {
      partes.add('Medicamento: ${manejo.medicamentoNome}');
    }
    if (manejo.pesoKg != null) {
      partes.add('Peso: ${manejo.pesoKg!.toStringAsFixed(2)} kg');
    }
    if (manejo.famachaEscore != null) {
      partes.add('Escore FAMACHA: ${manejo.famachaEscore}');
    }
    if (manejo.dose != null) {
      partes.add(
        ('Dose: ${manejo.dose!.toStringAsFixed(2)} ${manejo.doseUnidade ?? ''}')
            .trim(),
      );
    }
    return partes.isEmpty ? 'Toque para ver os detalhes' : partes.join(' • ');
  }

  Future<void> _editar(Map<String, dynamic> registro) async {
    final manejo = Manejo.fromMap(registro);
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManejoFormPage(manejo: manejo),
      ),
    );
    if (resultado == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _excluir(Map<String, dynamic> registro) async {
    final manejo = Manejo.fromMap(registro);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir procedimento?'),
        content: const Text(
          'Este procedimento será removido do histórico. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await _service.excluirManejo(manejo.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final animais = _registros
        .map((registro) => registro['animal_id']?.toString())
        .whereType<String>()
        .toSet();
    final tipos = <String>{
      for (final registro in _registros) _titulo(registro),
    };
    final data = _registros.isEmpty ? null : _registros.first['data'];

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da operação')),
      body: _registros.isEmpty
          ? const Center(child: Text('Esta operação não possui registros.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.playlist_add_check_circle_outlined,
                        color: AppTheme.primaryColor,
                        size: 38,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Operação de manejo',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Data: ${_data(data)}'),
                      const SizedBox(height: 4),
                      Text('${_registros.length} registros de procedimento'),
                      Text('${animais.length} animais envolvidos'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tipos
                            .map(
                              (tipo) => Chip(
                                label: Text(tipo),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Procedimentos realizados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._registros.map((registro) {
                  final manejo = Manejo.fromMap(registro);
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        _icone(manejo.tipo),
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(_titulo(registro)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${_animal(registro)}\n${_resumo(registro)}',
                        ),
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ManejoDetailsPage(
                              manejoId: manejo.id,
                            ),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (acao) {
                          if (acao == 'editar') _editar(registro);
                          if (acao == 'excluir') _excluir(registro);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'editar',
                            child: Text('Editar procedimento'),
                          ),
                          PopupMenuItem(
                            value: 'excluir',
                            child: Text('Excluir procedimento'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
