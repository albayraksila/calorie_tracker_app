// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // ⭐ Tema yönetimi için eklendi

import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ⭐ Tema & Servis
import 'theme/app_theme.dart';
import 'services/theme_service.dart'; // ⭐ ThemeService eklendi

// ⭐ Gate (yeni)
import 'auth/auth_gate.dart';
// ⭐ Splash
import 'splash/animated_logo_splash.dart';

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

  runApp(
    // ⭐ Uygulama başladığında tema servisini dinlemeye başlar
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const CaloriSenseApp(),
    ),
  );
}

class CaloriSenseApp extends StatelessWidget {
  const CaloriSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ⭐ Aktif tema modunu servisten çeker
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'CaloriSense',
      debugShowCheckedModeBanner: false,

      // ⭐ Tema Ayarları
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode, // ✅ Sistem yerine servisten gelen tercih

      // ✅ Artık giriş noktası AuthGate
      // - user yok => LoginScreen
      // - emailVerified false => VerifyEmailScreen
      // - verified true => ProfileGate => Home/ProfileSetup
      home: AnimatedLogoSplash(
        next: const AuthGate(),
      ),
    );
  }
}