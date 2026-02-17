// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../models/user_profile.dart';
import 'profile_setup_screen.dart';

// 🎨 Tasarım widget'ları
import '../widgets/pastel_button.dart';
import '../widgets/main_layout.dart'; // ✅ MainLayout eklendi

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _service = ProfileService();
  late Future<UserProfile?> _future;

  // ✅ Firestore alan isimleri
  static const String kName = 'name';
  static const String kBirthDate = 'birth_date'; 
  static const String kHeightCm = 'height_cm';
  static const String kWeightKg = 'weight_kg';
  static const String kTargetDailyCalories = 'target_daily_calories';
  static const String kIsProfileCompleted = 'is_profile_completed';

  @override
  void initState() {
    super.initState();
    _future = _service.getProfile();
  }

  void _refresh() {
    setState(() {
      _future = _service.getProfile();
    });
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day.$month.$year';
  }

  bool _isCompleteFromModel(UserProfile p) {
    bool okString(String? v) => v != null && v.trim().isNotEmpty;
    bool okNum(num? v) => v != null && v > 0;

    return okString(p.name) &&
        (p.birthDate != null) && 
        okNum(p.heightCm) &&
        okNum(p.weightKg) &&
        okNum(p.targetDailyCalories);
  }

  Future<void> _editField({
    required BuildContext context,
    required String title,
    required String fieldKey,
    required String initialValue,
    required TextInputType keyboardType,
    required String? Function(String? v) validator,
    required dynamic Function(String raw) parseValue,
  }) async {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title, style: theme.textTheme.titleMedium),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: title,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              validator: validator,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6F5E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;

                      setLocal(() => saving = true);

                      final raw = controller.text.trim();
                      final value = parseValue(raw);

                      try {
                        await _service.upsertProfileField(
                          field: fieldKey,
                          value: value,
                        );

                        final latest = await _service.getProfile();
                        if (latest != null) {
                          final completed = _isCompleteFromModel(latest);

                          await _service.upsertProfileField(
                            field: kIsProfileCompleted,
                            value: completed,
                          );
                        }

                        if (mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setLocal(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Kaydedilemedi: $e")),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Kaydet", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      _refresh();
    }
  }

  Future<void> _editBirthDate({
    required BuildContext context,
    required DateTime? initialDate,
  }) async {
    final now = DateTime.now();
    final init = initialDate ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      initialDate: init,
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2E6F5E),
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    try {
      await _service.upsertProfileField(
        field: kBirthDate,
        value: picked,
      );

      final latest = await _service.getProfile();
      if (latest != null) {
        final completed = _isCompleteFromModel(latest);
        await _service.upsertProfileField(
          field: kIsProfileCompleted,
          value: completed,
        );
      }

      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kaydedilemedi: $e")),
      );
    }
  }

  Widget _buildProfileBentoItem({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
         
             Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.black, fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.black26, size: 28),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ MainLayout entegrasyonu yapıldı
    return MainLayout(
      title: "Profil Bilgilerim",
      child: FutureBuilder<UserProfile?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2E6F5E)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text("Bir hata oluştu", style: theme.textTheme.titleMedium),
                    Text("${snapshot.error}", textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final profile = snapshot.data;

          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Profil bulunamadı", style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    PastelButton(
                      text: "Profilimi doldur",
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileSetupScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          final computedCompleted = _isCompleteFromModel(profile);
          final bd = profile.birthDate;
          final ageText = (profile.age == null) ? "-" : "${profile.age}";

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                _buildProfileHeader(profile.name, profile.isProfileCompleted),
                const SizedBox(height: 32),

                _buildProfileBentoItem(
                  context: context,
                  label: "Ad Soyad",
                  value: profile.name,
                  icon: Icons.person_rounded,
                  iconColor: Colors.blueAccent,
                  onEdit: () => _editField(
                    context: context,
                    title: "Ad Soyad",
                    fieldKey: kName,
                    initialValue: profile.name,
                    keyboardType: TextInputType.text,
                    validator: (v) {
                      final s = (v ?? "").trim();
                      if (s.isEmpty) return "Bu alan boş bırakılamaz";
                      if (s.length < 2) return "En az 2 karakter gir";
                      return null;
                    },
                    parseValue: (raw) => raw,
                  ),
                ),

                _buildProfileBentoItem(
                  context: context,
                  label: "Doğum Tarihi & Yaş",
                  value: bd == null ? "-" : "${_formatDate(bd)} ($ageText Yaş)",
                  icon: Icons.cake_rounded,
                  iconColor: Colors.purpleAccent,
                  onEdit: () => _editBirthDate(
                    context: context,
                    initialDate: bd,
                  ),
                ),

                _buildProfileBentoItem(
                  context: context,
                  label: "Boy Uzunluğu",
                  value: "${profile.heightCm} cm",
                  icon: Icons.height_rounded,
                  iconColor: Colors.orangeAccent,
                  onEdit: () => _editField(
                    context: context,
                    title: "Boy (cm)",
                    fieldKey: kHeightCm,
                    initialValue: profile.heightCm.toString(),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final s = (v ?? "").trim();
                      if (s.isEmpty) return "Bu alan boş bırakılamaz";
                      final n = int.tryParse(s);
                      if (n == null) return "Sayı gir";
                      if (n < 120 || n > 230) return "120-230 cm arası olmalı";
                      return null;
                    },
                    parseValue: (raw) => int.parse(raw),
                  ),
                ),

                _buildProfileBentoItem(
                  context: context,
                  label: "Vücut Ağırlığı",
                  value: "${profile.weightKg} kg",
                  icon: Icons.monitor_weight_rounded,
                  iconColor: Colors.tealAccent.shade700,
                  onEdit: () => _editField(
                    context: context,
                    title: "Kilo (kg)",
                    fieldKey: kWeightKg,
                    initialValue: profile.weightKg.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final s = (v ?? "").trim();
                      if (s.isEmpty) return "Bu alan boş bırakılamaz";
                      final n = double.tryParse(s.replaceAll(",", "."));
                      if (n == null) return "Sayı gir";
                      if (n < 30 || n > 300) return "30-300 kg arası olmalı";
                      return null;
                    },
                    parseValue: (raw) => double.parse(raw.replaceAll(",", ".")),
                  ),
                ),

                _buildProfileBentoItem(
                  context: context,
                  label: "Günlük Kalori Hedefi",
                  value: "${profile.targetDailyCalories} kcal",
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.redAccent,
                  onEdit: () => _editField(
                    context: context,
                    title: "Hedef Günlük Kalori",
                    fieldKey: kTargetDailyCalories,
                    initialValue: profile.targetDailyCalories.toString(),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final s = (v ?? "").trim();
                      if (s.isEmpty) return "Bu alan boş bırakılamaz";
                      final n = int.tryParse(s);
                      if (n == null) return "Sayı gir";
                      if (n < 800 || n > 6000) return "800-6000 arası olmalı";
                      return null;
                    },
                    parseValue: (raw) => int.parse(raw),
                  ),
                ),

                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: computedCompleted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    computedCompleted ? "✅ Profil tamamlandı" : "🟡 Profil eksik",
                    style: TextStyle(
                      color: computedCompleted ? const Color(0xFF2E6F5E) : Colors.orange.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name, bool isCompleted) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFE0E0E0),
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(
          isCompleted ? "Aktif Üye ✨" : "Profilini Tamamla",
          style: const TextStyle(color: Color(0xFF2E6F5E), fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}