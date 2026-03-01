import 'package:calorisense/screens/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/profile_service.dart';
import '../../screens/login_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/profile_setup_screen.dart';

class InitialRouter extends StatelessWidget {
  const InitialRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        // 1) User yok → login
        if (user == null) {
          return const LoginScreen();
        }

        // 2) Profil kontrolü stream → profil tamamlanınca otomatik geçiş
return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseFirestore.instance
      .collection('user_profiles')
      .doc(user.uid)
      .snapshots(),
  builder: (context, snap) {
    if (!snap.hasData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = snap.data!.data();
    if (data == null) return const ProfileSetupScreen();

    final isCompleted = data['is_profile_completed'] == true;
    final targetCalories = data['target_daily_calories'] ?? 0;

    if (!isCompleted || targetCalories == 0) {
      return const ProfileSetupScreen();
    }

    return const MainWrapper();
  },
);
      },
    );
  }
}
