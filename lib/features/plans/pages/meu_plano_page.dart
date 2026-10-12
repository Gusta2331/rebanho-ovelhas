import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../services/meu_plano_service.dart';

class MeuPlanoPage extends StatefulWidget {
  const MeuPlanoPage({super.key});

  @override
  State<MeuPlanoPage> createState() => _MeuPlanoPageState();
}

class _MeuPlanoPageState extends State<MeuPlanoPage> {
  final MeuPlanoService _service = MeuPlanoService();

  Map<String, dynamic> _dados = {};
  bool _carregando = true;
  String? _erro;
  String? _gerandoPlanoId;
  String? _verificandoPagamentoId;

  List<Map<String, dynamic>> get _catalogo =>
      List<Map<String, dynamic>>.from(_dados['catalogo'] as List? ?? const []);

  List<Map<String, dynamic>> get _pagamentos =>
      List<Map<String, dynamic>>.from(_dados['pagamentos'] as List? ?? const []);

  Map<String, dynamic>? get _atribuicao =>
      _asMap(_dados['atribuicao']);

  Map<String, dynamic>? get _planoAtual =>
      _asMap(_atribuicao?['planos_produtor']);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      final dados = await _service.carregar();
      if (!mounted) return;
      setState(() {
        _dados = dados;
        _carregando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _erro = error.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  Future<void> _gerarPix(Map<String, dynamic> plano) async {
    final id = plano['id']?.toString();
    if (id == null || id.isEmpty) return;

    setState(() => _gerandoPlanoId = id);
    try {
      final resultado = await _service.gerarPix(id);
      if (!mounted) return;
      await _carregar();
      if (!mounted) return;
      _mensagem(
        resultado['status']?.toString() == 'aprovado'
            ? 'A cobrança foi criada. Atualize o status para confirmar a ativação.'
            : 'Pix gerado. Após pagar, toque em “Verificar pagamento”.',
      );
    } catch (error) {
      if (mounted) {
        _mensagem(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _gerandoPlanoId = null);
    }
  }

  Future<void> _verificarPagamento(Map<String, dynamic> pagamento) async {
    final id = pagamento['id']?.toString();
    if (id == null || id.isEmpty) return;

    setState(() => _verificandoPagamentoId = id);
    try {
      final resultado = await _service.verificarPagamento(id);
      if (!mounted) return;
      _mensagem(
        resultado['mensagem']?.toString() ??
            'O status do pagamento foi consultado.',
      );
      await _carregar();
    } catch (error) {
      if (mounted) {
        _mensagem(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _verificandoPagamentoId = null);
    }
  }

  void _mensagem(String texto) {
    showAppSnackBar(
      context,
      SnackBar(content: Text(texto)),
    );
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  DateTime? _data(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  String _dataFormatada(DateTime data) =>
      '${data.day.toString().padLeft(2, "0")}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';

  String _dinheiro(dynamic valor) {
    final numero = valor is num
        ? valor.toDouble()
        : double.tryParse(valor?.toString() ?? '');
    if (numero == null) return 'Preço sob consulta';
    return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  bool _ehGratuito(Map<String, dynamic> plano) {
    final preco = _numero(plano['preco_mensal']);
    return plano['id'] == 'free_10' || preco == 0;
  }

  double? _numero(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _diasRestantes() {
    final validade = _data(_atribuicao?['validade_em']);
    if (validade == null) return null;
    final dias = (validade.difference(DateTime.now()).inSeconds / 86400).ceil();
    return dias < 0 ? 0 : dias;
  }

  bool get _planoVencido {
    final validade = _data(_atribuicao?['validade_em']);
    return validade != null && !validade.isAfter(DateTime.now());
  }

  Widget _buildPlanoAtual() {
    final plano = _planoAtual;
    final atribuicao = _atribuicao;
    final fazenda = _asMap(_dados['fazenda']);
    if (plano == null || atribuicao == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Nenhum plano encontrado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                fazenda == null
                    ? 'Seu plano aparecerá aqui quando a configuração da fazenda for concluída.'
                    : 'Não encontramos uma atribuição de plano para esta fazenda. Atualize a tela ou entre em contato com o suporte.',
              ),
            ],
          ),
        ),
      );
    }

    final gratuito = _ehGratuito(plano);
    final validade = _data(atribuicao['validade_em']);
    final limite = plano['limite_animais'];
    final ativos = _dados['animais_ativos'] as int? ?? 0;
    final vencido = _planoVencido || atribuicao['status'] == 'suspenso';
    final status = vencido
        ? 'Vencido'
        : gratuito
            ? 'Plano grátis'
            : 'Ativo';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plano['nome']?.toString() ?? 'Plano atual',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(status),
                    ],
                  ),
                ),
                if (vencido)
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ResumoPlano(
                    titulo: 'Animais ativos',
                    valor: limite == null ? '$ativos' : '$ativos / $limite',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResumoPlano(
                    titulo: 'Mensalidade',
                    valor: _dinheiro(plano['preco_mensal']),
                  ),
                ),
              ],
            ),
            if (limite != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: (ativos / (limite as num)).clamp(0.0, 1.0).toDouble(),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: vencido ? Colors.orange : AppTheme.primaryColor,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (gratuito)
              const Row(
                children: [
                  Icon(Icons.all_inclusive, size: 19),
                  SizedBox(width: 8),
                  Expanded(child: Text('Plano grátis, sem vencimento de assinatura.')),
                ],
              )
            else if (validade == null)
              const Row(
                children: [
                  Icon(Icons.event_busy_outlined, size: 19),
                  SizedBox(width: 8),
                  Expanded(child: Text('A validade deste plano não foi informada.')),
                ],
              )
            else ...[
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 19),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Vencimento: ${_dataFormatada(validade)}')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(
                    vencido ? Icons.error_outline : Icons.hourglass_bottom,
                    size: 19,
                    color: vencido ? Colors.orange.shade800 : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vencido
                          ? 'Seu plano venceu. Contrate um plano para recuperar o limite correspondente.'
                          : 'Restam ${_diasRestantes() ?? 0} dia(s) de plano.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: vencido ? Colors.orange.shade800 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogo() {
    final planosPagos = _catalogo.where((plano) {
      final preco = _numero(plano['preco_mensal']);
      return !_ehGratuito(plano) && preco != null && preco > 0;
    }).toList();

    final personalizados = _catalogo.where((plano) {
      return plano['limite_animais'] == null &&
          _numero(plano['preco_mensal']) == null;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Text(
            'Planos disponíveis',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
        if (planosPagos.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Não há planos pagos disponíveis para contratação no momento.'),
            ),
          ),
        ...planosPagos.map((plano) {
          final id = plano['id'].toString();
          final limite = plano['limite_animais'];
          final gerando = _gerandoPlanoId == id;
          final atual = _planoAtual?['id']?.toString() == id;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.credit_card_outlined, color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plano['nome']?.toString() ?? 'Plano',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(limite == null ? 'Limite personalizado' : 'Até $limite animais ativos'),
                          ],
                        ),
                      ),
                      Text(
                        '${_dinheiro(plano['preco_mensal'])}/mês',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _gerandoPlanoId != null ? null : () => _gerarPix(plano),
                      icon: gerando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_2),
                      label: Text(gerando ? 'Gerando Pix...' : atual ? 'Renovar este plano' : 'Contratar com Pix'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        ...personalizados.map(
          (plano) => Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(plano['nome']?.toString() ?? 'Plano personalizado'),
              subtitle: const Text('Preço sob consulta. Este plano não pode ser cobrado pelo Pix automático.'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagamentos() {
    if (_pagamentos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(
            'Pagamentos recentes',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
        ..._pagamentos.map(_buildPagamento),
      ],
    );
  }

  Widget _buildPagamento(Map<String, dynamic> pagamento) {
    final status = pagamento['status']?.toString() ?? 'pendente';
    final nomePlano = _asMap(pagamento['planos_produtor'])?['nome']?.toString() ??
        'Plano';
    final criado = _data(pagamento['criado_em']);
    final qrBase64 = pagamento['qr_code_base64']?.toString();
    final codigoPix = pagamento['qr_code']?.toString();
    final id = pagamento['id']?.toString() ?? '';
    final verificando = _verificandoPagamentoId == id;
    final pendente = status == 'pendente' || status == 'criado';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  status == 'aprovado'
                      ? Icons.check_circle_outline
                      : pendente
                          ? Icons.pending_outlined
                          : Icons.cancel_outlined,
                  color: status == 'aprovado'
                      ? Colors.green
                      : pendente
                          ? Colors.orange
                          : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nomePlano, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text('${_dinheiro(pagamento['valor'])} • ${_statusPagamento(status)}'),
                      if (criado != null)
                        Text(
                          'Criado em ${_dataFormatada(criado)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (pendente && qrBase64 != null && qrBase64.isNotEmpty) ...[
              const SizedBox(height: 14),
              Center(child: _imagemQr(qrBase64)),
            ],
            if (pendente && codigoPix != null && codigoPix.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Pix copia e cola', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              SelectableText(codigoPix),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: codigoPix));
                    if (mounted) _mensagem('Código Pix copiado.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código Pix'),
                ),
              ),
            ],
            if (pendente) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: verificando || _verificandoPagamentoId != null
                      ? null
                      : () => _verificarPagamento(pagamento),
                  icon: verificando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(verificando ? 'Consultando Mercado Pago...' : 'Já paguei, verificar pagamento'),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'O plano só muda depois que o Mercado Pago confirmar o pagamento.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (pagamento['ticket_url'] != null &&
                pagamento['ticket_url'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Link da cobrança'),
              SelectableText(pagamento['ticket_url'].toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imagemQr(String base64) {
    try {
      final conteudo = base64.contains(',')
          ? base64.substring(base64.indexOf(',') + 1)
          : base64;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Image.memory(
          base64Decode(conteudo),
          width: 210,
          height: 210,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 210,
            height: 80,
            child: Center(child: Text('Não foi possível exibir o QR Code. Use o Pix copia e cola.')),
          ),
        ),
      );
    } catch (_) {
      return const Text('Não foi possível exibir o QR Code. Use o Pix copia e cola.');
    }
  }

  String _statusPagamento(String status) {
    switch (status) {
      case 'aprovado':
        return 'Aprovado';
      case 'rejeitado':
        return 'Rejeitado';
      case 'cancelado':
        return 'Cancelado';
      case 'erro':
        return 'Erro na cobrança';
      default:
        return 'Aguardando pagamento';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu plano'),
        actions: [
          IconButton(
            tooltip: 'Atualizar plano e pagamentos',
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _carregando && _dados.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _erro != null && _dados.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 42),
                        const SizedBox(height: 12),
                        Text(_erro!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _carregar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _buildPlanoAtual(),
                      const SizedBox(height: 12),
                      _buildCatalogo(),
                      _buildPagamentos(),
                      if (_erro != null) ...[
                        const SizedBox(height: 8),
                        Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _ResumoPlano extends StatelessWidget {
  const _ResumoPlano({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
