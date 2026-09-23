import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../manejo/services/manejo_service.dart';
import '../models/animal.dart';
import '../models/animal_venda.dart';
import '../services/animal_venda_service.dart';

class AnimalSalePage extends StatefulWidget {
  final Animal animal;
  final String loteId;
  final String loteNome;

  const AnimalSalePage({
    super.key,
    required this.animal,
    required this.loteId,
    required this.loteNome,
  });

  @override
  State<AnimalSalePage> createState() => _AnimalSalePageState();
}

class _AnimalSalePageState extends State<AnimalSalePage> {
  final _formKey = GlobalKey<FormState>();
  final _valorFechadoController = TextEditingController();
  final _pesoController = TextEditingController();
  final _precoKgController = TextEditingController();
  final _compradorController = TextEditingController();
  final _observacoesController = TextEditingController();

  final AnimalVendaService _vendaService = AnimalVendaService();
  final ManejoService _manejoService = ManejoService();

  TipoVendaAnimal _tipoVenda = TipoVendaAnimal.valorFechado;
  DateTime _dataVenda = DateTime.now();
  bool _salvando = false;

  double? get _peso => _parseNumero(_pesoController.text);
  double? get _precoKg => _parseNumero(_precoKgController.text);
  double? get _valorFechado => _parseNumero(_valorFechadoController.text);

  double? get _valorTotal {
    if (_tipoVenda == TipoVendaAnimal.valorFechado) {
      return _valorFechado;
    }

    final peso = _peso;
    final preco = _precoKg;

    if (peso == null || preco == null) {
      return null;
    }

    return double.parse((peso * preco).toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    _carregarUltimoPeso();
  }

  @override
  void dispose() {
    _valorFechadoController.dispose();
    _pesoController.dispose();
    _precoKgController.dispose();
    _compradorController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  double? _parseNumero(String texto) {
    var normalizado = texto.trim();

    if (normalizado.isEmpty) {
      return null;
    }

    if (normalizado.contains(',')) {
      normalizado = normalizado.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(normalizado);
  }

  Future<void> _carregarUltimoPeso() async {
    try {
      final peso = await _manejoService.getUltimoPeso(widget.animal.id);

      if (!mounted || peso == null || peso <= 0) {
        return;
      }

      if (_pesoController.text.trim().isEmpty) {
        _pesoController.text = peso.toStringAsFixed(2).replaceAll('.', ',');
        setState(() {});
      }
    } catch (_) {
      // O peso é apenas uma sugestão. A venda continua funcionando sem ele.
    }
  }

  Future<void> _selecionarDataVenda() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _dataVenda,
      firstDate: DateTime(2000),
      lastDate: hoje,
      helpText: 'Selecione a data da venda',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (data != null && mounted) {
      setState(() {
        _dataVenda = data;
      });
    }
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) {
      return;
    }

    final valorTotal = _valorTotal;

    if (valorTotal == null || valorTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor de venda maior que zero.'),
        ),
      );
      return;
    }

    final vendaOffline = !ConnectivityService.instance.isOnline;

    setState(() {
      _salvando = true;
    });

    try {
      await _vendaService.venderAnimal(
        animalId: widget.animal.id,
        loteId: widget.loteId,
        dataVenda: _dataVenda,
        tipoVenda: _tipoVenda,
        pesoKg: _tipoVenda == TipoVendaAnimal.porKg ? _peso : null,
        precoPorKg: _tipoVenda == TipoVendaAnimal.porKg ? _precoKg : null,
        valorTotal: valorTotal,
        comprador: _compradorController.text,
        observacoes: _observacoesController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vendaOffline
                ? 'Venda salva neste aparelho e aguardando internet para sincronizar.'
                : 'Animal ${widget.animal.brinco} vendido por ${_formatarMoeda(valorTotal)}.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      String mensagem = 'Não foi possível registrar a venda.';

      if (error is PostgrestException) {
        mensagem = error.message;
      } else {
        final texto = error.toString();
        mensagem = texto.startsWith('Exception: ')
            ? texto.substring(11)
            : texto;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), duration: const Duration(seconds: 4)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  String _formatarMoeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final valorTotal = _valorTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vender animal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      color: AppTheme.primaryColor,
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.animal.nome?.trim().isNotEmpty == true
                                ? widget.animal.nome!.trim()
                                : 'Animal ${widget.animal.brinco}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Brinco ${widget.animal.brinco} • ${widget.loteNome}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Data da venda',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _salvando ? null : _selecionarDataVenda,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(_formatarData(_dataVenda)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Como o animal foi vendido?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TipoVendaAnimal>(
                segments: const [
                  ButtonSegment<TipoVendaAnimal>(
                    value: TipoVendaAnimal.valorFechado,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Valor fechado'),
                  ),
                  ButtonSegment<TipoVendaAnimal>(
                    value: TipoVendaAnimal.porKg,
                    icon: Icon(Icons.scale_outlined),
                    label: Text('Por kg'),
                  ),
                ],
                selected: {_tipoVenda},
                onSelectionChanged: _salvando
                    ? null
                    : (selection) {
                        setState(() {
                          _tipoVenda = selection.first;
                        });
                      },
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return AppTheme.textColor;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.primaryColor;
                    }
                    return Colors.white;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              if (_tipoVenda == TipoVendaAnimal.valorFechado)
                TextFormField(
                  controller: _valorFechadoController,
                  readOnly: _salvando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Valor total da venda *',
                    hintText: 'Ex.: 1.500,00',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    final numero = _parseNumero(value ?? '');
                    if (numero == null || numero <= 0) {
                      return 'Informe um valor maior que zero.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                )
              else ...[
                TextFormField(
                  controller: _pesoController,
                  readOnly: _salvando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Peso na venda (kg) *',
                    hintText: 'Ex.: 40',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                    suffixText: 'kg',
                  ),
                  validator: (value) {
                    final numero = _parseNumero(value ?? '');
                    if (numero == null || numero <= 0) {
                      return 'Informe um peso maior que zero.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _precoKgController,
                  readOnly: _salvando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Preço por kg *',
                    hintText: 'Ex.: 10,00',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    final numero = _parseNumero(value ?? '');
                    if (numero == null || numero <= 0) {
                      return 'Informe um preço por kg maior que zero.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E5DC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calculate_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Total da venda',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),
                      Text(
                        valorTotal == null
                            ? 'Informe peso e preço'
                            : _formatarMoeda(valorTotal),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _compradorController,
                readOnly: _salvando,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Comprador',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacoesController,
                readOnly: _salvando,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  hintText: 'Opcional',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 58),
                    child: Icon(Icons.notes_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Ao confirmar, o animal será marcado como vendido, permanecerá no histórico e uma receita será criada automaticamente no financeiro deste lote.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sell_outlined),
                  label: Text(
                    _salvando ? 'Registrando venda...' : 'Confirmar venda',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.6,
                    ),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
