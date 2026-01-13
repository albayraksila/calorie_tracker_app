// lib/screens/profile_details_screen.dart
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../models/user_profile.dart';
import 'profile_setup_screen.dart';

// 🎨 Tasarım widget'ları
import '../widgets/app_background.dart';
import '../widgets/glass_card_old.dart';
import '../widgets/pastel_button.dart';
import '../widgets/glass_app_bar.dart';

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
  static const String kAge = 'age';
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

  // ✅ required alanlar tamam mı? (model üzerinden güvenli kontrol)
  bool _isCompleteFromModel(UserProfile p) {
    bool okString(String? v) => v != null && v.trim().isNotEmpty;
    bool okNum(num? v) => v != null && v > 0;

    return okString(p.name) &&
        okNum(p.age) &&
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
          title: Text(title, style: theme.textTheme.titleMedium),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: title,
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
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;

                      setLocal(() => saving = true);

                      final raw = controller.text.trim();
                      final value = parseValue(raw);

                      try {
                        // ✅ atomik update (sadece bu field)
                        await _service.upsertProfileField(
                          field: fieldKey,
                          value: value,
                        );

                        // ✅ flag'i HER ZAMAN model üzerinden hesaplayıp yaz
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      _refresh();
    }
  }

  Widget _lineWithEdit({
    required BuildContext context,
    required String text,
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
  color: Colors.white.withOpacity(0.32), // ✅ 0.10 çok azdı
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: Colors.white.withOpacity(0.30)),
  boxShadow: [
    BoxShadow(
      blurRadius: 14,
      offset: const Offset(0, 6),
      color: Colors.black.withOpacity(0.08), // ✅ kartlar zeminden ayrılır
    ),
  ],
),

      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF2E6F5E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF2E6F5E)),
            onPressed: onEdit,
            tooltip: "Düzenle",
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: "Profil Bilgilerim",
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, kToolbarHeight + 32, 24, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FutureBuilder<UserProfile?>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Bir hata oluştu",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${snapshot.error}",
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  final profile = snapshot.data;

                  if (profile == null) {
                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Profil bulunamadı",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Profil bilgilerin bulunamadı. Lütfen profilini doldur.",
                            style: theme.textTheme.bodyMedium,
                          ),
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
                    );
                  }

                  final computedCompleted = _isCompleteFromModel(profile);

                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Profil detayların ✨",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color:const Color(0xFF2E6F5E),

                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "İstediğin zaman güncelleyebilirsin 🙂",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.70),

                          ),
                        ),
                        const SizedBox(height: 14),

                        _lineWithEdit(
                          context: context,
                          text: "👤 Adın: ${profile.name}",
                          onEdit: () => _editField(
                            context: context,
                            title: "Ad Soyad",
                            fieldKey: kName,
                            initialValue: (profile.name).toString(),
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

                        _lineWithEdit(
                          context: context,
                          text: "🎂 Yaşın: ${profile.age}",
                          onEdit: () => _editField(
                            context: context,
                            title: "Yaş",
                            fieldKey: kAge,
                            initialValue: (profile.age).toString(),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final s = (v ?? "").trim();
                              if (s.isEmpty) return "Bu alan boş bırakılamaz";
                              final n = int.tryParse(s);
                              if (n == null) return "Sayı gir";
                              if (n < 10 || n > 100) return "10-100 arası olmalı";
                              return null;
                            },
                            parseValue: (raw) => int.parse(raw),
                          ),
                        ),

                        _lineWithEdit(
                          context: context,
                          text: "📏 Boyun: ${profile.heightCm} cm",
                          onEdit: () => _editField(
                            context: context,
                            title: "Boy (cm)",
                            fieldKey: kHeightCm,
                            initialValue: (profile.heightCm).toString(),
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

                        _lineWithEdit(
                          context: context,
                          text: "⚖️ Kilon: ${profile.weightKg} kg",
                          onEdit: () => _editField(
                            context: context,
                            title: "Kilo (kg)",
                            fieldKey: kWeightKg,
                            initialValue: (profile.weightKg).toString(),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              final s = (v ?? "").trim();
                              if (s.isEmpty) return "Bu alan boş bırakılamaz";
                              final n = double.tryParse(s.replaceAll(",", "."));
                              if (n == null) return "Sayı gir";
                              if (n < 30 || n > 300) return "30-300 kg arası olmalı";
                              return null;
                            },
                            parseValue: (raw) =>
                                double.parse(raw.replaceAll(",", ".")),
                          ),
                        ),

                        _lineWithEdit(
                          context: context,
                          text: "🔥 Günlük hedefin: ${profile.targetDailyCalories} kcal",
                          onEdit: () => _editField(
                            context: context,
                            title: "Hedef Günlük Kalori",
                            fieldKey: kTargetDailyCalories,
                            initialValue: (profile.targetDailyCalories).toString(),
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

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
  color: Colors.white.withOpacity(0.32), // ✅ 0.10 çok azdı
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: Colors.white.withOpacity(0.30)),
  boxShadow: [
    BoxShadow(
      blurRadius: 14,
      offset: const Offset(0, 6),
      color: Colors.black.withOpacity(0.08), // ✅ kartlar zeminden ayrılır
    ),
  ],
),

                          child: Text(
                            computedCompleted
                                ? "✅ Profil tamamlandı"
                                : "🟡 Profil eksik",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF2E6F5E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        PastelButton(
                          text: "Düzenle ✍️",
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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
