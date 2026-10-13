import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _metodoGeracao;
  String? _verificandoPagamentoId;

  List<Map<String, dynamic>> get _catalogo =>
      List<Map<String, dynamic>>.from(_dados['catalogo'] as List? ?? const []);

  List<Map<String, dynamic>> get _pagamentos {
    final limiteData = DateTime.now().subtract(const Duration(days: 30));
    return List<Map<String, dynamic>>.from(
      _dados['pagamentos'] as List? ?? const [],
    ).where((pagamento) {
      final criado = _data(pagamento['criado_em']);
      // Oculta da tela cobranças antigas, sem apagar o histórico no banco.
      return criado == null || !criado.isBefore(limiteData);
    }).toList();
  }

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

  Future<bool> _confirmarRenovacaoSeNecessario(
    Map<String, dynamic> plano,
  ) async {
    final planoAtual = _planoAtual;
    final atribuicao = _atribuicao;
    final planoSelecionadoId = plano['id']?.toString();
    final planoAtualId = planoAtual?['id']?.toString();

    // A confirmação aparece somente ao renovar o mesmo plano pago ainda válido.
    if (planoSelecionadoId == null ||
        planoSelecionadoId != planoAtualId ||
        planoAtual == null ||
        atribuicao == null ||
        _ehGratuito(planoAtual)) {
      return true;
    }

    final validade = _data(atribuicao['validade_em']);
    if (validade == null || !validade.isAfter(DateTime.now())) {
      return true;
    }

    final diasRestantes = _diasRestantes() ?? 0;
    if (diasRestantes <= 0) return true;

    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.calendar_month_outlined),
        title: const Text('Você ainda tem dias disponíveis'),
        content: Text(
          'Seu plano atual ainda tem $diasRestantes '
          '${diasRestantes == 1 ? 'dia' : 'dias'} de validade. '
          'Se você renovar e o pagamento for aprovado, esses dias serão '
          'preservados e somados aos 30 dias da nova contratação. '
          'Você ficará com aproximadamente ${diasRestantes + 30} dias no total.\n\n'
          'Deseja continuar para o pagamento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    return continuar == true;
  }

  Future<void> _gerarPix(Map<String, dynamic> plano) async {
    final id = plano['id']?.toString();
    if (id == null || id.isEmpty) return;

    if (!mounted || !await _confirmarRenovacaoSeNecessario(plano)) return;

    setState(() {
      _gerandoPlanoId = id;
      _metodoGeracao = 'pix';
    });
    try {
      final resultado = await _service.gerarPix(id);
      if (!mounted) return;
      await _carregar();
      if (!mounted) return;
      await _mostrarPixGerado(resultado);
    } catch (error) {
      if (mounted) {
        _mensagem(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _gerandoPlanoId = null;
          _metodoGeracao = null;
        });
      }
    }
  }

  Future<void> _mostrarPixGerado(Map<String, dynamic> pagamento) async {
    final qrBase64 = pagamento['qr_code_base64']?.toString();
    final codigoPix = pagamento['qr_code']?.toString();
    final ticketUrl = pagamento['ticket_url']?.toString() ?? '';
    final pagamentoId = pagamento['pagamento_id']?.toString() ?? '';
    final nomePlano = pagamento['plano_nome']?.toString() ?? 'Plano';
    final valor = _dinheiro(pagamento['valor']);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pix pronto para pagar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Plano: $nomePlano',
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (qrBase64 != null && qrBase64.isNotEmpty) ...[
                const Text('Abra o aplicativo do seu banco e escaneie o QR Code.'),
                const SizedBox(height: 10),
                _imagemQr(qrBase64),
              ],
              if (codigoPix != null && codigoPix.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ou use o Pix copia e cola:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(codigoPix),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: codigoPix));
                      if (mounted) _mensagem('Código Pix copiado.');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar código Pix'),
                  ),
                ),
              ],
              if ((qrBase64 == null || qrBase64.isEmpty) &&
                  (codigoPix == null || codigoPix.isEmpty))
                const Text(
                  'O Mercado Pago não retornou o QR Code. Você pode tentar abrir a cobrança pelo link abaixo.',
                  textAlign: TextAlign.center,
                ),
              if (ticketUrl.startsWith('https://')) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _abrirCheckoutExistente(ticketUrl);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir cobrança'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            onPressed: pagamentoId.isEmpty
                ? null
                : () async {
                    Navigator.of(dialogContext).pop();
                    await _verificarPagamento({'id': pagamentoId});
                  },
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Já paguei'),
          ),
        ],
      ),
    );
  }

  Future<void> _gerarCheckoutCartao(Map<String, dynamic> plano) async {
    final id = plano['id']?.toString();
    if (id == null || id.isEmpty) return;

    if (!mounted || !await _confirmarRenovacaoSeNecessario(plano)) return;

    setState(() {
      _gerandoPlanoId = id;
      _metodoGeracao = 'cartao_credito';
    });
    try {
      final resultado = await _service.gerarCheckoutCartao(id);
      final checkoutUrl = resultado['checkout_url']?.toString() ?? '';
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw Exception('O Mercado Pago não retornou um link seguro de pagamento.');
      }

      await _carregar();
      if (!mounted) return;

      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu) {
        _mensagem('Não foi possível abrir o checkout. Tente novamente.');
        return;
      }
      await _mostrarStatusCartao({
        'id': resultado['pagamento_id']?.toString() ?? '',
        'nome': resultado['plano_nome']?.toString() ?? 'Plano',
        'valor': resultado['valor'],
        'status': resultado['status']?.toString() ?? 'pendente',
        'checkout_url': checkoutUrl,
      });
    } catch (error) {
      if (mounted) {
        _mensagem(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _gerandoPlanoId = null;
          _metodoGeracao = null;
        });
      }
    }
  }

  Future<void> _mostrarStatusCartao(Map<String, dynamic> pagamento) async {
    final pagamentoId = pagamento['id']?.toString() ?? '';
    final nomePlano = pagamento['nome']?.toString() ?? 'Plano';
    final valor = _dinheiro(pagamento['valor']);
    final checkoutUrl = pagamento['checkout_url']?.toString() ?? '';
    var status = pagamento['status']?.toString() ?? 'pendente';
    var mensagem = 'Finalize o pagamento no Mercado Pago. Depois, toque em verificar para confirmar a ativação do seu plano.';
    var verificando = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: status == 'aprovado',
      builder: (dialogContext) => StatefulBuilder(
        builder: (contextoDialogo, atualizarDialogo) {
          final aprovado = status == 'aprovado';
          final recusado = status == 'rejeitado' || status == 'cancelado';
          return AlertDialog(
            icon: Icon(
              aprovado
                  ? Icons.check_circle_outline
                  : recusado
                      ? Icons.error_outline
                      : Icons.hourglass_top_rounded,
              size: 42,
              color: aprovado
                  ? Colors.green
                  : recusado
                      ? Theme.of(context).colorScheme.error
                      : Colors.orange,
            ),
            title: Text(
              aprovado
                  ? 'Pagamento aprovado!'
                  : recusado
                      ? 'Pagamento não aprovado'
                      : 'Aguardando confirmação',
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nomePlano,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    aprovado
                        ? 'O Mercado Pago confirmou o pagamento e seu plano foi ativado. Você já pode continuar usando o OviGestão.'
                        : recusado
                            ? mensagem
                            : mensagem,
                    textAlign: TextAlign.center,
                  ),
                  if (verificando) ...[
                    const SizedBox(height: 14),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
            actions: [
              if (!aprovado && !recusado && checkoutUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: verificando
                      ? null
                      : () async {
                          await _abrirCheckoutExistente(checkoutUrl);
                        },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Continuar pagamento'),
                ),
              if (!aprovado && !recusado)
                FilledButton.icon(
                  onPressed: verificando || pagamentoId.isEmpty
                      ? null
                      : () async {
                          atualizarDialogo(() {
                            verificando = true;
                            mensagem = 'Consultando o Mercado Pago...';
                          });
                          try {
                            final resultado =
                                await _service.verificarPagamento(pagamentoId);
                            if (!mounted) return;
                            final novoStatus =
                                resultado['status']?.toString() ?? 'pendente';
                            await _carregar();
                            if (!mounted) return;
                            atualizarDialogo(() {
                              status = novoStatus;
                              mensagem = resultado['mensagem']?.toString() ??
                                  'O pagamento ainda não foi confirmado. Tente novamente em alguns instantes.';
                              verificando = false;
                            });
                          } catch (error) {
                            if (!mounted) return;
                            atualizarDialogo(() {
                              mensagem = error
                                  .toString()
                                  .replaceFirst('Exception: ', '');
                              verificando = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(
                    verificando ? 'Verificando...' : 'Verificar pagamento',
                  ),
                ),
              if (aprovado || recusado)
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Voltar ao Meu Plano'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _abrirCheckoutExistente(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _mensagem('O link de pagamento não é válido.');
      return;
    }
    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abriu && mounted) {
      _mensagem('Não foi possível abrir o checkout do Mercado Pago.');
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
      '${data.month.toString().padLeft(2, "0")}/${data.year}';

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
          final gerandoPix = gerando && _metodoGeracao == 'pix';
          final gerandoCartao = gerando && _metodoGeracao == 'cartao_credito';
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
                      icon: gerandoPix
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_2),
                      label: Text(gerandoPix ? 'Gerando Pix...' : atual ? 'Renovar com Pix' : 'Contratar com Pix'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _gerandoPlanoId != null ? null : () => _gerarCheckoutCartao(plano),
                      icon: gerandoCartao
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.credit_card_outlined),
                      label: Text(gerandoCartao ? 'Preparando checkout...' : 'Contratar com cartão de crédito'),
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

  Future<void> _limparHistoricoPagamentos() async {
    final tipo = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cleaning_services_outlined),
        title: const Text('Limpar histórico de pagamentos'),
        content: const Text(
          'Você pode ocultar somente cobranças pendentes ou todo o histórico. '
          'Os registros ficam guardados com segurança no sistema e isso não cancela cobranças nem altera planos já ativados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop('pendentes'),
            child: const Text('Só pendentes'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('todos'),
            child: const Text('Todo o histórico'),
          ),
        ],
      ),
    );
    if (tipo == null || !mounted) return;

    if (tipo == 'todos') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ocultar todo o histórico?'),
          content: const Text(
            'Todos os pagamentos deixarão de aparecer nesta tela, inclusive os aprovados. '
            'Isso não apaga os registros financeiros do sistema nem cancela pagamentos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    try {
      final quantidade = await _service.limparHistorico(
        somentePendentes: tipo == 'pendentes',
      );
      if (!mounted) return;
      await _carregar();
      if (!mounted) return;
      _mensagem(
        quantidade == 0
            ? 'Não havia pagamentos para ocultar.'
            : '$quantidade ${quantidade == 1 ? 'pagamento ocultado' : 'pagamentos ocultados'} do histórico.',
      );
    } catch (error) {
      if (mounted) {
        _mensagem(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }
  Widget _buildPagamentos() {
    if (_pagamentos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pagamentos recentes',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              if (_pagamentos.isNotEmpty)
                IconButton(
                  tooltip: 'Limpar histórico de pagamentos',
                  onPressed: _carregando ? null : _limparHistoricoPagamentos,
                  icon: const Icon(Icons.cleaning_services_outlined),
                ),
            ],
          ),
        ),
        ..._pagamentos.map(_buildPagamento),
      ],
    );
  }

  Widget _buildPagamento(Map<String, dynamic> pagamento) {
    final status = pagamento['status']?.toString() ?? 'pendente';
    final metodo = pagamento['metodo']?.toString() ?? 'pix';
    final checkoutUrl = pagamento['ticket_url']?.toString() ?? '';
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
                      Text('${_dinheiro(pagamento['valor'])} • ${metodo == 'cartao_credito' ? 'Cartão de crédito' : 'Pix'} • ${_statusPagamento(status)}'),
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
            if (pendente && metodo == 'cartao_credito' && checkoutUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _abrirCheckoutExistente(checkoutUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Continuar pagamento com cartão'),
                ),
              ),
            ],
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
            if (metodo != 'cartao_credito' && checkoutUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Link da cobrança'),
              SelectableText(checkoutUrl),
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
