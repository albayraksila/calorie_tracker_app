// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:calorisense/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import '../widgets/main_layout.dart';
import '../core/navigation/main_tab_scope.dart';

import '../services/dashboard_service.dart';
import '../models/today_summary.dart';
import '../core/utils/date_range.dart';
import 'daily_tracker_screen.dart';
import 'efficiency_screen.dart';
import '../ui/ui_kit.dart';

import 'package:fl_chart/fl_chart.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  Map<String, dynamic> _calcEfficiency({
  required int targetCalories,
  required double consumedCalories,
    required double waterMl,
  required double waterTargetMl,
  required int mealsCompleted, // 0..4
  required double fiberG,
  required double sugarG,
}) {
  String _fmtKcal(num v) {
  return "${v.round()} kcal";
}
  // 1) Kalori uyumu (0..40)
  double calScore;
  if (targetCalories <= 0) {
    calScore = 20;
  } else {
    final diff = (consumedCalories - targetCalories).abs();
    final tol = targetCalories * 0.15; // %15 tolerans
    final t = (1 - (diff / tol)).clamp(0.0, 1.0);
    calScore = 40 * t;
  }

  // 2) Öğün tamamlama (0..20)
  final mealScore = (mealsCompleted.clamp(0, 4) / 4.0) * 20.0;


 // 3) Su (0..20) hedefi kullanıcı ayarına göre
final safeTarget = (waterTargetMl <= 0) ? 2500.0 : waterTargetMl;
final waterScore = (waterMl / safeTarget).clamp(0.0, 1.0) * 20.0;

  // 4) Lif (0..10) 30g hedef
  final fiberScore = (fiberG / 30.0).clamp(0.0, 1.0) * 10.0;

  // 5) Şeker kontrol (0..10) 50g üstü düşür
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


  // öneri
  String tip = "Bugün gayet iyi gidiyor.";
  if (waterScore < 12) tip = "Su düşük: 1-2 bardak su ekle.";
  if (fiberScore < 6) tip = "Lif düşük: 1 porsiyon sebze/kurubaklagil ekle.";
  if (sugarScore < 6) tip = "Şeker yüksek: tatlı/atıştırmayı azalt.";
  if (mealScore < 10) tip = "Öğün dağınık: en az 1 öğün daha kaydet.";
  if (calScore < 20) tip = "Kalori hedefinden sapma var: porsiyonları dengele.";

  return {"score": total, "tip": tip};
  
}


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();
    final userName = user?.email?.split('@')[0] ?? "Kullanıcı";
    final _dashboardService = DashboardService();
    final uid = user!.uid;

