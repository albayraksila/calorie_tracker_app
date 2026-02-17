import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodSearchScreen extends StatefulWidget {
  final String? mealType; // Null-safe hale getirildi

  const FoodSearchScreen({super.key, this.mealType});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Null check hatasını önlemek için mealType güvenli hale getirildi
    final String title = widget.mealType ?? "Yiyecek";

    return MainLayout(
      title: "$title Ekle",
      actions: const [], // Null hatasını önlemek için boş liste zorunlu
      child: SingleChildScrollView(
        // Beyaz ekranı önlemek için scroll eklendi
        physics:
            const NeverScrollableScrollPhysics(), // MainLayout scroll'u ile çakışmaz
        child: IntrinsicHeight(
          // İçeriğin boyutunu hesaplamasını sağlar (Beyaz ekran çözümü)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // 🔍 Arama Çubuğu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: "Yiyecek veya marka ara...",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon:
                          Icon(Icons.search, color: Color(0xFF2E6F5E)),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  "Sık Tercih Edilenler",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54),
                ),
              ),

              const SizedBox(height: 10),

              // 📋 Sonuç Listesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildFoodItem(
                        "Yumurta (Haşlanmış)", 155, 13.0, 1.1, 11.0, 10.0, 1.0, "100g"),
                    _buildFoodItem(
                        "Beyaz Peynir", 310, 20.0, 1.0, 25.0, 10.0, 1.0, "100g"),
                    _buildFoodItem(
                        "Zeytin (Siyah)", 115, 1.3, 10.0, 9.5, 10.0, 1.0,  "100g"),
                    _buildFoodItem("Tam Buğday Ekmeği", 247, 8.0, 48.0, 2.5, 10.0, 1.0, 
                        "100g"),
                    _buildFoodItem(
                        "Yulaf Ezmesi", 389, 16.5, 67.5, 4.5, 10.0, 1.0, "100g"),
                    _buildFoodItem(
                        "Süzme Yoğurt", 60, 3.5, 3.5, 4.5, 10.0, 1.0,  "100g"),
                  ],
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItem(
    String name,
    int kcalPer100g,
    double proteinPer100g,
    double carbsPer100g,
    double fatPer100g,
    double fiberPer100g,
    double sugarPer100g,
    String portion,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          subtitle: Text("$portion • $kcalPer100g kcal",
              style: const TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          trailing: GestureDetector(
            onTap: () => _showAddFoodBottomSheet(
              context,
              name,
              kcalPer100g,
              proteinPer100g,
              carbsPer100g,
              fatPer100g,
              fiberPer100g,
              sugarPer100g,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2E6F5E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFoodBottomSheet(
    BuildContext context,
    String foodName,
    int kcalPer100g,
    double proteinPer100g,
    double carbsPer100g,
    double fatPer100g,
    double fiberPer100g,
double sugarPer100g,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final amountController = TextEditingController(text: "100");
            final unitGramController =
                TextEditingController(text: "100"); // adet/porsiyon gramı

            String unit = "g"; // g | adet | porsiyon

            double _toDouble(String s) =>
                double.tryParse(s.replaceAll(',', '.')) ?? 0.0;

            double calcTotalGrams() {
              final amount = _toDouble(amountController.text.trim());
              if (unit == "g") return amount;
              final gramPerUnit = _toDouble(unitGramController.text.trim());
              return amount * gramPerUnit;
            }
String _todayId() {
  final now = DateTime.now();
  return "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
}

            Future<void> addToDiary() async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                      content: Text("Oturum bulunamadı. Tekrar giriş yap.")),
                );
                return;
              }

              try {
                final totalGrams = calcTotalGrams();
                final factor = totalGrams / 100.0;

                final calories = (kcalPer100g * factor).round();
                final proteinG = (proteinPer100g * factor).round();
                final carbsG = (carbsPer100g * factor).round();
                final fatG = (fatPer100g * factor).round();
                final fiberG = (fiberPer100g * factor).round();
final sugarG = (sugarPer100g * factor).round();


                final amountValue = _toDouble(amountController.text.trim());
                final unitGrams = unit == "g"
                    ? null
                    : _toDouble(unitGramController.text.trim());

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('food_entries')
                    .add({
                  'name': foodName,
                  'mealType': widget.mealType ?? 'Yiyecek',

                  // kullanıcı girişi
                  'amount_value': amountValue,
                  'amount_unit': unit, // g | adet | porsiyon
                  'unit_grams': unitGrams,
                  'total_grams': totalGrams,

                  // hesaplanan değerler
                  'calories': calories,
                  'protein_g': proteinG,
                  'carbs_g': carbsG,
                  'fat_g': fatG,
                  'fiber_g': fiberG,
'sugar_g': sugarG,


                  'createdAt': Timestamp.now(),
                });
await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .collection('daily_summaries')
    .doc(_todayId())
    .set({
  'date': _todayId(),
  'calories': calories,
  'protein_g': proteinG,
  'carbs_g': carbsG,
  'fat_g': fatG,
  'fiber_g': fiberG,
  'sugar_g': sugarG,
  'water_ml': 0,
  'completed': false,
}, SetOptions(merge: true));

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text("Günlüğe eklendi ✅")),
                  );
                }
              } catch (e) {
                debugPrint("❌ addToDiary error: $e");
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text("Kayıt eklenemedi: $e")),
                  );
                }
              }
            }
