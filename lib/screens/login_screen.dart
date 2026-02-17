// lib/screens/login_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import 'verify_email_screen.dart'; 
import '../utils/validators.dart';
import 'main_wrapper.dart';

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

  bool _isFormValid = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true; // true -> giriş, false -> kayıt
  bool _isLoading = false;
  String? _errorText;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  String? _emailError;
  String? _passwordError;

  bool get _canSubmitLogin =>
      Validators.email(_emailController.text.trim()) == null &&
      Validators.password(_passwordController.text) == null;

  bool get _canSubmitRegister =>
      Validators.email(_emailController.text.trim()) == null &&
      Validators.password(_passwordController.text) == null;

  // Login mi register mı fark etmeksizin bu yeterli:
  bool get _canSubmit => _isLoginMode ? _canSubmitLogin : _canSubmitRegister;

  bool get _canForgotPassword =>
      Validators.email(_emailController.text.trim()) == null;


  //Şifremi Unuttum
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    // Email boşsa kullanıcıyı yönlendir
    if (email.isEmpty) {
      setState(() => _errorText = "Şifre sıfırlamak için önce e-posta adresi gerekli.");
      return;
    }

    // Email formatı hatalıysa (senin validatorın varsa kullan)
    final emailErr = Validators.email(email);
    if (emailErr != null) {
      setState(() => _errorText = emailErr);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Eğer bu e-posta sistemimize kayıtlıysa şifre sıfırlama e-postası gönderildi. Gelen kutunu ve spam klasörünü kontrol etmeyi unutma."),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Şifre sıfırlama isteği gönderilemedi.";

      switch (e.code) {
        case 'user-not-found':
          msg = "Bu e-posta ile kayıtlı kullanıcı bulunamadı.";
          break;

        case 'no-password-provider':
          msg = "Bu e-posta Google/Apple ile kayıtlı. Şifre sıfırlama yok; Google ile giriş yap.";
          break;

        case 'invalid-email':
          msg = "Geçersiz e-posta adresi.";
          break;

        case 'too-many-requests':
          msg = "Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar dene.";
          break;

        default:
          msg = e.message ?? msg;
      }

      setState(() => _errorText = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        MaterialPageRoute(builder: (_) => const MainWrapper()),
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
        // ✅ Login: AuthService içinde emailVerified kontrolü var.
        // doğrulanmamışsa FirebaseAuthException(code: email-not-verified) fırlatır.
        user = await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (user != null && mounted) {
          await _afterAuthSuccess(context);
        }
      } else {
        // ✅ Register: doğrulama maili gönder + kullanıcıyı VERIFY ekranına al
        user = await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          signOutAfterSend: false, // ✅ IMPORTANT: Verify ekranı currentUser ister
        );

        if (!mounted) return;

        // Home/Setup'a gitme! (spam engel)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Doğrulama e-postası gönderildi. Lütfen mailindeki linke tıklayıp hesabını doğrula.",
            ),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu.';

      switch (e.code) {
        case 'email-not-verified':
          message = 'E-posta doğrulanmamış. Lütfen e-postanı doğrula.';
          // ✅ Doğrulama ekranına yönlendir
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
            );
          }
          break;

        case 'user-not-found':
          message = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
          break;

        case 'wrong-password':
          message = 'Şifre yanlış.';
          break;

        // ✅ Yeni Firebase sürümlerinde yanlış şifre / yanlış hesap için sık gelir
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
          message = 'E-posta veya şifre hatalı.';
          break;

        case 'user-disabled':
          message = 'Bu hesap devre dışı bırakılmış.';
          break;

        case 'too-many-requests':
          message = 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
          break;

        case 'email-already-in-use':
          message = 'Bu e-posta zaten kayıtlı.';
          break;

        case 'weak-password':
          message = 'Şifre çok zayıf (en az 6 karakter).';
          break;

        case 'invalid-email':
          message = 'Geçerli bir e-posta adresi gir.';
          break;

        default:
          message = 'Giriş başarısız: ${e.message ?? e.code}';
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
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
                                          color: const Color(0xFF2E6F5E),
                                        ),
                                  ),
                                  const SizedBox(height: 20),

                                  if (_errorText != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
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
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: const Icon(Icons.email_outlined),
                                      errorText: (_emailTouched ? _emailError : null),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    autovalidateMode: AutovalidateMode.disabled,
                                    onChanged: (_) {
                                      final err = Validators.email(_emailController.text.trim());
                                      setState(() {
                                        _emailTouched = true;
                                        _emailError = err;
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 12),

                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      labelText: 'Şifre',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      errorText: (_passwordTouched ? _passwordError : null),
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() => _obscurePassword = !_obscurePassword);
                                        },
                                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                        tooltip: _obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                                      ),
                                    ),
                                    obscureText: _obscurePassword,
                                    autovalidateMode: AutovalidateMode.disabled,
                                    onChanged: (_) {
                                      final err = Validators.password(_passwordController.text);
                                      setState(() {
                                        _passwordTouched = true;
                                        _passwordError = err;
                                      });
                                    },
                                  ),


                                  const SizedBox(height: 16),

                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFA3E4A6),
                                        foregroundColor: const Color(0xFF114432),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ).merge(
                                        ButtonStyle(
                                          shadowColor: MaterialStateProperty.all(
                                            Colors.black.withOpacity(0.18),
                                          ),
                                          elevation: MaterialStateProperty.resolveWith((states) {
                                            if (states.contains(MaterialState.pressed)) {
                                              return 2;
                                            }
                                            return 6;
                                          }),
                                        ),
                                      ),
                                      onPressed: (!_canSubmit || _isLoading) 
                                          ? null
                                          : _submitEmailPassword,
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
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
                                  if (_isLoginMode)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: (_isLoading || !_canForgotPassword) ? null : _forgotPassword,
                                        child: const Text("Şifremi unuttum"),
                                      ),
                                    ),



                                  const SizedBox(height: 8),
                                  TextButton(
                                    
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _isLoginMode = !_isLoginMode;

                                              // mod değişince alan hatalarını resetle
                                              _emailTouched = false;
                                              _passwordTouched = false;
                                              _emailError = null;
                                              _passwordError = null;
                                              _errorText = null;
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

                                  SizedBox(
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? const Color(0xFF2C2C2C)
                                            : Colors.white,
                                        foregroundColor: isDark ? Colors.white : Colors.black87,
                                        elevation: isDark ? 2 : 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      onPressed: _isLoading ? null : _handleGoogleSignIn,
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