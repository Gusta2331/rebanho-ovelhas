import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/services/supabase_connection_test.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final conectado = await SupabaseConnectionTest.testar();

  debugPrint(
    conectado
        ? 'SUPABASE: conexão realizada com sucesso!'
        : 'SUPABASE: erro na conexão.',
  );

  runApp(const FazendaBaixinhaApp());
}
