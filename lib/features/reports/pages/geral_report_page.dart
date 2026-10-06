import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../services/additional_report_service.dart';

class GeralReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const GeralReportPage({super.key, required this.onBack});

  @override
  State<GeralReportPage> createState() => _GeralReportPageState();
}

class _GeralReportPageState extends State<GeralReportPage> {
  final _service = AdditionalReportService();
  bool _loading = true;
  bool _generating = false;
  String? _error;
  final Set<String> _selectedIds = <String>{};
  final List<_ReportSection> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final farm = await SupabaseService.client
          .from('fazendas')
          .select('id')
          .eq('proprietario_id', user.id)
          .eq('ativo', true)
          .maybeSingle();
      final farmId = farm?['id']?.toString();

      if (farmId == null || farmId.isEmpty) {
        throw Exception('Nenhuma fazenda ativa foi encontrada.');
      }

      final firstResults = await Future.wait([
        SupabaseService.client.from('animais').select(
              'id,status,sexo,data_nascimento,origem,racas(nome)',
            ).eq('fazenda_id', farmId),
        SupabaseService.client.from('reproducoes').select(
              'id,status,data_cobertura,data_confirmacao_prenhez,data_parto',
            ).eq('fazenda_id', farmId),
        SupabaseService.client.from('manejos').select(
              'id,tipo,data,peso_kg,famacha_escore',
            ).eq('fazenda_id', farmId),
        SupabaseService.client.from('farmacia_produtos').select(
              'id,nome,categoria,estoque,estoque_minimo,validade,unidade,unidade_estoque',
            ).eq('fazenda_id', farmId).eq('ativo', true),
        SupabaseService.client.from('farmacia_lotes').select(
              'id,produto_id,quantidade_atual,validade,codigo_lote',
            ).eq('fazenda_id', farmId).gt('quantidade_atual', 0),
        SupabaseService.client.from('farmacia_alertas').select(
              'id,produto_id,tipo,aberto',
            ).eq('fazenda_id', farmId).eq('aberto', true),
        SupabaseService.client.from('financeiro_lancamentos').select(
              'id,tipo,categoria,descricao,valor,data',
            ).eq('fazenda_id', farmId),
      ]);

      final reproducoes =
          List<Map<String, dynamic>>.from(firstResults[1] as List);
      final reproducaoIds =
          reproducoes.map((e) => e['id'].toString()).toList();

      final nascimentoFuture = reproducaoIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : SupabaseService.client.from('reproducao_nascimentos').select(
              'id,reproducao_id,sexo,data_nascimento',
            ).inFilter('reproducao_id', reproducaoIds);
      final coberturaFuture = reproducaoIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : SupabaseService.client.from('reproducao_coberturas').select(
              'id,reproducao_id,carneiro_id,data_cobertura',
            ).inFilter('reproducao_id', reproducaoIds);

      final reproductionDetails =
          await Future.wait([nascimentoFuture, coberturaFuture]);

