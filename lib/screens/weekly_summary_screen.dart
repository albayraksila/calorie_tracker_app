import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';

class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Haftalık Özet",
      // ✅ ListView yerine Column kullanarak boyut çatışmasını bitiriyoruz
      child: Column(
        mainAxisSize: MainAxisSize.min, // Kendi içeriği kadar yer kaplasın
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🍱 Bento Kart 1: Toplam Kalori
                _buildSummaryCard(
                  title: "Haftalık Kalori",
                  value: "12,450 kcal",
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                
                // 🍱 Bento Kart 2: Su Hedefi
                _buildSummaryCard(
                  title: "Ortalama Su",
                  value: "2.4 Litre",
                  icon: Icons.water_drop_rounded,
                  color: Colors.blue,
                ),
                
                const SizedBox(height: 30),
                const Text(
                  "Analiz",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                
                // 🍱 Bento Kart 3: Bilgi Notu
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "Bu hafta protein hedefini %15 aştın! Harika bir gelişim gösteriyorsun. ✨",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                
                // Sayfanın en altında içerik kesilmesin diye ek boşluk
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title, 
    required String value, 
    required IconData icon, 
    required Color color
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
    );
  }
}