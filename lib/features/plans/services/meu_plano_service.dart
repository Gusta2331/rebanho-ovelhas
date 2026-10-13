import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class MeuPlanoService {
  SupabaseClient get _client => SupabaseService.client;

  Future<Map<String, dynamic>> carregar() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw Exception('Faça login para consultar seu plano.');

    final fazenda = await _client
        .from('fazendas')
        .select('id,nome')
        .eq('proprietario_id', usuario.id)
        .eq('ativo', true)
        .maybeSingle();

    Map<String, dynamic>? atribuicao;
    var animaisAtivos = 0;

    if (fazenda != null) {
      final resultado = await _client
          .from('planos_fazenda')
          .select(
            'plano_id,status,validade_em,atualizado_em,'
            'planos_produtor(id,nome,limite_animais,preco_mensal)',
          )
          .eq('fazenda_id', fazenda['id'])
          .maybeSingle();
      if (resultado != null) {
        atribuicao = Map<String, dynamic>.from(resultado);
      }

      final contagem = await _client
          .from('animais')
          .select('id')
          .eq('fazenda_id', fazenda['id'])
          .eq('status', 'ativo')
          .count(CountOption.exact);
      animaisAtivos = contagem.count;
    } else {
      final pendente = await _client
          .from('planos_pendentes_produtor')
          .select(
            'plano_id,validade_em,atualizado_em,'
            'planos_produtor(id,nome,limite_animais,preco_mensal)',
          )
          .eq('usuario_id', usuario.id)
          .maybeSingle();
      if (pendente != null) {
        atribuicao = Map<String, dynamic>.from(pendente);
      }
    }

    final catalogo = await _client
        .from('planos_produtor')
        .select('id,nome,limite_animais,preco_mensal,ativo')
        .eq('ativo', true)
        .order('limite_animais', ascending: true, nullsFirst: false);

    final pagamentos = await _client
        .from('pagamentos_planos')
        .select(
          'id,plano_id,valor,status,metodo,qr_code,qr_code_base64,ticket_url,'
          'expira_em,criado_em,planos_produtor(nome)',
        )
        .eq('usuario_id', usuario.id)
        .order('criado_em', ascending: false)
        .limit(10);

    return {
      'fazenda': fazenda == null ? null : Map<String, dynamic>.from(fazenda),
      'atribuicao': atribuicao,
      'animais_ativos': animaisAtivos,
      'catalogo': List<Map<String, dynamic>>.from(catalogo),
      'pagamentos': List<Map<String, dynamic>>.from(pagamentos),
    };
  }

  Future<Map<String, dynamic>?> carregarResumoVencimento() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return null;

    final fazenda = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', usuario.id)
        .eq('ativo', true)
        .maybeSingle();

    Map<String, dynamic>? atribuicao;
    if (fazenda != null) {
      final resultado = await _client
          .from('planos_fazenda')
          .select('status,validade_em,planos_produtor(nome,preco_mensal)')
          .eq('fazenda_id', fazenda['id'])
          .maybeSingle();
      if (resultado != null) {
        atribuicao = Map<String, dynamic>.from(resultado);
      }
    } else {
      final resultado = await _client
          .from('planos_pendentes_produtor')
          .select('validade_em,planos_produtor(nome,preco_mensal)')
          .eq('usuario_id', usuario.id)
          .maybeSingle();
      if (resultado != null) {
        atribuicao = Map<String, dynamic>.from(resultado);
      }
    }

    if (atribuicao == null) return null;
    final planoRaw = atribuicao['planos_produtor'];
    final plano = planoRaw is Map
        ? Map<String, dynamic>.from(planoRaw)
        : <String, dynamic>{};
    final nome = plano['nome']?.toString() ?? 'Plano atual';
    final preco = num.tryParse(plano['preco_mensal']?.toString() ?? '');
    final gratuito = (preco != null && preco <= 0) ||
        nome.toLowerCase().contains('grátis') ||
        nome.toLowerCase().contains('gratuito') ||
        nome.toLowerCase().contains('free');
    final validadeRaw = atribuicao['validade_em']?.toString();
    final validade = validadeRaw == null ? null : DateTime.tryParse(validadeRaw)?.toLocal();
    final diasRestantes = validade == null
        ? null
        : (validade.difference(DateTime.now()).inSeconds / 86400).ceil().clamp(0, 36500);

    return {
      'nome': nome,
      'gratuito': gratuito,
      'validade_em': validadeRaw,
      'dias_restantes': diasRestantes,
      'vencido': validade != null && !validade.isAfter(DateTime.now()),
    };
  }
  Future<Map<String, dynamic>> gerarPix(String planoId) async {
    final response = await _client.functions.invoke(
      'create-plan-pix',
      body: {'plano_id': planoId},
    );
    final data = response.data;
    if (response.status >= 400 || data is! Map) {
      final message = data is Map
          ? data['error']?.toString()
          : 'Não foi possível gerar a cobrança Pix.';
      throw Exception(message ?? 'Não foi possível gerar a cobrança Pix.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> gerarCheckoutCartao(String planoId) async {
    final response = await _client.functions.invoke(
      'create-plan-card-checkout',
      body: {'plano_id': planoId},
    );
    final data = response.data;
    if (response.status >= 400 || data is! Map) {
      final message = data is Map
          ? data['error']?.toString()
          : 'Não foi possível abrir o checkout de cartão.';
      throw Exception(message ?? 'Não foi possível abrir o checkout de cartão.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> verificarPagamento(String pagamentoId) async {
    final response = await _client.functions.invoke(
      'verify-plan-payment',
      body: {'pagamento_id': pagamentoId},
    );
    final data = response.data;
    if (response.status >= 400 || data is! Map) {
      final message = data is Map
          ? data['error']?.toString()
          : 'Não foi possível verificar o pagamento.';
      throw Exception(message ?? 'Não foi possível verificar o pagamento.');
    }
    return Map<String, dynamic>.from(data);
  }
}
