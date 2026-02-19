import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String name;

  /// ✅ Yaş saklanmaz. Bunun yerine doğum tarihi tutulur.
  final DateTime? birthDate;

  final int heightCm;
  final double weightKg;
  final int targetDailyCalories;
  final int weighInIntervalDays;

  /// ✅ Firestore’a yazılan tamamlanma bilgisi (ama hesabı tek merkezden yapılacak)
  final bool isProfileCompleted;

  UserProfile({
    required this.name,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    required this.targetDailyCalories,
    required this.isProfileCompleted,
      required this.weighInIntervalDays,
  });

  /// ✅ Yaş her zaman doğum tarihinden dinamik hesaplanır
  int? get age {
    if (birthDate == null) return null;
    return calculateAge(birthDate!);
  }

  /// ✅ Doğru yaş hesaplama (doğum günü geldi mi kontrol eder)
  static int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;

    final hasHadBirthdayThisYear =
        (today.month > birthDate.month) ||
            (today.month == birthDate.month && today.day >= birthDate.day);

    if (!hasHadBirthdayThisYear) {
      age--;
    }
    return age;
  }

  // ==========================================================
  // ✅ TEK MERKEZ: PROFİL TAMAMLANMA KURALI
  // ==========================================================
  static bool calculateIsCompleted({
    required String name,
    required DateTime? birthDate,
    required int heightCm,
    required double weightKg,
    required int targetDailyCalories,
  }) {
    return name.trim().isNotEmpty &&
        birthDate != null &&
        heightCm > 0 &&
        weightKg > 0 &&
        targetDailyCalories > 0;
  }

  /// ✅ Bu instance için “tamam mı?” kontrolü (UI ve yönlendirmede kullan)
  bool get isCompletedComputed => calculateIsCompleted(
        name: name,
        birthDate: birthDate,
        heightCm: heightCm,
        weightKg: weightKg,
        targetDailyCalories: targetDailyCalories,
      );

  /// ✅ Kullanışlı: Firestore’a kaydetmeden önce completed’i otomatik düzelt
  UserProfile withAutoCompleted() {
    final computed = isCompletedComputed;
    if (computed == isProfileCompleted) return this;
    return copyWith(isProfileCompleted: computed);
  }

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    final rawBirthDate = data['birth_date'];

    DateTime? parsedBirthDate;
    if (rawBirthDate is Timestamp) {
      parsedBirthDate = rawBirthDate.toDate();
    } else if (rawBirthDate is DateTime) {
      parsedBirthDate = rawBirthDate;
    } else {
      parsedBirthDate = null;
    }

    final name = data['name'] ?? '';
    final heightCm = data['height_cm'] ?? 0;
    final weightKg = (data['weight_kg'] ?? 0).toDouble();
    final targetDailyCalories = data['target_daily_calories'] ?? 0;
    final weighInIntervalDays = (data['weigh_in_interval_days'] ?? 7) as int;

    // ✅ Firestore’dan gelen değer bozuk/eksik olabilir; biz yine de kurala göre hesaplayabiliriz.
    // Tercih: DB’deki değeri "truth" kabul etmek yerine kuralı baz almak daha güvenli.
    final computed = calculateIsCompleted(
      name: name,
      birthDate: parsedBirthDate,
      heightCm: heightCm,
      weightKg: weightKg,
      targetDailyCalories: targetDailyCalories,
    );

    return UserProfile(
      name: name,
      birthDate: parsedBirthDate,
      heightCm: heightCm,
      weightKg: weightKg,
      targetDailyCalories: targetDailyCalories,
       weighInIntervalDays: weighInIntervalDays,

      // ✅ computed kullanıyoruz (önerilen)
      isProfileCompleted: computed,
      // Eğer illa Firestore’daki değeri kullanmak istersen:
      // isProfileCompleted: data['is_profile_completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    // ✅ Firestore’a yazmadan hemen önce completed’i kurala göre düzelt
    final computedCompleted = isCompletedComputed;

    return {
      'name': name,

      /// Firestore’a yazarken Timestamp olarak kaydet
      'birth_date': birthDate == null ? null : Timestamp.fromDate(birthDate!),

      'height_cm': heightCm,
      'weight_kg': weightKg,
      'target_daily_calories': targetDailyCalories,
            'weigh_in_interval_days': weighInIntervalDays,


      /// ✅ Artık sabit değil, kurala göre yazılıyor
      'is_profile_completed': computedCompleted,
    }..removeWhere((k, v) => v == null);
  }

  UserProfile copyWith({
    String? name,
    DateTime? birthDate,
    int? heightCm,
    double? weightKg,
    int? targetDailyCalories,
        int? weighInIntervalDays,

    bool? isProfileCompleted,
    bool autoRecomputeCompleted = false, // ✅ opsiyon
  }) {
    final next = UserProfile(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
            weighInIntervalDays: weighInIntervalDays ?? this.weighInIntervalDays,

      targetDailyCalories: targetDailyCalories ?? this.targetDailyCalories,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
    );

    // ✅ İstersen copyWith sonrası otomatik hesapla
    return autoRecomputeCompleted ? next.withAutoCompleted() : next;
  }
}
