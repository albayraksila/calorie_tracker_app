// lib/screens/profile_details_screen.dart
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../models/user_profile.dart';
import 'profile_setup_screen.dart';

class ProfileDetailsScreen extends StatelessWidget {
  const ProfileDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profil Bilgilerim")),
      body: FutureBuilder<UserProfile?>(
        future: ProfileService().getProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Bir hata oluştu: ${snapshot.error}"),
            );
          }

          final profile = snapshot.data;

          if (profile == null) {
            return const Center(
              child: Text("Profil bulunamadı. Lütfen profilinizi doldurun."),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ad: ${profile.name}"),
                Text("Yaş: ${profile.age}"),
                Text("Boy: ${profile.heightCm} cm"),
                Text("Kilo: ${profile.weightKg} kg"),
                Text("Hedef Günlük Kalori: ${profile.targetDailyCalories}"),
                Text("Profil Tamamlandı: ${profile.isProfileCompleted ? "Evet" : "Hayır"}"),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileSetupScreen(), // düzenleme için aynı form
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Düzenle"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
