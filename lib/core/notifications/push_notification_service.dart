import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  SupabaseClient get _client => SupabaseService.client;
  bool _iniciado = false;

  Future<void> iniciar() async {
    if (_iniciado) return;

    try {
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _salvarToken(token);
      }

      messaging.onTokenRefresh.listen((novoToken) async {
        await _salvarToken(novoToken);
      });

      _iniciado = true;
    } catch (e) {
      // O app continua funcionando sem push enquanto o Firebase ainda não
      // estiver configurado no projeto Android/iOS.
    }
  }

  Future<void> _salvarToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final fazenda = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', user.id)
        .eq('ativo', true)
        .maybeSingle();

    final fazendaId = fazenda?['id']?.toString();
    if (fazendaId == null || fazendaId.isEmpty) return;

    await _client.from('notificacao_dispositivos').upsert(
      {
        'user_id': user.id,
        'fazenda_id': fazendaId,
        'fcm_token': token,
        'plataforma': Platform.isAndroid ? 'android' : 'ios',
        'ativo': true,
        'ultimo_acesso': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'fcm_token',
    );
  }

  Future<void> desativarToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _client
          .from('notificacao_dispositivos')
          .update({'ativo': false})
          .eq('fcm_token', token);
    } catch (_) {}
  }
}
