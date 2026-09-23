import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/services/auth_service.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _hidePasswords = true;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.alterarSenha(
        senhaAtual: _currentPassword.text,
        novaSenha: _newPassword.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('AuthException: ', '');
        _busy = false;
      });
    }
  }

  String? _validarNovaSenha(String? value) =>
      (value ?? '').length < 8 ? 'Use pelo menos 8 caracteres.' : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Alterar senha'),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPassword,
                enabled: !_busy,
                obscureText: _hidePasswords,
                decoration: const InputDecoration(
                  labelText: 'Senha atual',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.isEmpty ?? true)
                    ? 'Informe sua senha atual.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPassword,
                enabled: !_busy,
                obscureText: _hidePasswords,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _hidePasswords = !_hidePasswords),
                    icon: Icon(
                      _hidePasswords ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: _validarNovaSenha,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmation,
                enabled: !_busy,
                obscureText: _hidePasswords,
                decoration: const InputDecoration(
                  labelText: 'Confirme a nova senha',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value != _newPassword.text
                    ? 'As senhas não conferem.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Salvar'),
      ),
    ],
  );
}
