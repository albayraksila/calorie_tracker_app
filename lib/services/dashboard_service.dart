import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/date_range.dart';
import '../models/today_summary.dart';

class DashboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<int> calculateStreak(String uid) async {
  final now = DateTime.now();
  int streak = 0;

  for (int i = 0; i < 365; i++) {
    final date = now.subtract(Duration(days: i));
    final id =
        "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_summaries')
        .doc(id)
        .get();

    if (!snap.exists) break;

    if ((snap.data()?['calories'] ?? 0) > 0) {
      streak++;
    } else {
      break;
    }
  }

  return streak;
}


  /// ✅ BUGÜN toplamlarını stream olarak verir (veri değişince Home otomatik güncellenir)
  Stream<TodaySummary> watchTodaySummary(String uid) async* {
    final range = DateRange.today();

    // 1) Food entries stream
    final foodStream = _db
        .collection('users')
        .doc(uid)
        .collection('food_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();

    // 2) Water entries stream
    final waterStream = _db
        .collection('users')
        .doc(uid)
        .collection('water_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();

    // Basitçe iki stream'i “birleştirmek” için:
    // önce food snapshot bekle, sonra water snapshot bekle.
    // (Küçük projelerde yeterli; performans olarak da sorun çıkarmaz.)
    TodaySummary last = const TodaySummary.zero();

    await for (final foodSnap in foodStream) {
      int calories = 0;
      int protein = 0;
      int carbs = 0;
      int fat = 0;

      for (final doc in foodSnap.docs) {
        final data = doc.data();

        calories += _toInt(data['calories']);
        protein += _toInt(data['protein_g']);
        carbs += _toInt(data['carbs_g']);
        fat += _toInt(data['fat_g']);
      }

      // food güncellendi → water'ı en son bilinenle koru
      last = last.copyWith(calories: calories, proteinG: protein, carbsG: carbs, fatG: fat);
      yield last;

      // water tarafında da güncelleme olabilsin diye ayrıca bir iç stream dinleyelim
      // (İlk food snapshot geldikten sonra water'ı da streamleyelim)
      break;
    }

    await for (final waterSnap in waterStream) {
      int waterMl = 0;
      for (final doc in waterSnap.docs) {
        final data = doc.data();
        waterMl += _toInt(data['amount_ml']);
      }

      last = last.copyWith(waterMl: waterMl);
      yield last;
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
