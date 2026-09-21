import 'package:flutter/material.dart';

import '../services/farm_service.dart';

class FarmSetupPage extends StatefulWidget {
  const FarmSetupPage({super.key});

  @override
  State<FarmSetupPage> createState() => _FarmSetupPageState();
}

class _FarmSetupPageState extends State<FarmSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _observacoesController = TextEditingController();

  final FarmService _farmService = FarmService();

  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _enderecoController.dispose();
    _telefoneController.dispose();
    _observacoesController.dispose();

    super.dispose();
  }

  Future<void> _salvarFazenda() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      await _farmService.criarFazenda(
        nome: _nomeController.text,
        cidade: _cidadeController.text,
        estado: _estadoController.text,
        endereco: _enderecoController.text,
        telefone: _telefoneController.text,
        observacoes: _observacoesController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fazenda cadastrada com sucesso!')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível cadastrar a fazenda: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha fazenda'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),

              Icon(
                Icons.agriculture,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 16),

              const Text(
                'Vamos cadastrar sua fazenda',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Essas informações serão usadas para organizar o seu rebanho.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 28),

              TextFormField(
                controller: _nomeController,
                textInputAction: TextInputAction.next,
                decoration: _decoracaoCampo(
                  label: 'Nome da fazenda',
                  icon: Icons.home_work_outlined,
                  hint: 'Ex.: Fazenda Baixinha',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da fazenda.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _cidadeController,
                textInputAction: TextInputAction.next,
                decoration: _decoracaoCampo(
                  label: 'Cidade',
                  icon: Icons.location_city_outlined,
                  hint: 'Ex.: Irecê',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _estadoController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: _decoracaoCampo(
                  label: 'Estado',
                  icon: Icons.map_outlined,
                  hint: 'Ex.: BA',
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _enderecoController,
                textInputAction: TextInputAction.next,
                decoration: _decoracaoCampo(
                  label: 'Endereço',
                  icon: Icons.location_on_outlined,
                  hint: 'Ex.: Zona Rural',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _telefoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _decoracaoCampo(
                  label: 'Telefone',
                  icon: Icons.phone_outlined,
                  hint: 'Opcional',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _observacoesController,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: _decoracaoCampo(
                  label: 'Observações',
                  icon: Icons.notes_outlined,
                  hint: 'Informações adicionais da fazenda',
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _salvando ? null : _salvarFazenda,
                  child: _salvando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text(
                          'Cadastrar fazenda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
