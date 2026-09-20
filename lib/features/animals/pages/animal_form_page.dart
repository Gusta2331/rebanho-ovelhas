import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../models/animal.dart';
import '../widgets/animal_photo.dart';
import '../widgets/animal_parent_selector.dart';
import 'racas_page.dart';


class AnimalFormPage extends StatefulWidget {
  final Set<String> brincosExistentes;
  final List<Animal> animais;
  final Animal? animalParaEditar;

  const AnimalFormPage({
    super.key,
    required this.brincosExistentes,
    required this.animais,
    this.animalParaEditar,
  });

  bool get modoEdicao => animalParaEditar != null;

  @override
  State<AnimalFormPage> createState() => _AnimalFormPageState();
}

class _AnimalFormPageState extends State<AnimalFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _brincoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _racaController = TextEditingController();
  final _observacoesController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final ImageCropper _imageCropper = ImageCropper();

  SexoAnimal _sexoSelecionado = SexoAnimal.femea;
  StatusAnimal _statusSelecionado = StatusAnimal.ativo;

  DateTime? _dataNascimento;
  String? _fotoPath;

  Animal? _maeSelecionada;
  Animal? _paiSelecionado;

  @override
  void initState() {
    super.initState();

    final animal = widget.animalParaEditar;

    if (animal != null) {
      _brincoController.text = animal.brinco;
      _nomeController.text = animal.nome ?? '';
      _racaController.text = animal.raca;
      _observacoesController.text = animal.observacoes ?? '';

      _sexoSelecionado = animal.sexo;
      _statusSelecionado = animal.status;
      _dataNascimento = animal.dataNascimento;
      _fotoPath = animal.fotoPath;

      _maeSelecionada = _buscarAnimalPorId(animal.idMae);
      _paiSelecionado = _buscarAnimalPorId(animal.idPai);
    }
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

  @override
  void dispose() {
    _brincoController.dispose();
    _nomeController.dispose();
    _racaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  String _normalizarBrinco(String brinco) {
    final numero = int.tryParse(brinco.trim());

    if (numero != null) {
      return numero.toString();
    }

    return brinco.trim().toLowerCase();
  }

  bool _brincoExiste(String brinco) {
    final brincoNormalizado = _normalizarBrinco(brinco);

    return widget.brincosExistentes.any(
      (brincoExistente) =>
          _normalizarBrinco(brincoExistente) == brincoNormalizado,
    );
  }

  int _proximoBrincoDisponivel() {
    var numero = 1;

    while (_brincoExiste(numero.toString())) {
      numero++;
    }

    return numero;
  }

  void _gerarBrincoAutomatico() {
    final proximo = _proximoBrincoDisponivel();

    setState(() {
      _brincoController.text = proximo.toString().padLeft(3, '0');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Brinco ${proximo.toString().padLeft(3, '0')} '
          'gerado automaticamente.',
        ),
      ),
    );
  }

  Future<void> _selecionarRaca() async {
    final racaSelecionada = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const RacasPage(modoSelecao: true),
      ),
    );

    if (racaSelecionada == null || !mounted) {
      return;
    }

    setState(() {
      _racaController.text = racaSelecionada;
    });
  }

  Future<void> _selecionarDataNascimento() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? hoje,
      firstDate: DateTime(2000),
      lastDate: hoje,
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (data != null && mounted) {
      setState(() {
        _dataNascimento = data;
      });
    }
  }

  Future<void> _abrirOpcoesFoto() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto do animal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Escolha como deseja adicionar a foto.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: const Text(
                    'Tirar foto',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Usar a câmera do celular'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _selecionarFoto(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: const Text(
                    'Escolher da galeria',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Selecionar uma foto existente'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _selecionarFoto(ImageSource.gallery);
                  },
                ),
                if (_fotoPath != null) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                    ),
                    title: const Text(
                      'Remover foto',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: const Text('Voltar para o ícone padrão'),
                    onTap: () {
                      Navigator.of(context).pop();

                      setState(() {
                        _fotoPath = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selecionarFoto(ImageSource source) async {
    try {
      final imagem = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (imagem == null || !mounted) {
        return;
      }

      final imagemCortada = await _imageCropper.cropImage(
        sourcePath: imagem.path,
        compressQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Editar foto',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppTheme.primaryColor,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Editar foto',
            cancelButtonTitle: 'Cancelar',
            doneButtonTitle: 'Concluir',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (imagemCortada == null || !mounted) {
        return;
      }

      setState(() {
        _fotoPath = imagemCortada.path;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível editar a foto.')),
      );
    }
  }

  void _salvarAnimal() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final animalAnterior = widget.animalParaEditar;

    final animal = Animal(
      id: animalAnterior?.id,
      brinco: _brincoController.text.trim(),
      nome: _nomeController.text.trim().isEmpty
          ? null
          : _nomeController.text.trim(),
      sexo: _sexoSelecionado,
      raca: _racaController.text.trim(),
      dataNascimento: _dataNascimento,
      status: _statusSelecionado,
      observacoes: _observacoesController.text.trim().isEmpty
          ? null
          : _observacoesController.text.trim(),
      fotoPath: _fotoPath,

      // Filiação
      idMae: _maeSelecionada?.id,
      idPai: _paiSelecionado?.id,
    );

    Navigator.of(context).pop(animal);
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  String _statusLabel(StatusAnimal status) {
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

  IconData _statusIcon(StatusAnimal status) {
    switch (status) {
      case StatusAnimal.ativo:
        return Icons.check_circle_outline_rounded;

      case StatusAnimal.vendido:
        return Icons.sell_outlined;

      case StatusAnimal.morto:
        return Icons.cancel_outlined;

      case StatusAnimal.descartado:
        return Icons.remove_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final modoEdicao = widget.modoEdicao;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          modoEdicao ? 'Editar animal' : 'Novo animal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                modoEdicao ? 'Editar dados do animal' : 'Dados do animal',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                modoEdicao
                    ? 'Atualize as informações do animal.'
                    : 'Cadastre as informações básicas do animal.',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 28),

              // FOTO
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _abrirOpcoesFoto,
                      child: Stack(
                        children: [
                          AnimalPhoto(
                            fotoPath: _fotoPath,
                            size: 140,
                            borderRadius: 28,
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _abrirOpcoesFoto,
                      icon: Icon(
                        _fotoPath == null
                            ? Icons.add_a_photo_outlined
                            : Icons.edit_outlined,
                      ),
                      label: Text(
                        _fotoPath == null ? 'Adicionar foto' : 'Alterar foto',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // BRINCO
              const Text(
                'Número do brinco *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _brincoController,
                readOnly: modoEdicao,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Ex.: 001',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  suffixIcon: modoEdicao
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.black38,
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o número do brinco.';
                  }

                  final numero = int.tryParse(value.trim());

                  if (numero == null || numero <= 0) {
                    return 'Informe um número de brinco válido.';
                  }

                  if (!modoEdicao && _brincoExiste(value)) {
                    return 'O brinco '
                        '${numero.toString().padLeft(3, '0')} '
                        'já está cadastrado.';
                  }

                  return null;
                },
              ),

              if (modoEdicao)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'O número do brinco identifica o animal '
                    'e não pode ser alterado.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),

              if (!modoEdicao) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _gerarBrincoAutomatico,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Gerar brinco automaticamente'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // NOME
              const Text(
                'Nome',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nomeController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Ex.: Branquinha',
                  prefixIcon: Icon(Icons.pets_outlined),
                ),
              ),

              const SizedBox(height: 20),

              // SEXO
              const Text(
                'Sexo *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<SexoAnimal>(
                segments: const [
                  ButtonSegment<SexoAnimal>(
                    value: SexoAnimal.femea,
                    icon: Icon(Icons.female_rounded),
                    label: Text('Fêmea'),
                  ),
                  ButtonSegment<SexoAnimal>(
                    value: SexoAnimal.macho,
                    icon: Icon(Icons.male_rounded),
                    label: Text('Macho'),
                  ),
                ],
                selected: {_sexoSelecionado},
                onSelectionChanged: (selection) {
                  setState(() {
                    _sexoSelecionado = selection.first;
                  });
                },
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }

                    return AppTheme.textColor;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.primaryColor;
                    }

                    return Colors.white;
                  }),
                ),
              ),

              const SizedBox(height: 20),

              // RAÇA
              const Text(
                'Raça *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selecionarRaca,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                    suffixIcon: Icon(Icons.chevron_right_rounded),
                  ),
                  child: Text(
                    _racaController.text.isEmpty
                        ? 'Selecionar raça'
                        : _racaController.text,
                    style: TextStyle(
                      color: _racaController.text.isEmpty
                          ? Colors.black45
                          : AppTheme.textColor,
                    ),
                  ),
                ),
              ),

              if (_racaController.text.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'Selecione uma raça na biblioteca.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),

              const SizedBox(height: 20),

              // DATA DE NASCIMENTO
              const Text(
                'Data de nascimento',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selecionarDataNascimento,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _dataNascimento == null
                        ? 'Selecionar data'
                        : _formatarData(_dataNascimento!),
                    style: TextStyle(
                      color: _dataNascimento == null
                          ? Colors.black45
                          : AppTheme.textColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // FILIAÇÃO
              const Text(
                'Filiação',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Informe a mãe e o pai do animal, se conhecidos.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),

              const SizedBox(height: 16),

              // MÃE
              AnimalParentSelector(
                titulo: 'Mãe',
                textoVazio: 'Selecionar a mãe',
                animalSelecionado: _maeSelecionada,
                sexoPermitido: SexoAnimal.femea,
                animais: widget.animais,
                idAnimalAtual: widget.animalParaEditar?.id,
                onChanged: (animal) {
                  setState(() {
                    _maeSelecionada = animal;
                  });
                },
              ),

              const SizedBox(height: 14),

              // PAI
              AnimalParentSelector(
                titulo: 'Pai',
                textoVazio: 'Selecionar o pai',
                animalSelecionado: _paiSelecionado,
                sexoPermitido: SexoAnimal.macho,
                animais: widget.animais,
                idAnimalAtual: widget.animalParaEditar?.id,
                onChanged: (animal) {
                  setState(() {
                    _paiSelecionado = animal;
                  });
                },
              ),

              const SizedBox(height: 28),

              // STATUS
              const Text(
                'Status *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<StatusAnimal>(
                initialValue: _statusSelecionado,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: StatusAnimal.values.map((status) {
                  return DropdownMenuItem<StatusAnimal>(
                    value: status,
                    child: Row(
                      children: [
                        Icon(_statusIcon(status), size: 20),
                        const SizedBox(width: 10),
                        Text(_statusLabel(status)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (status) {
                  if (status == null) {
                    return;
                  }

                  setState(() {
                    _statusSelecionado = status;
                  });
                },
              ),

              const SizedBox(height: 20),

              // OBSERVAÇÕES
              const Text(
                'Observações',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _observacoesController,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText:
                      'Alguma informação importante '
                      'sobre o animal...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 58),
                    child: Icon(Icons.notes_outlined),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // SALVAR
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _salvarAnimal,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    modoEdicao ? 'Salvar alterações' : 'Salvar animal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
      ),
    );
  }
}
