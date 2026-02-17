import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import '../widgets/main_layout.dart'; // ✅ MainLayout eklendi

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _loading = false;
  String? _msg;

  // ✅ Polling
  Timer? _pollTimer;

  // ✅ Cooldown (20 sn)
  static const int _cooldownTotal = 20;
  int _cooldownLeft = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _checkAndRoute(silent: true);

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkAndRoute(silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRoute(silent: true); // tarayıcıdan geri dönünce anında kontrol
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  ButtonStyle _pastelPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFA3E4A6), // pastel green
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
          if (states.contains(MaterialState.disabled)) return 0;
          if (states.contains(MaterialState.pressed)) return 2;
          return 6;
        }),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return const Color(0xFFA3E4A6).withOpacity(0.45);
          }
          return const Color(0xFFA3E4A6);
        }),
      ),
    );
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _cooldownTotal);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownLeft <= 1) {
        t.cancel();
        setState(() => _cooldownLeft = 0);
      } else {
        setState(() => _cooldownLeft -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_cooldownLeft > 0 || _loading) return;

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _msg = "Aktif kullanıcı yok. Lütfen tekrar giriş yap.");
        _showSnack("Aktif kullanıcı yok. Lütfen tekrar giriş yap.");
        return;
      }

      await user.sendEmailVerification();

      setState(() => _msg = "Doğrulama e-postası tekrar gönderildi.");
      _showSnack("Doğrulama e-postası gönderildi.");
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        const text =
            "E-posta gecikmiş olabilir. Lütfen birkaç dakika sonra tekrar deneyin.";
        setState(() => _msg = text);
        _showSnack(text);
      } else {
        const text = "E-posta gönderilemedi. Lütfen daha sonra tekrar deneyin.";
        setState(() => _msg = text);
        _showSnack(text);
      }
    } catch (_) {
      const text = "E-posta gönderilemedi. Lütfen daha sonra tekrar deneyin.";
      setState(() => _msg = text);
      _showSnack(text);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ Otomatik kontrol + doğrulandıysa yönlendirme
  Future<void> _checkAndRoute({bool silent = false}) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      if (!silent) _msg = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await user.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final fresh = FirebaseAuth.instance.currentUser;

      if (fresh != null && fresh.emailVerified) {
        _showSnack("E-posta doğrulandı✅.Devam ediliyor...");

        _pollTimer?.cancel();

        final isCompleted = await ProfileService().isProfileCompleted();
        if (!mounted) return;

        if (isCompleted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
            (route) => false,
          );
        }
        return;
      }

      if (!silent && mounted) {
        const text =
            "Hâlâ doğrulanmamış. Maildeki linke tıkla, otomatik yönlendireceğim.";
        setState(() => _msg = text);
        _showSnack(text);
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _msg = "Kontrol edilemedi: $e");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "";

    // ✅ MainLayout ile sarmalanarak arka plan ve AppBar yönetimi ona devredildi
    return MainLayout(
      title: "E-posta Doğrulama",
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // Bilgi Kartı (Bento Stili)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.mark_email_unread_outlined, size: 64, color: Color(0xFF2E6F5E)),
                    const SizedBox(height: 16),
                    Text(
                      "Hesabını doğrulaman gerekiyor.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF2E6F5E), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: _pastelPrimaryButtonStyle(),
                onPressed: (_loading || _cooldownLeft > 0) ? null : _resend,
                child: Text(
                  _cooldownLeft > 0
                      ? "Tekrar göndermek için $_cooldownLeft sn"
                      : "Doğrulama e-postasını tekrar gönder",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              "Doğrulama tamamlandığında otomatik olarak devam edeceksin.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),

            const SizedBox(height: 24),

            TextButton(
              onPressed: _loading ? null : _logout,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E6F5E),
              ),
              child: const Text(
                "Çıkış yap",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),

            const Spacer(),
            if (_loading) 
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E6F5E)),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}