final int targetCalories = 2000;

    final tabs = MainTabScope.of(context);
    void goTab(int index) => tabs?.setIndex(index);


    // ✅ Home için de DailyTracker gibi hedefi profilden çekiyoruz
    final profileStream = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(uid)
        .snapshots();

    // ✅ Lif/şeker için bugünkü food_entries stream’i
    final range = DateRange.today();
    final foodStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('food_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();

    return MainLayout(
      title: "CaloriSense",
      actions: [
        _buildAppBarAction(
          context,
          icon: Icons.settings_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 10),
        _buildAppBarAction(
          context,
          icon: Icons.logout_rounded,
          onTap: () async {
            await authService.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
        ),
        const SizedBox(width: 20),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ÜST SELAMLAMA VE STREAK
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
               Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text("İyi ki buradasın ✨",
        style: TextStyle(
            color: Color(0xFF2E6F5E),
            fontSize: 14,
            fontWeight: FontWeight.w600)),
    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, snap) {
        final profileName = snap.data?.data()?['name']?.toString().trim() ?? '';
        final displayName = profileName.isNotEmpty ? profileName : userName;
        return Text(displayName,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5));
      },
    ),
  ],
),
                FutureBuilder<int>(
  future: _dashboardService.calculateStreak(uid),
  builder: (context, snapshot) {
    final streak = snapshot.data ?? 0;
    return _buildStreakIndicator("$streak");
  },
),

              ],
            ),
          ),

          // 2. ANA DASHBOARD (GLASS) -> hedef profilden
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: profileStream,
            builder: (context, profileSnap) {
              int _toInt(dynamic v) {
                if (v == null) return 0;
                if (v is int) return v;
                if (v is double) return v.round();
                if (v is num) return v.toInt();
                return int.tryParse(v.toString()) ?? 0;
              }

              int? pickInt(Map<String, dynamic>? m, List<String> keys) {
                if (m == null) return null;
                for (final k in keys) {
                  if (!m.containsKey(k)) continue;
                  final val = _toInt(m[k]);
                  if (val > 0) return val;
                }
                return null;
              }

              final profileData = profileSnap.data?.data();

              final targetCalories = pickInt(profileData, [
                    'target_daily_calories',
                    'targetDailyCalories',
                    'targetCalories',
                    'dailyTargetCalories',
                    'calorieTarget',
                    'target_calories',
                    'daily_calorie_target',
                  ]) ??
                  2100;

              return StreamBuilder<TodaySummary>(
                stream: _dashboardService.watchTodaySummary(uid),
                builder: (context, summarySnap) {
                  final s = summarySnap.data ?? const TodaySummary.zero();

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: foodStream,
                    builder: (context, foodSnap) {
                      final docs = foodSnap.data?.docs ?? [];

                      int fiberG = 0;
                      int sugarG = 0;

                      for (final d in docs) {
                        final data = d.data();
                        fiberG += _toInt(data['fiber_g']);
                        sugarG += _toInt(data['sugar_g']);
                      }

                      return GestureDetector(
                        onTap: () => goTab(1),
                        behavior: HitTestBehavior.opaque,
                        child: _buildMainDashboardCard(
                          targetCalories: targetCalories,
                          consumedCalories: s.calories,

                            burnedCalories: s.burnedCalories,

  proteinTargetG: pickInt(profileData, [
        'protein_target_g',
        'proteinTargetG',
        'target_protein_g',
        'proteinTarget',
        'protein_target',
      ]) ??
      160,

                          proteinG: s.proteinG,
                          carbsG: s.carbsG,
                          fatG: s.fatG,

                        
                          fiberG: fiberG,
                          sugarG: sugarG,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
const SizedBox(height: 14),
Padding(
  
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: _buildMonthlyCalendar(uid, targetCalories: targetCalories),

),
const SizedBox(height: 12),

StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots(),
  builder: (context, userSnap) {
    if (!userSnap.hasData) {
      return const SizedBox();
    }

    final userData = userSnap.data!.data() ?? {};

    final targetCalories =
        (userData['targetCalories'] ?? 2000).toDouble();

    return _buildMiniCalorieLineChart(
      uid,
      days: 14,
      targetCalories: targetCalories,
    );
  },
),

// 3. BENTO GRID (SU VE VERİMLİLİK) -> canlı skor
StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: profileStream,
  builder: (context, profileSnap) {
    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    int? pickInt(Map<String, dynamic>? m, List<String> keys) {
      if (m == null) return null;
      for (final k in keys) {
        if (!m.containsKey(k)) continue;
        final val = _toInt(m[k]);
        if (val > 0) return val;
      }
      return null;
    }

    final profileData = profileSnap.data?.data();
    final targetCalories = pickInt(profileData, [
          'target_daily_calories',
          'targetDailyCalories',
          'targetCalories',
          'dailyTargetCalories',
          'calorieTarget',
          'target_calories',
          'daily_calorie_target',
        ]) ??
        2100;

    // ✅ Su hedefi: users/{uid}.water_target_glasses -> ml -> litre
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final targetGlasses =
            (userData?['water_target_glasses'] as num?)?.toInt() ?? 10;

        final waterTargetMl = targetGlasses * 250.0;
        final waterTargetLiters = waterTargetMl / 1000.0;

        return StreamBuilder<TodaySummary>(
          stream: _dashboardService.watchTodaySummary(uid),
          builder: (context, summarySnap) {
            final s = summarySnap.data ?? const TodaySummary.zero();
            final currentLiters = s.waterMl / 1000.0;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: foodStream,
              builder: (context, foodSnap) {
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
                  consumedCalories: s.calories.toDouble(),
                  waterMl: s.waterMl.toDouble(),
                  waterTargetMl: waterTargetMl, // ✅ artık tanımlı
                  mealsCompleted: mealsCompleted,
                  fiberG: fiber,
                  sugarG: sugar,
                );

              return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 🔹 ÜST SATIR (eşit yükseklik)
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, // kritik
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => goTab(4), // su tab'ına git
                behavior: HitTestBehavior.opaque,
                child: _buildWaterBento(
                  currentLiters,
                  waterTargetLiters,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const EfficiencyScreen()),
  );
},
                behavior: HitTestBehavior.opaque,
                child: _buildEfficiencyBento(
                  score: res['score'] as int,
                  tip: res['tip'] as String,
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 15),

      // 🔹 ALT SATIR (tam genişlik)
      GestureDetector(
        onTap: () => goTab(2),
        behavior: HitTestBehavior.opaque,
        child: _buildEnergyBalanceBento(
          consumedCalories: s.calories,
          burnedCalories: s.burnedCalories,
          targetCalories: targetCalories,
        ),
      ),
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
          
          // ════════════════════════════════════════════════════════════
// home_screen.dart  →  "Bugünkü Menün" bölümü  (REPLACE)
//
// Eski: SizedBox(height: 220, ...) → yatay scroll, sabit yükseklik
// Yeni: Padding + StreamBuilder → dikey liste, AppMealSummaryCard
//
// ADIMLAR:
//  1. ui_kit.dart dosyasını tamamen yeni versiyonla değiştir
//  2. Aşağıdaki bloğu home_screen.dart'taki şu satırın yerine yapıştır:
//       // 4. MENÜ BAŞLIĞI   →   // const SizedBox(height: 100),
// ════════════════════════════════════════════════════════════

// 4. MENÜ BAŞLIĞI
Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
  child: AppSectionTitle(
    title: 'Bugünkü Menün',
    actionText: 'Tümü',
    onAction: () => goTab(1),
  ),
),

// 5. YEMEK KARTLARI — dikey liste, AppMealSummaryCard ile
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: foodStream,
    builder: (context, snap) {
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final docs = snap.data!.docs;

      // ── Öğüne göre grupla ──
      const mealOrder = <String>[
        'Kahvaltı',
        'Öğle Yemeği',
        'Akşam Yemeği',
        'Ara Öğün',
        'Yiyecek',
      ];

      IconData _mealIcon(String m) {
        switch (m) {
          case 'Kahvaltı':
            return Icons.breakfast_dining_rounded;
          case 'Öğle Yemeği':
            return Icons.lunch_dining_rounded;
          case 'Akşam Yemeği':
            return Icons.dinner_dining_rounded;
          case 'Ara Öğün':
            return Icons.emoji_food_beverage_rounded;
          default:
            return Icons.restaurant_rounded;
        }
      }

      if (docs.isEmpty) {
        // boş durum: placeholder göster
        return Column(
          children: [
            for (final m in ['Kahvaltı', 'Öğle Yemeği', 'Akşam Yemeği'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: 0.40,
                  child: AppMealSummaryCard(
                    mealType: m,
                    icon: _mealIcon(m),
                    totalKcal: 0,
                    itemNames: const [],
                    onTap: () => goTab(1),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Bugün henüz öğün eklenmedi.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.40),
                fontSize: 13,
              ),
            ),
          ],
        );
      }

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
      for (final d in docs) {
        final meal = (d.data()['mealType'] ?? 'Yiyecek').toString();
        grouped.putIfAbsent(meal, () => []).add(d);
      }

      final meals = grouped.keys.toList()
        ..sort((a, b) {
          final ia = mealOrder.indexOf(a);
          final ib = mealOrder.indexOf(b);
          if (ia == -1 && ib == -1) return a.compareTo(b);
          if (ia == -1) return 1;
          if (ib == -1) return -1;
          return ia.compareTo(ib);
        });

      return Column(
        children: [
          for (final mealType in meals) ...[
            AppMealSummaryCard(
              mealType: mealType,
              icon: _mealIcon(mealType),
              totalKcal: () {
                double t = 0;
                for (final e in grouped[mealType]!) {
                  final c = e.data()['calories'];
                  if (c is num) t += c.toDouble();
                }
                return t;
              }(),
              itemNames: grouped[mealType]!
                  .map((e) {
                    final d = e.data();
                    return (d['name'] ?? d['foodName'] ?? '').toString();
                  })
                  .where((n) => n.isNotEmpty)
                  .toList(),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyTrackerScreen()),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    },
  ),
),

const SizedBox(height: 100),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- YARDIMCI WIDGETLAR ---

 Widget _buildEnergyBalanceBento({
  required int consumedCalories,
  required int burnedCalories,
  required int targetCalories,
}) {
  final net = consumedCalories - burnedCalories;

  final t = targetCalories > 0 ? targetCalories : 2000;
  final keepBand = (t * 0.05).round().clamp(120, 240);
  final strongDeficit = (t * 0.10).round();
  final strongSurplus = (t * 0.08).round();

  final diff = net - t;

  String mode;
  IconData modeIcon;
  Color modeColor;

  if (diff <= -strongDeficit) {
    mode = "Yağ yakma";
    modeIcon = Icons.trending_down_rounded;
    modeColor = const Color(0xFF2E6F5E);
  } else if (diff.abs() <= keepBand) {
    mode = "Koruma";
    modeIcon = Icons.horizontal_rule_rounded;
    modeColor = Colors.blueGrey;
  } else if (diff >= strongSurplus) {
    mode = "Kilo alma";
    modeIcon = Icons.trending_up_rounded;
    modeColor = Colors.deepOrange;
  } else if (diff < 0) {
    mode = "Hafif açık";
    modeIcon = Icons.trending_down_rounded;
    modeColor = const Color(0xFF2E6F5E);
  } else {
    mode = "Hafif fazla";
    modeIcon = Icons.trending_up_rounded;
    modeColor = Colors.deepOrange;
  }

//bar yaparken hedefin biraz üstünü max yapıyoruz ki barın doluluk oranı daha anlamlı olsun
final barMax = (t * 1.20).toDouble();
final barPct = (net.toDouble() / barMax).clamp(0.0, 1.0);

  Widget _kpi(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.black45),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  return _buildBentoWrapper(
    color: const Color(0xFFFFF8E1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.balance_rounded, color: Colors.brown, size: 26),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Enerji Dengesi",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.brown,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(modeIcon, size: 16, color: modeColor),
                  const SizedBox(width: 6),
                  Text(
                    mode,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: modeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Text(
          "$net kcal",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Net (Alınan - Yakılan) • Hedef: $t kcal",
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.black45,
          ),
        ),

        const SizedBox(height: 12),

        // Sade bar
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: barPct,
            minHeight: 10,
            backgroundColor: Colors.black12,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Text(
              "${(t * 0.8).round()}",
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black45),
            ),
            const Spacer(),
            Text(
              "${(t * 1.2).round()}",
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black45),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            _kpi("Alınan", "$consumedCalories kcal", Icons.restaurant_outlined),
            const SizedBox(width: 10),
            _kpi("Yakılan", "$burnedCalories kcal", Icons.fitness_center_outlined),
            const SizedBox(width: 10),
            _kpi("Hedef", "$t kcal", Icons.flag_outlined),
          ],
        ),
      ],
    ),
  );
}

 Widget _buildMealGroupCardLive(
  BuildContext context,
  String mealType,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
) {
  // Toplam kalori
  double total = 0;
  for (final e in entries) {
    final d = e.data();
    final c = (d['calories'] ?? 0);
    if (c is int) total += c.toDouble();
    if (c is double) total += c;
  }

  IconData icon;
  switch (mealType) {
    case 'Kahvaltı':
      icon = Icons.breakfast_dining_rounded;
      break;
    case 'Öğle Yemeği':
      icon = Icons.lunch_dining_rounded;
      break;
    case 'Akşam Yemeği':
      icon = Icons.dinner_dining_rounded;
      break;
    case 'Ara Öğün':
      icon = Icons.emoji_food_beverage_rounded;
      break;
    default:
      icon = Icons.restaurant_rounded;
  }

  final titleColor = const Color(0xFF0B3D2E);
  final accent = const Color(0xFF128D64);

  // Kart içinde gösterilecek max öğe
  final showMax = 4;
  final visible = entries.take(showMax).toList();
  final remaining = entries.length - visible.length;

  return Container(
    width: 280,
    margin: const EdgeInsets.only(right: 14),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const DailyTrackerScreen()),
),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFEFF8F4),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF128D64).withOpacity(0.10),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: ikon + başlık + kcal badge
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mealType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _fmtKcal(total),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // İnce ayraç
                Container(
                  height: 1,
                  width: double.infinity,
                  color: Colors.black.withOpacity(0.06),
                ),

                const SizedBox(height: 12),

                // Mini liste (chip gibi modern)
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final e in visible)
                        _foodChipFromEntry(e, accent),

                      if (remaining > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                          ),
                          child: Text(
                            "+$remaining daha",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: titleColor.withOpacity(0.7),
                            ),
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
    ),
  );
}

