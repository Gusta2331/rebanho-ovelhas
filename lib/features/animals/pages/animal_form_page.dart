import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../models/animal.dart';
import '../services/animal_service.dart';
import '../widgets/animal_parent_selector.dart';
import '../widgets/animal_photo.dart';
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
  final _valorAquisicaoController = TextEditingController();
  final _vendedorController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final ImageCropper _imageCropper = ImageCropper();
  final AnimalService _animalService = AnimalService();

  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;

  SexoAnimal _sexoSelecionado = SexoAnimal.femea;
  StatusAnimal _statusSelecionado = StatusAnimal.ativo;

  DateTime? _dataNascimento;
  DateTime? _dataAquisicao;
  String? _fotoPath;

  OrigemAnimal _origemSelecionada = OrigemAnimal.nascido;

  Animal? _maeSelecionada;
  Animal? _paiSelecionado;

  bool _salvando = false;

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
      _dataAquisicao = animal.dataAquisicao;
      _fotoPath = animal.fotoPath;
      _origemSelecionada = animal.origem;
      _valorAquisicaoController.text = animal.valorAquisicao == null
          ? ''
          : animal.valorAquisicao!.toStringAsFixed(2).replaceAll('.', ',');
      _vendedorController.text = animal.vendedor ?? '';
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
    _valorAquisicaoController.dispose();
    _vendedorController.dispose();
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

    for (final animal in widget.animais) {
      // Durante a edição, o animal pode continuar com o próprio brinco.
      if (animal.id == widget.animalParaEditar?.id) {
        continue;
      }

      if (_normalizarBrinco(animal.brinco) == brincoNormalizado) {
        return true;
      }
    }

    return false;
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


  Future<void> _selecionarDataAquisicao() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _dataAquisicao ?? hoje,
      firstDate: DateTime(2000),
      lastDate: hoje,
      helpText: 'Selecione a data da compra',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (data != null && mounted) {
      setState(() {
        _dataAquisicao = data;
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

  String _sexoParaBanco(SexoAnimal sexo) {
    switch (sexo) {
      case SexoAnimal.femea:
        return 'femea';

      case SexoAnimal.macho:
        return 'macho';
    }
  }

  String _statusParaBanco(StatusAnimal status) {
    switch (status) {
      case StatusAnimal.ativo:
        return 'ativo';

      case StatusAnimal.vendido:
        return 'vendido';

      case StatusAnimal.morto:
        return 'morto';

      case StatusAnimal.descartado:
        return 'descartado';
    }
  }

  Future<void> _salvarAnimal() async {
    if (_salvando) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final brinco = int.tryParse(_brincoController.text.trim());

    if (brinco == null || brinco <= 0) {
      return;
    }

    if (!widget.modoEdicao && _origemSelecionada == OrigemAnimal.comprado) {
      final valor = double.tryParse(_valorAquisicaoController.text.trim().replaceAll(',', '.'));

      if (_dataAquisicao == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe a data da compra.')),
        );
        return;
      }

      if (valor == null || valor <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe um valor de compra maior que zero.')),
        );
        return;
      }
    }

    final valorAquisicao = double.tryParse(
      _valorAquisicaoController.text.trim().replaceAll(',', '.'),
    );

    final rebanhoSelecionado = _rebanhoSelectionService.rebanhoSelecionado;

    if (rebanhoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um rebanho antes de cadastrar o animal.'),
        ),
      );

      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final animalAnterior = widget.animalParaEditar;

      Map<String, dynamic> dadosSalvos;

      if (animalAnterior == null) {
        dadosSalvos = await _animalService.criarAnimal(
          brinco: brinco,
          rebanhoId: rebanhoSelecionado.id,
          nome: _nomeController.text,
          sexo: _sexoParaBanco(_sexoSelecionado),
          raca: _racaController.text,
          dataNascimento: _dataNascimento,
          status: _statusParaBanco(_statusSelecionado),
          dataEntrada: DateTime.now(),
          observacoes: _observacoesController.text,
          fotoUrl: null,
          fotoPath: _fotoPath,

          // A filiação é salva no Supabase.
          maeId: _maeSelecionada?.id,
          paiId: _paiSelecionado?.id,
          origem: _origemSelecionada == OrigemAnimal.comprado ? 'comprado' : 'nascido',
          dataAquisicao: _dataAquisicao,
          valorAquisicao: valorAquisicao,
          vendedor: _vendedorController.text,
        );
      } else {
        dadosSalvos = await _animalService.atualizarAnimal(
          id: animalAnterior.id,
          brinco: brinco,
          rebanhoId: rebanhoSelecionado.id,
          nome: _nomeController.text,
          sexo: _sexoParaBanco(_sexoSelecionado),
          raca: _racaController.text,
          dataNascimento: _dataNascimento,
          status: _statusParaBanco(_statusSelecionado),

          // Null aqui não deve apagar a data de entrada
          // já existente. O service preserva a informação
          // atual no banco quando necessário.
          dataEntrada: null,

          dataSaida: _statusSelecionado == StatusAnimal.ativo
              ? null
              : DateTime.now(),

          observacoes: _observacoesController.text,
          fotoUrl: null,
          fotoPath: _fotoPath,

          // Mantém a filiação durante a edição.
          maeId: _maeSelecionada?.id,
          paiId: _paiSelecionado?.id,
        );
      }

      final animalSalvo = Animal.fromMap(dadosSalvos);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            animalAnterior == null
                ? 'Animal cadastrado com sucesso.'
                : 'Animal atualizado com sucesso.',
          ),
        ),
      );

      // A tela anterior recebe o animal realmente salvo
      // no Supabase.
      Navigator.of(context).pop(animalSalvo);
    } catch (error) {
      if (!mounted) {
        return;
      }

      String mensagem = 'Não foi possível salvar o animal.';

      if (error is PostgrestException) {
        mensagem = error.message;
      } else if (error is Exception) {
        final texto = error.toString();

        if (texto.startsWith('Exception: ')) {
          mensagem = texto.substring(11);
        } else {
          mensagem = texto;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), duration: const Duration(seconds: 4)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
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
                      onTap: _salvando ? null : _abrirOpcoesFoto,
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
                      onPressed: _salvando ? null : _abrirOpcoesFoto,
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
                readOnly: _salvando,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'Ex.: 001',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o número do brinco.';
                  }

                  final numero = int.tryParse(value.trim());

                  if (numero == null || numero <= 0) {
                    return 'Informe um número de brinco válido.';
                  }

                  if (_brincoExiste(value)) {
                    return 'O brinco '
                        '${numero.toString().padLeft(3, '0')} '
                        'já foi utilizado.';
                  }

                  return null;
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  'O número do brinco é permanente e nunca pode '
                  'ser reutilizado por outro animal, mesmo após '
                  'venda, morte ou descarte.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _salvando ? null : _gerarBrincoAutomatico,
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

              const SizedBox(height: 20),

              // NOME
              const Text(
                'Nome',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nomeController,
                readOnly: _salvando,
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
                onSelectionChanged: _salvando
                    ? null
                    : (selection) {
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
                onTap: _salvando ? null : _selecionarRaca,
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
                onTap: _salvando ? null : _selecionarDataNascimento,
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


              const SizedBox(height: 20),

              // ORIGEM
              const Text(
                'Origem do animal *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<OrigemAnimal>(
                segments: const [
                  ButtonSegment<OrigemAnimal>(
                    value: OrigemAnimal.nascido,
                    icon: Icon(Icons.child_friendly_outlined),
                    label: Text('Nascido'),
                  ),
                  ButtonSegment<OrigemAnimal>(
                    value: OrigemAnimal.comprado,
                    icon: Icon(Icons.shopping_cart_outlined),
                    label: Text('Comprado'),
                  ),
                ],
                selected: {_origemSelecionada},
                onSelectionChanged: _salvando
                    ? null
                    : (selection) {
                        setState(() {
                          _origemSelecionada = selection.first;

                          if (_origemSelecionada == OrigemAnimal.nascido) {
                            _dataAquisicao = null;
                            _valorAquisicaoController.clear();
                            _vendedorController.clear();
                          }
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
              const SizedBox(height: 8),
              Text(
                _origemSelecionada == OrigemAnimal.nascido
                    ? 'Animal nascido na própria fazenda. Não gera lançamento financeiro.'
                    : 'Animal comprado. O valor será lançado automaticamente no financeiro do lote.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (_origemSelecionada == OrigemAnimal.comprado) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: _salvando ? null : _selecionarDataAquisicao,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data da compra *',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      _dataAquisicao == null
                          ? 'Selecionar data'
                          : _formatarData(_dataAquisicao!),
                      style: TextStyle(
                        color: _dataAquisicao == null
                            ? Colors.black45
                            : AppTheme.textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorAquisicaoController,
                  readOnly: _salvando,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Valor da compra *',
                    hintText: 'Ex.: 850,00',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  validator: (value) {
                    if (_origemSelecionada != OrigemAnimal.comprado) {
                      return null;
                    }

                    final valor = double.tryParse(
                      value?.trim().replaceAll(',', '.') ?? '',
                    );

                    if (valor == null || valor <= 0) {
                      return 'Informe um valor de compra válido.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vendedorController,
                  readOnly: _salvando,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Vendedor / fornecedor',
                    hintText: 'Opcional',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],

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
                  if (_salvando) {
                    return;
                  }

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
                  if (_salvando) {
                    return;
                  }

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
                items: (modoEdicao && widget.animalParaEditar?.status == StatusAnimal.vendido
                        ? const [StatusAnimal.vendido]
                        : StatusAnimal.values.where(
                            (status) => status != StatusAnimal.vendido,
                          ))
                    .map((status) {
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
                onChanged: _salvando
                    ? null
                    : (status) {
                        if (status == null) {
                          return;
                        }

                        setState(() {
                          _statusSelecionado = status;
                        });
                      },
              ),

              if (_statusSelecionado == StatusAnimal.ativo &&
                  (!modoEdicao || widget.animalParaEditar?.status == StatusAnimal.ativo))
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'Para vender este animal, use a opção “Vender animal” na ficha. '
                    'Assim o valor da venda é registrado automaticamente no financeiro.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
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
                readOnly: _salvando,
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
                  onPressed: _salvando ? null : _salvarAnimal,
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
                        : modoEdicao
                        ? 'Salvar alterações'
                        : 'Salvar animal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.6,
                    ),
                    disabledForegroundColor: Colors.white,
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
