// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';

// ⭐ Yeni eklediklerimiz
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🧪 ÖDEV / TEST: Uygulama HER açıldığında logout
  await FirebaseAuth.instance.signOut();

  runApp(const CaloriSenseApp());
}

class CaloriSenseApp extends StatelessWidget {
  const CaloriSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaloriSense',
      debugShowCheckedModeBanner: false,

      // ⭐ Burada tema yapımızı giydiriyoruz:
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      // ⭐ Kullanıcıya tema seçtirmiyoruz → ödevin istediği
      themeMode: ThemeMode.system,

      home: const LoginScreen(),
    );
  }
}