// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'food_search_screen.dart';
import '../widgets/main_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/date_range.dart';

class DailyTrackerScreen extends StatelessWidget {
  const DailyTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final range = DateRange.today();

    final foodStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('food_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();

    // ✅ 2.7: hedef kaloriyi profilden çek
    final profileStream = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .snapshots();

    final theme = Theme.of(context);

    return MainLayout(
      title: "Günlük Takip",
      // ✅ ASLA SingleChildScrollView veya ListView ekleme.
      // MainLayout'un içindeki SliverList zaten her şeyi kaydırıyor.
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profileStream,
        builder: (context, profileSnap) {
          int _toInt(dynamic v) {
            if (v == null) return 0;
            if (v is int) return v;
            if (v is double) return v.round();
            if (v is num) return v.toInt();
            return int.tryParse(v.toString()) ?? 0;
          }

          // ✅ Profil yoksa / alan yoksa 2100 fallback
          final profileData = profileSnap.data?.data();

          // 🔎 Debug: gerçekten doc geliyor mu ve hangi alanlar var?
          debugPrint("PROFILE exists=${profileSnap.data?.exists} data=$profileData");

          // Birden fazla olası key’i dene (hangisi doluysa onu al)
          int? pickInt(Map<String, dynamic>? m, List<String> keys) {
            if (m == null) return null;
            for (final k in keys) {
              if (!m.containsKey(k)) continue;
              final raw = m[k];
              final val = _toInt(raw);
              // 0 da geçerli olabilir ama hedefin 0 olmasını istemiyoruz:
              if (val > 0) return val;
            }
            return null;
          }

          final targetCalories = pickInt(profileData, [
                // senin önceki kod mantığı
                'target_daily_calories',
                'targetDailyCalories',

                // yaygın alternatifler
                'targetCalories',
                'dailyTargetCalories',
                'calorieTarget',
                'target_calories',
                'daily_calorie_target',
              ]) ??
              2100;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: foodStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              int totalProtein = 0, totalCarbs = 0, totalFat = 0;

              for (final d in docs) {
                final data = d.data();
                totalProtein += _toInt(data['protein_g']);
                totalCarbs += _toInt(data['carbs_g']);
                totalFat += _toInt(data['fat_g']);
              }

              int mealTotal(String mealType) {
                int sum = 0;
                for (final d in docs) {
                  final data = d.data();
                  if ((data['mealType'] ?? '') == mealType) {
                    sum += _toInt(data['calories']);
                  }
                }
                return sum;
              }

              final breakfast = mealTotal('Kahvaltı');
              final lunch = mealTotal('Öğle Yemeği');
              final dinner = mealTotal('Akşam Yemeği');
              final snack = mealTotal('Atıştırmalık');
              final totalConsumed = breakfast + lunch + dinner + snack;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📊 Özet Bento Kartı (Artık dinamik + makrolar)
                    _buildSummaryBento(
                      theme,
                      targetCalories: targetCalories,
                      consumedCalories: totalConsumed,
                      proteinG: totalProtein,
                      carbsG: totalCarbs,
                      fatG: totalFat,
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "Öğünlerin",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 🍳 Öğün Kartları
                    _buildMealBento(
                      context,
                      "Kahvaltı",
                      "$breakfast kcal",
                      Icons.wb_sunny_rounded,
                      const Color(0xFFFFF3E0),
                    ),
                    _buildMealBento(
                      context,
                      "Öğle Yemeği",
                      "$lunch kcal",
                      Icons.wb_cloudy_rounded,
                      const Color(0xFFE3F2FD),
                    ),
                    _buildMealBento(
                      context,
                      "Akşam Yemeği",
                      "$dinner kcal",
                      Icons.nightlight_round_rounded,
                      const Color(0xFFF3E5F5),
                    ),
                    _buildMealBento(
                      context,
                      "Atıştırmalık",
                      "$snack kcal",
                      Icons.apple_rounded,
                      const Color(0xFFE8F5E9),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryBento(
    ThemeData theme, {
    required int targetCalories,
    required int consumedCalories,
    required int proteinG,
    required int carbsG,
    required int fatG,
  }) {
    final remaining = (targetCalories - consumedCalories).clamp(0, targetCalories);
    final percent = targetCalories == 0
        ? 0.0
        : (consumedCalories / targetCalories).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularPercentIndicator(
                radius: 50.0,
                lineWidth: 8.0,
                percent: percent,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$remaining",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      "Kalan",
                      style: TextStyle(color: Colors.black45, fontSize: 10),
                    ),
                  ],
                ),
                progressColor: const Color(0xFF2E6F5E),
                backgroundColor: const Color(0xFFE8F5E9),
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMiniStat("Hedef", "$targetCalories"),
                  const SizedBox(height: 10),
                  Container(width: 80, height: 1, color: Colors.black12),
                  const SizedBox(height: 10),
                  _buildMiniStat("Alınan", "$consumedCalories"),
                ],
              ),
            ],
          ),

          // ✅ Makrolar (tasarım)
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macroPill("Protein", "${proteinG}g"),
              _macroPill("Karb", "${carbsG}g"),
              _macroPill("Yağ", "${fatG}g"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        Text(
          "$value kcal",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildMealBento(
    BuildContext context,
    String title,
    String calories,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FoodSearchScreen(mealType: title)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.black54, size: 22),
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const Spacer(),
            Text(
              calories,
              style: const TextStyle(
                color: Colors.black38,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF2E6F5E),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