/// Entry -> modern mini chip
Widget _foodChipFromEntry(
  QueryDocumentSnapshot<Map<String, dynamic>> entry,
  Color accent,
) {
  final d = entry.data();
  final name = (d['name'] ?? d['foodName'] ?? 'Yiyecek').toString();

  final calRaw = d['calories'] ?? 0;
  final cal = (calRaw is int) ? calRaw.toDouble() : (calRaw is double ? calRaw : 0.0);

  return Container(
    constraints: const BoxConstraints(maxWidth: 240),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 6),
        )
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: Color(0xFF163B2F),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _fmtKcal(cal),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black.withOpacity(0.45),
            letterSpacing: -0.1,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildAppBarAction(BuildContext context,
      {required IconData icon, required VoidCallback onTap}) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.8)),
          ),
          child: Icon(icon, color: const Color(0xFF2E6F5E), size: 22),
        ),
      ),
    );
  }

Widget _buildMiniCalorieLineChart(
  String uid, {
  required int days,
  required double targetCalories,
}) {
  final now = DateTime.now();
  final start =
      DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

  String dateId(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

final streamEnd = DateTime(now.year, now.month, now.day + 1);
final stream = FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('food_entries')
    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
    .where('createdAt', isLessThan: Timestamp.fromDate(streamEnd))
    .snapshots();


  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snap) {
      final docs = snap.data?.docs ?? [];
      if (snap.hasError) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 15),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.75),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white),
    ),
    child: Text("Grafik verisi alınamadı: ${snap.error}",
        style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

     // map: date -> TOTAL calories (sum)
final map = <String, double>{};
for (final d in docs) {
  final data = d.data();
  final ts = data['createdAt'];
  if (ts is! Timestamp) continue;
  final date = dateId(ts.toDate().toLocal()); // ← dateId zaten fonksiyon olarak tanımlı
  final raw = data['calories'] ?? 0;
  final cal = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
  map[date] = (map[date] ?? 0) + (cal > 0 ? cal : 0); // toplama, negatif yok
}
      final points = <FlSpot>[];
      
      final belowTargetSpots = <FlSpot>[];
final aboveTargetSpots = <FlSpot>[];

for (final spot in points) {
  if (spot.y <= targetCalories) {
    belowTargetSpots.add(spot);
  } else {
    aboveTargetSpots.add(spot);
  }
}
      final hasData = List<bool>.filled(days, false);

      double maxY = 0;

      // önce hasData + maxY üretelim
      for (int i = 0; i < days; i++) {
        final day = start.add(Duration(days: i));
        final id = dateId(day);

        if (map.containsKey(id)) {
          final y = map[id] ?? 0.0;
          hasData[i] = true;
          if (y > maxY) maxY = y;
        }
      }

      // soldan/sağdan kırpma: ilk ve son veri index
      int baseIndex = hasData.indexWhere((e) => e);
      int endIndex = hasData.lastIndexWhere((e) => e);

      // hiç veri yoksa: kırpma yapma
      if (baseIndex == -1) baseIndex = 0;
      if (endIndex == -1) endIndex = days - 1;

      final visibleDays = (endIndex - baseIndex + 1).clamp(1, days);

      // şimdi points’i, baseIndex’e göre kaydırarak üret
      points.clear();
      for (int i = baseIndex; i <= endIndex; i++) {
        if (!hasData[i]) continue;

        final day = start.add(Duration(days: i));
        final id = dateId(day);
        final y = map[id] ?? 0.0;

        points.add(FlSpot((i - baseIndex).toDouble(), y));
      }

      if (points.isEmpty) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 15),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.75),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Haftalık Kalori Takibi",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                "Henüz veri yok — öğün ekledikçe grafik oluşur",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}
