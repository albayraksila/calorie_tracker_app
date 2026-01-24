import 'package:calorisense/screens/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

        // 2) Profil kontrolü async → FutureBuilder
        return FutureBuilder<bool>(
          future: ProfileService().isProfileCompleted(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isCompleted = snap.data!;
            if (!isCompleted) {
              return const ProfileSetupScreen();
            }

            return const MainWrapper();
          },
        );
      },
    );
  }
}
