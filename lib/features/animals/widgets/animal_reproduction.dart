import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../reproduction/models/reproducao.dart';
import '../../reproduction/services/reproducao_service.dart';

class AnimalReproduction extends StatefulWidget {
  final String animalId;
  final String brinco;
  final bool ehFemea;

  const AnimalReproduction({
    super.key,
    required this.animalId,
    required this.brinco,
    required this.ehFemea,
  });

  @override
  State<AnimalReproduction> createState() => _AnimalReproductionState();
}

class _AnimalReproductionState extends State<AnimalReproduction> {
  final ReproducaoService _service = ReproducaoService();

  List<Reproducao> _reproducoes = [];

  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarReproducoes();
  }

  Future<void> _carregarReproducoes() async {
    try {
      final todas = await _service.getReproducoes();

      if (!mounted) {
        return;
      }

      final reproducoes = todas.where((reproducao) {
        return reproducao.maeId == widget.animalId ||
            reproducao.paiId == widget.animalId;
      }).toList();

      setState(() {
        _reproducoes = reproducoes;
        _carregando = false;
        _erro = null;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildCabecalho(), _buildConteudo()],
      ),
    );
  }

  Widget _buildCabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite_outline_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reprodução',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Histórico reprodutivo deste animal.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
            Text(
              _erro!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _carregarReproducoes,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_reproducoes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Text(
          widget.ehFemea
              ? 'Nenhuma reprodução registrada '
                    'para esta ovelha.'
              : 'Nenhuma reprodução registrada '
                    'para este carneiro.',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${_reproducoes.length}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _reproducoes.length == 1
                    ? 'reprodução registrada'
                    : 'reproduções registradas',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._reproducoes.map(_buildReproducao),
        ],
      ),
    );
  }

  Widget _buildReproducao(Reproducao reproducao) {
    final cor = _corStatus(reproducao.status);

    final ehMae = reproducao.maeId == widget.animalId;

    final outroAnimalId = ehMae ? reproducao.paiId : reproducao.maeId;

    final outroAnimalTexto = outroAnimalId == null
        ? 'Ainda não definido'
        : 'ID: ${_encurtarId(outroAnimalId)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ehMae ? 'Como mãe' : 'Como pai',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _nomeStatus(reproducao.status),
                  style: TextStyle(
                    color: cor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfo(
            Icons.calendar_today_outlined,
            'Cobertura',
            _formatarData(reproducao.dataCobertura),
          ),
          const SizedBox(height: 8),
          _buildInfo(
            Icons.event_outlined,
            'Previsão de parto',
            _formatarData(reproducao.dataPrevisaoParto),
          ),
          const SizedBox(height: 8),
          _buildInfo(
            ehMae ? Icons.male : Icons.female,
            ehMae ? 'Pai' : 'Mãe',
            outroAnimalTexto,
          ),
          if (reproducao.dataParto != null) ...[
            const SizedBox(height: 8),
            _buildInfo(
              Icons.child_friendly_outlined,
              'Parto realizado',
              _formatarData(reproducao.dataParto),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfo(IconData icone, String titulo, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 18, color: Colors.black45),
        const SizedBox(width: 9),
        Text(
          '$titulo: ',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
        ),
      ],
    );
  }

  String _encurtarId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return '${id.substring(0, 8)}...';
  }
}
