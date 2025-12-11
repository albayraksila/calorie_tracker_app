// lib/screens/profile_setup_screen.dart
import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Bilgilerim')),
      body: const Center(
        child: Text('Profil setup ekranı (2. görevde doldurulacak).'),
      ),
    );
  }
}
