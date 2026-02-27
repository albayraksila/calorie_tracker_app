// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import '../models/user_profile.dart';
import '../ui/ui_kit.dart';
import '../widgets/main_layout.dart';
import 'login_screen.dart';
import 'profile_details_screen.dart';
import 'profile_goals_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();
  final _scrollController = ScrollController();

  late Future<UserProfile?> _profileFuture;

  bool _notificationsEnabled = true;
  int _weighInIntervalDays = 7;
  bool _savingWeighInterval = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.getProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {
        _profileFuture = _profileService.getProfile();
      });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MainLayout(
      title: 'Ayarlar',
      child: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data;

          // weigh interval state sync (setState'siz okuma)
          if (profile != null &&
              _weighInIntervalDays != profile.weighInIntervalDays) {
            _weighInIntervalDays = profile.weighInIntervalDays;
          }

          final userName = profile?.name ?? 'Kullanıcı';
          final isComplete = profile?.isProfileCompleted ?? false;

          return SingleChildScrollView(
            key: const PageStorageKey('settings_scroll'),
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Profil Özet Kartı ───────────────────────
                AppProfileCard(
                  name: userName,
                  isComplete: isComplete,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ProfileDetailsScreen()),
                    );
                    _refresh();
                  },
                ),
                const SizedBox(height: 24),

                // ─── Hesap Ayarları ──────────────────────────
                AppSettingsGroup(
                  label: 'Hesap Ayarları',
                  tiles: [
                    AppSettingsTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Profil Bilgilerimi Düzenle',
                      subtitle: 'Boy, kilo ve kişisel bilgiler',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ProfileDetailsScreen()),
                        );
                        _refresh();
                      },
                    ),
                    AppSettingsTile(
                      icon: Icons.flag_outlined,
                      title: 'Program & Hedefler',
                      subtitle: 'Kalori hedefi, aktivite seviyesi',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ProfileGoalsScreen()),
                        );
                        _refresh();
                      },
                    ),

                     AppSettingsTile(
                      icon: Icons.monitor_weight_outlined,
                      title: 'Tartılma Aralığı',
                      subtitle: 'Hatırlatma aralığını belirle',
                      trailing: _savingWeighInterval
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: [7, 14, 30].contains(_weighInIntervalDays)
                                    ? _weighInIntervalDays
                                    : 7,
                                items: [7, 14, 30]
                                    .map((d) => DropdownMenuItem<int>(
                                          value: d,
                                          child: Text('$d gün',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                        ))
                                    .toList(),
                                onChanged: (v) async {
                                  if (v == null) return;
                                  setState(() {
                                    _weighInIntervalDays = v;
                                    _savingWeighInterval = true;
                                  });
                                  try {
                                    await _profileService.upsertProfileField(
                                      field: 'weigh_in_interval_days',
                                      value: v,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Tartılma aralığı kaydedildi.')));
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content:
                                                  Text('Kaydedilemedi: $e')));
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() =>
                                          _savingWeighInterval = false);
                                    }
                                  }
                                },
                              ),
                            ),
                    ),
                    
                    AppSettingsTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'E-posta',
                      subtitle: FirebaseAuth.instance.currentUser?.email ?? '',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Uygulama Tercihleri ─────────────────────
                AppSettingsGroup(
                  label: 'Uygulama Tercihleri',
                  tiles: [
                    AppSettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Bildirimler',
                      trailing: Switch.adaptive(
                        value: _notificationsEnabled,
                        onChanged: (v) =>
                            setState(() => _notificationsEnabled = v),
                        activeColor: AppThemeColors.primary,
                      ),
                    ),
                    AppSettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Karanlık Mod',
                      trailing: Switch.adaptive(
                        value: themeService.isDarkMode,
                        onChanged: themeService.toggleTheme,
                        activeColor: AppThemeColors.primary,
                      ),
                    ),
                   
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Destek & Bilgi ──────────────────────────
                AppSettingsGroup(
                  label: 'Destek & Bilgi',
                  tiles: [
                    AppSettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Yardım Merkezi',
                      onTap: () {},
                    ),
                    AppSettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Hakkımızda',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ─── Çıkış Butonu ────────────────────────────
                _buildLogoutButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await _authService.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        label: const Text(
          'Hesaptan Çıkış Yap',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.25)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}