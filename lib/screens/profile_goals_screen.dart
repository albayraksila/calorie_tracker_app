// lib/screens/profile_goals_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/main_layout.dart';
import '../services/profile_service.dart';
import '../services/nutrition_calculator.dart';
import '../models/user_profile.dart';
import '../ui/ui_kit.dart';

class ProfileGoalsScreen extends StatefulWidget {
  const ProfileGoalsScreen({super.key});

  @override
  State<ProfileGoalsScreen> createState() => _ProfileGoalsScreenState();
}

class _ProfileGoalsScreenState extends State<ProfileGoalsScreen> {
  final _profileService = ProfileService();

  bool _loading = true;
  bool _saving = false;

  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.light;
  GoalProgram _goal = GoalProgram.loseFat;

  int? _targetCalories;
  double? _proteinTarget;

  UserProfile? _profile;

  // ─── label helpers ─────────────────────────────
  static const _activityLabels = {
    ActivityLevel.sedentary: 'Hareketsiz',
    ActivityLevel.light: 'Hafif aktif',
    ActivityLevel.moderate: 'Orta aktif',
    ActivityLevel.active: 'Aktif',
    ActivityLevel.veryActive: 'Çok aktif',
  };

  static const _goalLabels = {
    GoalProgram.loseFat: 'Yağ Yakma',
    GoalProgram.maintain: 'Kilo Koru',
    GoalProgram.gainWeight: 'Kilo Al',
    GoalProgram.gainMuscle: 'Kas Kazan',
    GoalProgram.maintainMuscle: 'Kas Koru',
  };

  static const _goalDescriptions = {
    GoalProgram.loseFat: '500 kcal kalori açığı · yüksek protein',
    GoalProgram.maintain: 'TDEE = hedef kalori',
    GoalProgram.gainWeight: '300 kcal fazlası · dengeli makro',
    GoalProgram.gainMuscle: '200 kcal fazlası · maksimum protein',
    GoalProgram.maintainMuscle: 'TDEE · kas koruma protokolü',
  };

  // ─── parse helpers ──────────────────────────────
  Gender _parseGender(String? s) => Gender.values
      .firstWhere((e) => e.name == s, orElse: () => Gender.male);

  ActivityLevel _parseActivity(String? s) => ActivityLevel.values
      .firstWhere((e) => e.name == s, orElse: () => ActivityLevel.light);

  GoalProgram _parseGoal(String? s) => GoalProgram.values
      .firstWhere((e) => e.name == s, orElse: () => GoalProgram.loseFat);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    _profile = await _profileService.getProfile();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _gender = _parseGender(data['gender']?.toString());
        _activityLevel = _parseActivity(data['activity_level']?.toString());
        _goal = _parseGoal(data['goal_program']?.toString());

        final tdc = data['target_daily_calories'];
        if (tdc is num) _targetCalories = tdc.toInt();
        final pt = data['protein_target_g'];
        if (pt is num) _proteinTarget = pt.toDouble();
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _calculate() {
    final p = _profile;
    if (p == null) {
      _snack('Önce profil bilgilerini doldurmalısın.');
      return;
    }
    final bd = p.birthDate;
    if (bd == null) {
      _snack('Doğum tarihi boş. Profilini güncelle.');
      return;
    }

    final age = UserProfile.calculateAge(bd);
    final tdee = NutritionCalculator.tdee(
      gender: _gender,
      weightKg: p.weightKg,
      heightCm: p.heightCm,
      age: age,
      activityLevel: _activityLevel,
    );

    setState(() {
      _targetCalories = NutritionCalculator.targetCalories(
        tdeeValue: tdee,
        goal: _goal,
      );
      _proteinTarget = NutritionCalculator.proteinTargetG(
        weightKg: p.weightKg,
        goal: _goal,
      );
    });

    _snack(
        'Hedef: $_targetCalories kcal · Protein: ${_proteinTarget!.toStringAsFixed(0)} g');
  }

  Future<void> _save() async {
    if (_targetCalories == null || _proteinTarget == null) {
      _calculate();
      if (_targetCalories == null || _proteinTarget == null) return;
    }

    setState(() => _saving = true);
    try {
      await _profileService.upsertProfileFields({
        'gender': _gender.name,
        'activity_level': _activityLevel.name,
        'goal_program': _goal.name,
        'target_daily_calories': _targetCalories,
        'protein_target_g': _proteinTarget,
      });
      if (mounted) _snack('Hedefler kaydedildi ✅');
    } catch (e) {
      if (mounted) _snack('Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Program & Hedefler',
      subtitle: 'Programını seç, kalorini hesapla',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Form ────────────────────────────────────
                  AppFormGroup(
                    label: 'Kişisel Bilgiler',
                    fields: [
                      DropdownButtonFormField<Gender>(
                        value: _gender,
                        items: const [
                          DropdownMenuItem(
                              value: Gender.male, child: Text('Erkek')),
                          DropdownMenuItem(
                              value: Gender.female, child: Text('Kadın')),
                        ],
                        onChanged: (v) =>
                            setState(() => _gender = v ?? _gender),
                        decoration: const InputDecoration(
                          labelText: 'Cinsiyet',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  AppFormGroup(
                    label: 'Aktivite & Program',
                    fields: [
                      DropdownButtonFormField<ActivityLevel>(
                        value: _activityLevel,
                        items: ActivityLevel.values
                            .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(_activityLabels[l] ?? l.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _activityLevel = v ?? _activityLevel),
                        decoration: const InputDecoration(
                          labelText: 'Aktivite Seviyesi',
                          prefixIcon: Icon(Icons.insights_outlined),
                        ),
                      ),
                      DropdownButtonFormField<GoalProgram>(
                        value: _goal,
                        items: GoalProgram.values
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(_goalLabels[g] ?? g.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _goal = v ?? _goal),
                        decoration: const InputDecoration(
                          labelText: 'Program',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Program açıklaması
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      _goalDescriptions[_goal] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.40),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Hesapla Butonu ───────────────────────────
                  OutlinedButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Hesapla'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppThemeColors.primary,
                      side: BorderSide(
                          color: AppThemeColors.primary.withOpacity(0.40)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── Sonuç Kartı ──────────────────────────────
                  if (_targetCalories != null && _proteinTarget != null) ...[
                    AppCard(
                      radius: AppRadius.r22,
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Expanded(
                            child: _resultStat(
                              label: 'Günlük Kalori',
                              value: '$_targetCalories kcal',
                              icon: Icons.local_fire_department_rounded,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.black.withOpacity(0.07),
                          ),
                          Expanded(
                            child: _resultStat(
                              label: 'Protein Hedefi',
                              value:
                                  '${_proteinTarget!.toStringAsFixed(0)} g/gün',
                              icon: Icons.fitness_center_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Kaydet Butonu ────────────────────────────
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Kaydet'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppThemeColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),

                  const SizedBox(height: 16),
                  if (_profile != null)
                    Text(
                      'Kilo / boy / doğum tarihi değiştiyse önce Profil Bilgileri ekranını güncelle.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.40),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _resultStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppThemeColors.accent, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: AppThemeColors.accent,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.50),
          ),
        ),
      ],
    );
  }
}