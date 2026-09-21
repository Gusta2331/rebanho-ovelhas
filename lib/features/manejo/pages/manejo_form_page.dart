import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../models/manejo.dart';
import '../services/manejo_service.dart';
import '../widgets/famacha_reference_widget.dart';

class ManejoFormPage extends StatefulWidget {
  final Manejo? manejo;

  const ManejoFormPage({
    super.key,
    this.manejo,
  });

  @override
  State<ManejoFormPage> createState() => _ManejoFormPageState();
}

class _ManejoFormPageState extends State<ManejoFormPage> {
  final ManejoService _service = ManejoService();
  final AnimalService _animalService = AnimalService();
  final TextEditingController _observacoes = TextEditingController();

  List<Map<String, dynamic>> _animais = [];
  String? _animalId;
  final Set<String> _animaisSelecionados = {};
  final Map<String, int> _famachaPorAnimal = {};

  TipoManejo _tipo = TipoManejo.vacinacao;
  DateTime _data = DateTime.now();
  int? _famacha;
  bool _carregando = true;
  bool _salvando = false;

  bool get _editando => widget.manejo != null;
  bool get _avaliacaoEmLote => !_editando && _tipo == TipoManejo.famacha;

  @override
  void initState() {
    super.initState();

    final manejo = widget.manejo;
    if (manejo != null) {
      _animalId = manejo.animalId;
      _tipo = manejo.tipo;
      _data = manejo.data;
      _famacha = manejo.famachaEscore;
      _observacoes.text = manejo.observacoes ?? '';
    }

    _carregarAnimais();
  }

