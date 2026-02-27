import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Basit MET presetleri (istersen büyütürüz)
  static const Map<String, double> metPresets = {
    'Yürüyüş (orta tempo)': 3.5,
    'Yürüyüş (hızlı)': 4.8,
    'Koşu (yavaş)': 8.3,
    'Koşu (orta)': 9.8,
    'Bisiklet (orta)': 7.5,
    'Ağırlık Antrenmanı': 6.0,
    'Yüzme (orta)': 6.0,
    'Futbol': 7.0,
  };

  /// kcal = [(MET × 3.5 × kg) / 200] × dakika
  double caloriesBurned({
    required double met,
    required double weightKg,
    required int durationMin,
  }) {
    final perMin = (met * 3.5 * weightKg) / 200.0;
    return perMin * durationMin;
  }

  CollectionReference<Map<String, dynamic>> _ref(String uid) {
    return _db.collection('users').doc(uid).collection('activity_entries');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDay({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) {
    return _ref(uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addActivity({
    required String uid,
    required String type,
    required double met,
    required int durationMin,
    required double weightKg,
    String? note,
    DateTime? when,
  }) async {
    final createdAt = when ?? DateTime.now();
    final burned = caloriesBurned(met: met, weightKg: weightKg, durationMin: durationMin);

    await _ref(uid).add({
      'type': type,
      'met': met,
      'durationMin': durationMin,
      'weightKg': weightKg,
      'caloriesBurned': burned,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null));
  }

  Future<void> deleteActivity({
    required String uid,
    required String entryId,
  }) async {
    await _ref(uid).doc(entryId).delete();
  }
}