import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/utils/date_range.dart';
import '../models/today_summary.dart';
import '../services/dashboard_service.dart';
import '../widgets/main_layout.dart';

class EfficiencyScreen extends StatelessWidget {
  const EfficiencyScreen({super.key});

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  int? _pickInt(Map<String, dynamic>? m, List<String> keys) {
    if (m == null) return null;
    for (final k in keys) {
      if (!m.containsKey(k)) continue;
      final val = _toInt(m[k]);
      if (val > 0) return val;
    }
    return null;
  }

  Map<String, dynamic> _calcEfficiency({
    required int targetCalories,
    required double consumedCalories,
    required double waterMl,
    required double waterTargetMl,
    required int mealsCompleted,
    required double fiberG,
    required double sugarG,
  }) {
    double calScore;
    if (targetCalories <= 0) {
      calScore = 20;
    } else {
      final diff = (consumedCalories - targetCalories).abs();
      final tol = targetCalories * 0.15;
      final t = (1 - (diff / tol)).clamp(0.0, 1.0);
      calScore = 40 * t;
    }

    final mealScore = (mealsCompleted.clamp(0, 4) / 4.0) * 20.0;

    final safeTarget = (waterTargetMl <= 0) ? 2500.0 : waterTargetMl;
    final waterScore = (waterMl / safeTarget).clamp(0.0, 1.0) * 20.0;

    final fiberScore = (fiberG / 30.0).clamp(0.0, 1.0) * 10.0;

    double sugarScore;
    if (sugarG <= 50) {
      sugarScore = 10;
    } else if (sugarG >= 90) {
      sugarScore = 0;
    } else {
      final t = (1 - ((sugarG - 50) / 40)).clamp(0.0, 1.0);
      sugarScore = 10 * t;
    }

    final total = (calScore + mealScore + waterScore + fiberScore + sugarScore)
        .round()
        .clamp(0, 100);

    String tip = "Bugün gayet iyi gidiyor.";
    if (waterScore < 12) tip = "Su düşük: 1-2 bardak su ekle.";
    if (fiberScore < 6) tip = "Lif düşük: 1 porsiyon sebze/kurubaklagil ekle.";
    if (sugarScore < 6) tip = "Şeker yüksek: tatlı/atıştırmayı azalt.";
    if (mealScore < 10) tip = "Öğün dağınık: en az 1 öğün daha kaydet.";
    if (calScore < 20) tip = "Kalori hedefinden sapma var: porsiyonları dengele.";

    return {
      "score": total,
      "tip": tip,
    };
  }

