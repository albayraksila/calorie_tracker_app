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
    final p = await getProfile();
    if (p == null) return false;
    return p.isProfileCompleted && p.targetDailyCalories > 0;
  }
}
