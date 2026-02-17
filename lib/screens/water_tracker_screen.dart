// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/main_layout.dart'; // ✅ MainLayout import edildi
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({super.key});

  @override
  State<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen> {
  int _currentGlasses = 0;
  final int _targetGlasses = 10;

  Future<void> _addGlass() async {
  if (_currentGlasses >= _targetGlasses) return;

  setState(() => _currentGlasses++);

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('water_entries')
      .add({
    'amount_ml': 250,
    'createdAt': Timestamp.now(),

  });
}


 Future<void> _resetWater() async {
  setState(() => _currentGlasses = 0);

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  final q = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('water_entries')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('createdAt', isLessThan: Timestamp.fromDate(end))
      .get();

  for (final doc in q.docs) {
    await doc.reference.delete();
  }
}

  @override
  Widget build(BuildContext context) {
    double progress = _currentGlasses / _targetGlasses;

    // ✅ Scaffold ve manuel Container yerine MainLayout kullanıldı
    return MainLayout(
      title: "Su Takibi",
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // 💧 Modern Su Tankı Bento
            _buildWaterTankBento(progress),
            const SizedBox(height: 30),

            // 🥛 Bardak Seçim Bento Grid
            _buildSectionHeader("Bugün içtiğin bardaklar"),
            const SizedBox(height: 15),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(_targetGlasses, (index) {
                bool isDrunk = index < _currentGlasses;
                return _buildGlassIcon(isDrunk, index == _currentGlasses);
              }),
            ),
            
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: _resetWater,
              icon: const Icon(Icons.refresh_rounded, color: Colors.black38),
              label: const Text(
                "Günü Sıfırla", 
                style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600)
              ),
            ),
            const SizedBox(height: 100), // Alt navigasyon boşluğu
          ],
        ),
      ),
    );
  }

  // --- WIDGETLAR (Bozulmadan Korundu) ---

  Widget _buildWaterTankBento(double progress) {
    return Card( // ✅ Standart Bento stili için Card kullanıldı
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 220,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutQuart,
                  height: 220 * progress,
                  width: 140,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF2196F3)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text("${(_currentGlasses * 0.25).toStringAsFixed(1)}L", 
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const Text("Bugünkü Toplam", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIcon(bool isDrunk, bool isNext) {
    return GestureDetector(
      onTap: isNext ? _addGlass : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isDrunk ? const Color(0xFFE3F2FD) : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isNext ? const Color(0xFF2196F3).withOpacity(0.3) : Colors.white,
            width: isNext ? 2 : 1,
          ),
        ),
        child: Icon(
          Icons.local_drink_rounded,
          color: isDrunk ? const Color(0xFF2196F3) : Colors.black12,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title, 
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)
      ),
    );
  }
}