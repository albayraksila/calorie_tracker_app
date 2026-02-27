// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/activity_service.dart';
import '../services/profile_service.dart';
import '../core/utils/date_range.dart';
import '../ui/ui_kit.dart';

class ActivityTrackerScreen extends StatefulWidget {
  final DateTime? selectedDate;
  const ActivityTrackerScreen({super.key, this.selectedDate});

  @override
  State<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends State<ActivityTrackerScreen> {
  final _activityService = ActivityService();

  String _selectedType = ActivityService.metPresets.keys.first;
  final _durationCtrl = TextEditingController(text: '30');
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<double> _getWeightKg(String uid) async {
    final profile = await ProfileService().getProfile();
    if (profile == null) return 0;
    return profile.weightKg;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final day = widget.selectedDate == null
        ? DateTime.now()
        : DateTime(
            widget.selectedDate!.year,
            widget.selectedDate!.month,
            widget.selectedDate!.day,
          );
    final range = DateRange.forDay(day);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1113) : const Color(0xFFFBFBF9),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _activityService.watchDay(
          uid: uid,
          start: range.start,
          end: range.end,
        ),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          double totalBurned = 0;
          for (final d in docs) {
            final v = d.data()['caloriesBurned'];
            if (v is num) totalBurned += v.toDouble();
          }

          // Tüm sayfa tek CustomScrollView — form + liste birlikte kayar
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── SliverAppBar — MainLayout ile aynı ──────────
              SliverAppBar(
                expandedHeight: 80.0,
                collapsedHeight: 60.0,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: FlexibleSpaceBar(
                      titlePadding: const EdgeInsetsDirectional.only(
                          start: 20, bottom: 16),
                      centerTitle: false,
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aktivite',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A4D40),
                            ),
                          ),
                          Text(
                            'Yakılan kalori ve aktivite geçmişi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (isDark
                                      ? Colors.white
                                      : const Color(0xFF1A4D40))
                                  .withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // ─── Takvim Modu Özet Banner ─────────────────────
              if (widget.selectedDate != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _DaySummaryBanner(uid: uid, day: day, range: range),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, widget.selectedDate != null ? 12 : 14, 20, 0),
                  child: AppFormGroup(
                    fields: [
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        items: ActivityService.metPresets.keys
                            .map((k) =>
                                DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _selectedType = v ?? _selectedType),
                        decoration: const InputDecoration(
                          labelText: 'Aktivite Türü',
                          prefixIcon: Icon(Icons.directions_run),
                        ),
                      ),
                      TextField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Süre (dk)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                      ),
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Not (opsiyonel)',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      _saving
                          ? const Center(
                              child: SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _addActivity(uid, day),
                              icon: const Icon(Icons.add),
                              label: const Text('Aktivite Ekle'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              // ─── Boşluk + Özet pill ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: !snap.hasData
                      ? const SizedBox.shrink()
                      : docs.isEmpty
                          ? Text(
                              'Bugün henüz aktivite eklenmedi.',
                              style: TextStyle(
                                  color: Colors.black.withOpacity(0.45)),
                            )
                          : AppPill(
                              icon: Icons.local_fire_department_rounded,
                              text:
                                  'Bugün yakılan: ${totalBurned.toStringAsFixed(0)} kcal',
                            ),
                ),
              ),

              // ─── Liste ───────────────────────────────────────
              if (!snap.hasData)
                const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (docs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Opacity(
                      opacity: 0.45,
                      child: _buildActivityRow(
                        context,
                        type: 'Yürüyüş (orta tempo)',
                        duration: 30,
                        met: 3.5,
                        burned: 140,
                        onDelete: () async {},
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i.isOdd) return const SizedBox(height: 10);
                        final doc = docs[i ~/ 2];
                        final data = doc.data();
                        final type = (data['type'] ?? '').toString();
                        final duration = (data['durationMin'] is num)
                            ? (data['durationMin'] as num).toInt()
                            : 0;
                        final met = (data['met'] is num)
                            ? (data['met'] as num).toDouble()
                            : 0.0;
                        final burned = (data['caloriesBurned'] is num)
                            ? (data['caloriesBurned'] as num).toDouble()
                            : 0.0;

                        return _buildActivityRow(
                          context,
                          type: type,
                          duration: duration,
                          met: met,
                          burned: burned,
                          onDelete: () async {
                            await _activityService.deleteActivity(
                              uid: uid,
                              entryId: doc.id,
                            );
                          },
                        );
                      },
                      childCount: docs.length * 2 - 1,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addActivity(String uid, DateTime day) async {
    setState(() => _saving = true);
    try {
      final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
      final met = ActivityService.metPresets[_selectedType] ?? 0;
      final weightKg = await _getWeightKg(uid);

      if (weightKg <= 0 || duration <= 0 || met <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kilo / süre / MET geçersiz.')),
          );
        }
        return;
      }

      await _activityService.addActivity(
        uid: uid,
        type: _selectedType,
        met: met,
        durationMin: duration,
        weightKg: weightKg,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        when: widget.selectedDate == null
            ? null
            : DateTime(day.year, day.month, day.day, 12),
      );

      if (mounted) {
        _noteCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivite eklendi ✅')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildActivityRow(
    BuildContext context, {
    required String type,
    required int duration,
    required double met,
    required double burned,
    required Future<void> Function() onDelete,
  }) {
    const accent = Color(0xFF128D64);
    const titleColor = Color(0xFF0B3D2E);

    final lower = type.toLowerCase();
    IconData icon;
    if (lower.contains('yürüy')) {
      icon = Icons.directions_walk_rounded;
    } else if (lower.contains('koş')) {
      icon = Icons.directions_run_rounded;
    } else if (lower.contains('bisik')) {
      icon = Icons.directions_bike_rounded;
    } else {
      icon = Icons.fitness_center_rounded;
    }

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: const BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      type.isEmpty ? 'Aktivite' : type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _miniPill(
                            icon: Icons.timer_outlined,
                            text: '$duration dk'),
                        const SizedBox(width: 8),
                        _miniPill(
                            icon: Icons.speed_rounded,
                            text: 'MET ${met.toStringAsFixed(1)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${burned.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Silinsin mi?'),
                          content:
                              const Text('Bu aktivite kaydı silinecek.'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Vazgeç'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await onDelete();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black.withOpacity(0.50)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.60),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Takvim modu günlük özet banner ─────────────────────────────────────────
class _DaySummaryBanner extends StatelessWidget {
  final String uid;
  final DateTime day;
  final dynamic range; // DateRange

  const _DaySummaryBanner({
    required this.uid,
    required this.day,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    // food_entries → consumed
    final foodStream = db
        .collection('users')
        .doc(uid)
        .collection('food_entries')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();

    // activity_entries → burned (aynı watchDay stream'i ile tutarlı)
    final activityStream = db
        .collection('users')
        .doc(uid)
        .collection('activity_entries')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();

    // targetCalories → user_profiles
    final profileStream = db
        .collection('user_profiles')
        .doc(uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data();
        int targetCalories = 2100;
        if (profileData != null) {
          for (final k in [
            'target_daily_calories',
            'targetDailyCalories',
            'targetCalories',
            'target_calories',
          ]) {
            final v = profileData[k];
            if (v is num && v > 0) {
              targetCalories = v.toInt();
              break;
            }
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: foodStream,
          builder: (context, foodSnap) {
            int consumed = 0;
            for (final d in foodSnap.data?.docs ?? []) {
              final v = d.data()['calories'];
              if (v is num) consumed += v.toInt();
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: activityStream,
              builder: (context, actSnap) {
                double burned = 0;
                for (final d in actSnap.data?.docs ?? []) {
                  final v = d.data()['caloriesBurned'];
                  if (v is num) burned += v.toDouble();
                }

                final net = consumed - burned.round();
                final remaining = targetCalories - net;

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.80),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _statCell(
                        label: 'Alınan',
                        value: '$consumed',
                        unit: 'kcal',
                        color: const Color(0xFF2E6F5E),
                      ),
                      _divider(),
                      _statCell(
                        label: 'Yakılan',
                        value: '${burned.toStringAsFixed(0)}',
                        unit: 'kcal',
                        color: const Color(0xFF128D64),
                      ),
                      _divider(),
                      _statCell(
                        label: 'Net',
                        value: '$net',
                        unit: 'kcal',
                        color: const Color(0xFF0B3D2E),
                      ),
                      _divider(),
                      _statCell(
                        label: 'Kalan',
                        value: '${remaining > 0 ? remaining : 0}',
                        unit: 'kcal',
                        color: remaining >= 0
                            ? const Color(0xFF2E6F5E)
                            : Colors.red.shade400,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _statCell({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.black.withOpacity(0.07),
      );
}