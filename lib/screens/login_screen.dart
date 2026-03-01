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

Widget _buildTab(String label, bool isActive, VoidCallback onTap) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.95),
                    const Color(0xFFE8F5E9).withOpacity(0.55),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(11),
          border: isActive
              ? Border.all(color: Colors.white.withOpacity(0.75))
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isActive
                ? const Color(0xFF0B3D2E)
                : const Color(0xFF2E6F5E).withOpacity(0.45),
          ),
        ),
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final titleText = _isLoginMode ? 'Giriş Yap' : 'Kayıt Ol';
    final isDark = Theme.of(context).brightness == Brightness.dark;

   return Scaffold(
  backgroundColor: const Color(0xFF2E6F5E), // header rengi, geçiş pürüzsüz
  body: Stack(
    children: [
      // ── HEADER — sabit arka plan ──
      Container(
        height: MediaQuery.of(context).size.height * 0.42,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B3D2E), Color(0xFF2E6F5E), Color(0xFF3A8A72)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Dekor daire — sağ üst
            Positioned(
              top: -60, right: -60,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA3E4A6).withOpacity(0.10),
                ),
              ),
            ),
            // Dekor daire — sol alt
            Positioned(
              bottom: 24, left: 20,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA3E4A6).withOpacity(0.07),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── TÜM İÇERİK scroll edilebilir ──
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header içerik
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo ikonu
                   Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // Yazılar — sol
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CaloriSense',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: const Color(0xFFA3E4A6).withOpacity(0.70),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 30, height: 1.2, letterSpacing: -0.3,
              color: Colors.white, fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(text: 'Hedefine\n'),
              TextSpan(
                text: 'odaklan.',
                style: TextStyle(
                  color: Color(0xFFA3E4A6),
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    // Logo — sağ
    Container(
      width: 78, height: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(
          color: Colors.white.withOpacity(0.18), width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.local_fire_department,
          color: Color(0xFFA3E4A6), size: 38,
        ),
      ),
    ),
  ],
),
                  ],
                ),
              ),

              // ── BODY KARTI — AppCard dili ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.97),
                      const Color(0xFFE8F5E9).withOpacity(0.50),
                    ],
                  ),
                 borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.80), width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.60),
                      blurRadius: 0,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tab
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E6F5E).withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF2E6F5E).withOpacity(0.10),
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            _buildTab('Giriş Yap', _isLoginMode, () {
                              if (!_isLoginMode && !_isLoading) {
                                setState(() {
                                  _isLoginMode = true;
                                  _emailTouched = false;
                                  _passwordTouched = false;
                                  _emailError = null;
                                  _passwordError = null;
                                  _errorText = null;
                                });
                              }
                            }),
                            _buildTab('Kayıt Ol', !_isLoginMode, () {
                              if (_isLoginMode && !_isLoading) {
                                setState(() {
                                  _isLoginMode = false;
                                  _emailTouched = false;
                                  _passwordTouched = false;
                                  _emailError = null;
                                  _passwordError = null;
                                  _errorText = null;
                                });
                              }
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Hata
                      if (_errorText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13, fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Email label
                      const Text('EMAİL',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: Color(0xFF2E6F5E), letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(
                          color: Color(0xFF0B3D2E),
                          fontWeight: FontWeight.w600, fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ornek@mail.com',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.28),
                            fontWeight: FontWeight.w500, fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.email_outlined,
                            color: Colors.black.withOpacity(0.28), size: 19),
                          errorText: _emailTouched ? _emailError : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.72), width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E6F5E), width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 16),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.disabled,
                        onChanged: (_) {
                          final err = Validators.email(_emailController.text.trim());
                          setState(() { _emailTouched = true; _emailError = err; });
                        },
                      ),
                      const SizedBox(height: 14),

                      // Şifre label
                      const Text('ŞİFRE',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: Color(0xFF2E6F5E), letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Şifre field
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(
                          color: Color(0xFF0B3D2E),
                          fontWeight: FontWeight.w600, fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.28),
                            fontWeight: FontWeight.w500, fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.lock_outline,
                            color: Colors.black.withOpacity(0.28), size: 19),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.black.withOpacity(0.28), size: 19,
                            ),
                          ),
                          errorText: _passwordTouched ? _passwordError : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.72), width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E6F5E), width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 16),
                        ),
                        obscureText: _obscurePassword,
                        autovalidateMode: AutovalidateMode.disabled,
                        onChanged: (_) {
                          final err = Validators.password(_passwordController.text);
                          setState(() { _passwordTouched = true; _passwordError = err; });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Ana buton
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: (!_canSubmit || _isLoading)
                              ? null : _submitEmailPassword,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: (!_canSubmit || _isLoading) ? null
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF0B3D2E), Color(0xFF2E6F5E)],
                                    ),
                              color: (!_canSubmit || _isLoading)
                                  ? const Color(0xFFDAEEE5) : null,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: (!_canSubmit || _isLoading) ? []
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF0B3D2E).withOpacity(0.28),
                                        blurRadius: 24, offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFFA3E4A6),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isLoginMode ? 'Giriş Yap' : 'Kayıt Ol',
                                          style: TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                            color: (!_canSubmit || _isLoading)
                                                ? const Color(0xFF8FB8A5)
                                                : const Color(0xFFA3E4A6),
                                          ),
                                        ),
                                        if (_canSubmit && !_isLoading)
                                          const Text('  →',
                                            style: TextStyle(
                                              fontSize: 16, color: Color(0xFFA3E4A6),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Ayraç
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(child: Container(height: 1,
                              color: const Color(0xFF2E6F5E).withOpacity(0.10))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('VEYA',
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2E6F5E).withOpacity(0.35),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(child: Container(height: 1,
                              color: const Color(0xFF2E6F5E).withOpacity(0.10))),
                          ],
                        ),
                      ),

                      // Google butonu
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.92),
                              const Color(0xFFE8F5E9).withOpacity(0.45),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.72), width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _isLoading ? null : _handleGoogleSignIn,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.language_rounded, size: 18,
                                  color: const Color(0xFF2E6F5E)),
                                const SizedBox(width: 10),
                                const Text('Google ile devam et',
                                  style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E6F5E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Alt linkler
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoginMode) ...[
                            GestureDetector(
                              onTap: (_isLoading || !_canForgotPassword)
                                  ? null : _forgotPassword,
                              child: Text('Şifremi unuttum',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: const Color(0xFF2E6F5E).withOpacity(0.50),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('·',
                                style: TextStyle(
                                  color: const Color(0xFF2E6F5E).withOpacity(0.20),
                                ),
                              ),
                            ),
                          ],
                          GestureDetector(
                            onTap: _isLoading ? null : () => setState(() {
                              _isLoginMode = !_isLoginMode;
                              _emailTouched = false;
                              _passwordTouched = false;
                              _emailError = null;
                              _passwordError = null;
                              _errorText = null;
                            }),
                            child: Text(
                              _isLoginMode ? 'Hesap oluştur' : 'Giriş yap',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: const Color(0xFF2E6F5E).withOpacity(0.50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'CaloriSense • Proje ödevi için tasarlanmış prototip arayüz',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.20),
                          fontSize: 11, fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }
}