import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/main_layout.dart';
import '../models/weight_entry.dart';
import 'weekly_summary_screen.dart';
import '../services/weight_service.dart';


class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

int _rangeDays = 7; // 7=haftalık, 30=aylık

double? _parseKg(String raw) {
  final cleaned = raw
      .trim()
      .toLowerCase()
      .replaceAll('kg', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.');

  return double.tryParse(cleaned);
}


  // ----------------------------
  // Streams
  // ----------------------------
  
Color _getTrendColor(List<WeightEntry> entries) {
  if (entries.length < 2) {
    return const Color(0xFF2E6F5E); // veri azsa nötr-yeşil
  }

  // kronolojik sıraya al
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));

  final first = sorted.first.weightKg;
  final last = sorted.last.weightKg;

  final diff = last - first; // + ise kilo alımı, - ise kayıp

  // Haftalık / aylık ölçekleme
  final perWeek = diff * (7 / _rangeDays);

  // 🎯 Kurallar
  if (perWeek <= -0.2) {
    // Yavaş düşüş
    return const Color(0xFF2E6F5E); // yeşil
  }

  if (perWeek >= 0.8) {
    // Hızlı artış
    return const Color(0xFFD64545); // kırmızı
  }

  if (perWeek >= 0.2) {
    // Hafif artış
    return const Color(0xFFE76F51); // turuncu
  }

  // Stabil
  return const Color(0xFF2E6F5E);
}


  Stream<int> _weighIntervalStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(7);

    return FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      final v = data?['weigh_in_interval_days'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 7;
    });
  }
  
Stream<List<WeightEntry>> _weightEntriesStream() {
  final uid = _uid;
  if (uid == null) return const Stream.empty();

  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final start = end.subtract(Duration(days: _rangeDays));

  final q = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('weight_entries')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThan: Timestamp.fromDate(end))
      .orderBy('date', descending: true);

  return q.snapshots().map((snap) {
    final list = snap.docs.map((d) => WeightEntry.fromSnapshot(d)).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  });
}


  Stream<_WeeklyMacros> _weeklyMacrosStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 7));

    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('food_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end));

    return q.snapshots().map((snap) {
      int p = 0, c = 0, f = 0;
      for (final d in snap.docs) {
        final data = d.data();
        p += _toInt(data['protein_g']);
        c += _toInt(data['carbs_g']);
        f += _toInt(data['fat_g']);
      }
      return _WeeklyMacros(carbsG: c, proteinG: p, fatG: f);
    });
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

void _openWeightManageSheet(List<WeightEntry> entries) {
  final ws = WeightService();

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final e = entries[entries.length - 1 - i]; // en yeni üstte
          final dateStr =
              "${e.date.day.toString().padLeft(2,'0')}.${e.date.month.toString().padLeft(2,'0')}.${e.date.year}";

          return ListTile(
            title: Text(
              "$dateStr • ${e.weightKg.toStringAsFixed(1)} kg",
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  final ctrl = TextEditingController(text: e.weightKg.toStringAsFixed(1));
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Kilo düzenle"),
                      content: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: "kg"),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Kaydet")),
                      ],
                    ),
                  );

                  if (ok == true) {
                    final kg = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
                    if (kg != null) await ws.updateWeight(entryId: e.id, kg: kg);
                  }
                }

                if (v == 'delete') {
                  await ws.deleteWeight(entryId: e.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text("Düzenle")),
                PopupMenuItem(value: 'delete', child: Text("Sil")),
              ],
            ),
          );
        },
      ),
    ),
  );
}
  // ----------------------------
  // UI
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "İstatistikler",
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Kilo Değişimi"),
            const SizedBox(height: 12),

            const SizedBox(height: 8),
