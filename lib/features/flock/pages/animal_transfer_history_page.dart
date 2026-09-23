import 'package:flutter/material.dart';

import '../../../core/widgets/contextual_help.dart';
import '../../../core/theme/app_theme.dart';
import '../services/animal_transfer_service.dart';

class AnimalTransferHistoryPage extends StatefulWidget {
  final String animalId;
  final String brinco;

  const AnimalTransferHistoryPage({
    super.key,
    required this.animalId,
    required this.brinco,
  });

  @override
  State<AnimalTransferHistoryPage> createState() =>
      _AnimalTransferHistoryPageState();
}

class _AnimalTransferHistoryPageState extends State<AnimalTransferHistoryPage> {
  final AnimalTransferService _transferService = AnimalTransferService();

  List<Map<String, dynamic>> _transferencias = [];

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    setState(() {
      _carregando = true;
    });

    try {
      final transferencias = await _transferService.getHistoricoTransferencias(
        animalId: widget.animalId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _transferencias = transferencias;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
      });

      _mostrarErro(e);
    }
  }

  void _mostrarErro(Object erro) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Não foi possível carregar o histórico.\n$erro'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String _nomeRebanho(dynamic valor, String valorPadrao) {
    if (valor is Map) {
      final nome = valor['nome']?.toString().trim();

      if (nome != null && nome.isNotEmpty) {
        return nome;
      }
    }

    return valorPadrao;
  }

  String _dataHoraTexto(dynamic valor) {
    if (valor == null) {
      return 'Data não informada';
    }

    final data = DateTime.tryParse(valor.toString());

    if (data == null) {
      return 'Data não informada';
    }

    final dataLocal = data.toLocal();

    final dia = dataLocal.day.toString().padLeft(2, '0');
    final mes = dataLocal.month.toString().padLeft(2, '0');
    final ano = dataLocal.year.toString();

    final hora = dataLocal.hour.toString().padLeft(2, '0');
    final minuto = dataLocal.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  String? _observacao(dynamic valor) {
    if (valor == null) {
      return null;
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return texto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBar(
        title: const Text(
          'Histórico de transferências',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textColor,
        elevation: 0,
        actions: const [
          ContextualHelpButton(
            title: 'Histórico de transferências',
            introduction:
                'Consulte as mudanças de lote registradas para este animal.',
            topics: [
              HelpTopic(
                title: 'Origem e destino',
                description: 'Cada item mostra de onde o animal saiu e para qual lote foi transferido.',
              ),
              HelpTopic(
                title: 'Data e observações',
                description: 'Use os detalhes registrados para entender quando e por que a movimentação aconteceu.',
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_transferencias.isEmpty) {
      return _buildSemTransferencias();
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _carregarHistorico,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _buildAnimalHeader(),
          const SizedBox(height: 20),
          _buildResumo(),
          const SizedBox(height: 20),
          ..._transferencias.asMap().entries.map(
            (entrada) => _buildTransferenciaCard(entrada.value, entrada.key),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: AppTheme.primaryColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Animal',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  'Brinco ${widget.brinco}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumo() {
    final quantidade = _transferencias.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quantidade == 1
                  ? '1 transferência registrada'
                  : '$quantidade transferências registradas',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferenciaCard(
    Map<String, dynamic> transferencia,
    int indice,
  ) {
    final origem = _nomeRebanho(
      transferencia['rebanho_origem'],
      'Lote de origem',
    );

    final destino = _nomeRebanho(
      transferencia['rebanho_destino'],
      'Lote de destino',
    );

    final data = _dataHoraTexto(transferencia['data_transferencia']);

    final observacao = _observacao(transferencia['observacao']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transferência ${_numeroTransferencia(indice)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildRebanhoLinha(
            titulo: 'Origem',
            nome: origem,
            icon: Icons.logout_rounded,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 5, bottom: 5),
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: Colors.black38,
            ),
          ),
          _buildRebanhoLinha(
            titulo: 'Destino',
            nome: destino,
            icon: Icons.login_rounded,
          ),
          if (observacao != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_outlined,
                    size: 20,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Observação',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          observacao,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRebanhoLinha({
    required String titulo,
    required String nome,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: Colors.black54),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                nome,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _numeroTransferencia(int indice) {
    final numero = _transferencias.length - indice;

    return numero.toString().padLeft(2, '0');
  }

  Widget _buildSemTransferencias() {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _carregarHistorico,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.swap_horiz_rounded,
            size: 68,
            color: AppTheme.primaryColor.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 18),
          const Text(
            'Nenhuma transferência registrada',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'O animal ${widget.brinco} ainda não possui '
            'transferências entre lotes.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Quando este animal for transferido, '
            'o histórico aparecerá aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
