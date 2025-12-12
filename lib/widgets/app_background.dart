import 'dart:ui';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // 🌈 Pastel radial gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFFC8EEAE),
                Color(0xFF94E9DF),
              ],
            ),
          ),
        ),

        // (Opsiyonel) arka plana hafif blur ekleyebiliriz
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 0 : 0,
            sigmaY: isDark ? 0 : 0,
          ),
          child: Container(color: Colors.transparent),
        ),

        // Ekranın gerçek içeriği
        SafeArea(child: child),
      ],
    );
  }
}
