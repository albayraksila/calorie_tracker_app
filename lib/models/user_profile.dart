class UserProfile {
  final String name;
  final int age;
  final int heightCm;
  final double weightKg;
  final int targetDailyCalories;
  final bool isProfileCompleted;

  UserProfile({
    required this.name,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.targetDailyCalories,
    required this.isProfileCompleted,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      heightCm: data['height_cm'] ?? 0,
      weightKg: (data['weight_kg'] ?? 0).toDouble(),
      targetDailyCalories: data['target_daily_calories'] ?? 0,
      isProfileCompleted: data['is_profile_completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'target_daily_calories': targetDailyCalories,
      'is_profile_completed': isProfileCompleted,
    };
  }
}
