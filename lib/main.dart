// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// ⭐ Tema
import 'theme/app_theme.dart';

// ⭐ Gate (yeni)
import 'auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final auth = FirebaseAuth.instance;

  // 🔐 SADECE email doğrulama DIŞINDA logout
  if (auth.currentUser == null ||
      auth.currentUser!.emailVerified == true) {
    await auth.signOut();
  }

  runApp(const CaloriSenseApp());
}


class CaloriSenseApp extends StatelessWidget {
  const CaloriSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaloriSense',
      debugShowCheckedModeBanner: false,

      // ⭐ Tema
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // ✅ Artık giriş noktası AuthGate
      // - user yok => LoginScreen
      // - emailVerified false => VerifyEmailScreen
      // - verified true => ProfileGate => Home/ProfileSetup
      home: const AuthGate(),
    );
  }
}
