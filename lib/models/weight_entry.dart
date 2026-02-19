import 'package:cloud_firestore/cloud_firestore.dart';

class WeightEntry {
  final DateTime date; // ölçüm zamanı
  final double weightKg;

  WeightEntry({required this.date, required this.weightKg});

  factory WeightEntry.fromDoc(Map<String, dynamic> data) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    final date = parseDate(data['date']);
    final weightKg = (data['weight_kg'] ?? 0).toDouble();

    return WeightEntry(
      date: date,
      weightKg: weightKg,
    );
  }
}
