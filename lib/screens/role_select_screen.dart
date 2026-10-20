import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guard_screen.dart';
import 'boss_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛡️ Зона объекта')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Выберите, кто вы',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _pickGuard,
              child: const Text('Я охранник', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _pickBoss,
              child: const Text('Я начальник', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Охранник включает слежение на смене — приложение сообщает '
              'начальнику, когда он входит в зону объекта или покидает её.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _pickGuard() async {
    final slot = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Выберите номер'),
        children: [1, 2, 3]
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, s),
                  child: Text('Охранник $s'),
                ))
            .toList(),
      ),
    );
    if (slot == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'guard');
    await prefs.setInt('slot', slot);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GuardScreen(slot: slot)),
    );
  }

  void _pickBoss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'boss');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BossScreen()));
  }
}
