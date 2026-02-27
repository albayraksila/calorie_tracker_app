import 'dart:async';
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
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('daily_summaries')
          .doc(id)
          .get();

      if (!snap.exists) break;

      final data = snap.data() ?? {};
final v = (data['totalCalories'] ?? data['calories'] ?? 0);
final total = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

if (total > 0) {
  streak++;
} else {
  break;
}
    }

    return streak;
  }

  /// ✅ BUGÜN toplamlarını stream olarak verir (food + water sürekli güncellenir)
  Stream<TodaySummary> watchTodaySummary(String uid) {
    final range = DateRange.today();

    final foodQuery = _db
        .collection('users')
        .doc(uid)
        .collection('food_entries')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end));

    final waterQuery = _db
        .collection('users')
        .doc(uid)
        .collection('water_entries')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end));

     final activityQuery = _db 
        .collection('users')
        .doc(uid)
        .collection('activity_entries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end));

    final controller = StreamController<TodaySummary>.broadcast();

    int calories = 0,burned = 0, protein = 0, carbs = 0, fat = 0, waterMl = 0;
    StreamSubscription? foodSub;
    StreamSubscription? waterSub;
     StreamSubscription? activitySub;

    void emit() {
      if (!controller.isClosed) {
        controller.add(TodaySummary(
          calories: calories,
          burnedCalories: burned,
          proteinG: protein,
          carbsG: carbs,
          fatG: fat,
          waterMl: waterMl,
        ));
      }
    }

    controller.onListen = () {
      foodSub = foodQuery.snapshots().listen((snap) {
        int c = 0, p = 0, cb = 0, f = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          c += _toInt(data['calories']);
          p += _toInt(data['protein_g']);
          cb += _toInt(data['carbs_g']);
          f += _toInt(data['fat_g']);
        }
        calories = c;
        protein = p;
        carbs = cb;
        fat = f;
        emit();
      }, onError: controller.addError);

       waterSub = waterQuery.snapshots().listen((snap) {
        int w = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          w += _toInt(data['amount_ml']);
        }
        waterMl = w;
        emit();
      }, onError: controller.addError);

      activitySub = activityQuery.snapshots().listen((snap) { // ✅
        double b = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          final v = data['caloriesBurned'];
          if (v is num) b += v.toDouble();
        }
        burned = b.round();
        emit();
      }, onError: controller.addError);
    };

    controller.onCancel = () async {
      await foodSub?.cancel();
      await waterSub?.cancel();
      await activitySub?.cancel(); // ✅
      await controller.close();
    };

    return controller.stream;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}