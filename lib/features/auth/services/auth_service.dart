import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _loggedInKey = 'is_logged_in';
  static const String _emailKey = 'saved_email';

  Future<void> saveLogin(String email) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_emailKey, email);
    await preferences.setBool(_loggedInKey, true);
  }

  Future<bool> isLoggedIn() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool(_loggedInKey) ?? false;
  }

  Future<String?> getSavedEmail() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getString(_emailKey);
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_loggedInKey, false);
  }
}
