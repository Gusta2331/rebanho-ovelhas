import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../animals/pages/animals_page.dart';
import '../animals/services/animal_service.dart';
import '../auth/login_page.dart';
import '../auth/services/auth_service.dart';
import '../farm/models/farm.dart';
import '../farm/services/farm_service.dart';
import '../flock/models/rebanho.dart';
import '../flock/pages/rebanho_form_page.dart';
import '../flock/pages/rebanhos_page.dart';
import '../flock/services/rebanho_selection_service.dart';
import '../flock/services/rebanho_service.dart';
import '../manejo/pages/manejos_page.dart';
import '../manejo/pages/manejo_agenda_page.dart';
import '../farmacia/pages/farmacia_page.dart';
import '../financeiro/pages/financeiro_page.dart';
import '../more/mais_page.dart';
import '../reproduction/pages/reproductions_page.dart';
import 'widgets/animal_card.dart';
import 'widgets/management_item.dart';
import 'widgets/quick_action.dart';
import 'widgets/rebanho_selector.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  final FarmService _farmService = FarmService();
  final AnimalService _animalService = AnimalService();
  final RebanhoService _rebanhoService = RebanhoService();

  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;

  Farm? _farm;

  List<Rebanho> _rebanhos = [];
  Rebanho? _rebanhoSelecionado;

  bool _loadingFarm = true;
  bool _loadingAnimals = true;
  bool _loadingRebanhos = true;

  int _totalAnimais = 0;
  int _totalFemeas = 0;
  int _totalMachos = 0;
  int _totalFemeasNaIdadeReproducao = 0;

  @override
  void initState() {
    super.initState();

    _loadFarm();
    _loadRebanhos();
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
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFarm = false;
      });

      _mostrarErro(error);
    }
  }

  Future<void> _loadRebanhos() async {
    try {
      final dados = await _rebanhoService.getRebanhos(somenteAtivos: true);

      final rebanhos = dados.map((mapa) => Rebanho.fromMap(mapa)).toList();

      Rebanho? rebanhoSelecionado;

      final idSelecionado = _rebanhoSelectionService.rebanhoSelecionadoId;

      if (idSelecionado != null) {
        for (final rebanho in rebanhos) {
          if (rebanho.id == idSelecionado) {
            rebanhoSelecionado = rebanho;
            break;
          }
        }
      }

      rebanhoSelecionado ??= rebanhos.isNotEmpty ? rebanhos.first : null;

      if (rebanhoSelecionado != null) {
        _rebanhoSelectionService.selecionar(rebanhoSelecionado);
      } else {
        _rebanhoSelectionService.limpar();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _rebanhos = rebanhos;
        _rebanhoSelecionado = rebanhoSelecionado;
        _loadingRebanhos = false;
      });

      await _loadAnimals();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingRebanhos = false;
        _loadingAnimals = false;
      });

      _mostrarErro(error);
    }
  }

  Future<void> _loadAnimals() async {
    if (_rebanhoSelecionado == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _totalAnimais = 0;
        _totalFemeas = 0;
        _totalMachos = 0;
        _totalFemeasNaIdadeReproducao = 0;
        _loadingAnimals = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _loadingAnimals = true;
      });
    }

    try {
      final animaisDoRebanho = await _animalService.getAnimaisAtivos(
        rebanhoId: _rebanhoSelecionado!.id,
      );

      int femeas = 0;
      int machos = 0;
      int femeasNaIdadeReproducao = 0;

      for (final animal in animaisDoRebanho) {
        final sexo = animal['sexo']?.toString().toLowerCase();

        if (sexo == 'femea') {
          femeas++;

          final dataNascimento = _parseDate(animal['data_nascimento']);

          if (dataNascimento != null) {
            final limite = _dataLimiteReproducao();

            if (!dataNascimento.isAfter(limite)) {
              femeasNaIdadeReproducao++;
            }
          }
        } else if (sexo == 'macho') {
          machos++;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _totalAnimais = animaisDoRebanho.length;
        _totalFemeas = femeas;
        _totalMachos = machos;
        _totalFemeasNaIdadeReproducao = femeasNaIdadeReproducao;
        _loadingAnimals = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingAnimals = false;
      });

      _mostrarErro(error);
    }
  }

  DateTime _dataLimiteReproducao() {
    final hoje = DateTime.now();

    return DateTime(hoje.year - 1, hoje.month, hoje.day);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  Future<void> _selecionarRebanho(Rebanho rebanho) async {
    _rebanhoSelectionService.selecionar(rebanho);

    if (!mounted) {
      return;
    }

    setState(() {
      _rebanhoSelecionado = rebanho;
    });

    await _loadAnimals();
  }

  Future<void> _abrirGerenciamentoRebanhos() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const RebanhosPage()));

    if (!mounted) {
      return;
    }

    await _loadRebanhos();
  }

  Future<void> _criarRebanho() async {
    final rebanhoCriado = await Navigator.of(context).push<Rebanho>(
      MaterialPageRoute(builder: (context) => const RebanhoFormPage()),
    );

    if (rebanhoCriado == null || !mounted) {
      return;
    }

    await _loadRebanhos();

    if (!mounted) {
      return;
    }

    final novoRebanho = _rebanhos.where(
      (rebanho) => rebanho.id == rebanhoCriado.id,
    );

    if (novoRebanho.isNotEmpty) {
      await _selecionarRebanho(novoRebanho.first);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lote "${rebanhoCriado.nome}" criado com sucesso.'),
      ),
    );
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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sair da conta'),
          content: const Text('Tem certeza que deseja sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmar == true && mounted) {
      await _logout();
    }
  }

  Future<void> _openManejos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManejosPage()),
    );
  }

  Future<void> _openManejoAgenda() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManejoAgendaPage()),
    );
  }

  Future<void> _openReproductions() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ReproductionsPage()));
  }

  Future<void> _openFarmacia() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FarmaciaPage()),
    );
  }

  Future<void> _openFinanceiro() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FinanceiroPage()),
    );
  }

  Future<void> _openMais() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MaisPage()),
    );
  }

  Future<void> _openAnimals() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const AnimalsPage()));

    if (!mounted) {
      return;
    }

    await _loadRebanhos();
  }

  void _mostrarErro(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_mensagemErro(error))));
  }

  String _mensagemErro(Object error) {
    final mensagem = error.toString();

    if (mensagem.startsWith('Exception: ')) {
      return mensagem.substring(11);
    }

    return mensagem;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            await _loadFarm();
            await _loadRebanhos();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              RebanhoSelector(
                loading: _loadingRebanhos,
                rebanhos: _rebanhos,
                rebanhoSelecionado: _rebanhoSelecionado,
                onChanged: _selecionarRebanho,
                onGerenciar: _abrirGerenciamentoRebanhos,
                onCriar: _criarRebanho,
              ),
              const SizedBox(height: 20),
              _buildTotalCard(),
              const SizedBox(height: 16),
              _buildAnimalCards(),
              const SizedBox(height: 24),
              _buildSectionTitle('Ações rápidas'),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildSectionTitle('Próximos manejos'),
              const SizedBox(height: 12),
              _buildManagementItems(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _farm?.nome ?? 'Fazenda Baixinha',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _loadingFarm ? 'Carregando fazenda...' : 'Gestão do lote',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _showLogoutConfirmation,
          tooltip: 'Sair',
          icon: const Icon(Icons.logout_rounded, color: AppTheme.primaryColor),
        ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Animais ativos',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _loadingAnimals ? '...' : _totalAnimais.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_rebanhoSelecionado != null)
                  Text(
                    _rebanhoSelecionado!.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalCards() {
    return Row(
      children: [
        Expanded(
          child: AnimalCard(
            icon: Icons.female_rounded,
            title: 'Fêmeas',
            value: _loadingAnimals ? '...' : _totalFemeas.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimalCard(
            icon: Icons.male_rounded,
            title: 'Machos',
            value: _loadingAnimals ? '...' : _totalMachos.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimalCard(
            icon: Icons.favorite_rounded,
            title: 'Fêmeas reprodutoras',
            value: _loadingAnimals
                ? '...'
                : _totalFemeasNaIdadeReproducao.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: AppTheme.textColor,
      ),
    );
  }

  Widget _buildQuickActions() {
    final acoes = [
      QuickAction(
        icon: Icons.add_circle_outline_rounded,
        title: 'Adicionar animal',
        onTap: _openAnimals,
      ),
      QuickAction(
        icon: Icons.groups_rounded,
        title: 'Lotes',
        onTap: _abrirGerenciamentoRebanhos,
      ),
      QuickAction(
        icon: Icons.favorite_outline_rounded,
        title: 'Reprodução',
        onTap: _openReproductions,
      ),
      QuickAction(
        icon: Icons.assignment_outlined,
        title: 'Manejo',
        onTap: _openManejos,
      ),
      QuickAction(
        icon: Icons.event_note_outlined,
        title: 'Agenda de manejo',
        onTap: _openManejoAgenda,
      ),
      QuickAction(
        icon: Icons.medical_services_outlined,
        title: 'Farmácia',
        onTap: _openFarmacia,
      ),
      QuickAction(
        icon: Icons.attach_money_rounded,
        title: 'Despesas e lucro',
        onTap: _openFinanceiro,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: acoes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.65,
      ),
      itemBuilder: (context, index) {
        return acoes[index];
      },
    );
  }

  Widget _buildManagementItems() {
    return Column(
      children: [
        ManagementItem(
          icon: Icons.vaccines_outlined,
          title: 'Vacinação',
          description: 'Próxima vacinação do lote',
          date: 'Em breve',
        ),
        const SizedBox(height: 12),
        ManagementItem(
          icon: Icons.monitor_weight_outlined,
          title: 'Pesagem',
          description: 'Acompanhe o peso dos animais',
          date: 'Em breve',
        ),
        const SizedBox(height: 12),
        ManagementItem(
          icon: Icons.favorite_border_rounded,
          title: 'Acompanhamento',
          description: 'Controle reprodutivo do lote',
          date: 'Em breve',
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 1) {
          _openAnimals();
        } else if (index == 2) {
          _openManejos();
        } else if (index == 3) {
          _openMais();
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Início',
        ),
        NavigationDestination(
          icon: Icon(Icons.pets_outlined),
          selectedIcon: Icon(Icons.pets_rounded),
          label: 'Animais',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: 'Manejo',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          selectedIcon: Icon(Icons.more_horiz_rounded),
          label: 'Mais',
        ),
      ],
    );
  }
}
