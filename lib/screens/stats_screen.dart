import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'weekly_summary_screen.dart'; 
import '../widgets/main_layout.dart'; // ✅ MainLayout import edildi

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Scaffold ve manuel Container yerine MainLayout kullanıldı
    return MainLayout(
      title: "İstatistikler",
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Kilo Değişimi"),
            const SizedBox(height: 12),
            _buildChartBento(
              child: LineChart(_weightChartData()),
              height: 220,
            ),

            const SizedBox(height: 30),

            _buildSectionHeader("Besin Dağılımı"),
            const SizedBox(height: 12),
            _buildChartBento(
              child: Row(
                children: [
                  SizedBox(height: 160, width: 160, child: PieChart(_macroChartData())),
                  const SizedBox(width: 20),
                  const 
                     Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MacroIndicator(color: Color(0xFF2E6F5E), text: "Karb."),
                        SizedBox(height: 8),
                        _MacroIndicator(color: Color(0xFFFFB74D), text: "Protein"),
                        SizedBox(height: 8),
                        _MacroIndicator(color: Color(0xFF4FC3F7), text: "Yağ"),
                      ],
                    ),
                  
                ],
              ),
              height: 200,
            ),

            const SizedBox(height: 30),
            // ✅ Haftalık Özet Sayfasına Giden Buton
            _buildSummaryButton(context),
          ],
        ),
      ),
    );
  }

  // ✅ Butonun Tasarım Fonksiyonu (Aynen Korundu)
  Widget _buildSummaryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2E6F5E), // CaloriSense Ana Yeşili
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E6F5E).withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Haftalık Analiz",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "7 günlük detaylı raporu gör",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5));
  }

  // ✅ Bento Tasarımı (Card yapısına uygun hale getirilebilir veya Container olarak kalabilir)
  Widget _buildChartBento({required Widget child, required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: child,
    );
  }

  LineChartData _weightChartData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: const [FlSpot(0, 92), FlSpot(1, 91.5), FlSpot(2, 90.8), FlSpot(3, 90.2), FlSpot(4, 89.5)],
          isCurved: true,
          color: const Color(0xFF2E6F5E),
          barWidth: 5,
          belowBarData: BarAreaData(show: true, color: const Color(0xFF2E6F5E).withOpacity(0.1)),
        ),
      ],
    );
  }

  PieChartData _macroChartData() {
    return PieChartData(
      sectionsSpace: 4,
      centerSpaceRadius: 35,
      sections: [
        PieChartSectionData(color: const Color(0xFF2E6F5E), value: 45, radius: 45, showTitle: false),
        PieChartSectionData(color: const Color(0xFFFFB74D), value: 30, radius: 45, showTitle: false),
        PieChartSectionData(color: const Color(0xFF4FC3F7), value: 25, radius: 45, showTitle: false),
      ],
    );
  }
}

class _MacroIndicator extends StatelessWidget {
  final Color color;
  final String text;
  const _MacroIndicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
      ],
    );
  }
}