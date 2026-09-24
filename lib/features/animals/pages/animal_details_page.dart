import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/contextual_help.dart';
import '../../manejo/models/manejo.dart';
import '../../manejo/services/manejo_service.dart';
import '../../manejo/widgets/famacha_score_badge.dart';
import '../../reproduction/pages/reproduction_form_page.dart';
import '../../flock/pages/animal_transfer_page.dart';
import '../../flock/pages/animal_transfer_history_page.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../../flock/services/rebanho_service.dart';
import '../models/animal.dart';
import '../services/animal_service.dart';
import '../models/animal_venda.dart';
import '../services/animal_venda_service.dart';
import 'animal_sale_page.dart';
import '../widgets/animal_photo.dart';
import '../widgets/animal_descendants.dart';
import '../widgets/animal_family_tree.dart';
import 'animal_form_page.dart';

class AnimalDetailsPage extends StatefulWidget {
  final Animal animal;
  final List<Animal> animais;

  const AnimalDetailsPage({
    super.key,
    required this.animal,
    required this.animais,
  });

  @override
  State<AnimalDetailsPage> createState() => _AnimalDetailsPageState();
}

class _AnimalDetailsPageState extends State<AnimalDetailsPage> {
  late Animal _animal;
  late List<Animal> _animaisContexto;

  final AnimalService _animalService = AnimalService();
  final AnimalVendaService _vendaService = AnimalVendaService();
  final ManejoService _manejoService = ManejoService();

  List<Manejo> _historicoManejos = [];
  bool _carregandoManejos = true;
  String? _erroManejos;

  AnimalVenda? _venda;

  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;

  String? _rebanhoAtualId;
  String? _rebanhoAtualNome;

  @override
  void initState() {
    super.initState();
    _animal = widget.animal;
    _animaisContexto = List<Animal>.from(widget.animais);
    _carregarRebanhoAtual();
    _carregarAnimaisRelacionados();
    _carregarVenda();
    _carregarHistoricoManejos();
  }

  Future<void> _carregarHistoricoManejos() async {
    if (mounted) {
      setState(() {
        _carregandoManejos = true;
        _erroManejos = null;
      });
    }
    try {
      final rows = await _manejoService.getManejosPorAnimal(_animal.id);
      if (!mounted) return;
      setState(() {
        _historicoManejos = rows.map(Manejo.fromMap).toList();
        _carregandoManejos = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _erroManejos = error.toString().replaceFirst('Exception: ', '');
        _carregandoManejos = false;
      });
    }
  }

  Future<void> _atualizarFicha() async {
    try {
      final registros = await _animalService.getAnimaisPorIds([_animal.id]);
      if (registros.isNotEmpty && mounted) {
        final atualizado = Animal.fromMap(registros.first);
        setState(() {
          _animal = atualizado;
          _animaisContexto = [
            for (final animal in _animaisContexto)
              if (animal.id != atualizado.id) animal,
            atualizado,
          ];
        });
      }
    } catch (_) {
      // Continue refreshing the history when animal details are unavailable.
    }
    await Future.wait([
      _carregarHistoricoManejos(),
      _carregarAnimaisRelacionados(),
      _carregarVenda(),
    ]);
  }

  List<Manejo> _manejosDoTipo(Set<TipoManejo> tipos) =>
      _historicoManejos.where((manejo) => tipos.contains(manejo.tipo)).toList();

