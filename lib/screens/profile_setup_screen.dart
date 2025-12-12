// lib/screens/profile_setup_screen.dart
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';

// 🎨 Tasarım widget'ları
import '../widgets/app_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/pastel_button.dart';

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
      appBar: AppBar(
        title: const Text("Profil Bilgileri"),
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Seni biraz tanıyalım',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Profil bilgilerin, CaloriSense’in sana uygun günlük kalori hedefi belirlemesine yardımcı olur.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 24),

                  GlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: "Ad",
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: ageCtrl,
                          decoration: const InputDecoration(
                            labelText: "Yaş",
                            prefixIcon: Icon(Icons.cake_outlined),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: heightCtrl,
                          decoration: const InputDecoration(
                            labelText: "Boy (cm)",
                            prefixIcon: Icon(Icons.height),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: weightCtrl,
                          decoration: const InputDecoration(
                            labelText: "Kilo (kg)",
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: calorieCtrl,
                          decoration: const InputDecoration(
                            labelText: "Hedef Günlük Kalori",
                            prefixIcon: Icon(Icons.local_fire_department),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),

                        _saving
                            ? const Center(
                                child: SizedBox(
                                  height: 32,
                                  width: 32,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : PastelButton(
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
