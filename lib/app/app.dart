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
