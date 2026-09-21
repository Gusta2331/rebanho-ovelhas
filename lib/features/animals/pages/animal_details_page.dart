import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../flock/pages/animal_transfer_page.dart';
import '../../flock/pages/animal_transfer_history_page.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../models/animal.dart';
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

  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;

  String? _rebanhoAtualId;
  String? _rebanhoAtualNome;

  @override
  void initState() {
    super.initState();
    _animal = widget.animal;
    _carregarRebanhoAtual();
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
          animais: widget.animais,
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

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AnimalTransferPage(
          animalId: _animal.id,
          brinco: _animal.brinco,
          rebanhoAtualId: rebanhoId,
          rebanhoAtualNome: rebanhoNome,
        ),
      ),
    );

    if (resultado != true || !mounted) {
      return;
    }

    final rebanhoSelecionado = _rebanhoSelectionService.rebanhoSelecionado;

    if (rebanhoSelecionado != null && rebanhoSelecionado.id != rebanhoId) {
      setState(() {
        _rebanhoAtualId = rebanhoSelecionado.id;
        _rebanhoAtualNome = rebanhoSelecionado.nome;
      });
    }

    _mostrarMensagem('Animal transferido com sucesso.');
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
                _buildStatusOption(
                  context: sheetContext,
                  status: StatusAnimal.vendido,
                  icon: Icons.sell_outlined,
                  color: Colors.blue,
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
          IconButton(
            onPressed: _alterarStatus,
            tooltip: 'Alterar status',
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            onPressed: _editarAnimal,
            tooltip: 'Editar animal',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
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

          AnimalReproduction(
            animalId: _animal.id,
            brinco: _animal.brinco,
            ehFemea: _animal.sexo == SexoAnimal.femea,
          ),

          const SizedBox(height: 16),

          AnimalFamilyTree(animal: _animal, animais: widget.animais),

          const SizedBox(height: 16),

          AnimalDescendants(animal: _animal, animais: widget.animais),

          const SizedBox(height: 12),

          _buildFutureSection(
            title: 'Saúde',
            icon: Icons.medical_services_outlined,
            description:
                'Vacinas, medicamentos, doenças, tratamentos e consultas.',
          ),

          const SizedBox(height: 12),

          _buildFutureSection(
            title: 'Pesagens',
            icon: Icons.monitor_weight_outlined,
            description: 'Histórico de peso e evolução do animal.',
          ),

          const SizedBox(height: 12),

          _buildFutureSection(
            title: 'Manejo',
            icon: Icons.agriculture_outlined,
            description: 'Registros de manejo e atividades realizadas.',
          ),

          const SizedBox(height: 12),

          _buildFutureSection(
            title: 'Financeiro',
            icon: Icons.attach_money_rounded,
            description: 'Custos, vendas, receitas e histórico financeiro.',
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

    for (final animal in widget.animais) {
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
