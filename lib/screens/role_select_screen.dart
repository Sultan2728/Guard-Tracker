import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'site_select_screen.dart';
import 'boss_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛡️ Охранный Трекер')),
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SiteSelectScreen()),
              ),
              child: const Text('Я охранник', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () => _pickBoss(context),
              child: const Text('Я начальник', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Охранник перед сменой выбирает объект, на котором сегодня '
              'работает, — приложение сообщает начальнику, когда он входит '
              'в зону объекта или покидает её.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _pickBoss(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'boss');
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BossScreen()));
  }
}
