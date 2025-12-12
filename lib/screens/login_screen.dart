// lib/screens/login_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoginMode = true; // true -> giriş, false -> kayıt
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Giriş / kayıt BAŞARILI olduktan sonra ortak akış:
  /// 1) Firestore'dan profil tamam mı diye bak
  /// 2) Tamamsa -> HomeScreen
  /// 3) Değilse -> ProfileSetupScreen (zorunlu)
  Future<void> _afterAuthSuccess(BuildContext context) async {
    final isCompleted = await ProfileService().isProfileCompleted();

    if (!mounted) return;

    if (isCompleted) {
      // Profil hazır -> direkt Home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // Profil yok / eksik -> zorunlu profil ekranı
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      User? user;
      if (_isLoginMode) {
        user = await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        user = await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (user != null && mounted) {
        await _afterAuthSuccess(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu.';

      if (e.code == 'user-not-found') {
        message = 'Bu email ile kayıtlı kullanıcı bulunamadı.';
      } else if (e.code == 'wrong-password') {
        message = 'Şifre yanlış.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Bu email zaten kayıtlı.';
      } else if (e.code == 'weak-password') {
        message = 'Şifre çok zayıf (en az 6 karakter).';
      } else if (e.code == 'invalid-email') {
        message = 'Geçerli bir email adresi gir.';
      }

      setState(() {
        _errorText = message;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Beklenmeyen bir hata oluştu: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        await _afterAuthSuccess(context);
      }
    } catch (e) {
      setState(() {
        _errorText = 'Google ile giriş başarısız: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isLoginMode ? 'Giriş Yap' : 'Kayıt Ol';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 🌈 Pastel gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0xFFC8EEAE), // #c8eeae
                  Color(0xFF94E9DF), // #94e9df
                ],
              ),
            ),
          ),

          // 🧊 Glassmorphism card + içerik
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / ikon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                            isDark ? 0.14 : 0.25,
                          ),
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Uygulama adı
                      Text(
                        'CaloriSense',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Akıllı kalori ve profil takibi',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                      const SizedBox(height: 24),

                      // 🧊 Glassmorphism card (blur + yarı şeffaf)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: (isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white)
                                  .withOpacity(0.70),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    titleText,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2E6F5E), // 🌿 koyu mint / tema uyumlu
                                        ),
                                  ),
                                  const SizedBox(height: 16),

                                  if (_errorText != null)
                                    Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50
                                            .withOpacity(isDark ? 0.22 : 1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _errorText!,
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),

                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon:
                                          Icon(Icons.email_outlined),
                                    ),
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Email gir.';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Geçerli bir email gir.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Şifre',
                                      prefixIcon:
                                          Icon(Icons.lock_outline),
                                    ),
                                    obscureText: true,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Şifre gir.';
                                      }
                                      if (value.trim().length < 6) {
                                        return 'Şifre en az 6 karakter olmalı.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // 🎨 Pastel primary buton (soft shadow)
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFA3E4A6),
                                        foregroundColor:
                                            const Color(0xFF114432),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ).merge(
                                        ButtonStyle(
                                          shadowColor:
                                              MaterialStateProperty.all(
                                            Colors.black.withOpacity(0.18),
                                          ),
                                          elevation: MaterialStateProperty
                                              .resolveWith((states) {
                                            if (states.contains(
                                                MaterialState.pressed)) {
                                              return 2;
                                            }
                                            return 6;
                                          }),
                                        ),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : _submitEmailPassword,
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              titleText,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _isLoginMode = !_isLoginMode;
                                            });
                                          },
                                    child: Text(
                                      _isLoginMode
                                          ? 'Hesabın yok mu? Kayıt ol'
                                          : 'Zaten hesabın var mı? Giriş yap',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 12),

                                  // Google butonu (daha nötr)
                                  SizedBox(
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? const Color(0xFF2C2C2C)
                                            : Colors.white,
                                        foregroundColor: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        elevation: isDark ? 2 : 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : _handleGoogleSignIn,
                                      icon: const Icon(Icons.login),
                                      label: const Text('Google ile devam et'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'CaloriSense • Proje ödevi için tasarlanmış prototip arayüz',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
