import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEntry {
  final String id;
  final String type; // walking, running, cycling...
  final double met;
  final int durationMin;
  final double weightKg;
  final double caloriesBurned;
  final DateTime createdAt;
  final String? note;

  ActivityEntry({
    required this.id,
    required this.type,
    required this.met,
    required this.durationMin,
    required this.weightKg,
    required this.caloriesBurned,
    required this.createdAt,
    this.note,
  });

  factory ActivityEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    return ActivityEntry(
      id: doc.id,
      type: (d['type'] ?? '').toString(),
      met: (d['met'] is num) ? (d['met'] as num).toDouble() : 0,
      durationMin: (d['durationMin'] is num) ? (d['durationMin'] as num).toInt() : 0,
      weightKg: (d['weightKg'] is num) ? (d['weightKg'] as num).toDouble() : 0,
      caloriesBurned: (d['caloriesBurned'] is num) ? (d['caloriesBurned'] as num).toDouble() : 0,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      note: d['note']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'met': met,
      'durationMin': durationMin,
      'weightKg': weightKg,
      'caloriesBurned': caloriesBurned,
      'createdAt': Timestamp.fromDate(createdAt),
      'note': note,
    }..removeWhere((k, v) => v == null);
  }
}