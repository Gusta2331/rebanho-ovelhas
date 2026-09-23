import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class AuthService {
  SupabaseClient get _client => SupabaseService.client;

  Future<void> login({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> solicitarRecuperacaoSenha(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> concluirRecuperacaoSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: codigo.trim(),
      type: OtpType.recovery,
    );
    if (response.session == null) {
      throw const AuthException(
        'O código de recuperação é inválido ou expirou.',
      );
    }
    await _client.auth.updateUser(UserAttributes(password: novaSenha));
    await _client.auth.signOut();
  }

  Future<void> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'Entre novamente na sua conta para alterar a senha.',
      );
    }
    await _client.auth.signInWithPassword(email: email, password: senhaAtual);
    await _client.auth.updateUser(UserAttributes(password: novaSenha));
  }

  Future<bool> isLoggedIn() async {
    return _client.auth.currentSession != null;
  }

  Future<String?> getSavedEmail() async {
    return _client.auth.currentUser?.email;
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  User? get currentUser {
    return _client.auth.currentUser;
  }
}
