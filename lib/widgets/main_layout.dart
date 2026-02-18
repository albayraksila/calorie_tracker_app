// widgets/main_layout.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle; 
  final List<Widget>? actions;
  final bool showAppBar;

  const MainLayout({
    super.key,
    required this.child,
    this.title,
    this.subtitle, 
    this.actions,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.maybeOf(context)?.padding.bottom ?? 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1113) : const Color(0xFFFBFBF9),
      body: Stack(
        children: [
          // Arka Plan
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? [const Color(0xFF0F1113), const Color(0xFF1C1F22)]
                    : [const Color(0xFFFBFBF9), const Color(0xFFE8F5E9).withOpacity(0.5)],
                ),
              ),
            ),
          ),

          // Ana Kaydırma Yapısı
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (showAppBar)
                SliverAppBar(
                  expandedHeight: 80.0,
                  collapsedHeight: 60.0,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: FlexibleSpaceBar(
                        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
                        centerTitle: false,
                         title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title ?? "",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A4D40),
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : const Color(0xFF1A4D40))
                    .withOpacity(0.65),
              ),
            ),
          ),
      ],
    ),
                      ),
                    ),
                  ),
                  actions: actions ?? [],
                ),

              // 🟢 KRİTİK ÇÖZÜM:
              // hasScrollBody: false diyerek Column yapısının Sliver içinde 
              // dikeyde yayılmasını ve boyutunun hesaplanmasını zorunlu kılıyoruz.
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding + 30),
                  child: child,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}