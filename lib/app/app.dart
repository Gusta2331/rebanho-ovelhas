import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/offline/offline_status_banner.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';

class FazendaBaixinhaApp extends StatelessWidget {
  const FazendaBaixinhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fazenda Baixinha',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      locale: const Locale('pt', 'BR'),

      supportedLocales: const [Locale('pt', 'BR')],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const _AppHome(),
    );
  }
}


class _AppHome extends StatelessWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        OfflineStatusBanner(),
        Expanded(child: LoginPage()),
      ],
    );
  }
}
