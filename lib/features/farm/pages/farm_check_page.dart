import 'package:flutter/material.dart';

import '../../../features/dashboard/dashboard_page.dart';
import '../services/farm_service.dart';
import 'farm_setup_page.dart';

class FarmCheckPage extends StatefulWidget {
  const FarmCheckPage({super.key});

  @override
  State<FarmCheckPage> createState() => _FarmCheckPageState();
}

class _FarmCheckPageState extends State<FarmCheckPage> {
  final FarmService _farmService = FarmService();

  @override
  void initState() {
    super.initState();
    _verificarFazenda();
  }

  Future<void> _verificarFazenda() async {
    try {
      final fazenda = await _farmService.getMinhaFazenda();

      if (!mounted) {
        return;
      }

      if (fazenda == null) {
        final resultado = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => const FarmSetupPage()));

        if (!mounted) {
          return;
        }

        if (resultado == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
          return;
        }

        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível verificar sua fazenda: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
