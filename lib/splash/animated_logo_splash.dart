import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedLogoSplash extends StatefulWidget {
  final Widget next;
  const AnimatedLogoSplash({super.key, required this.next});

  @override
  State<AnimatedLogoSplash> createState() => _AnimatedLogoSplashState();
}

class _AnimatedLogoSplashState extends State<AnimatedLogoSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // TABAK
  late final Animation<double> tabakOpacity;
  late final Animation<double> tabakScale;

  // FIRE
  late final Animation<double> fireOpacity;
  late final Animation<double> fireScale;
  late final Animation<Offset> fireSlide;
  late final Animation<double> fireBounce;

  // STARS
  late final Animation<double> starsOpacity;
  late final Animation<double> starsScale;
  late final Animation<double> starsTwinkle;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // TABAK: 0.00 - 0.35
    tabakOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.00, 0.35, curve: Curves.easeOut),
    );
    tabakScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.00, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // FIRE: 0.18 - 0.70
    fireOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.18, 0.70, curve: Curves.easeOut),
    );
    fireScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.18, 0.60, curve: Curves.easeOutBack),
      ),
    );
    fireSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.18, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    fireBounce = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );

    // STARS: 0.78 - 1.00
    starsOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.78, 1.00, curve: Curves.easeOut),
    );
    starsScale = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.78, 1.00, curve: Curves.easeOutBack),
      ),
    );
    starsTwinkle = Tween<double>(begin: 0.90, end: 1.05).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.86, 1.00, curve: Curves.easeInOut),
      ),
    );

    _c.forward();

    // Splash bitince next ekrana geç
    _navTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) => widget.next,
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final base = math.min(size.width, size.height);

    // boyutlar
    final tabakW = base * 0.62;
    final fireW = base * 0.32;
    final starsW = base * 0.18;

    // ✅ çakışmayı önleyen boşluklar (düzeltilmiş)
    final tabakDown  = base * 0.09;  // tabak aşağı
final fireUp      = base * 0.20; // fire daha yukarı
final starsUp     = base * 0.32; // stars daha yukarı
final starsRight  = base * 0.20; // stars daha sağa

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFEFF5F1),
                  Color(0xFFBFE2D7),
                ],
              ),
            ),
          ),
          // çok hafif overlay
          Container(color: Colors.white.withOpacity(0.04)),

          Center(
            child: SizedBox(
              width: tabakW * 1.5,
              height: tabakW * 1.8,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // TABAK
                  // TABAK
FadeTransition(
  opacity: tabakOpacity,
  child: Transform.translate(
    offset: Offset(0, tabakDown),
    child: ScaleTransition(
      scale: tabakScale,
      child: Image.asset(
        "assets/splash/splash_logo_tabak.png",
        width: tabakW,
        fit: BoxFit.contain,
      ),
    ),
  ),
),

                  // FIRE
                  FadeTransition(
                    opacity: fireOpacity,
                    child: SlideTransition(
                      position: fireSlide,
                      child: Transform.translate(
                        offset: Offset(0, -fireUp),
                        child: Transform.scale(
                          scale: fireScale.value *
                              (1.0 + 0.03 * math.sin(fireBounce.value * math.pi)),
                          child: Image.asset(
                            "assets/splash/splash_logo_fire.png",
                            width: fireW,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // STARS
                  FadeTransition(
                    opacity: starsOpacity,
                    child: Transform.translate(
                      offset: Offset(starsRight, -starsUp),
                      child: Transform.scale(
                        scale: starsScale.value * starsTwinkle.value,
                        child: Image.asset(
                          "assets/splash/splash_logo_stars.png",
                          width: starsW,
                          fit: BoxFit.contain,
                        ),
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
