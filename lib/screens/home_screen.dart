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
                    Text(userName,
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
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

                          proteinG: s.proteinG,
                          carbsG: s.carbsG,
                          fatG: s.fatG,

                          // ✅ lif/şeker: bugün entries’den
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
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => goTab(3),
                            behavior: HitTestBehavior.opaque,
                            // ✅ 2.5 sabiti yerine dinamik hedef litre
                            child: _buildWaterBento(currentLiters, waterTargetLiters),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => goTab(2),
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
                );
              },
            );
          },
        );
      },
    );
  },
),
          
          // 4. MENÜ BAŞLIĞI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Bugünkü Menün",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5)),
                TextButton(
                  onPressed: () => goTab(1),
                  child: const Text("Tümü",
                      style: TextStyle(
                          color: Color(0xFF128D64),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // 5. YEMEK KARTLARI (Yatay Kaydırma)
         SizedBox(
  height: 220,
  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: foodStream, // HomeScreen'de zaten tanımlı
    builder: (context, snap) {
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final docs = snap.data!.docs;

      if (docs.isEmpty) {
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          children: [
            _buildEmptyMenuCard(context),
          ],
        );
      }

      // createdAt'e göre en yeni üstte
      docs.sort((a, b) {
        final ta = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tb = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return tb.compareTo(ta);
      });

      // ✅ Öğüne göre grupla
final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
for (final d in docs) {
  final meal = (d.data()['mealType'] ?? 'Yiyecek').toString();
  grouped.putIfAbsent(meal, () => []).add(d);
}

// (İsteğe bağlı) sabit sıralama
const mealOrder = <String>[
  'Kahvaltı',
  'Öğle Yemeği',
  'Akşam Yemeği',
  'Ara Öğün',
  'Yiyecek',
];

final meals = grouped.keys.toList()
  ..sort((a, b) {
    final ia = mealOrder.indexOf(a);
    final ib = mealOrder.indexOf(b);
    if (ia == -1 && ib == -1) return a.compareTo(b);
    if (ia == -1) return 1;
    if (ib == -1) return -1;
    return ia.compareTo(ib);
  });

return ListView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: 15),
  children: meals.map((mealType) {
    final entries = grouped[mealType] ?? [];
    return _buildMealGroupCardLive(context, mealType, entries);
  }).toList(),
);
    },
  ),
),


          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- YARDIMCI WIDGETLAR ---

  Widget _buildMealGroupCardLive(
  BuildContext context,
  String mealType,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
) {
  // kart toplamı
  final total = entries.fold<double>(0.0, (sum, e) {
    final c = e.data()['calories'];
    final v = (c is num) ? c.toDouble() : double.tryParse(c?.toString() ?? '0') ?? 0.0;
    return sum + v;
  });

  // kart içi max 6 item gösterelim
  final shown = entries.take(6).toList();

  return Container(
    width: 280,
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.75),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withOpacity(0.9)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                mealType,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              "${total.round()} kcal",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF128D64),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final data = shown[i].data();
              final name = (data['name'] ?? 'Yiyecek').toString();
              final kcal = (data['calories'] ?? 0).toString();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACC1).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "$kcal kcal",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (entries.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "+${entries.length - 6} daha",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black38,
              ),
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

final stream = FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('daily_summaries')
    .where('date', isGreaterThanOrEqualTo: dateId(start))
    .where('date', isLessThanOrEqualTo: dateId(now))
    .orderBy('date') // ✅ şart
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
  final date = (data['date'] ?? '').toString();

 final raw = (data['totalCalories'] ?? data['calories'] ?? 0);
final cal = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;

// daily_summaries zaten gün bazlı tek doc ise biriktirme yerine direkt ata
map[date] = cal < 0 ? 0 : cal;
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

      if (points.isEmpty) maxY = 500;
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

    required int proteinG,
    required int carbsG,
    required int fatG,

    required int fiberG,
    required int sugarG,
  }) {
    // ✅ hedefler (şimdilik sabit; istersen profilden de çekebiliriz)
    const int proteinTarget = 160;
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
                        "${proteinTarget}g",
                        const Color(0xFFFFE0B2).withOpacity(0.3),
                        percent: pct(proteinG, proteinTarget),
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
              ],
            ),
          ),
        ),
      ),
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
  return GestureDetector(
    onTap: () => MainTabScope.of(context)?.setIndex(1),
    child: Container(
      width: 260,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.add_circle_outline_rounded,
            color: Color(0xFF2E6F5E),
            size: 28,
          ),
          SizedBox(height: 10),
          Text(
            "Bugün henüz bir şey eklemedin",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Bir öğüne dokun ve eklemeye başla.",
            style: TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
}