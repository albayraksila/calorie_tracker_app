import 'package:calorisense/screens/food_search_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card_old.dart';
import '../widgets/glass_app_bar.dart';
import 'package:percent_indicator/percent_indicator.dart'; // pubspec.yaml'a eklemelisin

class DailyTrackerScreen extends StatelessWidget {
  const DailyTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: "Günlük Takip"),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 20, 20, 20),
          child: Column(
            children: [
              // 📊 Özet Kartı
              _buildSummaryCard(theme),
              const SizedBox(height: 20),
              
              // 🍳 Öğün Listeleri
              _buildMealSection(context, "Kahvaltı", "0 kcal", Icons.wb_sunny_outlined),
              _buildMealSection(context, "Öğle Yemeği", "0 kcal", Icons.wb_cloudy_outlined),
              _buildMealSection(context, "Akşam Yemeği", "0 kcal", Icons.nightlight_round_outlined),
              _buildMealSection(context, "Atıştırmalık", "0 kcal", Icons.apple_outlined),
              
              const SizedBox(height: 20),
              
              // 💧 Su Takibi Hızlı Erişimi
              _buildWaterQuickTrack(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          CircularPercentIndicator(
            radius: 50.0,
            lineWidth: 8.0,
            percent: 0.4, // Örnek: %40 tamamlandı
            center: Text("1250\nKalan", textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
            progressColor: const Color(0xFF2E6F5E),
            backgroundColor: Colors.white.withOpacity(0.3),
            circularStrokeCap: CircularStrokeCap.round,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow("Hedef", "2100", Colors.white70),
              const SizedBox(height: 8),
              _buildStatRow("Alınan", "850", Colors.white),
              const SizedBox(height: 8),
              _buildStatRow("Yakılan", "320", Colors.white70),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        Text("$value kcal", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildMealSection(BuildContext context, String title, String calories, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2E6F5E)),
            const SizedBox(width: 15),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Text(calories, style: const TextStyle(color: Colors.black54)),
            IconButton(
  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2E6F5E)),
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(mealType: title),
      ),
    );
  },
),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterQuickTrack(ThemeData theme) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Su Takibi", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Hedef: 2.5 Litre", style: TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            children: List.generate(3, (index) => const Icon(Icons.local_drink, color: Colors.blueAccent, size: 28)),
          ),
        ],
      ),
    );
  }
}