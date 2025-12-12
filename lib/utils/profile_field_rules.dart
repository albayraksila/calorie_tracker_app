class ProfileFieldRules {
  // ✅ Firestore key’leri (snake_case)
  static const String fullName = 'full_name';
  static const String age = 'age';
  static const String heightCm = 'height_cm';
  static const String weightKg = 'weight_kg';
  static const String targetCalories = 'target_daily_calories';
  static const String activityLevel = 'activity_level';

  // ✅ profil tamamlık bayrağı
  static const String isProfileCompleted = 'is_profile_completed';

  /// ✅ Silinemez / boş bırakılamaz alanlar
  static const Set<String> requiredFields = {
    targetCalories,
    age,
    heightCm,
    weightKg,
  };

  static String? validate(String field, String? input) {
    final v = (input ?? '').trim();

    if (requiredFields.contains(field) && v.isEmpty) {
      return 'Bu alan boş bırakılamaz';
    }

    if (v.isEmpty) return null;

    int? asInt() => int.tryParse(v);
    double? asDouble() => double.tryParse(v.replaceAll(',', '.'));

    switch (field) {
      case fullName:
        if (v.length < 2) return 'En az 2 karakter gir';
        return null;

      case age:
        final n = asInt();
        if (n == null) return 'Sayı gir';
        if (n < 10 || n > 100) return '10-100 arası olmalı';
        return null;

      case heightCm:
        final n = asInt();
        if (n == null) return 'Sayı gir';
        if (n < 120 || n > 230) return '120-230 cm arası olmalı';
        return null;

      case weightKg:
        final n = asDouble();
        if (n == null) return 'Sayı gir';
        if (n < 30 || n > 300) return '30-300 kg arası olmalı';
        return null;

      case targetCalories:
        final n = asInt();
        if (n == null) return 'Sayı gir';
        if (n < 800 || n > 6000) return '800-6000 arası olmalı';
        return null;

      default:
        return null;
    }
  }
}