      _buildSections(
        animais: List<Map<String, dynamic>>.from(firstResults[0] as List),
        reproducoes: reproducoes,
        nascimentos:
            List<Map<String, dynamic>>.from(reproductionDetails[0] as List),
        coberturas:
            List<Map<String, dynamic>>.from(reproductionDetails[1] as List),
        manejos: List<Map<String, dynamic>>.from(firstResults[2] as List),
        produtos: List<Map<String, dynamic>>.from(firstResults[3] as List),
        lotes: List<Map<String, dynamic>>.from(firstResults[4] as List),
        alertas: List<Map<String, dynamic>>.from(firstResults[5] as List),
        financeiro: List<Map<String, dynamic>>.from(firstResults[6] as List),
      );

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _buildSections({
    required List<Map<String, dynamic>> animais,
    required List<Map<String, dynamic>> reproducoes,
    required List<Map<String, dynamic>> nascimentos,
    required List<Map<String, dynamic>> coberturas,
    required List<Map<String, dynamic>> manejos,
    required List<Map<String, dynamic>> produtos,
    required List<Map<String, dynamic>> lotes,
    required List<Map<String, dynamic>> alertas,
    required List<Map<String, dynamic>> financeiro,
  }) {
    final hoje = DateTime.now();
    final dia = DateTime(hoje.year, hoje.month, hoje.day);

    final ativos = animais.where((e) => e['status'] == 'ativo').toList();
    final femeas = ativos.where((e) => _sexo(e['sexo']) == 'femea').length;
    final machos = ativos.where((e) => _sexo(e['sexo']) == 'macho').length;
    final vendidos = animais.where((e) => e['status'] == 'vendido').length;
    final mortos = animais.where((e) => e['status'] == 'morto').length;
    final descartados = animais.where((e) => e['status'] == 'descartado').length;

    final cordeiros = ativos.where((e) {
      final nascimento = DateTime.tryParse(e['data_nascimento']?.toString() ?? '');
      return nascimento != null && hoje.difference(nascimento).inDays < 365;
    }).length;

    final racas = <String, int>{};
    for (final animal in ativos) {
      final rel = animal['racas'];
      final nome = rel is Map ? rel['nome']?.toString().trim() : null;
      final raca = nome == null || nome.isEmpty ? 'Não informada' : nome;
      racas[raca] = (racas[raca] ?? 0) + 1;
    }

    final reproducoesPrenhes =
        reproducoes.where((e) => e['status'] == 'prenhe').length;
    final naoPrenhes =
        reproducoes.where((e) => e['status'] == 'nao_prenhe').length;
    final partos =
        reproducoes.where((e) => e['status'] == 'parto_realizado').length;
    final abortos = reproducoes.where((e) => e['status'] == 'abortou').length;
    final cobertas = reproducoes.where((e) => e['status'] == 'coberta').length;
    final planejadas =
        reproducoes.where((e) => e['status'] == 'planejada').length;
    final basePrenhez = reproducoesPrenhes + naoPrenhes + partos + abortos;
    final taxaPrenhez =
        basePrenhez == 0 ? 0.0 : (reproducoesPrenhes + partos) * 100 / basePrenhez;

    final nascFemeas =
        nascimentos.where((e) => _sexo(e['sexo']) == 'femea').length;
    final nascMachos =
        nascimentos.where((e) => _sexo(e['sexo']) == 'macho').length;

    final tiposManejo = <String, int>{};
    final pesos = <double>[];
    for (final manejo in manejos) {
      final tipo = manejo['tipo']?.toString() ?? 'outro';
      tiposManejo[tipo] = (tiposManejo[tipo] ?? 0) + 1;
      if (tipo == 'pesagem' && manejo['peso_kg'] != null) {
        final peso = _number(manejo['peso_kg']);
        if (peso > 0) pesos.add(peso);
      }
    }
    final pesoMedio =
        pesos.isEmpty ? null : pesos.reduce((a, b) => a + b) / pesos.length;

    final estoqueBaixo = produtos
        .where((e) => _number(e['estoque']) <= _number(e['estoque_minimo']))
        .length;

    final lotesVencidos = lotes.where((e) {
      final validade = DateTime.tryParse(e['validade']?.toString() ?? '');
      return validade != null && validade.isBefore(dia);
    }).length;

    final lotesVencendo = lotes.where((e) {
      final validade = DateTime.tryParse(e['validade']?.toString() ?? '');
      if (validade == null || validade.isBefore(dia)) return false;
      return !validade.isAfter(dia.add(const Duration(days: 30)));
    }).length;

    final alertasEstoque =
        alertas.where((e) => e['tipo'] == 'estoque_baixo').length;
    final alertasValidade =
        alertas.where((e) => e['tipo'] == 'validade_proxima').length;
    final alertasVencidos =
        alertas.where((e) => e['tipo'] == 'produto_vencido').length;

    final receitas = financeiro
        .where((e) => e['tipo'] == 'receita')
        .fold<double>(0, (s, e) => s + _number(e['valor']));
    final despesas = financeiro
        .where((e) => e['tipo'] == 'despesa')
        .fold<double>(0, (s, e) => s + _number(e['valor']));
    final saldo = receitas - despesas;

    final ultimos30 = financeiro.where((e) {
      final data = DateTime.tryParse(e['data']?.toString() ?? '');
      return data != null && !data.isBefore(dia.subtract(const Duration(days: 30)));
    }).toList();
    final receitas30 = ultimos30
        .where((e) => e['tipo'] == 'receita')
        .fold<double>(0, (s, e) => s + _number(e['valor']));
    final despesas30 = ultimos30
        .where((e) => e['tipo'] == 'despesa')
        .fold<double>(0, (s, e) => s + _number(e['valor']));

    final despesasCategoria = <String, double>{};
    for (final item in financeiro.where((e) => e['tipo'] == 'despesa')) {
      final categoria = item['categoria']?.toString().trim();
      final nome = categoria == null || categoria.isEmpty ? 'Sem categoria' : categoria;
      despesasCategoria[nome] =
          (despesasCategoria[nome] ?? 0) + _number(item['valor']);
    }
    final principais = despesasCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String racaPredominante = 'Nenhuma';
    if (racas.isNotEmpty) {
      final ordenadas = racas.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      racaPredominante = ordenadas.first.key;
    }

    _sections
      ..clear()
      ..addAll([
        _ReportSection(
          id: 'resumo',
          title: 'Resumo executivo',
          icon: 'assets/images/icon_relatorios.png',
          items: [
            _Metric('Rebanho ativo', ativos.length.toString() + ' animais'),
            _Metric('Prenhes', reproducoesPrenhes.toString()),
            _Metric('Nascimentos', nascimentos.length.toString()),
            _Metric('Estoque baixo', estoqueBaixo.toString() + ' produto(s)'),
            _Metric('Saldo histórico', 'R\$ ' + _money(saldo)),
            _Metric('Alertas abertos', alertas.length.toString()),
          ],
        ),
        _ReportSection(
          id: 'rebanho',
          title: 'Rebanho',
          icon: 'assets/images/icon_animais.png',
          items: [
            _Metric('Total cadastrado', animais.length.toString()),
            _Metric('Ativos', ativos.length.toString()),
            _Metric('Fêmeas ativas', femeas.toString()),
            _Metric('Machos ativos', machos.toString()),
            _Metric('Cordeiros (< 12 meses)', cordeiros.toString()),
            _Metric('Vendidos', vendidos.toString()),
            _Metric('Mortos', mortos.toString()),
            _Metric('Descartados', descartados.toString()),
            _Metric('Raça predominante', racaPredominante),
            _Metric('Raças registradas', racas.length.toString()),
            _Metric('Distribuição por raça', _formatRacas(racas)),
          ],
        ),
        _ReportSection(
          id: 'reproducao',
          title: 'Reprodução',
          icon: 'assets/images/icon_reproducao.png',
          items: [
            _Metric('Reproduções', reproducoes.length.toString()),
            _Metric('Coberturas', coberturas.length.toString()),
            _Metric('Planejadas', planejadas.toString()),
            _Metric('Cobertas', cobertas.toString()),
            _Metric('Prenhes', reproducoesPrenhes.toString()),
            _Metric('Não prenhes', naoPrenhes.toString()),
            _Metric('Partos realizados', partos.toString()),
            _Metric('Abortos', abortos.toString()),
            _Metric('Nascimentos', nascimentos.length.toString()),
            _Metric('Nascimentos fêmeas', nascFemeas.toString()),
            _Metric('Nascimentos machos', nascMachos.toString()),
            _Metric('Taxa de prenhez', taxaPrenhez.toStringAsFixed(1) + '%'),
          ],
        ),
        _ReportSection(
          id: 'manejo',
          title: 'Manejo',
          icon: 'assets/images/icon_manejo.png',
          items: [
            _Metric('Total de registros', manejos.length.toString()),
            _Metric('Pesagens', (tiposManejo['pesagem'] ?? 0).toString()),
            _Metric('Vacinações', (tiposManejo['vacinacao'] ?? 0).toString()),
            _Metric('Vermifugações', (tiposManejo['vermifugacao'] ?? 0).toString()),
            _Metric('Tratamentos', (tiposManejo['tratamento'] ?? 0).toString()),
            _Metric('FAMACHA', (tiposManejo['famacha'] ?? 0).toString()),
            _Metric('Dentição', (tiposManejo['denticao'] ?? 0).toString()),
            _Metric('Tosquias', (tiposManejo['tosquia'] ?? 0).toString()),
            _Metric('Outros', (tiposManejo['outro'] ?? 0).toString()),
            if (pesoMedio != null)
              _Metric('Peso médio registrado', pesoMedio.toStringAsFixed(1) + ' kg'),
          ],
        ),
        _ReportSection(
          id: 'farmacia',
          title: 'Farmácia',
          icon: 'assets/images/icon_farmacia.png',
          items: [
            _Metric('Produtos ativos', produtos.length.toString()),
            _Metric('Estoque baixo', estoqueBaixo.toString()),
            _Metric('Lotes com estoque', lotes.length.toString()),
            _Metric('Lotes vencidos', lotesVencidos.toString()),
            _Metric('Vencendo em até 30 dias', lotesVencendo.toString()),
            _Metric('Alertas de estoque', alertasEstoque.toString()),
            _Metric('Alertas de validade', alertasValidade.toString()),
            _Metric('Alertas de vencimento', alertasVencidos.toString()),
          ],
        ),
        _ReportSection(
          id: 'financeiro',
          title: 'Financeiro',
          icon: 'assets/images/icon_financeiro.png',
          items: [
            _Metric('Receitas históricas', 'R\$ ' + _money(receitas)),
            _Metric('Despesas históricas', 'R\$ ' + _money(despesas)),
            _Metric('Saldo histórico', 'R\$ ' + _money(saldo)),
            _Metric('Lançamentos', financeiro.length.toString()),
            _Metric('Receitas últimos 30 dias', 'R\$ ' + _money(receitas30)),
            _Metric('Despesas últimos 30 dias', 'R\$ ' + _money(despesas30)),
            if (principais.isNotEmpty)
              _Metric('Principais despesas', _formatDespesas(principais.take(5).toList())),
          ],
        ),
        _ReportSection(
          id: 'alertas',
          title: 'Pontos de atenção',
          icon: 'assets/images/icon_relatorios.png',
          items: [
            _Metric('Alertas abertos', alertas.length.toString()),
            _Metric('Produtos em estoque baixo', estoqueBaixo.toString()),
            _Metric('Lotes vencidos', lotesVencidos.toString()),
            _Metric('Lotes vencendo em 30 dias', lotesVencendo.toString()),
            _Metric(
              'Situação',
              alertas.isEmpty ? 'Nenhum alerta aberto' : 'Existem itens para revisão',
            ),
          ],
        ),
      ]);
  }

