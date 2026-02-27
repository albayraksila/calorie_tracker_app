class TodaySummary {
  final int calories;
  final int burnedCalories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;

  const TodaySummary({
    required this.calories,
     required this.burnedCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
  });

  const TodaySummary.zero()
      : calories = 0,
        burnedCalories = 0,
        proteinG = 0,
        carbsG = 0,
        fatG = 0,
        waterMl = 0;

  int get netCalories => calories - burnedCalories;

  TodaySummary copyWith({
    int? calories,
    int? burnedCalories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? waterMl,
  }) {
    return TodaySummary(
      calories: calories ?? this.calories,
      burnedCalories: burnedCalories ?? this.burnedCalories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      waterMl: waterMl ?? this.waterMl,
    );
  }
}
