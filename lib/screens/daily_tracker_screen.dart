// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'food_search_screen.dart';
import '../widgets/main_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/date_range.dart';
import '../services/weight_service.dart';



class DailyTrackerScreen extends StatelessWidget {
   final DateTime? selectedDate;
  const DailyTrackerScreen({super.key, this.selectedDate});

  String _formatTrDate(DateTime d) {
    const months = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
    return "${d.day} ${months[d.month - 1]}";
  }
  String _dateId(DateTime d) =>
    "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
Future<void> _applyDailySummaryDelta({
  required String uid,
  required DateTime day,
  required Map<String, double> delta,
}) async {
  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_summaries')
      .doc(_dateId(day));

  final data = <String, dynamic>{
    'date': _dateId(day),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  for (final e in delta.entries) {
    if (e.value == 0) continue;
    data[e.key] = FieldValue.increment(e.value);
  }

  await ref.set(data, SetOptions(merge: true));
}

void _showFoodEntryActions(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  DateTime selectedDay,
) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Düzenle"),
              onTap: () {
                Navigator.pop(context);
                _editFoodEntry(context, uid, doc, selectedDay);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("Sil"),
              onTap: () {
                Navigator.pop(context);
                _deleteFoodEntry(context, uid, doc, selectedDay);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _updateDailySummary({
  required String uid,
  required DateTime date,
  required double caloriesToAdd,
}) async {
  final dateStr =
      "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";

  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_summaries')
      .doc(dateStr);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);

    if (snapshot.exists) {
      final currentCalories =
          (snapshot.data()?['totalCalories'] ?? 0).toDouble();

      transaction.update(docRef, {
        'totalCalories': currentCalories + caloriesToAdd,
      });
    } else {
      transaction.set(docRef, {
        'date': dateStr,
        'totalCalories': caloriesToAdd,
      });
    }
  });
}

Future<void> _deleteFoodEntry(
  BuildContext context,
  String uid,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  DateTime selectedDay,
) async {
  final data = doc.data();

  final kcal = _asDouble(data['calories']);
  final protein = _asDouble(data['protein_g']);
  final carbs = _asDouble(data['carbs_g']);
  final fat = _asDouble(data['fat_g']);
  final fiber = _asDouble(data['fiber_g']);
  final sugar = _asDouble(data['sugar_g']);

  // 1) entry sil
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('food_entries')
      .doc(doc.id)
      .delete();

  // 2) summary toplamından düş
  await _applyDailySummaryDelta(
    uid: uid,
    day: selectedDay,
    delta: {
      'totalCalories': -kcal,
      'calories': -kcal,
      'protein_g': -protein,
      'carbs_g': -carbs,
      'fat_g': -fat,
      'fiber_g': -fiber,
      'sugar_g': -sugar,
    },
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Yemek silindi.")),
    );
  }
}

