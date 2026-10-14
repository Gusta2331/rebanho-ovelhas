import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/support_service.dart';

class FaleComOviGestaoPage extends StatefulWidget {
  const FaleComOviGestaoPage({super.key});

  @override
  State<FaleComOviGestaoPage> createState() => _FaleComOviGestaoPageState();
}

class _FaleComOviGestaoPageState extends State<FaleComOviGestaoPage> {
  final _formKey = GlobalKey<FormState>();
  final _assuntoController = TextEditingController();
  final _mensagemController = TextEditingController();
  final _picker = ImagePicker();
  final _supportService = SupportService();

  String _tipo = 'bug';
  List<XFile> _imagens = [];
  bool _enviando = false;

  static const _tipos = <String, String>{
    'bug': 'Relatar um erro ou problema',
    'sugestao': 'Sugerir uma melhoria',
    'duvida': 'Tirar uma dúvida',
    'outro': 'Outro assunto',
  };

  @override
  void dispose() {
    _assuntoController.dispose();
    _mensagemController.dispose();
    super.dispose();
  }

  Future<void> _adicionarImagens() async {
    if (_imagens.length >= 3) {
      _mostrarAviso('Você pode anexar no máximo 3 imagens.');
      return;
    }

    try {
      final selecionadas = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (!mounted || selecionadas.isEmpty) return;

      final novas = <XFile>[];
      for (final imagem in selecionadas) {
        if (_imagens.length + novas.length >= 3) break;
        final bytes = await imagem.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          _mostrarAviso('A imagem "${imagem.name}" ultrapassa 5 MB e não foi adicionada.');
          continue;
        }
        novas.add(imagem);
      }

      if (novas.isNotEmpty && mounted) {
        setState(() => _imagens = [..._imagens, ...novas]);
      }
    } catch (_) {
      _mostrarAviso('Não foi possível abrir a galeria. Tente novamente.');
    }
  }

  void _removerImagem(int indice) {
    setState(() => _imagens.removeAt(indice));
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      final resultado = await _supportService.enviarMensagem(
        tipo: _tipo,
        assunto: _assuntoController.text,
        mensagem: _mensagemController.text,
        imagens: _imagens,
      );

      if (!mounted) return;
      _mostrarAviso(
        resultado.notificationSent
            ? 'Mensagem enviada! Obrigado por ajudar a melhorar o OviGestão.'
            : 'Mensagem registrada, mas o aviso por e-mail falhou. Seu relato foi salvo e não precisa ser enviado novamente.',
      );
      Navigator.of(context).pop();
    } catch (erro) {
      if (!mounted) return;
      _mostrarAviso(_mensagemErro(erro));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString();
    if (texto.contains('5 MB') || texto.contains('JPG, PNG')) {
      return texto.replaceFirst('Exception: ', '');
    }
    if (texto.contains('SocketException') || texto.contains('Failed host lookup')) {
      return 'Sem conexão com a internet. Confira sua conexão e tente novamente.';
    }
    return 'Não foi possível enviar a mensagem. Confira a conexão e tente novamente.';
  }

  void _mostrarAviso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fale com o OviGestão')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.support_agent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Como podemos ajudar?',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Conte o que aconteceu ou compartilhe uma ideia. Se quiser, anexe imagens para nos ajudar a entender.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de contato',
                  border: OutlineInputBorder(),
                ),
                items: _tipos.entries
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.key,
                        child: Text(item.value),
                      ),
                    )
                    .toList(),
                onChanged: _enviando
                    ? null
                    : (valor) {
                        if (valor != null) setState(() => _tipo = valor);
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _assuntoController,
                enabled: !_enviando,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Assunto',
                  hintText: 'Ex.: erro ao cadastrar animal',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'Informe o assunto.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mensagemController,
                enabled: !_enviando,
                minLines: 5,
                maxLines: 8,
                maxLength: 3000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Mensagem',
                  hintText: 'Descreva o problema, sua dúvida ou sugestão...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'Escreva uma mensagem.';
                  }
                  if (valor.trim().length < 5) {
                    return 'A mensagem precisa ter pelo menos 5 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _enviando ? null : _adicionarImagens,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Adicionar imagens (${_imagens.length}/3)'),
              ),
              if (_imagens.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Anexos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < _imagens.length; i++)
                      _MiniaturaImagem(
                        key: ValueKey(_imagens[i].path),
                        imagem: _imagens[i],
                        onRemover: _enviando ? null : () => _removerImagem(i),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_enviando ? 'Enviando...' : 'Enviar mensagem'),
              ),
              const SizedBox(height: 12),
              Text(
                'Sua mensagem e os anexos serão enviados com segurança para a equipe do OviGestão.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniaturaImagem extends StatelessWidget {
  const _MiniaturaImagem({
    super.key,
    required this.imagem,
    required this.onRemover,
  });

  final XFile imagem;
  final VoidCallback? onRemover;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: imagem.readAsBytes(),
      builder: (context, snapshot) {
        return SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: snapshot.hasData
                    ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                    : const ColoredBox(
                        color: Color(0xFFE8E8E8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
              if (onRemover != null)
                Positioned(
                  top: 3,
                  right: 3,
                  child: IconButton.filled(
                    tooltip: 'Remover imagem',
                    onPressed: onRemover,
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
