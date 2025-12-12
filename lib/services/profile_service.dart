// lib/services/profile_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class ProfileService {
  final _fire = FirebaseFirestore.instance;

  // ✅ Tek kaynak: profil doküman referansı
  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _fire.collection('user_profiles').doc(uid);
  }

  Future<UserProfile?> getProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _profileRef(uid).get();

    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _profileRef(uid).set(
      profile.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<bool> isProfileCompleted() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    debugPrint("🔍 isProfileCompleted() çağrıldı, uid = $uid");

    final doc = await _profileRef(uid).get();

    if (!doc.exists) {
      debugPrint("❌ Profil dokümanı YOK → tamamlanmamış");
      return false;
    }

    final data = doc.data()!;
    final isCompleted = data['is_profile_completed'] == true;
    final targetDailyCalories = data['target_daily_calories'] ?? 0;

    debugPrint(
      "📄 Profil bulundu. is_completed=$isCompleted, target=$targetDailyCalories",
    );

    if (!isCompleted || targetDailyCalories == 0) {
      debugPrint("❌ Profil eksik → tamamlanmamış");
      return false;
    }

    debugPrint("✅ Profil TAM → tamamlanmış");
    return true;
  }

  // ============================================================
  // ✅ YENİ: Profil alan bazlı düzenleme için atomik update’ler
  // ============================================================

  /// ✅ Sadece tek alanı günceller (atomik).
  /// Doküman yoksa "not-found" hatası alırsın.
  Future<void> updateProfileField({
    required String field,
    required dynamic value,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _profileRef(uid).update({
      field: value,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Doküman yoksa bile alanı merge ederek yazar (upsert).
  /// Profil ekranı için güvenli seçenek.
  Future<void> upsertProfileField({
    required String field,
    required dynamic value,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _profileRef(uid).set({
      field: value,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Birden fazla alanı tek seferde (atomik) güncellemek istersen
  Future<void> upsertProfileFields(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _profileRef(uid).set({
      ...fields,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
