import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeightService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  WeightService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _docIdFor(DateTime day) {
    return "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
  }

  /// ✅ Bugünün kilosunu kaydeder (Stats ile tamamen uyumlu alan adları)
Future<void> addWeight({
  required double kg,
  DateTime? forDateTime,
}) async {
  final uid = _uid;
  if (uid == null) throw Exception("no-auth");

  // ✅ Eğer geçmiş gün seçildiyse onu kullan
  final dt = forDateTime ?? DateTime.now();
  final day = _startOfDay(dt);

  await _db
      .collection('users')
      .doc(uid)
      .collection('weight_entries')
      .add({
    // ✅ Aynı gün gruplama/filtre için
    'day': Timestamp.fromDate(day),

    // ✅ Grafikte tarih etiketi bunun üzerinden okunacak
    'date': Timestamp.fromDate(dt),

    'weight_kg': kg,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> updateWeight({
  required String entryId,
  required double kg,
}) async {
  final uid = _uid;
  if (uid == null) throw Exception("no-auth");

  await _db
      .collection('users')
      .doc(uid)
      .collection('weight_entries')
      .doc(entryId)
      .update({
    'weight_kg': kg,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> deleteWeight({
  required String entryId,
}) async {
  final uid = _uid;
  if (uid == null) throw Exception("no-auth");

  await _db
      .collection('users')
      .doc(uid)
      .collection('weight_entries')
      .doc(entryId)
      .delete();
}
  /// ✅ Stats ekranı için stream
  Stream<QuerySnapshot<Map<String, dynamic>>> streamEntries({int limit = 20}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(uid)
        .collection('weight_entries')
        // date eksik doc varsa orderBy patlar; o yüzden date_key de var.
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots();
  }
}