Future<void> updateDailySummary(String uid, Map<String, dynamic> entry) async {
  final now = DateTime.now();
  final dateId = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";

  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_summaries')
      .doc(dateId);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);

    int addInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    final newCalories = addInt(entry['calories']);
    final newProtein = addInt(entry['protein_g']);
    final newCarbs = addInt(entry['carbs_g']);
    final newFat = addInt(entry['fat_g']);
    final newFiber = addInt(entry['fiber_g']);
    final newSugar = addInt(entry['sugar_g']);

    if (!snap.exists) {
      tx.set(ref, {
        "date": dateId,
        "calories": newCalories,
        "protein_g": newProtein,
        "carbs_g": newCarbs,
        "fat_g": newFat,
        "fiber_g": newFiber,
        "sugar_g": newSugar,
        "water_ml": 0,
        "completed": false,
      });
    } else {
      tx.update(ref, {
        "calories": FieldValue.increment(newCalories),
        "protein_g": FieldValue.increment(newProtein),
        "carbs_g": FieldValue.increment(newCarbs),
        "fat_g": FieldValue.increment(newFat),
        "fiber_g": FieldValue.increment(newFiber),
        "sugar_g": FieldValue.increment(newSugar),
      });
    }
  });
}

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFBFBF9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    Text(foodName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const Text("Miktarı Belirleyin",
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const Text("Birim:",
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: unit,
                          items: const [
                            DropdownMenuItem(
                                value: "g", child: Text("Gram (g)")),
                            DropdownMenuItem(
                                value: "adet", child: Text("Adet")),
                            DropdownMenuItem(
                                value: "porsiyon", child: Text("Porsiyon")),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setModalState(() => unit = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (unit != "g") ...[
                      TextField(
                        controller: unitGramController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: unit == "adet"
                              ? "1 adet kaç gram?"
                              : "1 porsiyon kaç gram?",
                          labelStyle: const TextStyle(
                              color: Color(0xFF2E6F5E),
                              fontWeight: FontWeight.bold),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.straighten_outlined,
                              color: Color(0xFF2E6F5E)),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: unit == "g"
                            ? "Miktar (gram)"
                            : (unit == "adet"
                                ? "Miktar (adet)"
                                : "Miktar (porsiyon)"),
                        labelStyle: const TextStyle(
                          color: Color(0xFF2E6F5E),
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.scale_outlined,
                            color: Color(0xFF2E6F5E)),
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E6F5E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 5,
                        ),
                        onPressed: addToDiary,
                        child: const Text("Günlüğe Ekle",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
