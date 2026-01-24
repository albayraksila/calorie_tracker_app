import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card_old.dart';
import '../widgets/glass_app_bar.dart';

class FoodSearchScreen extends StatefulWidget {
  final String mealType; // Hangi öğüne eklendiğini bilmek için (Kahvaltı, Öğle vb.)

  const FoodSearchScreen({super.key, required this.mealType});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: "${widget.mealType} Ekle",
      ),
      body: AppBackground(
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 20),
            
            // 🔍 Arama Çubuğu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassCard(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Yiyecek veya marka ara...",
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF2E6F5E)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 📋 Sonuç Listesi (Şimdilik Taslak Veriler)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  _buildFoodItem("Yumurta (Haşlanmış)", "155 kcal", "100g"),
                  _buildFoodItem("Beyaz Peynir", "310 kcal", "100g"),
                  _buildFoodItem("Zeytin (Siyah)", "115 kcal", "100g"),
                  _buildFoodItem("Tam Buğday Ekmeği", "247 kcal", "100g"),
                  _buildFoodItem("Yulaf Ezmesi", "389 kcal", "100g"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem(String name, String calories, String portion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("$portion - $calories"),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF2E6F5E)),
           onPressed: () {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$name - Kaç porsiyon?", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Miktar (gram/adet)"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Listeye Ekle"),
            )
          ],
        ),
      ),
    ),
  );
},
          ),
        ),
      ),
    );
  }
}