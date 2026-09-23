import '../../../core/services/supabase_service.dart';

class AdminProducersService {
  Future<Map<String, dynamic>> listar() async => _invoke({'action': 'list'});

  Future<void> criar({
    required String nome,
    required String email,
    required String senha,
    required String planoId,
  }) async {
    await _invoke({
      'action': 'create_producer',
      'nome': nome,
      'email': email,
      'password': senha,
      'plano_id': planoId,
    });
  }

  Future<void> alterarPlano({
    required String usuarioId,
    required String planoId,
  }) async {
    await _invoke({
      'action': 'set_plan',
      'user_id': usuarioId,
      'plano_id': planoId,
    });
  }

  Future<void> definirPreco({
    required String planoId,
    required double preco,
  }) async {
    await _invoke({
      'action': 'set_plan_price',
      'plano_id': planoId,
      'preco_mensal': preco,
    });
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await SupabaseService.client.functions.invoke(
      'admin-producers',
      body: body,
    );
    final data = response.data;
    if (response.status >= 400 || data is! Map) {
      final message = data is Map
          ? data['error']?.toString()
          : 'Não foi possível concluir a operação administrativa.';
      throw Exception(message ?? 'Acesso administrativo indisponível.');
    }
    return Map<String, dynamic>.from(data);
  }
}
