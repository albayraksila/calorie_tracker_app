// lib/screens/profile_details_screen.dart
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../models/user_profile.dart';
import 'profile_setup_screen.dart';

// 🎨 Tasarım widget'ları
import '../widgets/app_background.dart';
import '../widgets/glass_card_old.dart';
import '../widgets/pastel_button.dart';
import '../widgets/glass_app_bar.dart';

class ProfileDetailsScreen extends StatelessWidget {
  const ProfileDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,

      // ✅ AppBar arkasında arka plan görünsün (cam efekt için şart)
      extendBodyBehindAppBar: true,

      appBar: const GlassAppBar(
        title: "Profil Bilgilerim",
      ),

      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            // ✅ AppBar’ın üstüne binmesin diye tek sefer üst padding
            padding: const EdgeInsets.fromLTRB(24, kToolbarHeight + 32, 24, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FutureBuilder<UserProfile?>(
                future: ProfileService().getProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Bir hata oluştu",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${snapshot.error}",
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  final profile = snapshot.data;

                  if (profile == null) {
                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Profil bulunamadı",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Profil bilgilerin bulunamadı. Lütfen profilini doldur.",
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          PastelButton(
                            text: "Profilimi doldur",
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileSetupScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Profil Bilgilerin",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text("Ad: ${profile.name}"),
                        Text("Yaş: ${profile.age}"),
                        Text("Boy: ${profile.heightCm} cm"),
                        Text("Kilo: ${profile.weightKg} kg"),
                        Text("Hedef Günlük Kalori: ${profile.targetDailyCalories}"),
                        Text(
                          'Profil Tamamlandı: ${profile.isProfileCompleted ? "Evet" : "Hayır"}',
                        ),
                        const SizedBox(height: 24),
                        PastelButton(
                          text: "Düzenle",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileSetupScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
