import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class SupabaseConnectionTest {
  static Future<bool> testar() async {
    try {
      await SupabaseService.client.from('fazendas').select('id').limit(1);

      return true;
    } catch (e) {
      debugPrint('Erro ao conectar com o Supabase: $e');
      return false;
    }
  }
}