  Widget _miniStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2E6F5E)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

 Widget _scoreHeroCard({
  required int score,
  required String tip,
}) {
  final s = score.clamp(0, 100);
  final pct = (s / 100).clamp(0.0, 1.0);

  // Skora göre renk ve etiket
  Color accent;
  Color tint;
  String label;

if (s >= 80) {
  accent = const Color(0xFF2E6F5E); // yeşil
  tint = const Color(0xFF2E6F5E).withOpacity(0.10);
  label = "Harika";
} else if (s >= 60) {
  accent = const Color(0xFF00ACC1); // turkuaz
  tint = const Color(0xFF00ACC1).withOpacity(0.10);
  label = "İyi gidiyor";
} else if (s >= 30) {
  accent = const Color(0xFFF39C12); // turuncu
  tint = const Color(0xFFF39C12).withOpacity(0.12);
  label = "Geliştirilebilir";
} else {
  accent = const Color(0xFFE57373); // kırmızı
  tint = const Color(0xFFE57373).withOpacity(0.12);
  label = "Düşük";
}

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.90),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        // Sol: skor göstergesi
       Container(
  width: 110,
  height: 110,
  decoration: BoxDecoration(
    color: tint,
    borderRadius: BorderRadius.circular(32),
  ),
  child: Center(
    child: SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 18,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: "",
                  style: const TextStyle(
                    fontSize: 22, // küçültüldü
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const TextSpan(
                  text: "%",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),
        const SizedBox(width: 14),

        // Sağ: başlık + etiket + tip
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Günlük Verimlilik",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Tip kutusu (daha motivasyonel görünüyor)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  tip,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                    height: 1.25,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 10),

              // Alt: mini motivasyon satırı
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    "Bugün: ${(pct * 100).round()}% tamamlandı",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _detailRow({
  required String title,
  required String subtitle,
  String? subtitle2,
  required double pct, // 0..1
  required IconData icon,
}) {
  final p = pct.clamp(0.0, 1.0);
  final pctText = "${(p * 100).round()}%";

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.88),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.025),
          blurRadius: 18,
          offset: const Offset(0, 8),
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF2E6F5E).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF2E6F5E)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              pctText,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Color(0xFF2E6F5E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black54,
            fontSize: 12,
            height: 1.2,
          ),
        ),
        if (subtitle2 != null && subtitle2.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle2,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 10,
            backgroundColor: Colors.black12,
          ),
        ),
      ],
    ),
  );
}

  Widget _loading() => const SizedBox(
        width: double.infinity,
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _error(String text) => SizedBox(
        width: double.infinity,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    final profileStream = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(uid)
        .snapshots();

    final range = DateRange.today();
    final foodStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('food_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();

    return MainLayout(
      title: "Verimlilik",
      subtitle: "Günlük uyum puanı ve detaylar",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: profileStream,
          builder: (context, profileSnap) {
            if (profileSnap.hasError) return _error("Profil okunamadı");
            if (!profileSnap.hasData) return _loading();

            final profileData = profileSnap.data?.data();
            final targetCalories = _pickInt(profileData, [
                  'target_daily_calories',
                  'targetDailyCalories',
                  'targetCalories',
                  'dailyTargetCalories',
                  'calorieTarget',
                  'target_calories',
                  'daily_calorie_target',
                ]) ??
                2100;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, userSnap) {
                if (userSnap.hasError) return _error("Kullanıcı verisi okunamadı");
                if (!userSnap.hasData) return _loading();

                final userData = userSnap.data?.data();
                final targetGlasses =
                    (userData?['water_target_glasses'] as num?)?.toInt() ?? 10;
                final waterTargetMl = targetGlasses * 250.0;

                return StreamBuilder<TodaySummary>(
                  stream: DashboardService().watchTodaySummary(uid),
                  builder: (context, sumSnap) {
                    if (sumSnap.hasError) return _error("Günlük özet okunamadı");
                    if (!sumSnap.hasData) return _loading();

                    final s = sumSnap.data ?? const TodaySummary.zero();
                    final safeCalories = (s.calories).toDouble();
                    final safeWaterMl = (s.waterMl).toDouble();

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: foodStream,
                      builder: (context, foodSnap) {
                        if (foodSnap.hasError) return _error("Yemek verileri okunamadı");
                        if (!foodSnap.hasData) return _loading();

                        final docs = foodSnap.data?.docs ?? [];

                        double fiber = 0;
                        double sugar = 0;
                        final meals = <String>{};

                        for (final d in docs) {
                          final data = d.data();
                          final meal = (data['mealType'] ?? '').toString();
                          if (meal.isNotEmpty) meals.add(meal);

                          final f = data['fiber_g'];
                          final su = data['sugar_g'];
                          if (f is num) fiber += f.toDouble();
                          if (su is num) sugar += su.toDouble();
                        }

                        final mealsCompleted = meals.length.clamp(0, 4);

                        final res = _calcEfficiency(
                          targetCalories: targetCalories,
                          consumedCalories: safeCalories,
                          waterMl: safeWaterMl,
                          waterTargetMl: waterTargetMl,
                          mealsCompleted: mealsCompleted,
                          fiberG: fiber,
                          sugarG: sugar,
                        );

                        final score = res['score'] as int;
                        final tip = res['tip'] as String;

                        // Kalori uyumu (±%15 tolerans)
                      double calPct;
if (targetCalories <= 0) {
  calPct = 0.0;
} else {
  // ✅ tüketim/hedef: hedefe yaklaştıkça artar, hedefi geçince 1.0’da sabitlenir
  calPct = (safeCalories / targetCalories).clamp(0.0, 1.0);
}

                        final waterPct = (waterTargetMl <= 0)
                            ? 0.0
                            : (safeWaterMl / waterTargetMl).clamp(0.0, 1.0);

                        final mealsPct = (mealsCompleted / 4.0).clamp(0.0, 1.0);
                        final fiberPct = (fiber / 30.0).clamp(0.0, 1.0);

                        double sugarPct;
                        if (sugar <= 50) {
                          sugarPct = 1.0;
                        } else if (sugar >= 90) {
                          sugarPct = 0.0;
                        } else {
                          sugarPct = (1 - ((sugar - 50) / 40)).clamp(0.0, 1.0);
                        }

                        final calDiff = targetCalories > 0
                            ? (safeCalories - targetCalories).round()
                            : 0;
                        final calDiffText = targetCalories <= 0
                            ? ""
                            : "Sapma: ${calDiff >= 0 ? "+" : ""}$calDiff kcal";

                        final calSubtitle = targetCalories <= 0
                            ? "Hedef yok • Bugün: ${safeCalories.round()} kcal"
                            : "Bugün: ${safeCalories.round()} • Hedef: $targetCalories";
                        final calSubtitle2 = targetCalories <= 0 ? "" : calDiffText;

                        final waterSubtitle =
    "${safeWaterMl.round()} ml / ${waterTargetMl.round()} ml hedef";
                        final mealsSubtitle = "$mealsCompleted / 4 öğün";
                        final fiberSubtitle = "${fiber.round()}g / 30g";
                 final sugarSubtitle = "${sugar.round()}g / 50g ";

                        // ✅ main_layout ile çakışmasın diye:
                        // - Scroll yok
                        // - LayoutBuilder yok
                        // - GridView yok
                        // 2 sütun genişliği MediaQuery ile hesaplanır
                        final screenW = MediaQuery.of(context).size.width;
                        final outerW = screenW - 40; // padding 20+20
                        final innerW = outerW - 32; // container padding 16+16
                        final itemW = ((innerW - 12) / 2).clamp(140.0, innerW);

                        return SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _scoreHeroCard(score: score, tip: tip),
                              const SizedBox(height: 12),

                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _miniStatChip(
                                    icon: Icons.local_fire_department_outlined,
                                    label: "Kalori",
                                    value: "${safeCalories.round()} kcal",
                                  ),
                                  _miniStatChip(
                                    icon: Icons.water_drop_outlined,
                                    label: "Su",
                                    value: "${safeWaterMl.round()} ml",
                                  ),
                                  _miniStatChip(
                                    icon: Icons.restaurant_outlined,
                                    label: "Öğün",
                                    value: "$mealsCompleted / 4",
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(color: Colors.white),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Detaylar",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    Column(
  children: [
    _detailRow(
      title: "Kalori Uyumu",
      subtitle: calSubtitle,
      subtitle2: calSubtitle2,
      pct: calPct,
      icon: Icons.track_changes_outlined,
    ),
    const SizedBox(height: 14),

    _detailRow(
      title: "Su",
      subtitle: waterSubtitle,
      pct: waterPct,
      icon: Icons.water_drop_outlined,
    ),
    const SizedBox(height: 14),

    _detailRow(
      title: "Öğün",
      subtitle: mealsSubtitle,
      pct: mealsPct,
      icon: Icons.restaurant_menu_outlined,
    ),
    const SizedBox(height: 14),

    _detailRow(
      title: "Lif",
      subtitle: fiberSubtitle,
      pct: fiberPct,
      icon: Icons.grass_outlined,
    ),
    const SizedBox(height: 14),

    _detailRow(
      title: "Şeker",
      subtitle: sugarSubtitle,
      pct: sugarPct,
      icon: Icons.cookie_outlined,
    ),
  ],
),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}