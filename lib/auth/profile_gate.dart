// lib/auth/profile_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/profile_setup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_wrapper.dart';

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snap.data?.data();

        // Doküman yoksa: daha hiç profil oluşturulmamış -> Setup
        if (data == null) return const ProfileSetupScreen();

        final completed = (data['is_profile_completed'] == true);
        return completed ? const MainWrapper() : const ProfileSetupScreen();
      },
    );
  }
}
