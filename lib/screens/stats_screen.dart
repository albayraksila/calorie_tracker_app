import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card_old.dart';
import '../widgets/glass_app_bar.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: "İstatistikler"),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 📈 Kilo Değişim Grafiği (Line Chart)
              _buildSectionTitle("Kilo Değişimi", theme),
              const SizedBox(height: 10),
              GlassCard(
                child: SizedBox(
                  height: 200,
                  child: LineChart(_weightChartData()),
                ),
              ),

              const SizedBox(height: 30),

              // 🥧 Makro Dağılımı (Pie Chart)
              _buildSectionTitle("Besin Dağılımı (Makrolar)", theme),
              const SizedBox(height: 10),
              GlassCard(
                child: Row(
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: PieChart(_macroChartData()),
                    ),
                    const SizedBox(width: 20),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChartIndicator(color: Colors.blue, text: "Karb."),
                        _ChartIndicator(color: Colors.red, text: "Protein"),
                        _ChartIndicator(color: Colors.orange, text: "Yağ"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: const Color(0xFF2E6F5E),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Çizgi Grafik Verisi (Simüle Edilmiş)
  LineChartData _weightChartData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 92),
            FlSpot(1, 91.5),
            FlSpot(2, 90.8),
            FlSpot(3, 90.2),
            FlSpot(4, 89.5),
          ],
          isCurved: true,
          color: const Color(0xFF2E6F5E),
          barWidth: 4,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF2E6F5E).withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  // Pasta Grafik Verisi (Simüle Edilmiş)
  PieChartData _macroChartData() {
    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: [
        PieChartSectionData(color: Colors.blue, value: 45, title: "%45", radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        PieChartSectionData(color: Colors.red, value: 30, title: "%30", radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        PieChartSectionData(color: Colors.orange, value: 25, title: "%25", radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// Grafik Yanındaki Açıklama İkonları
class _ChartIndicator extends StatelessWidget {
  final Color color;
  final String text;
  const _ChartIndicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}