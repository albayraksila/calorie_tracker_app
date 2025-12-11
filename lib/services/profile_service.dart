// lib/services/profile_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class ProfileService {
  final _fire = FirebaseFirestore.instance;

  Future<UserProfile?> getProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _fire.collection('user_profiles').doc(uid).get();

    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _fire.collection('user_profiles').doc(uid).set(
          profile.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<bool> isProfileCompleted() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    debugPrint("🔍 isProfileCompleted() çağrıldı, uid = $uid");

    final doc = await _fire.collection('user_profiles').doc(uid).get();

    if (!doc.exists) {
      debugPrint("❌ Profil dokümanı YOK → tamamlanmamış");
      return false;
    }

    final data = doc.data()!;
    final isCompleted = data['is_profile_completed'] == true;
    final targetDailyCalories = data['target_daily_calories'] ?? 0;

    debugPrint(
        "📄 Profil bulundu. is_completed=$isCompleted, target=$targetDailyCalories");

    if (!isCompleted || targetDailyCalories == 0) {
      debugPrint("❌ Profil eksik → tamamlanmamış");
      return false;
    }

    debugPrint("✅ Profil TAM → tamamlanmış");
    return true;
  }
}
