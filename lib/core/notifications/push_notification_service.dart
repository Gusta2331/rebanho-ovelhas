import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../services/supabase_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  SupabaseClient get _client => SupabaseService.client;

  static const String _canalId = 'farmacia_alertas';
  static const String _canalNome = 'Alertas da Fazenda';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _iniciado = false;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> iniciar() async {
    if (_iniciado) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final messaging = FirebaseMessaging.instance;

      await _inicializarNotificacoesLocais();

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_mostrarNotificacaoEmPrimeiroPlano);

      final token = await messaging.getToken();

      if (token != null && token.isNotEmpty) {
        await _salvarToken(token);
      }

      await _tokenSubscription?.cancel();
      _tokenSubscription = messaging.onTokenRefresh.listen((novoToken) async {
        await _salvarToken(novoToken);
      });

      await _authSubscription?.cancel();
      _authSubscription = _client.auth.onAuthStateChange.listen((data) async {
        if (data.session == null) return;

        final novoToken = await messaging.getToken();

        if (novoToken != null && novoToken.isNotEmpty) {
          await _salvarToken(novoToken);
        }
      });

      _iniciado = true;
    } catch (e, stackTrace) {
      developer.log(
        'Não foi possível iniciar o Firebase Messaging.',
        name: 'PushNotificationService',
        error: e,
        stackTrace: stackTrace,
      );

      // O aplicativo continua funcionando mesmo que o Firebase esteja
      // temporariamente indisponível ou ainda não esteja completamente
      // configurado no dispositivo.
    }
  }

  Future<void> _inicializarNotificacoesLocais() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _canalId,
        _canalNome,
        description: 'Alertas importantes da Fazenda Baixinha.',
        importance: Importance.max,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _mostrarNotificacaoEmPrimeiroPlano(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Fazenda Baixinha',
      body: notification.body ?? 'Há uma nova atenção na Fazenda.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalId,
          _canalNome,
          channelDescription: 'Alertas importantes da Fazenda Baixinha.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
      payload: message.data['alerta_id']?.toString(),
    );
  }

  Future<void> _salvarToken(String token) async {
    try {
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
    } catch (e, stackTrace) {
      developer.log(
        'Erro ao salvar token FCM.',
        name: 'PushNotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> desativarToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) return;

      await _client
          .from('notificacao_dispositivos')
          .update({'ativo': false})
          .eq('fcm_token', token);
    } catch (e, stackTrace) {
      developer.log(
        'Erro ao desativar token FCM.',
        name: 'PushNotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();

    _tokenSubscription = null;
    _authSubscription = null;
    _iniciado = false;
  }
}
