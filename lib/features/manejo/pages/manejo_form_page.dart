import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../animals/services/animal_service.dart';
import '../models/manejo.dart';
import '../services/manejo_service.dart';

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
  TipoManejo _tipo = TipoManejo.vacinacao;
  DateTime _data = DateTime.now();
  int? _famacha;
  bool _carregando = true;
  bool _salvando = false;

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

  Future<void> _salvar() async {
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
      if (widget.manejo == null) {
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

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida != null && mounted) setState(() => _data = escolhida);
  }

  String _animalTexto(Map<String, dynamic> animal) {
    final numero = int.tryParse(animal['brinco']?.toString() ?? '');
    final brinco = numero == null ? (animal['brinco']?.toString() ?? '') : numero.toString().padLeft(3, '0');
    final nome = animal['nome']?.toString().trim();
    return nome != null && nome.isNotEmpty ? brinco + ' • ' + nome : 'Brinco ' + brinco;
  }

  String _tipoTexto(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao: return 'Vacinação';
      case TipoManejo.vermifugacao: return 'Vermifugação';
      case TipoManejo.tratamento: return 'Tratamento';
      case TipoManejo.tosquia: return 'Tosquia';
      case TipoManejo.pesagem: return 'Pesagem';
      case TipoManejo.famacha: return 'FAMACHA';
      case TipoManejo.outro: return 'Outro';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manejo == null ? 'Novo manejo' : 'Editar manejo'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _intro(),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
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
                      child: Text(_animalTexto(animal), overflow: TextOverflow.ellipsis),
                    );
                  }).whereType<DropdownMenuItem<String>>().toList(),
                  onChanged: _salvando ? null : (value) => setState(() => _animalId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TipoManejo>(
                  value: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de manejo',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: TipoManejo.values.map((tipo) {
                    return DropdownMenuItem(value: tipo, child: Text(_tipoTexto(tipo)));
                  }).toList(),
                  onChanged: _salvando
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _tipo = value;
                            if (value != TipoManejo.famacha) _famacha = null;
                          });
                        },
                ),
                if (_tipo == TipoManejo.famacha) ...[
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
                      _data.day.toString().padLeft(2, '0') + '/' +
                      _data.month.toString().padLeft(2, '0') + '/' +
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _salvando
                          ? 'Salvando...'
                          : widget.manejo == null
                              ? 'Salvar manejo'
                              : 'Salvar alterações',
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.assignment_outlined, color: AppTheme.primaryColor, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Registre cuidados realizados no animal. A FAMACHA também ficará no histórico de manejos.',
              style: TextStyle(height: 1.4),
            ),
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
            'Compare a mucosa da pálpebra inferior com as cores de referência antes de escolher o escore.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          _famachaReferencia(),
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
              final cor = _corFamacha(escore);

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
                      foregroundColor: selecionado
                          ? Colors.white
                          : AppTheme.textColor,
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
                            color: cor,
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

  Widget _famachaReferencia() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 19,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Escala de referência',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final escore = index + 1;
              final cor = _corFamacha(escore);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: escore == 5 ? 0 : 6),
                  child: Column(
                    children: [
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: cor,
                          borderRadius: BorderRadius.circular(8),
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
              );
            }),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Mais vermelho',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
              Text(
                'Mais pálido',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