  String _detalhesManejo(Manejo manejo) {
    final partes = <String>[];
    switch (manejo.tipo) {
      case TipoManejo.vacinacao:
        if (manejo.vacinaNome != null) partes.add(manejo.vacinaNome!);
        if (manejo.vacinaFabricante != null) {
          partes.add('Fabricante: ${manejo.vacinaFabricante}');
        }
        if (manejo.vacinaLote != null) partes.add('Lote: ${manejo.vacinaLote}');
      case TipoManejo.vermifugacao:
        if (manejo.vermifugoNome != null) partes.add(manejo.vermifugoNome!);
        if (manejo.vermifugoPrincipioAtivo != null) {
          partes.add('Princípio ativo: ${manejo.vermifugoPrincipioAtivo}');
        }
      case TipoManejo.tratamento:
        if (manejo.enfermidade != null)
          partes.add('Enfermidade: ${manejo.enfermidade}');
        if (manejo.medicamentoNome != null) partes.add(manejo.medicamentoNome!);
        if (manejo.medicamentoPrincipioAtivo != null) {
          partes.add('Princípio ativo: ${manejo.medicamentoPrincipioAtivo}');
        }
      case TipoManejo.tosquia:
      case TipoManejo.outro:
        if (manejo.outroNome != null) partes.add(manejo.outroNome!);
      case TipoManejo.pesagem:
        if (manejo.pesoKg != null) {
          partes.add('${manejo.pesoKg!.toStringAsFixed(1)} kg');
        }
      case TipoManejo.famacha:
        if (manejo.famachaEscore != null) {
          partes.add('FAMACHA ${manejo.famachaEscore}');
        }
    }
    if (manejo.dose != null) {
      partes.add(
        'Dose: ${manejo.dose}${manejo.doseUnidade == null ? '' : ' ${manejo.doseUnidade}'}',
      );
    }
    if (manejo.observacoes != null) partes.add(manejo.observacoes!);
    return partes.join(' · ');
  }

  String _tituloManejo(Manejo manejo) {
    switch (manejo.tipo) {
      case TipoManejo.vacinacao:
        return 'Vacinação';
      case TipoManejo.vermifugacao:
        return 'Vermifugação';
      case TipoManejo.tratamento:
        return 'Tratamento';
      case TipoManejo.tosquia:
        return 'Tosquia';
      case TipoManejo.pesagem:
        return 'Pesagem';
      case TipoManejo.famacha:
        return 'Avaliação FAMACHA';
      case TipoManejo.outro:
        return manejo.outroNome ?? 'Outro manejo';
    }
  }

  Widget _buildHistoricoSection({
    required String title,
    required IconData icon,
    required List<Manejo> registros,
  }) {
    if (_carregandoManejos) {
      return _buildSection(
        title: title,
        icon: icon,
        children: const [
          Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_erroManejos != null) {
      return _buildSection(
        title: title,
        icon: icon,
        children: [
          ListTile(
            title: Text(_erroManejos!),
            trailing: IconButton(
              onPressed: _carregarHistoricoManejos,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      );
    }
    if (registros.isEmpty) {
      return _buildSection(
        title: title,
        icon: icon,
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('Ainda não há registros para este animal.'),
          ),
        ],
      );
    }
    return _buildSection(
      title: title,
      icon: icon,
      children: [
        for (final manejo in registros)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.10),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            title: Text(_tituloManejo(manejo)),
            subtitle: Text(
              [
                _dataTexto(manejo.data),
                _detalhesManejo(manejo),
              ].where((text) => text.isNotEmpty).join(' · '),
            ),
            trailing:
                manejo.tipo == TipoManejo.famacha &&
                    manejo.famachaEscore != null
                ? FamachaScoreBadge(score: manejo.famachaEscore!)
                : null,
          ),
      ],
    );
  }

  Future<void> _carregarAnimaisRelacionados() async {
    try {
      final porId = <String, Animal>{
        for (final animal in _animaisContexto) animal.id: animal,
      };
      var geracao = <Animal>[_animal];
      final visitados = <String>{_animal.id};

      // Load ancestors generation by generation so the tree can label and
      // display grandparents and later generations from real records.
      for (var nivel = 0; nivel < 8 && geracao.isNotEmpty; nivel++) {
        final idsPais = <String>{};
        for (final animal in geracao) {
          final maeId = animal.idMae;
          final paiId = animal.idPai;
          if (maeId != null && maeId.isNotEmpty && visitados.add(maeId)) {
            idsPais.add(maeId);
          }
          if (paiId != null && paiId.isNotEmpty && visitados.add(paiId)) {
            idsPais.add(paiId);
          }
        }
        if (idsPais.isEmpty) break;

        final faltantes = idsPais
            .where((id) => !porId.containsKey(id))
            .toList();
        if (faltantes.isNotEmpty) {
          final registros = await _animalService.getAnimaisPorIds(faltantes);
          for (final registro in registros) {
            final relacionado = Animal.fromMap(registro);
            porId[relacionado.id] = relacionado;
          }
        }
        geracao = idsPais.map((id) => porId[id]).whereType<Animal>().toList();
        if (geracao.isEmpty) break;
      }

      if (!mounted) return;
      setState(() => _animaisContexto = porId.values.toList());
    } catch (_) {
      // Mantém os dados já carregados na tela caso a atualização dos
      // animais relacionados não esteja disponível momentaneamente.
    }
  }

  Future<void> _carregarVenda() async {
    try {
      final venda = await _vendaService.buscarPorAnimal(_animal.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _venda = venda;
      });
    } catch (_) {
      // A ficha continua disponível mesmo se o histórico de venda não puder ser carregado.
    }
  }

