enum Gender { male, female }
enum ActivityLevel { sedentary, light, moderate, active, veryActive }
enum GoalProgram { loseFat, maintain, gainWeight, gainMuscle, maintainMuscle }

class NutritionCalculator {
  static double activityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  // Mifflin-St Jeor
  static double bmr({
    required Gender gender,
    required double weightKg,
    required int heightCm,
    required int age,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return gender == Gender.male ? (base + 5) : (base - 161);
  }

  static double tdee({
    required Gender gender,
    required double weightKg,
    required int heightCm,
    required int age,
    required ActivityLevel activityLevel,
  }) {
    return bmr(
          gender: gender,
          weightKg: weightKg,
          heightCm: heightCm,
          age: age,
        ) *
        activityMultiplier(activityLevel);
  }

  static int targetCalories({
    required double tdeeValue,
    required GoalProgram goal,
  }) {
    double target = tdeeValue;
    switch (goal) {
      case GoalProgram.loseFat:
        target = tdeeValue - 500; // yağ kaybı
        break;
      case GoalProgram.maintain:
        target = tdeeValue;
        break;
      case GoalProgram.gainWeight:
        target = tdeeValue + 300;
        break;
      case GoalProgram.gainMuscle:
        target = tdeeValue + 250;
        break;
      case GoalProgram.maintainMuscle:
        target = tdeeValue;
        break;
    }
    if (target < 1200) target = 1200;
    return target.round();
  }

  static double proteinTargetG({
    required double weightKg,
    required GoalProgram goal,
  }) {
    // Kullanıcının istediği kurallar:
    // kas kazanımı: 1.8x, koruma: 1.2x
    final mult = switch (goal) {
      GoalProgram.gainMuscle => 1.8,
      GoalProgram.maintainMuscle => 1.2,
      _ => 1.6, // diğer hedefler için makul default
    };
    return weightKg * mult;
  }
}