  String _formatRacas(Map<String, int> racas) {
    if (racas.isEmpty) return 'Nenhuma raça informada';
    final entries = racas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => e.key + ': ' + e.value.toString()).join(' | ');
  }

  String _formatDespesas(List<MapEntry<String, double>> entries) {
    return entries.map((e) => e.key + ': R\$ ' + _money(e.value)).join(' | ');
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() => _selectedIds.addAll(_sections.map((e) => e.id)));
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(assetPath: 'assets/images/icon_relatorios.png', size: 26),
            SizedBox(width: 8),
            Text('Relatório geral'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading || _generating || _selectedIds.isEmpty
                ? null
                : _chooseFormat,
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    _heroCard(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _selectAll,
                          icon: const Icon(Icons.select_all_rounded),
                          label: const Text('Selecionar todos'),
                        ),
                        TextButton(
                          onPressed:
                              _selectedIds.isEmpty ? null : _clearSelection,
                          child: const Text('Limpar'),
                        ),
                        const Spacer(),
                        Text(
                          _selectedIds.length.toString() +
                              '/' +
                              _sections.length.toString(),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    ..._sections.map(_sectionCard),
                  ],
                ),
    );
  }

  Widget _heroCard() {
    final resumo = _sections.isEmpty ? null : _sections.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF367C2B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Raio-X da Fazenda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Visão consolidada do rebanho, reprodução, manejo, farmácia e financeiro.',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
          if (resumo != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: resumo.items.map((item) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.label + ': ' + item.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard(_ReportSection section) {
    final selected = _selectedIds.contains(section.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _toggle(section.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF367C2B).withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: AppAssetIcon(assetPath: section.icon, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _toggle(section.id),
                  ),
                ],
              ),
              const Divider(height: 18),
              ...section.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          item.value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseFormat() async {
    if (_selectedIds.isEmpty || _generating) return;
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Escolha o formato')),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Excel'),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
          ],
        ),
      ),
    );
    if (format != null && mounted) await _generate(format);
  }

  Future<void> _generate(String format) async {
    setState(() => _generating = true);

    try {
      final sections = <String, List<List<String>>>{};

      for (final section in _sections) {
        if (!_selectedIds.contains(section.id)) continue;
        sections[section.title] = section.items
            .map((item) => [item.label, item.value])
            .toList();
      }

      final bytes = format == 'pdf'
          ? await _service.gerarPdfSecoes(
              title: 'Relatório geral da Fazenda',
              subtitle: 'Visão consolidada dos dados registrados',
              sections: sections,
            )
          : await _service.gerarExcelAbas(
              title: 'Relatório geral da Fazenda',
              subtitle: 'Visão consolidada dos dados registrados',
              sections: sections,
            );

      final mime = format == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mime)],
          fileNameOverrides: [
            format == 'pdf'
                ? 'ovigestao_relatorio_geral.pdf'
                : 'ovigestao_relatorio_geral.xlsx',
          ],
          title: 'Relatório geral da Fazenda',
          subject: 'Relatório geral - Fazenda Baixinha',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (format == 'pdf' ? 'PDF' : 'Excel') +
                  ' gerado com ' +
                  sections.length.toString() +
                  ' seção(ões).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível gerar o relatório: ' +
                  e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );

  String _sexo(dynamic value) =>
      value?.toString().toLowerCase() == 'macho' ? 'macho' : 'femea';

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  String _money(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
}

class _ReportSection {
  final String id;
  final String title;
  final String icon;
  final List<_Metric> items;

  const _ReportSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
  });
}

class _Metric {
  final String label;
  final String value;

  const _Metric(this.label, this.value);
}
