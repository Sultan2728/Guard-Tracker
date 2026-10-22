import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// A simple full-screen message with a logout button, used for every
/// "you can't use the app yet" state: pending approval, rejected, or
/// approved but not yet assigned to a site. Which one to show is decided
/// by the caller — this widget just displays it.
class StatusScreen extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;

  const StatusScreen({super.key, required this.emoji, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: () => AuthService().signOut(),
                  child: const Text('Выйти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
