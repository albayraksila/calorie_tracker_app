import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/main_layout.dart';

class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // -----------------------
  // SAFE PARSERS (NULL-SAFE)
  // -----------------------
  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim().replaceAll(',', '.')) ?? fallback;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<_WeeklySummaryData> _load() async {
    final uid = _uid;
    if (uid == null) return const _WeeklySummaryData.empty();

    final now = DateTime.now();
    final end = _startOfDay(now).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 7));

    final db = FirebaseFirestore.instance;

    // -----------------------
    // PROFILE TARGETS (SAFE)
    // -----------------------
    final profileSnap = await db.collection('user_profiles').doc(uid).get();
    final p = profileSnap.data() ?? <String, dynamic>{};

    final targetDailyCalories = _asInt(p['target_daily_calories'], fallback: 0);
    final targetDailyWaterMl = _asInt(p['target_daily_water_ml'], fallback: 2500);

    // -----------------------
    // FOOD (SAFE)
    // -----------------------
    int weeklyCalories = 0;
    int carbsG = 0;
    int proteinG = 0;
    int fatG = 0;

    final foodSnap = await db
        .collection('users')
        .doc(uid)
        .collection('food_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    for (final doc in foodSnap.docs) {
      final data = doc.data();
      weeklyCalories += _asInt(data['calories']);
      carbsG += _asInt(data['carbs_g']);
      proteinG += _asInt(data['protein_g']);
      fatG += _asInt(data['fat_g']);
    }

    // -----------------------
    // WATER (SAFE)
    // -----------------------
    int weeklyWaterMl = 0;

    final waterSnap = await db
        .collection('users')
        .doc(uid)
        .collection('water_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    for (final doc in waterSnap.docs) {
      final data = doc.data();
      weeklyWaterMl += _asInt(data['amount_ml']);
    }

    final avgWaterL = weeklyWaterMl / 7 / 1000.0;

    // -----------------------
    // WEIGHT CHANGE (SAFE)
    // -----------------------
    double? startKg;
    double? endKg;

    final weightSnap = await db
        .collection('users')
        .doc(uid)
        .collection('weight_entries')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: false)
        .get();

    if (weightSnap.docs.isNotEmpty) {
      final first = weightSnap.docs.first.data();
      final last = weightSnap.docs.last.data();

      final s = _asDouble(first['weight_kg'], fallback: 0);
      final e = _asDouble(last['weight_kg'], fallback: 0);

      // 0 gibi invalid değer gelirse “yok sayalım”
      if (s > 0) startKg = s;
      if (e > 0) endKg = e;
    }

    final analysis = _buildAnalysis(
      weeklyCalories: weeklyCalories,
      weeklyWaterMl: weeklyWaterMl,
      targetDailyCalories: targetDailyCalories,
      targetDailyWaterMl: targetDailyWaterMl,
      carbsG: carbsG,
      proteinG: proteinG,
      fatG: fatG,
      startKg: startKg,
      endKg: endKg,
    );

    return _WeeklySummaryData(
      weeklyCalories: weeklyCalories,
      avgWaterL: avgWaterL,
      analysisText: analysis,
    );
  }

  static String _buildAnalysis({
    required int weeklyCalories,
    required int weeklyWaterMl,
    required int targetDailyCalories,
    required int targetDailyWaterMl,
    required int carbsG,
    required int proteinG,
    required int fatG,
    required double? startKg,
    required double? endKg,
  }) {
    final targetWeekCal = targetDailyCalories * 7;
    final targetWeekWater = targetDailyWaterMl * 7;

    final double? calRatio =
        targetWeekCal > 0 ? (weeklyCalories / targetWeekCal) : null;
    final double? waterRatio =
        targetWeekWater > 0 ? (weeklyWaterMl / targetWeekWater) : null;

    final totalMacro = carbsG + proteinG + fatG;

    String macroMsg;
    if (totalMacro == 0) {
      macroMsg =
          "Bu hafta makro verisi az; birkaç öğün daha kaydedersen analiz daha netleşir.";
    } else {
      final pPct = (proteinG / totalMacro * 100).round();
      if (pPct >= 30) {
        macroMsg = "Protein dağılımın güçlü ($pPct%). Kas korunumu için iyi gidiyorsun.";
      } else if (pPct >= 20) {
        macroMsg = "Protein dağılımın dengeli ($pPct%). Biraz artırmak daha iyi sonuç verebilir.";
      } else {
        macroMsg = "Protein dağılımın düşük ($pPct%). Öğünlere yoğurt, yumurta, tavuk, bakliyat eklemeyi dene.";
      }
    }

    String calMsg;
    if (calRatio == null) {
      calMsg =
          "Kalori hedefin tanımlı değil; Ayarlar > Profil’den günlük hedef belirleyebilirsin.";
    } else if (calRatio <= 0.95) {
      calMsg = "Kaloride hedefinin biraz altında kaldın. İstikrarlı devam, harika.";
    } else if (calRatio <= 1.05) {
      calMsg = "Kaloride hedefe çok yakınsın. Tam kıvamında ilerliyorsun.";
    } else {
      calMsg =
          "Kaloride hedefin biraz üstüne çıkmışsın. Porsiyonları hafifçe küçültmek iyi gelir.";
    }

    String waterMsg;
    if (waterRatio == null) {
      waterMsg =
          "Su hedefin tanımlı değil; istersen hedef koyup takibini güçlendirebilirsin.";
    } else if (waterRatio >= 1.0) {
      waterMsg = "Su hedefini yakalamışsın ✅ Vücudun bu tempoyu sever.";
    } else if (waterRatio >= 0.75) {
      waterMsg = "Su iyi gidiyor; bir-iki bardakla hedefi rahat yakalarsın.";
    } else {
      waterMsg =
          "Su düşük kalmış; yanına şişe alıp gün içine yaymak iyi çalışır.";
    }

    String weightMsg;
    if (startKg != null && endKg != null) {
  final diff = endKg - startKg;

  if (diff < 0) {
    weightMsg = "Bu hafta ${diff.toStringAsFixed(1)} kg verdin 🎉 (Harika ilerliyorsun!)";
  } else if (diff > 0) {
    weightMsg = "Bu hafta +${diff.toStringAsFixed(1)} kg aldın. Panik yok—uyku, su ve porsiyon dengesiyle toparlarız.";
  } else {
    weightMsg = "Bu hafta kilon stabil. İstikrar, sürdürülebilirliğin işareti ✅";
  }
} else {
  weightMsg = "Bu hafta kilo kaydı az; 1-2 tartım ekleyince değişimi net görürüz.";
}

    const motivation =
        "Küçük adımların toplamı büyük değişim. Yarın için tek bir hedef seç: su + hareket + düzenli kayıt.";

    return "$weightMsg\n\n$macroMsg\n\n$calMsg\n\n$waterMsg\n\n$motivation";
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Haftalık Özet",
      child: FutureBuilder<_WeeklySummaryData>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Hata: ${snap.error}"));
          }

          final d = snap.data ?? const _WeeklySummaryData.empty();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(
                  title: "Haftalık Kalori",
                  value: "${d.weeklyCalories} kcal",
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(
                  title: "Ortalama Su",
                  value: "${d.avgWaterL.toStringAsFixed(1)} Litre",
                  icon: Icons.water_drop_rounded,
                  color: Colors.blue,
                ),
                const SizedBox(height: 28),
                const Text(
                  "Analiz",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      d.analysisText,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.70),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _WeeklySummaryData {
  final int weeklyCalories;
  final double avgWaterL;
  final String analysisText;

  const _WeeklySummaryData({
    required this.weeklyCalories,
    required this.avgWaterL,
    required this.analysisText,
  });

  const _WeeklySummaryData.empty()
      : weeklyCalories = 0,
        avgWaterL = 0,
        analysisText =
            "Bu hafta yeterli veri yok. Günlük kayıtlarını artırınca analiz burada görünecek.";
}
