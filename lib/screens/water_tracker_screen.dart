import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card_old.dart';
import '../widgets/glass_app_bar.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({super.key});

  @override
  State<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen> {
  int _currentGlasses = 0;
  final int _targetGlasses = 10; // Örn: 2.5 Litre (250ml x 10)

  void _addGlass() {
    if (_currentGlasses < _targetGlasses) {
      setState(() => _currentGlasses++);
    }
  }

  void _resetWater() {
    setState(() => _currentGlasses = 0);
  }

  @override
  Widget build(BuildContext context) {
    double progress = _currentGlasses / _targetGlasses;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: "Su Takibi"),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 30, 20, 20),
          child: Column(
            children: [
              // 💧 Su Tankı Görseli
              GlassCard(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          height: 200,
                          width: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 200 * progress,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "${(_currentGlasses * 0.25).toStringAsFixed(1)} L / 2.5 L",
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text("Hedefinin %${(progress * 100).toInt()}'ini tamamladın!", style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 🥛 Bardak Seçim Alanı
              _buildSectionTitle("Bugün içtiğin bardaklar", theme),
              const SizedBox(height: 15),
              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: List.generate(_targetGlasses, (index) {
                  bool isDrunk = index < _currentGlasses;
                  return GestureDetector(
                    onTap: () {
                      if (index == _currentGlasses) _addGlass();
                    },
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.local_drink,
                          size: 40,
                          color: isDrunk ? Colors.blueAccent : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 30),
              
              TextButton.icon(
                onPressed: _resetWater,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                label: const Text("Sıfırla", style: TextStyle(color: Colors.white70)),
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
      style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF2E6F5E), fontWeight: FontWeight.bold),
    );
  }
}