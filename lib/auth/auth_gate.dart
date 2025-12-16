// lib/auth/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/verify_email_screen.dart';
import 'profile_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Email verified durumunu güncelle
        return FutureBuilder<void>(
          future: user.reload(),
          builder: (context, reloadSnap) {
            if (reloadSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final freshUser = FirebaseAuth.instance.currentUser;
            if (freshUser == null) return const LoginScreen();

            if (!freshUser.emailVerified) {
              return const VerifyEmailScreen();
            }

            return const ProfileGate();
          },
        );
      },
    );
  }
}
