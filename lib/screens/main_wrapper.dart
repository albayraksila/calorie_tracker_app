import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'daily_tracker_screen.dart';
import 'profile_details_screen.dart';
import 'stats_screen.dart';
import 'water_tracker_screen.dart';

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
    const ProfileDetailsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack sayfaların durumunu korur (sekme değiştirince veri kaybolmaz)
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF128D64).withOpacity(0.1),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white.withOpacity(0.1), // Glassmorphism etkisi
          selectedItemColor: const Color(0xFF2E6F5E),
          unselectedItemColor: Colors.grey,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Ana Sayfa"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Günlük"),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "İstatistik"),
            BottomNavigationBarItem(icon: Icon(Icons.opacity), label: "Su"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
          ],
        ),
      ),
    );
  }
}