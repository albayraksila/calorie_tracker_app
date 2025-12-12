// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_details_screen.dart'; // ✅ Profil ekranı

// 🎨 Yeni eklediğimiz tasarım widget'ları
import '../widgets/app_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/pastel_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // 🎨 Arka planı Flutter temasına bırakmıyoruz, kendi gradientimizi kullanacağız
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // İstersen sonra burayı 'CaloriSense - Home' yaparız,
        // şu an senin istediğin gibi diğer her şey aynen kalsın.
        title: const Text('Calorie Tracker - Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfileDetailsScreen(), // ✅ Profil Bilgilerim
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üstte hoş geldin mesajı
                  Text(
                    'Hoş geldin, ${user?.email ?? "kullanıcı"}!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Günlük kalori takibini ve profil bilgilerini buradan yönetebilirsin.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🧊 Glassmorphism kart: günlük özet (şimdilik placeholder)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bugünkü durumun',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          // TODO: Gerçek verilerle doldurulacak
                          'Alınan kalori: 0 kcal\n'
                          'Hedef: 0 kcal\n'
                          'Kalan: 0 kcal',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🧊 Glassmorphism kart: hızlı aksiyonlar
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Hızlı aksiyonlar',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 🎨 Pastel buton: ileride "Yemek ekle" gibi aksiyonlar için
                        PastelButton(
                          text: 'Yemek ekle',
                          onPressed: () {
                            // TODO: Yemek ekleme ekranına yönlendirme
                          },
                        ),
                        const SizedBox(height: 8),

                        // Profil & hedef düzenleme (şimdilik profil detayları ekranına gitsin istersen)
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileDetailsScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.white : Colors.black87,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child:
                              const Text('Profil & hedef bilgilerini görüntüle'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