_buildRangeToggle(),
const SizedBox(height: 10),


            // ✅ Kilo grafiği + tartılma kartı (gerçek veri)
            _buildChartBento(
              height: 260,
              child: StreamBuilder<int>(
                stream: _weighIntervalStream(),
                builder: (context, intervalSnap) {
                  final intervalDays = intervalSnap.data ?? 7;

                  return StreamBuilder<List<WeightEntry>>(
                    stream: _weightEntriesStream(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(child: Text("Hata: ${snap.error}"));
                      }

                      final entries = snap.data ?? const <WeightEntry>[];

                      final showDueCard = _shouldShowWeighCard(entries, intervalDays);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            _buildWeightHeader(entries),
    const SizedBox(height: 10),
                          Expanded(
  child: entries.isEmpty
      ? LineChart(_weightChartDataDemo())
      : Stack(
          children: [
            LineChart(_weightChartDataFromEntries(entries)),
            Positioned(
              right: 0,
              top: 0,
              child: _buildMinMaxBadgesFromEntries(entries),
            ),
          ],
        ),
),


                          if (showDueCard) _buildWeighInCard(intervalDays),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            _buildSectionHeader("Besin Dağılımı"),
            const SizedBox(height: 12),

            // ✅ Haftalık makrolar (son 7 gün) — gerçek veri
            _buildChartBento(
              height: 200,
              child: StreamBuilder<_WeeklyMacros>(
                stream: _weeklyMacrosStream(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text("Hata: ${snap.error}"));
                  }

                  final m = snap.data ?? const _WeeklyMacros(carbsG: 0, proteinG: 0, fatG: 0);

                  final total = m.carbsG + m.proteinG + m.fatG;
                  if (total == 0) {
  return const Center(
    child: Text(
      "Bu hafta besin kaydı yok.\nÖğün ekledikçe dağılım burada görünecek.",
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45, height: 1.4),
    ),
  );
}
                 final double carbs = m.carbsG.toDouble();
final double protein = m.proteinG.toDouble();
final double fat = m.fatG.toDouble();

                  return Row(
                    children: [
                      SizedBox(
                        height: 160,
                        width: 160,
                        child: PieChart(_macroChartData(
                           carbsValue: carbs,
        proteinValue: protein,
        fatValue: fat,
                        )),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MacroIndicator(
                            color: const  Color(0xFFD8B26E),
                            text: "Karb. ${m.carbsG}g",
                          ),
                          const SizedBox(height: 8),
                          _MacroIndicator(
                            color: const Color(0xFFF3E6C6),
                            text: "Protein ${m.proteinG}g",
                          ),
                          const SizedBox(height: 8),
                          _MacroIndicator(
                            color: const Color(0xFFB9D38B),
                            text: "Yağ ${m.fatG}g",
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Haftalık analiz ekranına geçiş
            _buildSummaryButton(context),
          ],
        ),
      ),
    );
  }

  bool _shouldShowWeighCard(List<WeightEntry> entries, int intervalDays) {
    if (entries.isEmpty) return true;

    final last = entries.last.date; // kronolojik listede son = en yeni değil, o yüzden max alacağız
    DateTime newest = entries.first.date;
    for (final e in entries) {
      if (e.date.isAfter(newest)) newest = e.date;
    }

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final diff = todayStart.difference(newest).inDays;
    return diff >= intervalDays;
  }

  Widget _buildWeighInCard(int intervalDays) {
    return GestureDetector(
      onTap: _openAddWeightSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2E6F5E).withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2E6F5E).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.monitor_weight_outlined, color: Color(0xFF2E6F5E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Tartılma zamanı! (Aralık: $intervalDays gün)\nKilonu kaydet ve grafiğin güncellensin.",
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black54, height: 1.3),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddWeightSheet() async {
    final uid = _uid;
    if (uid == null) return;

    final ctrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Yeni Kilo Kaydı",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "Örn: 78.4",
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E6F5E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final v = _parseKg(ctrl.text);

                    if (v == null || v <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Geçerli bir kilo gir.")),
                      );
                      return;
                    }

                    final now = DateTime.now();
                    final day = DateTime(now.year, now.month, now.day);
                    final docId =
                        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('weight_entries')
                        .doc(docId)
                        .set({
                      'date': Timestamp.fromDate(day),
                      'weight_kg': v,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text("Kilo kaydedildi ✅")),
                    );
                  },
                  child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------
  // Existing UI helpers (seninkiyle uyumlu)
  // ----------------------------

  Widget _buildSummaryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2E6F5E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E6F5E).withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Haftalık Analiz",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "7 günlük detaylı raporu gör",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    );
  }
  Widget _buildWeightHeader(List<WeightEntry> entries) {
  if (entries.isEmpty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text("Son 10 tartım", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
        Text("—", style: TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }

final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
final oldest = sorted.first;
final newest = sorted.last;
  final diff = newest.weightKg - oldest.weightKg;
  final sign = diff >= 0 ? "+" : "";
  final diffText = "$sign${diff.toStringAsFixed(1)} kg";

  return Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Son kilo",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45),
          ),
          const SizedBox(height: 2),
          Text(
            "${newest.weightKg.toStringAsFixed(1)} kg",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          "Değişim",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45),
        ),
        const SizedBox(height: 2),
        Text(
          diffText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: diff <= 0 ? const Color(0xFF2E6F5E) : Colors.deepOrange,
          ),
        ),
      ],
    ),
    const SizedBox(width: 6),
    IconButton(
      icon: const Icon(Icons.more_vert, color: Colors.black45),
      onPressed: () => _openWeightManageSheet(entries),
    ),
  ],
);
}
Widget _buildRangeToggle() {
  Widget chip(String label, int days) {
    final selected = _rangeDays == days;
    return GestureDetector(
      onTap: () => setState(() => _rangeDays = days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E6F5E) : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  return Row(
    children: [
      chip("Haftalık", 7),
      const SizedBox(width: 10),
      chip("Aylık", 30),
    ],
  );
}

Widget _buildMinMaxBadgesFromEntries(List<WeightEntry> entries) {
  if (entries.isEmpty) return const SizedBox.shrink();

  double minV = entries.first.weightKg;
  double maxV = entries.first.weightKg;

  for (final e in entries) {
    if (e.weightKg < minV) minV = e.weightKg;
    if (e.weightKg > maxV) maxV = e.weightKg;
  }

  Widget chip(String title, double v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        "$title ${v.toStringAsFixed(1)}",
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.black54,
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      chip("Min", minV),
      chip("Max", maxV),
    ],
  );
}


  Widget _buildChartBento({required Widget child, required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: child,
    );
  }

  // ----------------------------
  // Chart data
  // ----------------------------

  LineChartData _weightChartDataDemo() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 92),
            FlSpot(1, 91.5),
            FlSpot(2, 90.8),
            FlSpot(3, 90.2),
            FlSpot(4, 89.5),
          ],
          isCurved: true,
          color: const Color(0xFF2E6F5E),
          barWidth: 5,
          belowBarData: BarAreaData(show: true, color: const Color(0xFF2E6F5E).withOpacity(0.1)),
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }

  LineChartData _weightChartDataFromEntries(List<WeightEntry> entries) {
    final spots = <FlSpot>[];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].weightKg));
    }

    final ys = entries.map((e) => e.weightKg).toList()..sort();
    final minY = ys.first - 1.5;
    final maxY = ys.last + 1.5;
