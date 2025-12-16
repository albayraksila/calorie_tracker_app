// lib/screens/verify_email_screen.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text("E-posta Doğrulama")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Hesabını doğrulaman gerekiyor.\n\nE-posta: $email"),
            const SizedBox(height: 12),

    

            const SizedBox(height: 12),

            SizedBox(
              height: 48,
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

            const SizedBox(height: 8),

            Text(
              "Doğrulama tamamlandığında otomatik olarak devam edeceksin.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _loading ? null : _logout,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E6F5E),
              ),
              child: const Text(
                "Çıkış yap",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),

            const Spacer(),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