  Future<void> _abrirVenda() async {
    if (_animal.status != StatusAnimal.ativo) {
      return;
    }

    final loteId = _rebanhoAtualId;
    final loteNome = _rebanhoAtualNome;

    if (loteId == null || loteNome == null) {
      _mostrarMensagem('Não foi possível identificar o lote atual do animal.');
      return;
    }

    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            AnimalSalePage(animal: _animal, loteId: loteId, loteNome: loteNome),
      ),
    );

    if (resultado == null || !mounted) {
      return;
    }

    final animaisAtualizados = await _animalService.getAnimaisPorIds([
      _animal.id,
    ]);

    if (animaisAtualizados.isNotEmpty && mounted) {
      setState(() {
        _animal = Animal.fromMap(animaisAtualizados.first);
      });
    }

    await _carregarVenda();
    _mostrarMensagem('Venda registrada com sucesso e lançada no financeiro.');
  }

  Future<void> _iniciarReproducao() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReproductionFormPage(initialMaeId: _animal.id),
      ),
    );
    if (resultado == true && mounted) {
      _mostrarMensagem(
        'Reprodução registrada. Você poderá registrar o parto e os cordeiros nela.',
      );
    }
  }

  void _carregarRebanhoAtual() {
    final rebanho = _rebanhoSelectionService.rebanhoSelecionado;

    if (rebanho == null) {
      return;
    }

    _rebanhoAtualId = rebanho.id;
    _rebanhoAtualNome = rebanho.nome;
  }

  Set<String> _obterBrincosExistentes() {
    return widget.animais
        .where((animal) {
          return animal.status == StatusAnimal.ativo && animal.id != _animal.id;
        })
        .map((animal) => animal.brinco)
        .toSet();
  }

  Future<void> _editarAnimal() async {
    final animalEditado = await Navigator.of(context).push<Animal>(
      MaterialPageRoute(
        builder: (context) => AnimalFormPage(
          brincosExistentes: _obterBrincosExistentes(),
          animais: _animaisContexto,
          animalParaEditar: _animal,
        ),
      ),
    );

    if (animalEditado == null || !mounted) {
      return;
    }

    setState(() {
      _animal = animalEditado;
    });

    _retornarAnimalAtualizado();
  }

  Future<void> _transferirAnimal() async {
    final rebanhoId = _rebanhoAtualId;
    final rebanhoNome = _rebanhoAtualNome;

    if (rebanhoId == null || rebanhoNome == null) {
      _mostrarMensagem(
        'Não foi possível identificar o rebanho atual do animal.',
      );
      return;
    }

    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => AnimalTransferPage(
          animalId: _animal.id,
          brinco: _animal.brinco,
          rebanhoAtualId: rebanhoId,
          rebanhoAtualNome: rebanhoNome,
        ),
      ),
    );

    if (resultado == null || !mounted) {
      return;
    }

    final resultadoPartes = resultado.split(':');
    final rebanhoDestinoId = resultadoPartes.length > 1
        ? resultadoPartes[1]
        : null;
    final rebanhoSelecionado = _rebanhoSelectionService.rebanhoSelecionado;

    if (rebanhoDestinoId != null) {
      final rebanhos = await RebanhoService().getRebanhos(somenteAtivos: true);
      final destino = rebanhos
          .where((item) => item['id']?.toString() == rebanhoDestinoId)
          .toList();
      setState(() {
        _rebanhoAtualId = rebanhoDestinoId;
        _rebanhoAtualNome = destino.isNotEmpty
            ? destino.first['nome']?.toString()
            : _rebanhoAtualNome;
      });
    } else if (rebanhoSelecionado != null &&
        rebanhoSelecionado.id != rebanhoId) {
      setState(() {
        _rebanhoAtualId = rebanhoSelecionado.id;
        _rebanhoAtualNome = rebanhoSelecionado.nome;
      });
    }

    _mostrarMensagem(
      resultado.startsWith('pendente:')
          ? 'Transferência salva neste aparelho e será sincronizada quando a internet voltar.'
          : 'Animal transferido com sucesso.',
    );
  }

  Future<void> _abrirHistoricoTransferencias() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AnimalTransferHistoryPage(
          animalId: _animal.id,
          brinco: _animal.brinco,
        ),
      ),
    );
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _alterarStatus() async {
    if (_animal.status == StatusAnimal.vendido) {
      _mostrarMensagem(
        'Este animal já foi vendido. A venda registrada permanece no histórico.',
      );
      return;
    }

    final novoStatus = await showModalBottomSheet<StatusAnimal>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alterar status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Escolha o novo status deste animal.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                _buildStatusOption(
                  context: sheetContext,
                  status: StatusAnimal.ativo,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.primaryColor,
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.sell_outlined, color: Colors.blue),
                  ),
                  title: const Text(
                    'Vender animal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  subtitle: const Text(
                    'Registrar valor e lançar no financeiro',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black38,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _abrirVenda();
                  },
                ),
                _buildStatusOption(
                  context: sheetContext,
                  status: StatusAnimal.morto,
                  icon: Icons.remove_circle_outline_rounded,
                  color: Colors.red,
                ),
                _buildStatusOption(
                  context: sheetContext,
                  status: StatusAnimal.descartado,
                  icon: Icons.block_outlined,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (novoStatus == null || novoStatus == _animal.status || !mounted) {
      return;
    }

    final confirmou = await _confirmarAlteracaoStatus(novoStatus);

    if (!confirmou || !mounted) {
      return;
    }

    setState(() {
      _animal = _animal.copyWith(status: novoStatus);
    });

    _retornarAnimalAtualizado();
  }

  Widget _buildStatusOption({
    required BuildContext context,
    required StatusAnimal status,
    required IconData icon,
    required Color color,
  }) {
    final selecionado = _animal.status == status;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        _statusTextoPara(status),
        style: TextStyle(
          fontWeight: selecionado ? FontWeight.bold : FontWeight.w600,
          color: AppTheme.textColor,
        ),
      ),
      trailing: selecionado
          ? Icon(Icons.check_circle_rounded, color: color)
          : const Icon(Icons.chevron_right_rounded, color: Colors.black38),
      onTap: () {
        Navigator.of(context).pop(status);
      },
    );
  }

  Future<bool> _confirmarAlteracaoStatus(StatusAnimal novoStatus) async {
    final statusAtual = _statusTexto();

    String mensagem;

    switch (novoStatus) {
      case StatusAnimal.ativo:
        mensagem =
            'O animal voltará para a lista de animais ativos.\n\n'
            'O brinco continuará registrado permanentemente '
            'e não poderá ser reutilizado por outro animal.';
        break;

      case StatusAnimal.vendido:
        mensagem =
            'O animal será marcado como vendido e sairá da lista '
            'de animais ativos.\n\n'
            'O registro continuará salvo no histórico de vendidos.';
        break;

      case StatusAnimal.morto:
        mensagem =
            'O animal será marcado como morto e sairá da lista '
            'de animais ativos.\n\n'
            'O registro continuará salvo no histórico de mortos.';
        break;

      case StatusAnimal.descartado:
        mensagem =
            'O animal será marcado como descartado e sairá da lista '
            'de animais ativos.\n\n'
            'O registro continuará salvo no histórico de descartados.';
        break;
    }

    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Alterar para '
            '${_statusTextoPara(novoStatus)}?',
          ),
          content: Text(
            'Status atual: $statusAtual\n\n'
            '$mensagem',
          ),
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
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    return resultado ?? false;
  }

  String _statusTextoPara(StatusAnimal status) {
    switch (status) {
      case StatusAnimal.ativo:
        return 'Ativo';

      case StatusAnimal.vendido:
        return 'Vendido';

      case StatusAnimal.morto:
        return 'Morto';

      case StatusAnimal.descartado:
        return 'Descartado';
    }
  }

  void _retornarAnimalAtualizado() {
    Navigator.of(context).pop(_animal);
  }

  String _sexoTexto() {
    switch (_animal.sexo) {
      case SexoAnimal.femea:
        return 'Fêmea';

      case SexoAnimal.macho:
        return 'Macho';
    }
  }

  String _statusTexto() {
    return _statusTextoPara(_animal.status);
  }

  Color _statusCor() {
    switch (_animal.status) {
      case StatusAnimal.ativo:
        return AppTheme.primaryColor;

      case StatusAnimal.vendido:
        return Colors.blue;

      case StatusAnimal.morto:
        return Colors.red;

      case StatusAnimal.descartado:
        return Colors.orange;
    }
  }

  String _dataTexto(DateTime? data) {
    if (data == null) {
      return 'Não informado';
    }

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  String _idadeTexto() {
    final nascimento = _animal.dataNascimento;

    if (nascimento == null) {
      return 'Não informada';
    }

    final hoje = DateTime.now();

    if (nascimento.isAfter(hoje)) {
      return 'Data inválida';
    }

    int anos = hoje.year - nascimento.year;
    int meses = hoje.month - nascimento.month;
    int dias = hoje.day - nascimento.day;

    if (dias < 0) {
      meses--;

      final ultimoDiaMesAnterior = DateTime(hoje.year, hoje.month, 0).day;

      dias += ultimoDiaMesAnterior;
    }

    if (meses < 0) {
      anos--;
      meses += 12;
    }

    final partes = <String>[];

    if (anos > 0) {
      partes.add('$anos ${anos == 1 ? 'ano' : 'anos'}');
    }

    if (meses > 0) {
      partes.add('$meses ${meses == 1 ? 'mês' : 'meses'}');
    }

    if (dias > 0) {
      partes.add('$dias ${dias == 1 ? 'dia' : 'dias'}');
    }

    if (partes.isEmpty) {
      return 'Recém-nascido';
    }

    return partes.join(' e ');
  }

  @override
  Widget build(BuildContext context) {
    final nome = _animal.nome?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ficha do animal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          const ContextualHelpButton(
            title: 'Ficha do animal',
            introduction: 'Veja os dados, a família e os registros de saúde e manejo deste animal.',
            topics: [
              HelpTopic(
                title: 'Histórico',
                description: 'Vacinas, vermifugações, tratamentos, FAMACHA, pesagens e outros manejos aparecem nas seções abaixo.',
              ),
              HelpTopic(
                title: 'Atualizar',
                description: 'Use o botão de atualizar ou puxe a tela para baixo para buscar os registros mais recentes.',
              ),
              HelpTopic(
                title: 'Família',
                description: 'A árvore mostra pais, avós e descendentes conforme os vínculos cadastrados nos animais.',
              ),
            ],
          ),
          IconButton(
            onPressed: _atualizarFicha,
            tooltip: 'Atualizar ficha',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _alterarStatus,
            tooltip: 'Alterar status',
            icon: const Icon(Icons.flag_outlined),
          ),
          if (_animal.status == StatusAnimal.ativo)
            IconButton(
              onPressed: _abrirVenda,
              tooltip: 'Vender animal',
              icon: const Icon(Icons.sell_outlined),
            ),
          IconButton(
            onPressed: _editarAnimal,
            tooltip: 'Editar animal',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _atualizarFicha,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildHeader(nome),
            const SizedBox(height: 20),

            _buildSection(
              title: 'Informações',
              icon: Icons.info_outline,
              children: [
                _buildInfoRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Brinco',
                  value: _animal.brinco,
                ),
                _buildInfoRow(
                  icon: _animal.sexo == SexoAnimal.femea
                      ? Icons.female
                      : Icons.male,
                  label: 'Sexo',
                  value: _sexoTexto(),
                ),
                _buildInfoRow(
                  icon: Icons.category_outlined,
                  label: 'Raça',
                  value: _animal.raca,
                ),
                _buildInfoRow(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Dentição',
                  value: _animal.denticao ?? 'Não informada',
                ),
                if (_animal.denticaoData != null)
                  _buildInfoRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Avaliação dentária',
                    value: _dataTexto(_animal.denticaoData),
                  ),
                if (_animal.denticaoObservacoes != null)
                  _buildInfoRow(
                    icon: Icons.notes_outlined,
                    label: 'Observação dentária',
                    value: _animal.denticaoObservacoes!,
                  ),
                _buildInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Data de nascimento',
                  value: _dataTexto(_animal.dataNascimento),
                ),
                _buildInfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Idade',
                  value: _idadeTexto(),
                ),
                _buildInfoRow(
                  icon: Icons.groups_outlined,
                  label: 'Rebanho atual',
                  value: _rebanhoAtualNome ?? 'Não identificado',
                ),
                _buildInfoRow(
                  icon: Icons.flag_outlined,
                  label: 'Status',
                  value: _statusTexto(),
                  valueColor: _statusCor(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildTransferCard(),

            const SizedBox(height: 16),

            _buildTransferHistoryCard(),

            if (_venda != null) ...[
              const SizedBox(height: 16),
              _buildVendaCard(),
            ],

            const SizedBox(height: 16),

            _buildSection(
              title: 'Filiação',
              icon: Icons.family_restroom_outlined,
              children: [
                _buildParentRow(
                  titulo: 'Mãe',
                  animal: _obterMae(),
                  sexo: SexoAnimal.femea,
                ),
                _buildParentRow(
                  titulo: 'Pai',
                  animal: _obterPai(),
                  sexo: SexoAnimal.macho,
                ),
              ],
            ),

            const SizedBox(height: 16),

            AnimalFamilyTree(animal: _animal, animais: _animaisContexto),

            const SizedBox(height: 16),

            AnimalDescendants(animal: _animal, animais: widget.animais),

            if (_animal.sexo == SexoAnimal.femea &&
                _animal.status == StatusAnimal.ativo) ...[
              const SizedBox(height: 16),
              _buildSection(
                title: 'Reprodução e parição',
                icon: Icons.child_friendly_outlined,
                children: [
                  ListTile(
                    title: const Text('Registrar reprodução / futura parição'),
                    subtitle: const Text(
                      'A mãe já ficará selecionada. Depois, registre o parto e os cordeiros.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _iniciarReproducao,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            _buildHistoricoSection(
              title: 'Saúde',
              icon: Icons.medical_services_outlined,
              registros: _manejosDoTipo({
                TipoManejo.vacinacao,
                TipoManejo.vermifugacao,
                TipoManejo.tratamento,
                TipoManejo.famacha,
              }),
            ),

            const SizedBox(height: 12),

            _buildHistoricoSection(
              title: 'Pesagens',
              icon: Icons.monitor_weight_outlined,
              registros: _manejosDoTipo({TipoManejo.pesagem}),
            ),

            const SizedBox(height: 12),

            _buildHistoricoSection(
              title: 'Manejo',
              icon: Icons.agriculture_outlined,
              registros: _manejosDoTipo({TipoManejo.tosquia, TipoManejo.outro}),
            ),

            const SizedBox(height: 12),

            _buildFutureSection(
              title: 'Financeiro',
              icon: Icons.attach_money_rounded,
              description: 'O registro de venda aparece nesta ficha. Consulte “Despesas e lucro” para os demais lançamentos da fazenda.',
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _editarAnimal,
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  'Editar informações',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendaCard() {
    final venda = _venda!;

    return _buildSection(
      title: 'Venda',
      icon: Icons.sell_outlined,
      children: [
        _buildInfoRow(
          icon: Icons.calendar_month_outlined,
          label: 'Data da venda',
          value: _dataTexto(venda.dataVenda),
        ),
        _buildInfoRow(
          icon: venda.tipoVenda == TipoVendaAnimal.porKg
              ? Icons.scale_outlined
              : Icons.payments_outlined,
          label: 'Forma de venda',
          value: venda.tipoVenda == TipoVendaAnimal.porKg
              ? 'Por kg'
              : 'Valor fechado',
        ),
        if (venda.pesoKg != null)
          _buildInfoRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Peso na venda',
            value:
                '${venda.pesoKg!.toStringAsFixed(2).replaceAll('.', ',')} kg',
          ),
        if (venda.precoPorKg != null)
          _buildInfoRow(
            icon: Icons.attach_money_rounded,
            label: 'Preço por kg',
            value:
                'R\$ ${venda.precoPorKg!.toStringAsFixed(2).replaceAll('.', ',')}',
          ),
        _buildInfoRow(
          icon: Icons.payments_outlined,
          label: 'Valor total',
          value:
              'R\$ ${venda.valorTotal.toStringAsFixed(2).replaceAll('.', ',')}',
          valueColor: AppTheme.primaryColor,
        ),
        if (venda.comprador != null)
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Comprador',
            value: venda.comprador!,
          ),
        if (venda.observacoes != null)
          _buildInfoRow(
            icon: Icons.notes_outlined,
            label: 'Observações',
            value: venda.observacoes!,
          ),
      ],
    );
  }

  Widget _buildTransferCard() {
    final temRebanho = _rebanhoAtualId != null && _rebanhoAtualNome != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transferência',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Mova este animal para outro rebanho.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: temRebanho ? _transferirAnimal : null,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Transferir para outro rebanho'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histórico de transferências',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Veja todas as movimentações deste animal.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _abrirHistoricoTransferencias,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Ver histórico'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String? nome) {
    final nomeExibicao = nome == null || nome.isEmpty
        ? 'Animal ${_animal.brinco}'
        : nome;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Row(
        children: [
          AnimalPhoto(fotoPath: _animal.fotoPath, size: 90, borderRadius: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeExibicao,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Brinco ${_animal.brinco}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusCor().withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusTexto(),
                    style: TextStyle(
                      color: _statusCor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 21),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildParentRow({
    required String titulo,
    required Animal? animal,
    required SexoAnimal sexo,
  }) {
    final temAnimal = animal != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (temAnimal)
            AnimalPhoto(fotoPath: animal.fotoPath, size: 58, borderRadius: 14)
          else
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                sexo == SexoAnimal.femea ? Icons.female : Icons.male,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  temAnimal
                      ? (animal.nome?.trim().isNotEmpty == true
                            ? animal.nome!.trim()
                            : 'Animal ${animal.brinco}')
                      : 'Não informado',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: temAnimal ? AppTheme.textColor : Colors.black45,
                  ),
                ),
                if (temAnimal) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Brinco ${animal.brinco} • ${animal.raca}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutureSection({
    required String title,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
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
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ainda não há registros',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Animal? _buscarAnimalPorId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final animal in _animaisContexto) {
      if (animal.id == id) {
        return animal;
      }
    }

    return null;
  }

  Animal? _obterMae() {
    return _buscarAnimalPorId(_animal.idMae);
  }

  Animal? _obterPai() {
    return _buscarAnimalPorId(_animal.idPai);
  }
}