final lineColor = _getTrendColor(entries);



    return LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
  show: true,
  drawVerticalLine: false,
  getDrawingHorizontalLine: (value) => FlLine(
    color: Colors.black.withOpacity(0.06),
    strokeWidth: 1,
  ),
),
      borderData: FlBorderData(show: false),
     titlesData: FlTitlesData(
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      interval: 1,
      reservedSize: 28,
      getTitlesWidget: (value, meta) {
        final idx = value.toInt();
        if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();

        final d = entries[idx].date;

final dd = d.day.toString().padLeft(2, '0');
final mm = d.month.toString().padLeft(2, '0');

// Aynı gün birden fazla ölçüm varsa saat:dk göster
final sameDayCount = entries.where((e) =>
    e.date.year == d.year &&
    e.date.month == d.month &&
    e.date.day == d.day).length;

final label = sameDayCount > 1
    ? "$dd/$mm ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}"
    : "$dd/$mm";


        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.black45,
            ),
          ),
        );
      },
    ),
  ),
),

      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: lineColor,
          barWidth: 5,
          belowBarData: BarAreaData(show: true, color:  lineColor.withOpacity(0.12)),
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }

  PieChartData _macroChartData({
  required double carbsValue,
  required double proteinValue,
  required double fatValue,
}) {
  final total = carbsValue + proteinValue + fatValue;

  if (total <= 0) {
    return PieChartData(
      sections: const [],
      centerSpaceRadius: 34,
      sectionsSpace: 4,
    );
  }

  // 🔍 En büyük makroyu bul
  final maxValue = [carbsValue, proteinValue, fatValue].reduce(
    (a, b) => a > b ? a : b,
  );

  double radiusFor(double value) {
    return value == maxValue ? 52 : 44;
  }

  String pct(double v) {
    return "${((v / total) * 100).round()}%";
  }

  bool showLabel(double v) => ((v / total) * 100) >= 6;

  PieChartSectionData section({
    required double value,
    required Color color,
    required bool lightText,
    Color? borderColor,
  }) {
    return PieChartSectionData(
      value: value,
      color: color,
      radius: radiusFor(value), // ⭐ BURASI DEĞİŞTİ
      showTitle: showLabel(value),
      title: showLabel(value) ? pct(value) : "",
      titleStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: lightText ? Colors.white : Colors.black54,
      ),
      borderSide: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor, width: 2),
    );
  }

  return PieChartData(
    centerSpaceRadius: 34,
    sectionsSpace: 4,
    sections: [
      // Karbonhidrat - Tahıl tonu
      section(
        value: carbsValue,
        color: const Color(0xFFD8B26E),
        lightText: false,
      ),

      // Protein - Yumurta / Tavuk krem tonu
      section(
        value: proteinValue,
        color: const Color(0xFFF3E6C6),
        lightText: false,
      
      ),

      // Yağ - Zeytin / Ayçiçek tonu
      section(
        value: fatValue,
        color: const Color(0xFFB9D38B),
        lightText: false,
      ),
    ],
  );
}


}

class _WeeklyMacros {
  final int carbsG;
  final int proteinG;
  final int fatG;

  const _WeeklyMacros({
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
  });
}

class _MacroIndicator extends StatelessWidget {
  final Color color;
  final String text;
  const _MacroIndicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
      ],
    );
  }
}
