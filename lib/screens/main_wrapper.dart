// ignore_for_file: deprecated_member_use

import 'package:calorisense/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/main_layout.dart'; // ✅ MainLayout import edildi
import 'home_screen.dart';
import 'daily_tracker_screen.dart';
import 'stats_screen.dart';
import 'water_tracker_screen.dart';
import '../core/navigation/main_tab_scope.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  // Navigasyon sekmeleri
  final List<Widget> _pages = [
    const HomeScreen(),
    const DailyTrackerScreen(),
    const StatsScreen(),
    const WaterTrackerScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ MainLayout tüm navigasyonun en dışına eklendi. 
    // showAppBar: false yapıyoruz çünkü her sayfa (Home, Daily vb.) 
    // kendi AppBar'ını MainLayout içinden yönetiyor.
    return MainTabScope(
  currentIndex: _currentIndex,
  setIndex: (index) => setState(() => _currentIndex = index),
  child: MainLayout(
    showAppBar: false,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.2)
              : const Color(0xFF128D64).withOpacity(0.05),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.white.withOpacity(0.2),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF2E6F5E),
          unselectedItemColor: isDark ? Colors.white38 : Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Ana Sayfa"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Günlük"),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "İstatistik"),
            BottomNavigationBarItem(icon: Icon(Icons.opacity), label: "Su"),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: "Ayarlar"),
          ],
        ),
      ),
    ),
  ),
);

  }
}