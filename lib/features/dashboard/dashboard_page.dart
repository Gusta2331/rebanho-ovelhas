import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../animals/pages/animals_page.dart';
import '../animals/services/animal_service.dart';
import '../auth/login_page.dart';
import '../auth/services/auth_service.dart';
import '../farm/models/farm.dart';
import '../farm/services/farm_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  final FarmService _farmService = FarmService();
  final AnimalService _animalService = AnimalService();

  Farm? _farm;

  bool _loadingFarm = true;
  bool _loadingAnimals = true;

  int _totalAnimais = 0;
  int _totalFemeas = 0;
  int _totalMachos = 0;
  int _totalFemeasNaIdadeReproducao = 0;

  @override
  void initState() {
    super.initState();
    _loadFarm();
    _loadAnimals();
  }

  Future<void> _loadFarm() async {
    try {
      final farm = await _farmService.getMinhaFazenda();

      if (!mounted) {
        return;
      }

      setState(() {
        _farm = farm;
        _loadingFarm = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFarm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar os dados da fazenda.'),
        ),
      );
    }
  }

  Future<void> _loadAnimals() async {
    try {
      final animais = await _animalService.getAnimaisAtivos();

      final totalFemeas = animais
          .where((animal) => animal['sexo'] == 'femea')
          .length;

      final totalMachos = animais
          .where((animal) => animal['sexo'] == 'macho')
          .length;

      final dataLimite = _dataLimiteReproducao();

      final totalFemeasNaIdadeReproducao = animais.where((animal) {
        if (animal['sexo'] != 'femea') {
          return false;
        }

        final dataNascimento = _parseDate(animal['data_nascimento']);

        if (dataNascimento == null) {
          return false;
        }

        return !dataNascimento.isAfter(dataLimite);
      }).length;

      if (!mounted) {
        return;
      }

      setState(() {
        _totalAnimais = animais.length;
        _totalFemeas = totalFemeas;
        _totalMachos = totalMachos;
        _totalFemeasNaIdadeReproducao = totalFemeasNaIdadeReproducao;
        _loadingAnimals = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingAnimals = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os animais.')),
      );
    }
  }

  DateTime _dataLimiteReproducao() {
    final hoje = DateTime.now();

    return DateTime(hoje.year, hoje.month - 8, hoje.day);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair da conta'),
          content: const Text('Tem certeza que deseja sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  void _openAnimals() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const AnimalsPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFarm || _loadingAnimals) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final nomeFazenda = _farm?.nome ?? 'OviGestão';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          nomeFazenda,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notificações',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutConfirmation();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded),
                      SizedBox(width: 12),
                      Text('Sair da conta'),
                    ],
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bom dia! 👋',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              const Text(
                'Resumo do rebanho',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 24),

              // Resumo principal
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total de animais',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_totalAnimais',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Animais ativos no rebanho',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Categorias do rebanho
              Row(
                children: [
                  Expanded(
                    child: _AnimalCard(
                      icon: Icons.pets_rounded,
                      title: 'Ovelhas',
                      value: '$_totalFemeas',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AnimalCard(
                      icon: Icons.male_rounded,
                      title: 'Carneiros',
                      value: '$_totalMachos',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AnimalCard(
                      icon: Icons.favorite_rounded,
                      title: 'Matrizes',
                      value: '$_totalFemeasNaIdadeReproducao',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Acesso rápido',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.pets_rounded,
                      title: 'Animais',
                      onTap: _openAnimals,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.favorite_border_rounded,
                      title: 'Reprodução',
                      onTap: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.medical_services_outlined,
                      title: 'Saúde',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.agriculture_outlined,
                      title: 'Manejo',
                      onTap: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.attach_money_rounded,
                      title: 'Financeiro',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.bar_chart_rounded,
                      title: 'Relatórios',
                      onTap: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Próximos manejos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 14),

              _ManagementItem(
                icon: Icons.medical_services_outlined,
                title: 'Vacinação',
                description: '12 animais precisam ser vacinados',
                date: 'Hoje',
              ),

              const SizedBox(height: 10),

              _ManagementItem(
                icon: Icons.monitor_weight_outlined,
                title: 'Pesagem',
                description: 'Pesagem dos cordeiros',
                date: 'Amanhã',
              ),

              const SizedBox(height: 10),

              _ManagementItem(
                icon: Icons.pets_rounded,
                title: 'Acompanhamento',
                description: '3 ovelhas próximas do parto',
                date: 'Esta semana',
              ),
            ],
          ),
        ),
      ),

      // Menu inferior
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            _openAnimals();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets_rounded),
            label: 'Animais',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Manejo',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _AnimalCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9E1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 25),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E9E1)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String date;

  const _ManagementItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