if (maxY < 500) maxY = 500;

      const trMonths = [
        "Oca",
        "Şub",
        "Mar",
        "Nis",
        "May",
        "Haz",
        "Tem",
        "Ağu",
        "Eyl",
        "Eki",
        "Kas",
        "Ara"
      ];
      const trWeekdays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cts", "Paz"];

      String formatDate(DateTime d) => "${d.day} ${trMonths[d.month - 1]}";
      String formatWeekday(DateTime d) => trWeekdays[d.weekday - 1];

      // bugün label'ı: her zaman altta sağda görünsün (grafiği uzatmadan)
      final today = DateTime(now.year, now.month, now.day);
      final todayLabel = "${formatWeekday(today)} ${formatDate(today)}";

      // bugün kırpılan aralığın içinde mi?
      final rawTodayShifted = (days - 1) - baseIndex;
      final todayShifted =
          rawTodayShifted.clamp(0, (visibleDays - 1).toInt()); // güvenli
      final todayIsInRange =
          (days - 1) >= baseIndex && (days - 1) <= endIndex; // gerçek kontrol

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Haftalık Kalori Takibi",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: Column(
                children: [
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (visibleDays - 1).toDouble(),
                        minY: 0,
                        maxY: maxY * 1.1,
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 26, // overlay ile daha kompakt
                              getTitlesWidget: (value, meta) {
                                final shifted = value.toInt();

                                if (shifted < 0 || shifted >= visibleDays) {
                                  return const SizedBox.shrink();
                                }

                                final actualIndex = shifted + baseIndex;
                                if (actualIndex < 0 || actualIndex >= days) {
                                  return const SizedBox.shrink();
                                }

                                // bugün grafiğin içindeyse belirgin yapalım
                                final isToday =
                                    todayIsInRange && shifted == todayShifted;

                                // bugün hariç kalabalığı azaltmak için 2 günde bir
                                if (!isToday && shifted % 2 != 0) {
                                  return const SizedBox.shrink();
                                }

                                // bugün hariç sadece veri olan günler
                                if (!isToday && !hasData[actualIndex]) {
                                  return const SizedBox.shrink();
                                }

                                final day =
                                    start.add(Duration(days: actualIndex));
                                final wd = formatWeekday(day);
                                final dt = formatDate(day);

                                final color = isToday
                                    ? Colors.grey.shade700
                                    : Colors.grey.withOpacity(0.28);

                                return SideTitleWidget(
                                  meta: meta,
                                  space: 10,
                                  child: Text(
                                    "$wd $dt",
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontSize: isToday ? 10.5 : 9,
                                      fontWeight: isToday
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) =>
                                Colors.white.withOpacity(0.9),
                          ),
                          touchCallback: (event, response) {
                            if (event is! FlTapUpEvent) return;

                            final spots = response?.lineBarSpots;
                            if (spots == null || spots.isEmpty) return;

                            final spot = spots.first;
                            final shifted = spot.x.round();
                            if (shifted < 0 || shifted >= visibleDays) return;

                            final actualIndex = shifted + baseIndex;
                            if (actualIndex < 0 || actualIndex >= days) return;

                            if (!hasData[actualIndex]) return;

                            final selectedDate = DateTime(
                              start.year,
                              start.month,
                              start.day,
                            ).add(Duration(days: actualIndex));

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DailyTrackerScreen(selectedDate: selectedDate),
                              ),
                            );
                          },
                        ),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: targetCalories,
                              strokeWidth: 1,
                              color: Colors.grey.withOpacity(0.25),
                              dashArray: [6, 6],
                            ),
                          ],
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: points,
                            isCurved: true,
                            barWidth: 3,
                            color: const Color(0xFF00ACC1),
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.12),
                              cutOffY: targetCalories,
                              applyCutOffY: true,
                            ),
                            aboveBarData: BarAreaData(
                              show: true,
                              color: Colors.red.withOpacity(0.10),
                              cutOffY: targetCalories,
                              applyCutOffY: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                 
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
  Widget _buildStreakIndicator(String days) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Colors.orange, size: 20),
          const SizedBox(width: 4),
          Text(days,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildMainDashboardCard({
    required int targetCalories,
    required int consumedCalories,

      required int burnedCalories,
  required int proteinTargetG,

    required int proteinG,
    required int carbsG,
    required int fatG,

    required int fiberG,
    required int sugarG,
  }) {
   
    const int carbsTarget = 215;
    const int fatTarget = 70;
    const int fiberTarget = 30;
    const int sugarTarget = 50;

    double pct(int current, int target) {
      if (target <= 0) return 0.0;
      final v = current / target;
      if (v < 0) return 0.0;
      if (v > 1) return 1.0;
      return v;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E6F5E).withOpacity(0.06), blurRadius: 30)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                // ✅ Hepsini daire tasarımında + yatay kaydırma
                SizedBox(
                  height: 115,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      const SizedBox(width: 4),
                      _buildMacroCircle(
                        "Kalori",
                        "$consumedCalories",
                        "$targetCalories",
                        const Color(0xFFA3E4A6).withOpacity(0.3),
                        percent: pct(consumedCalories, targetCalories),
                      ),
                      const SizedBox(width: 14),
                     _buildMacroCircle(
  "Protein",
  "${proteinG}g",
  "${proteinTargetG}g",
  const Color(0xFFFFE0B2).withOpacity(0.3),
  percent: pct(proteinG, proteinTargetG),
),
                      const SizedBox(width: 14),
                      _buildMacroCircle(
                        "Karb.",
                        "${carbsG}g",
                        "${carbsTarget}g",
                        const Color(0xFFBBDEFB).withOpacity(0.3),
                        percent: pct(carbsG, carbsTarget),
                      ),
                      const SizedBox(width: 14),
                      _buildMacroCircle(
                        "Yağ",
                        "${fatG}g",
                        "${fatTarget}g",
                        const Color(0xFFF3E5F5).withOpacity(0.55),
                        percent: pct(fatG, fatTarget),
                      ),
                      const SizedBox(width: 14),
                      _buildMacroCircle(
                        "Lif",
                        "${fiberG}g",
                        "${fiberTarget}g",
                        const Color(0xFFE8F5E9).withOpacity(0.55),
                        percent: pct(fiberG, fiberTarget),
                      ),
                      const SizedBox(width: 14),
                      _buildMacroCircle(
                        "Şeker",
                        "${sugarG}g",
                        "${sugarTarget}g",
                        const Color(0xFFFFF3E0).withOpacity(0.55),
                        percent: pct(sugarG, sugarTarget),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

// ✅ Yakılan + Net
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    _buildMiniInlineStat(
      label: "Yakılan",
      value: "$burnedCalories kcal",
      icon: Icons.local_fire_department_rounded,
    ),
    _buildMiniInlineStat(
      label: "Net",
      value: "${consumedCalories - burnedCalories} kcal",
      icon: Icons.balance_rounded,
    ),
  ],
),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildMiniInlineStat({
  required String label,
  required String value,
  required IconData icon,
}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF128D64)),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black45,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    ],
  );
}
  Widget _buildMacroCircle(
    String label,
    String current,
    String target,
    Color bgColor, {
    required double percent,
  }) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 35.0,
          lineWidth: 6.0,
          percent: percent,
          center: Text(
            current,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          progressColor: const Color(0xFF128D64),
          backgroundColor: bgColor,
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWaterBento(double current, double target) {
    return _buildBentoWrapper(
      color: const Color(0xFFE3F2FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.water_drop_rounded,
              color: Color(0xFF2196F3), size: 28),
          const SizedBox(height: 15),
          const Text("Su Takibi",
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold)),
          Text("$current / $target L",
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D47A1))),
        ],
      ),
    );
  }

  Widget _buildEfficiencyBento({required int score, required String tip}) {
  return _buildBentoWrapper(
    color: const Color(0xFFF3E5F5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.insights_rounded, color: Colors.purple, size: 28),
        const SizedBox(height: 15),
        const Text(
          "Verimlilik",
          style: TextStyle(
            fontSize: 12,
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "%$score Skor",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tip,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ],
    ),
  );
}


  Widget _buildBentoWrapper({required Widget child, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: child,
    );
  }
  
 
 Widget _buildMonthlyCalendar(String uid, {required int targetCalories}) {
  final now = DateTime.now();
  Color _dayColor(int calories, int target) {
  if (calories <= 0) return Colors.black.withOpacity(0.06);
  if (target <= 0) return const Color(0xFF2E6F5E).withOpacity(0.20);

  final ratio = calories / target;

  // 0..1: yeşile yaklaş
  if (ratio <= 1.0) {
    final t = ratio.clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFF2E6F5E).withOpacity(0.10),
      const Color(0xFF2E6F5E).withOpacity(0.40),
      t,
    )!;
  }

  // 1..1.4: turuncuya kay
  final overT = ((ratio - 1.0) / 0.4).clamp(0.0, 1.0);
  return Color.lerp(
    const Color(0xFF2E6F5E).withOpacity(0.40),
    Colors.orange.withOpacity(0.45),
    overT,
  )!;
}

  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

  final monthPrefix = "${now.year}-${now.month.toString().padLeft(2, '0')}";

  final stream = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_summaries')
      .where('date', isGreaterThanOrEqualTo: "$monthPrefix-01")
      .where(
        'date',
        isLessThan:
            "${now.year}-${(now.month + 1).toString().padLeft(2, '0')}-01",
      )
      .snapshots();

  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? [];
      final map = {for (final d in docs) d.id: d.data()};

      int _toInt(dynamic v) {
        if (v == null) return 0;
        if (v is int) return v;
        if (v is double) return v.round();
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }

      return SizedBox(
        height: 62,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: daysInMonth,
          itemBuilder: (context, index) {
            final day = index + 1;
            final id = "$monthPrefix-${day.toString().padLeft(2, '0')}";
            final data = map[id];

            final calories = _toInt(data?['calories']);

            final selectedDate = DateTime(now.year, now.month, day);
            final todayStart = DateTime(now.year, now.month, now.day);
            final isFuture = selectedDate.isAfter(todayStart);

            final isToday = day == now.day;

            final bg = _dayColor(calories, targetCalories);

            return Opacity(
              opacity: isFuture ? 0.45 : 1,
              child: GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DailyTrackerScreen(selectedDate: selectedDate),
                          ),
                        );
                      },
                child: Container(
                  width: 44,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: isToday
                        ? Border.all(
                            color: const Color(0xFF2E6F5E),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      "$day",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: calories > 0
                            ? const Color(0xFF2E6F5E)
                            : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Widget _buildFoodCardLive(
  BuildContext context,
  String title,
  String kcal,
  String mealType,
) {
  IconData icon;
  Color chipColor;

  switch (mealType) {
    case "Kahvaltı":
      icon = Icons.wb_sunny_rounded;
      chipColor = const Color(0xFFFFF3E0);
      break;
    case "Öğle Yemeği":
      icon = Icons.wb_cloudy_rounded;
      chipColor = const Color(0xFFE3F2FD);
      break;
    case "Akşam Yemeği":
      icon = Icons.nightlight_round_rounded;
      chipColor = const Color(0xFFF3E5F5);
      break;
    default:
      icon = Icons.apple_rounded;
      chipColor = const Color(0xFFE8F5E9);
  }

  return GestureDetector(
    onTap: () => MainTabScope.of(context)?.setIndex(1),
    child: Container(
      width: 175,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              kcal,
              style: const TextStyle(
                color: Color(0xFF2E6F5E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                mealType.isEmpty ? "Öğün" : mealType,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildEmptyMenuCard(BuildContext context) {
  final accent = const Color(0xFF128D64);

  return Container(
    width: 280,
    margin: const EdgeInsets.only(right: 14),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const DailyTrackerScreen()),
),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFEFF8F4),
              ],
            ),
            border: Border.all(
              color: accent.withOpacity(0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.restaurant_rounded, color: accent),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Bugün henüz ekleme yok",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: Color(0xFF0B3D2E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Öğün ekleyerek menünü burada görürsün.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        "Öğün ekle",
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: -0.1,
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
    ),
  );
}

Widget _buildEfficiencyCard({
  required String uid,
  required int targetCalories,
  required Stream<QuerySnapshot<Map<String, dynamic>>> foodStream,
  required double todayCalories, // TodaySummary’dan
  required double todayWaterMl,  // TodaySummary’dan
}) {
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
    builder: (context, userSnap) {
      final userData = userSnap.data?.data();
      final targetGlasses =
          (userData?['water_target_glasses'] as num?)?.toInt() ?? 10;

      final waterTargetMl = targetGlasses * 250.0;

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: foodStream,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          // meals completed + fiber/sugar
          final meals = <String>{};
          double fiber = 0;
          double sugar = 0;

          for (final d in docs) {
            final data = d.data();
            final meal = (data['mealType'] ?? '').toString();
            if (meal.isNotEmpty) meals.add(meal);

            final f = data['fiber_g'];
            final s = data['sugar_g'];
            if (f is num) fiber += f.toDouble();
            if (s is num) sugar += s.toDouble();
          }

          final mealsCompleted = meals.length.clamp(0, 4);

          final res = _calcEfficiency(
            targetCalories: targetCalories,
            consumedCalories: todayCalories,
            waterMl: todayWaterMl,
            waterTargetMl: waterTargetMl,
            mealsCompleted: mealsCompleted,
            fiberG: fiber,
            sugarG: sugar,
          );

          final score = res["score"] as int;
          final tip = res["tip"] as String;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E6F5E).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Skor",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$score",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Verimlilik",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tip,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


Widget _buildFoodCard(
  BuildContext context,
  String title,
  String kcal,
  String imgUrl,
) {
  return GestureDetector(
    onTap: () => MainTabScope.of(context)?.setIndex(1),
    child: Container(
      width: 175,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Image.network(
              imgUrl,
              height: 115,
              width: 175,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  kcal,
                  style: const TextStyle(
                    color: Color(0xFF2E6F5E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  String _fmtKcal(num v) {
  final n = v.round();
  return "$n kcal";
}

}