  @override
  void dispose() {
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _carregarAnimais() async {
    try {
      final animais = await _animalService.getAnimaisAtivos();

      if (!mounted) return;

      setState(() {
        _animais = animais;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _carregando = false);
      _mensagem(e.toString());
    }
  }

  void _selecionarTodos() {
    setState(() {
      _animaisSelecionados
        ..clear()
        ..addAll(
          _animais
              .map((animal) => animal['id']?.toString())
              .whereType<String>(),
        );
    });
  }

  void _limparSelecao() {
    setState(() {
      _animaisSelecionados.clear();
      _famachaPorAnimal.clear();
    });
  }

  void _alternarAnimal(String id, bool selecionado) {
    setState(() {
      if (selecionado) {
        _animaisSelecionados.add(id);
      } else {
        _animaisSelecionados.remove(id);
        _famachaPorAnimal.remove(id);
      }
    });
  }

  void _definirFamacha(String animalId, int escore) {
    setState(() => _famachaPorAnimal[animalId] = escore);
  }

  Future<void> _salvar() async {
    if (_avaliacaoEmLote) {
      await _salvarFamachaEmLote();
      return;
    }

    if (_animalId == null) {
      _mensagem('Selecione o animal.');
      return;
    }

    if (_tipo == TipoManejo.famacha && _famacha == null) {
      _mensagem('Selecione a classificação FAMACHA.');
      return;
    }

    setState(() => _salvando = true);

    try {
      if (!_editando) {
        await _service.criarManejo(
          animalId: _animalId!,
          tipo: _tipo,
          data: _data,
          famachaEscore: _tipo == TipoManejo.famacha ? _famacha : null,
          observacoes: _observacoes.text,
        );
      } else {
        await _service.atualizarManejo(
          id: widget.manejo!.id,
          animalId: _animalId!,
          tipo: _tipo,
          data: _data,
          famachaEscore: _tipo == TipoManejo.famacha ? _famacha : null,
          observacoes: _observacoes.text,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _salvando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _salvarFamachaEmLote() async {
    if (_animaisSelecionados.isEmpty) {
      _mensagem('Selecione pelo menos uma ovelha.');
      return;
    }

    final faltando = _animaisSelecionados.where(
      (id) => _famachaPorAnimal[id] == null,
    );

    if (faltando.isNotEmpty) {
      _mensagem('Informe o FAMACHA de todas as ovelhas selecionadas.');
      return;
    }

    setState(() => _salvando = true);

    try {
      await _service.criarManejosEmLote(
        animalIds: _animaisSelecionados.toList(),
        data: _data,
        famachaPorAnimal: _famachaPorAnimal,
        observacoes: _observacoes.text,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _salvando = false);
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (escolhida != null && mounted) {
      setState(() => _data = escolhida);
    }
  }

  String _animalTexto(Map<String, dynamic> animal) {
    final numero = int.tryParse(animal['brinco']?.toString() ?? '');
    final brinco = numero == null
        ? (animal['brinco']?.toString() ?? '')
        : numero.toString().padLeft(3, '0');
    final nome = animal['nome']?.toString().trim();

    return nome != null && nome.isNotEmpty
        ? '$brinco • $nome'
        : 'Brinco $brinco';
  }

  Map<String, dynamic>? _animalPorId(String id) {
    for (final animal in _animais) {
      if (animal['id']?.toString() == id) return animal;
    }
    return null;
  }

  String _tipoTexto(TipoManejo tipo) {
    switch (tipo) {
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
        return 'FAMACHA';
      case TipoManejo.outro:
        return 'Outro';
    }
  }

  Color _corFamacha(int escore) {
    switch (escore) {
      case 1:
        return const Color(0xFFB71C1C);
      case 2:
        return const Color(0xFFE53935);
      case 3:
        return const Color(0xFFE57373);
      case 4:
        return const Color(0xFFF8B6B6);
      case 5:
        return const Color(0xFFF5EAEA);
      default:
        return Colors.grey;
    }
  }

  String _descricaoFamacha(int escore) {
    switch (escore) {
      case 1:
        return 'Vermelho intenso';
      case 2:
        return 'Vermelho/rosado';
      case 3:
        return 'Rosa';
      case 4:
        return 'Rosa bem claro';
      case 5:
        return 'Muito pálido';
      default:
        return '';
    }
  }

  void _mensagem(String texto) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto.replaceFirst('Exception: ', ''))),
    );
  }

  void _mostrarInformativoFamacha() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informativo FAMACHA',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A FAMACHA usa a cor da mucosa da pálpebra inferior para estimar o grau de anemia do animal.',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 16),
                _infoLinha(
                  '1',
                  'Vermelho',
                  'Sem sinal visual de anemia importante.',
                ),
                _infoLinha(
                  '2',
                  'Vermelho/rosado',
                  'Faixa geralmente aceitável.',
                ),
                _infoLinha(
                  '3',
                  'Rosa',
                  'Faixa intermediária, merece acompanhamento.',
                ),
                _infoLinha(
                  '4',
                  'Rosa muito claro',
                  'Anemia importante, requer atenção.',
                ),
                _infoLinha(
                  '5',
                  'Muito pálido',
                  'Anemia grave, requer atenção imediata.',
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Importante: FAMACHA não identifica sozinha a causa da anemia. Parasitas que causam perda de sangue, como o Haemonchus contortus, são uma causa importante, mas outros problemas também podem estar envolvidos. Não use o escore como diagnóstico isolado.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Para uma avaliação correta, observe a mucosa diretamente, em boa iluminação, e compare com um cartão FAMACHA apropriado. O aplicativo serve como apoio de registro.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoLinha(String escore, String titulo, String descricao) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _corFamacha(int.parse(escore)),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              escore,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(descricao, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar manejo' : 'Novo manejo'),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _intro(),
                const SizedBox(height: 20),
                if (_avaliacaoEmLote)
                  _selecaoEmLote()
                else
                  _animalUnico(),
                const SizedBox(height: 16),
                DropdownButtonFormField<TipoManejo>(
                  value: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de manejo',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: TipoManejo.values.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(_tipoTexto(tipo)),
                    );
                  }).toList(),
                  onChanged: _salvando
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            _tipo = value;

                            if (value != TipoManejo.famacha) {
                              _famacha = null;
                              _animaisSelecionados.clear();
                              _famachaPorAnimal.clear();
                            }
                          });
                        },
                ),
                if (_avaliacaoEmLote) ...[
                  const SizedBox(height: 16),
                  _avaliacaoLote(),
                ] else if (_tipo == TipoManejo.famacha) ...[
                  const SizedBox(height: 16),
                  _famachaField(),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: _salvando ? null : _escolherData,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _data.day.toString().padLeft(2, '0') +
                          '/' +
                          _data.month.toString().padLeft(2, '0') +
                          '/' +
                          _data.year.toString(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _observacoes,
                  enabled: !_salvando,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _salvando
                          ? 'Salvando...'
                          : _avaliacaoEmLote
                              ? 'Salvar avaliações'
                              : _editando
                                  ? 'Salvar alterações'
                                  : 'Salvar manejo',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registro de manejo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _avaliacaoEmLote
                      ? 'Você pode avaliar várias ovelhas na mesma visita.'
                      : 'Registre cuidados realizados no animal.',
                  style: const TextStyle(height: 1.4),
                ),
                if (_tipo == TipoManejo.famacha) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _mostrarInformativoFamacha,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Entenda a FAMACHA'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animalUnico() {
    return DropdownButtonFormField<String>(
      value: _animalId,
      decoration: const InputDecoration(
        labelText: 'Animal',
        prefixIcon: Icon(Icons.pets_outlined),
        border: OutlineInputBorder(),
      ),
      hint: const Text('Selecione o animal'),
      items: _animais.map((animal) {
        final id = animal['id']?.toString();

        if (id == null) return null;

        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            _animalTexto(animal),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).whereType<DropdownMenuItem<String>>().toList(),
      onChanged: _salvando
          ? null
          : (value) => setState(() => _animalId = value),
    );
  }

  Widget _selecaoEmLote() {
    final todosSelecionados = _animais.isNotEmpty &&
        _animais.every(
          (animal) => _animaisSelecionados.contains(animal['id']?.toString()),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ovelhas avaliadas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _salvando
                      ? null
                      : todosSelecionados
                          ? _limparSelecao
                          : _selecionarTodos,
                  child: Text(
                    todosSelecionados ? 'Limpar' : 'Selecionar todas',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              _animaisSelecionados.length.toString() +
                  ' ovelha(s) selecionada(s)',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const Divider(height: 1),
          if (_animais.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nenhuma ovelha ativa encontrada.'),
            )
          else
            ..._animais.map((animal) {
              final id = animal['id']?.toString();
              if (id == null) return const SizedBox.shrink();

              final selecionado = _animaisSelecionados.contains(id);

              return CheckboxListTile(
                value: selecionado,
                onChanged: _salvando
                    ? null
                    : (value) => _alternarAnimal(id, value == true),
                title: Text(_animalTexto(animal)),
                secondary: const Icon(Icons.pets_outlined),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
        ],
      ),
    );
  }

  Widget _avaliacaoLote() {
    final selecionados = _animaisSelecionados
        .map(_animalPorId)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (selecionados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Selecione as ovelhas acima. Depois, o aplicativo mostrará uma avaliação para cada uma.',
          style: TextStyle(height: 1.4),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informe o FAMACHA de cada ovelha',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cada animal recebe seu próprio escore. Não é necessário dar o mesmo valor para todos.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...selecionados.map(_itemAvaliacaoAnimal),
        ],
      ),
    );
  }

  Widget _itemAvaliacaoAnimal(Map<String, dynamic> animal) {
    final id = animal['id'].toString();
    final escore = _famachaPorAnimal[id];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: escore == null
              ? Colors.black12
              : AppTheme.primaryColor.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _animalTexto(animal),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final valor = index + 1;
              final ativo = escore == valor;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: valor == 5 ? 0 : 5),
                  child: OutlinedButton(
                    onPressed: _salvando
                        ? null
                        : () => _definirFamacha(id, valor),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          ativo ? AppTheme.primaryColor : Colors.white,
                      foregroundColor:
                          ativo ? Colors.white : AppTheme.textColor,
                      side: BorderSide(
                        color: ativo
                            ? AppTheme.primaryColor
                            : Colors.black12,
                        width: ativo ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _corFamacha(valor),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          valor.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _famachaField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classificação FAMACHA',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Compare a mucosa da pálpebra inferior com uma referência apropriada antes de escolher o escore.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FamachaReferenceWidget(selecionado: _famacha),
          const SizedBox(height: 16),
          const Text(
            'Escore observado',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final escore = index + 1;
              final selecionado = _famacha == escore;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: escore == 5 ? 0 : 6),
                  child: OutlinedButton(
                    onPressed: _salvando
                        ? null
                        : () => setState(() => _famacha = escore),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          selecionado ? AppTheme.primaryColor : Colors.white,
                      foregroundColor:
                          selecionado ? Colors.white : AppTheme.textColor,
                      side: BorderSide(
                        color: selecionado
                            ? AppTheme.primaryColor
                            : Colors.black12,
                        width: selecionado ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _corFamacha(escore),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          escore.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_famacha != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _corFamacha(_famacha!).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Selecionado: FAMACHA ' +
                    _famacha.toString() +
                    ' • ' +
                    _descricaoFamacha(_famacha!),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'A escala é uma referência visual. A avaliação deve ser feita observando diretamente a mucosa do animal, em boa iluminação.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
