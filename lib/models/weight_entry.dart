import 'package:cloud_firestore/cloud_firestore.dart';

class WeightEntry {
  final String id;
  final DateTime date;
  final double weightKg;

  WeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
  });

  factory WeightEntry.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    final date = parseDate(data['date']);
    final weightKg = (data['weight_kg'] ?? 0).toDouble();

    return WeightEntry(
      id: doc.id,
      date: date,
      weightKg: weightKg,
    );
  }
}