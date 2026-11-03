import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/worker.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';

/// Registration for a new worker (guard, cleaner, plumber, …) or a new
/// boss account. Worker accounts start 'pending' until the boss approves
/// them; boss accounts are active immediately.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  final _customRoleCtrl = TextEditingController();

  bool _isBoss = false;
  String _role = kWorkerRoles.first;
  bool _loading = false;
  String? _error;
  String? _nameErr, _phoneErr, _roleErr, _passErr, _confirmErr;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _customRoleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final role = _role == 'Другое' ? _customRoleCtrl.text.trim() : _role;

    final nameErr = validateName(name);
    final phoneErr = validatePhone(phone);
    final roleErr = (!_isBoss && _role == 'Другое') ? validateCustomRole(role) : null;
    final passErr = validatePassword(password);
    final confirmErr = password != _passwordConfirmCtrl.text ? 'Пароли не совпадают.' : null;
    setState(() {
      _nameErr = nameErr;
      _phoneErr = phoneErr;
      _roleErr = roleErr;
      _passErr = passErr;
      _confirmErr = confirmErr;
      _error = null;
    });
    if ([nameErr, phoneErr, roleErr, passErr, confirmErr].any((e) => e != null)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.register(
        name: name,
        phone: phone,
        password: password,
        role: _isBoss ? 'Начальник' : role,
        isBoss: _isBoss,
      );
      // On success, the app's top-level auth listener takes over routing
      // (to the pending-approval screen for a worker, or straight into
      // the boss panel for a boss). Just pop back to the auth flow.
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Я работник')),
                  ButtonSegment(value: true, label: Text('Я начальник')),
                ],
                selected: {_isBoss},
                onSelectionChanged: (s) => setState(() => _isBoss = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: 'Имя и фамилия', errorText: _nameErr),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Номер телефона', hintText: '+7 7XX XXX XX XX', errorText: _phoneErr),
              ),
              if (!_isBoss) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Должность'),
                  items: kWorkerRoles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? kWorkerRoles.first),
                ),
                if (_role == 'Другое') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customRoleCtrl,
                    decoration: InputDecoration(labelText: 'Укажите должность', errorText: _roleErr),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Пароль (6+ символов, буквы и цифры)', errorText: _passErr),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordConfirmCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Повторите пароль', errorText: _confirmErr),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Зарегистрироваться'),
              ),
              if (!_isBoss) ...[
                const SizedBox(height: 12),
                const Text(
                  'После регистрации нужно подождать, пока начальник одобрит '
                  'вашу заявку и назначит вас на объект.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
