// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_setup_screen.dart'; // ✅ yeni ekran
import 'services/profile_service.dart';     // ✅ profil servisi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CalorieTrackerApp());
}

class CalorieTrackerApp extends StatelessWidget {
  const CalorieTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calorie Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1) Firebase Auth dinleme hâlâ bağlanıyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2) Kullanıcı yok → Login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3) Kullanıcı var → Profil tamam mı kontrol et
        return FutureBuilder<bool>(
          future: ProfileService().isProfileCompleted(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Bir hata oluştu: ${profileSnap.error}'),
                ),
              );
            }

            final isCompleted = profileSnap.data ?? false;

            if (!isCompleted) {
              // ✅ PROFİL EKSİK → ZORUNLU PROFİL EKRANI
              return const ProfileSetupScreen();
            }

            // ✅ PROFİL TAMAM → HOME
            return const HomeScreen();
          },
        );
      },
    );
  }
}
