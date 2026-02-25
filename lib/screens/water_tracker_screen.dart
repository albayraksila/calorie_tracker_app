// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({super.key});

  @override
  State<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen> {
  int _currentGlasses = 0;
 int _targetGlasses = 10;

  User? get _user => FirebaseAuth.instance.currentUser;

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _todayEnd => _todayStart.add(const Duration(days: 1));

  CollectionReference<Map<String, dynamic>>? get _waterCol {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('water_entries');
  }
DocumentReference<Map<String, dynamic>>? get _userDoc {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return FirebaseFirestore.instance.collection('users').doc(user.uid);
}
  @override
  void initState() {
    super.initState();
    _loadTarget();
    _loadTodayCount();
  }

  Future<void> _loadTodayCount() async {
    final col = _waterCol;
    if (col == null) return;

    final q = await col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_todayStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(_todayEnd))
        .get();

    if (!mounted) return;
    setState(() => _currentGlasses = q.docs.length.clamp(0, _targetGlasses));
  }

  Future<void> _loadTarget() async {
  final doc = _userDoc;
  if (doc == null) return;

  final snap = await doc.get();
  final data = snap.data();

  final raw = data?['water_target_glasses'];
  final parsed = (raw is num) ? raw.toInt() : 10;

  if (!mounted) return;
  setState(() {
    _targetGlasses = parsed.clamp(1, 30);
    _currentGlasses = _currentGlasses.clamp(0, _targetGlasses);
  });
}

Future<void> _saveTarget(int newTarget) async {
  final doc = _userDoc;
  if (doc == null) return;

  final clamped = newTarget.clamp(1, 30);

  setState(() {
    _targetGlasses = clamped;
    _currentGlasses = _currentGlasses.clamp(0, _targetGlasses);
  });

  await doc.set({'water_target_glasses': clamped}, SetOptions(merge: true));
}

Future<void> _openTargetDialog() async {
  int temp = _targetGlasses;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Su Hedefi",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "$temp bardak",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  Slider(
                    value: temp.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    onChanged: (v) => setModalState(() => temp = v.round()),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Vazgeç"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _saveTarget(temp);
                          },
                          child: const Text("Kaydet"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
  Future<void> _addGlass() async {
    if (_currentGlasses >= _targetGlasses) return;

    final col = _waterCol;
    if (col == null) return;

    // UI hızlı tepki versin
    setState(() => _currentGlasses++);

    try {
      await col.add({
        'amount_ml': 250,
        'createdAt': Timestamp.now(),
      });
    } catch (_) {
      // yazma başarısızsa geri al
      if (!mounted) return;
      setState(() => _currentGlasses = (_currentGlasses - 1).clamp(0, _targetGlasses));
    }
  }

  Future<void> _removeGlass() async {
    if (_currentGlasses <= 0) return;

    final col = _waterCol;
    if (col == null) return;

    // Bugünün en son kaydını bul
    final q = await col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_todayStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(_todayEnd))
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      // veri yoksa state'i de sıfırla (tutarlılık)
      if (!mounted) return;
      setState(() => _currentGlasses = 0);
      return;
    }

    // UI hızlı tepki
    setState(() => _currentGlasses--);

    try {
      await q.docs.first.reference.delete();
    } catch (_) {
      // silme başarısızsa geri al
      if (!mounted) return;
      setState(() => _currentGlasses = (_currentGlasses + 1).clamp(0, _targetGlasses));
    }
  }

  Future<void> _resetWater() async {
    setState(() => _currentGlasses = 0);

    final col = _waterCol;
    if (col == null) return;

    final q = await col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_todayStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(_todayEnd))
        .get();

    for (final doc in q.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentGlasses / _targetGlasses).clamp(0.0, 1.0);

    return MainLayout(
      title: "Su Takibi",
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // 💧 Tank + yanlarda +/- kontrol
            _buildWaterTankWithSideControls(progress),
            const SizedBox(height: 24),

            _buildSectionHeader(""),
            const SizedBox(height: 7),

            // sadece gösterim (tıklama yok)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(_targetGlasses, (index) {
                final isDrunk = index < _currentGlasses;
                return _buildGlassIcon(isDrunk);
              }),
            ),

            const SizedBox(height: 34),
            TextButton.icon(
              onPressed: _resetWater,
              icon: const Icon(Icons.refresh_rounded, color: Colors.black38),
              label: const Text(
                "Günü Sıfırla",
                style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterTankWithSideControls(double progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
  children: [
    const Spacer(),
    InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openTargetDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              "Hedef: $_targetGlasses",
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
            ),
          ],
        ),
      ),
    ),
  ],
),
const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // - BUTONU (sol)
                _buildSideButton(
                  icon: Icons.remove_rounded,
                  onTap: (_currentGlasses > 0) ? _removeGlass : null,
                ),
                const SizedBox(width: 10),

                // TANK
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

                const SizedBox(width: 10),
                // + BUTONU (sağ)
                _buildSideButton(
                  icon: Icons.add_rounded,
                  onTap: (_currentGlasses < _targetGlasses) ? _addGlass : null,
                ),
              ],
            ),

            const SizedBox(height: 18),
            Text(
              "${(_currentGlasses * 0.25).toStringAsFixed(1)}L",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
            ),
            Text(
              "Bugünkü Toplam • $_currentGlasses/$_targetGlasses",
              style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideButton({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled ? Colors.black.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 26, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildGlassIcon(bool isDrunk) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isDrunk ? const Color(0xFFE3F2FD) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Icon(
        Icons.local_drink_rounded,
        color: isDrunk ? const Color(0xFF2196F3) : Colors.black12,
        size: 28,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
    );
  }
}