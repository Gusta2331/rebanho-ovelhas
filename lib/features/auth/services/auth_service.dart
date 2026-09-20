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
