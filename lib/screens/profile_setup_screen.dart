import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profil Bilgileri")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Ad"),
            ),
            TextField(
              controller: ageCtrl,
              decoration: const InputDecoration(labelText: "Yaş"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: heightCtrl,
              decoration: const InputDecoration(labelText: "Boy (cm)"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: weightCtrl,
              decoration: const InputDecoration(labelText: "Kilo (kg)"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: calorieCtrl,
              decoration: const InputDecoration(labelText: "Hedef Günlük Kalori"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _saving
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      setState(() => _saving = true);

                      final profile = UserProfile(
                        name: nameCtrl.text.trim(),
                        age: int.tryParse(ageCtrl.text) ?? 0,
                        heightCm: int.tryParse(heightCtrl.text) ?? 0,
                        weightKg: double.tryParse(weightCtrl.text) ?? 0,
                        targetDailyCalories: int.tryParse(calorieCtrl.text) ?? 0,
                        isProfileCompleted: true,
                      );

                      await ProfileService().saveProfile(profile);

                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    child: const Text("Kaydet ve Devam Et"),
                  ),
          ],
        ),
      ),
    );
  }
}
