class TodaySummary {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;

  const TodaySummary({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
  });

  const TodaySummary.zero()
      : calories = 0,
        proteinG = 0,
        carbsG = 0,
        fatG = 0,
        waterMl = 0;

  TodaySummary copyWith({
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? waterMl,
  }) {
    return TodaySummary(
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      waterMl: waterMl ?? this.waterMl,
    );
  }
}
