import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline/offline_status_banner.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';
import '../features/farm/pages/farm_check_page.dart';

class FazendaBaixinhaApp extends StatefulWidget {
  const FazendaBaixinhaApp({super.key});

  @override
  State<FazendaBaixinhaApp> createState() => _FazendaBaixinhaAppState();
}

class _FazendaBaixinhaAppState extends State<FazendaBaixinhaApp> {
  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _processandoLink = false;

  @override
  void initState() {
    super.initState();

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _tratarLink,
      onError: (Object error) {
        debugPrint('OVIGESTÃO: erro ao receber link: $error');
      },
    );

    _verificarLinkInicial();
  }

  Future<void> _verificarLinkInicial() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await _tratarLink(uri);
      }
    } catch (error) {
      debugPrint('OVIGESTÃO: erro ao verificar link inicial: $error');
    }
  }

  Future<void> _tratarLink(Uri uri) async {
    if (uri.scheme != 'ovigestao' ||
        uri.host != 'login-callback' ||
        _processandoLink) {
      return;
    }

    _processandoLink = true;

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);

      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FarmCheckPage()),
        (route) => false,
      );
    } on AuthException catch (error) {
      debugPrint(
        'OVIGESTÃO: não foi possível processar a autenticação pelo link: '
        '${error.message}',
      );
    } catch (error) {
      debugPrint('OVIGESTÃO: falha ao processar link de autenticação: $error');
    } finally {
      _processandoLink = false;
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'OviGestão',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Column(
          children: [
            const OfflineStatusBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const LoginPage(),
    );
  }
}
