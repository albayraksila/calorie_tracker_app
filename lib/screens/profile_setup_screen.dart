// lib/screens/profile_setup_screen.dart
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';

// 🎨 Tasarım widget'ları
import '../widgets/app_background.dart';
import '../widgets/glass_card_old.dart';
import '../widgets/pastel_button.dart';
import '../widgets/glass_app_bar.dart';


class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final calorieCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    ageCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    calorieCtrl.dispose();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true, // ✅ EKLENDİ
      appBar: const GlassAppBar(title: "Profil Oluşturma"),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ✅ ÜST KISIM SCROLL
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Text(
                            'Seni biraz tanıyalım✨',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Color(0xFF2E6F5E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Profil bilgilerin, CaloriSense’in sana uygun günlük kalori hedefi belirlemesine yardımcı olur.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 32),

                          GlassCard(
                            child: Column(
                              children: [
                                TextField(
                                  controller: nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Adın",
                                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF2E6F5E)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: ageCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Yaşın",
                                    prefixIcon: Icon(Icons.cake_outlined, color: Color(0xFF2E6F5E)),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: heightCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Boyun (cm)",
                                    prefixIcon: Icon(Icons.height, color: Color(0xFF2E6F5E)),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: weightCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Kilon (kg)",
                                    prefixIcon:
                                        Icon(Icons.monitor_weight_outlined, color: Color(0xFF2E6F5E)),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: calorieCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Hedef Günlük Kalorin",
                                    prefixIcon:
                                        Icon(Icons.local_fire_department, color: Color(0xFF2E6F5E)),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // ✅ ALT: SABİT BUTON (Overflow biter)
                  _saving
                      ? const Center(
                          child: SizedBox(
                            height: 32,
                            width: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.only(
                            top: 8,
                            bottom: 8 + MediaQuery.of(context).viewPadding.bottom,
                          ),
                          child: PastelButton(
                            text: "Kaydet ve Devam Et",
                            onPressed: () async {
                              setState(() => _saving = true);

                              final profile = UserProfile(
                                name: nameCtrl.text.trim(),
                                age: int.tryParse(ageCtrl.text) ?? 0,
                                heightCm: int.tryParse(heightCtrl.text) ?? 0,
                                weightKg:
                                    double.tryParse(weightCtrl.text) ?? 0,
                                targetDailyCalories:
                                    int.tryParse(calorieCtrl.text) ?? 0,
                                isProfileCompleted: true,
                              );

                              await ProfileService().saveProfile(profile);

                              if (!mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );

                              if (mounted) {
                                setState(() => _saving = false);
                              }
                            },
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