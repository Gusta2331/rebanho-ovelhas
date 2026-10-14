import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';

class SupportMessageResult {
  const SupportMessageResult({required this.notificationSent});

  final bool notificationSent;
}

class SupportService {
  static const _bucket = 'support-attachments';
  static const _uuid = Uuid();

  SupabaseClient get _client => SupabaseService.client;

  Future<SupportMessageResult> enviarMensagem({
    required String tipo,
    required String assunto,
    required String mensagem,
    required List<XFile> imagens,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre na sua conta para enviar uma mensagem.');
    }

    if (imagens.length > 3) {
      throw Exception('Você pode anexar no máximo 3 imagens.');
    }

    final mensagemId = _uuid.v4();
    final caminhos = <String>[];

    try {
      for (final imagem in imagens) {
        final bytes = await imagem.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw Exception('Cada imagem deve ter no máximo 5 MB.');
        }

        final extensao = _extensaoPermitida(imagem.name);
        final caminho = '${user.id}/$mensagemId/${_uuid.v4()}.$extensao';
        final mimeType = switch (extensao) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };

        await _client.storage.from(_bucket).uploadBinary(
              caminho,
              Uint8List.fromList(bytes),
              fileOptions: FileOptions(
                contentType: mimeType,
                upsert: false,
              ),
            );
        caminhos.add(caminho);
      }

      await _client.from('mensagens_suporte').insert({
        'id': mensagemId,
        'usuario_id': user.id,
        'tipo': tipo,
        'assunto': assunto.trim(),
        'mensagem': mensagem.trim(),
        'anexos': caminhos,
      });
    } catch (_) {
      if (caminhos.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(caminhos);
        } catch (_) {
          // Mantém o erro original; os anexos continuam privados no bucket.
        }
      }
      rethrow;
    }

    try {
      await _client.functions.invoke(
        'notify-support-message',
        body: {'message_id': mensagemId},
      );
      return const SupportMessageResult(notificationSent: true);
    } catch (_) {
      // A mensagem já está salva. Uma falha de e-mail não deve apagar o relato.
      return const SupportMessageResult(notificationSent: false);
    }
  }

  String _extensaoPermitida(String nome) {
    final extensao = nome.contains('.') ? nome.split('.').last.toLowerCase() : '';
    if (extensao == 'png') return 'png';
    if (extensao == 'webp') return 'webp';
    if (extensao == 'jpg' || extensao == 'jpeg') return 'jpg';
    throw Exception('Use imagens JPG, PNG ou WEBP.');
  }
}