Future<void> _editFoodEntry(
  BuildContext context,
  String uid,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  DateTime selectedDay,
) async {
  final old = doc.data();

  final nameCtrl = TextEditingController(text: (old['name'] ?? '').toString());
  final kcalCtrl = TextEditingController(text: _asDouble(old['calories']).toStringAsFixed(0));
  final pCtrl = TextEditingController(text: _asDouble(old['protein_g']).toStringAsFixed(1));
  final cCtrl = TextEditingController(text: _asDouble(old['carbs_g']).toStringAsFixed(1));
  final fCtrl = TextEditingController(text: _asDouble(old['fat_g']).toStringAsFixed(1));

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text("Yemeği düzenle"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ad")),
              TextField(controller: kcalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Kalori (kcal)")),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Protein (g)"))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Karbonhidrat (g)"))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Yağ (g)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Kaydet")),
        ],
      );
    },
  );

  if (ok != true) return;

  final newName = nameCtrl.text.trim().isEmpty ? (old['name'] ?? 'Yiyecek').toString() : nameCtrl.text.trim();
  final newKcal = _asDouble(kcalCtrl.text);
  final newP = _asDouble(pCtrl.text);
  final newC = _asDouble(cCtrl.text);
  final newF = _asDouble(fCtrl.text);

  final oldKcal = _asDouble(old['calories']);
  final oldP = _asDouble(old['protein_g']);
  final oldC = _asDouble(old['carbs_g']);
  final oldF = _asDouble(old['fat_g']);

  // 1) entry update
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('food_entries')
      .doc(doc.id)
      .update({
    'name': newName,
    'calories': newKcal,
    'protein_g': newP,
    'carbs_g': newC,
    'fat_g': newF,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  // 2) summary delta uygula
  await _applyDailySummaryDelta(
    uid: uid,
    day: selectedDay,
    delta: {
      'totalCalories': (newKcal - oldKcal),
      'calories': (newKcal - oldKcal),
      'protein_g': (newP - oldP),
      'carbs_g': (newC - oldC),
      'fat_g': (newF - oldF),
    },
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Yemek güncellendi.")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

   
    final day = selectedDate == null
        ? DateTime.now()
        : DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);

    final range = DateRange.forDay(day);

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final isFuture = day.isAfter(todayOnly);
    final isCalendarMode = selectedDate != null;

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
       title: isCalendarMode ? (isFuture ? "Gelecek Tarih" : _formatTrDate(day)) : "Günlük Takip",
      subtitle: isCalendarMode ? "Günlük Takip" : null,
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
List<QueryDocumentSnapshot<Map<String, dynamic>>> mealDocs(String mealType) {
  return docs
      .where((d) => (d.data()['mealType'] ?? '') == mealType)
      .toList();
}

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
                      entries: mealDocs("Kahvaltı"),
                    ),
                    _buildMealBento(
                      context,
                      "Öğle Yemeği",
                      "$lunch kcal",
                      Icons.wb_cloudy_rounded,
                      const Color(0xFFE3F2FD),
                      entries: mealDocs("Öğle Yemeği"),
                    ),
                    _buildMealBento(
                      context,
                      "Akşam Yemeği",
                      "$dinner kcal",
                      Icons.nightlight_round_rounded,
                      const Color(0xFFF3E5F5),
                      entries: mealDocs("Akşam Yemeği"),
                    ),
                    _buildMealBento(
                      context,
                      "Atıştırmalık",
                      "$snack kcal",
                      Icons.apple_rounded,
                      const Color(0xFFE8F5E9),
                      entries: mealDocs("Atıştırmalık"),
                    ),
                   _buildWeightQuickAddCard(context),
const SizedBox(height: 14),
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

  double? _parseKg(String raw) {
  final cleaned = raw
      .trim()
      .toLowerCase()
      .replaceAll('kg', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned);
}
  Widget _buildWeightQuickAddCard(BuildContext context) {
  return GestureDetector(
    onTap: () => _openAddWeightSheet(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: const [
          Icon(Icons.monitor_weight_outlined, color: Color(0xFF2E6F5E)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Kilo Kaydı Ekle",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
          Icon(Icons.add_circle_outline_rounded, color: Colors.black26),
        ],
      ),
    ),
  );
}

Future<void> _openAddWeightSheet(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Giriş yapılmamış görünüyor.")),
    );
    return;
  }

  final ctrl = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Kilo Kaydı", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: "Örn: 78.4",
                filled: true,
                fillColor: Colors.black.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
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
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text("Geçerli bir kilo gir.")),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  final day = DateTime(now.year, now.month, now.day);
                  final docId =
                      "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

              final base = selectedDate ?? DateTime.now();

await WeightService().addWeight(
  kg: v,
  forDateTime: DateTime(base.year, base.month, base.day, 12),
);




                  Navigator.pop(sheetContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Kilo kaydedildi ✅")),
                  );
                },
                child: const Text(
                  "Kaydet",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildMealBento(
    BuildContext context,
    String title,
    String calories,
    IconData icon,
    Color color, {
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
 } ) {
     final selectedDay = selectedDate == null
    ? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
    : DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);


    return GestureDetector(
   

     onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FoodSearchScreen(mealType: title, selectedDate: selectedDay)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
       child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.black54),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                calories,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Colors.black38),
      ],
    ),

    // ✅ AŞAMA 3: CHIP LİSTESİ
    if (entries.isNotEmpty) ...[
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.take(4).map((e) {
          final data = e.data();
          final name = (data['name'] ?? 'Yiyecek').toString();
          final kcal = (data['calories'] ?? 0).toString();

   return Material(
  color: Colors.transparent, // ✅ InkWell için yüzey
  child: InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () {}, // ✅ parent GestureDetector ile gesture çakışmasını azaltır
    onLongPress: () => _showFoodEntryActions(context, e, selectedDay),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
      ),
      child: Text(
        "$name • ${kcal}kcal",
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    ),
  ),
);
        }).toList(),
      ),
      if (entries.length > 4)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            "+${entries.length - 4} daha",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black38,
            ),
          ),
        ),
    ],
  ],
),

      ),
    );
  }
}
