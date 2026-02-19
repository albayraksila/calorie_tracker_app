// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:calorisense/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';


import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart'; 
import '../models/user_profile.dart';
import 'login_screen.dart';
import 'profile_details_screen.dart'; 
import '../widgets/main_layout.dart'; // ✅ MainLayout import edildi

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();
  late Future<UserProfile?> _profileFuture;

final ScrollController _scrollController = ScrollController();

@override
void dispose() {
  _scrollController.dispose();
  super.dispose();
}

  // Uygulama Ayarları State'leri
  bool _notificationsEnabled = true;
    int _weighInIntervalDays = 7;
  bool _savingWeighInterval = false;


  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.getProfile();
  }

  // Sayfaya geri dönüldüğünde verilerin güncellenmesi için
  void _refresh() {
    setState(() {
      _profileFuture = _profileService.getProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Tema servisine erişim sağlandı
    final themeService = Provider.of<ThemeService>(context);

    // ✅ MainLayout entegrasyonu yapıldı, AppBar ve Arka Plan ona devredildi
    return MainLayout(
      title: "Ayarlar",
      child: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data;
                    if (profile != null && _weighInIntervalDays != profile.weighInIntervalDays) {
            // FutureBuilder her build olduğunda setState çağırmayalım diye
            // sadece farklıysa local state'i güncelliyoruz.
            _weighInIntervalDays = profile.weighInIntervalDays;
          }

          final userName = profile?.name ?? "Kullanıcı";

          return SingleChildScrollView(
             key: const PageStorageKey("settings_scroll"),
  controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👤 Profil Özet Bento
                _buildProfileSummary(userName, profile?.isProfileCompleted ?? false),
                const SizedBox(height: 15),

                _buildSectionTitle("Hesap Ayarları"),
                const SizedBox(height: 10),
                _buildSettingsBento([
                  _buildSettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: "Profil Bilgilerimi Düzenle",
                    subtitle: "Boy, kilo ve günlük hedefler",
                    onTap: () async {
                      // ✅ ProfileDetailsScreen'e git ve dönünce sayfayı yenile
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileDetailsScreen()),
                      );
                      _refresh();
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.mail_outline_rounded,
                    title: "E-posta Değiştir",
                    subtitle: FirebaseAuth.instance.currentUser?.email ?? "",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 15),

                _buildSectionTitle("Uygulama Tercihleri"),
                const SizedBox(height: 10),
                _buildSettingsBento([
                  _buildToggleTile(
                    icon: Icons.notifications_none_rounded,
                    title: "Bildirimler",
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                  // ✅ Karanlık Mod artık ThemeService'e bağlı
                  _buildToggleTile(
                    icon: Icons.dark_mode_outlined,
                    title: "Karanlık Mod",
                    value: themeService.isDarkMode,
                    onChanged: (v) {
                      themeService.toggleTheme(v);
                    },
                  ),
                   
                     _buildWeighIntervalTile(
        icon: Icons.monitor_weight_outlined,
        title: "Tartılma Aralığı",
        value: _weighInIntervalDays,
        saving: _savingWeighInterval,
        onChanged: (v) async {
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tartılma aralığı kaydedildi.")),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Kaydedilemedi: $e")),
              );
            }
          } finally {
            if (mounted) setState(() => _savingWeighInterval = false);
          }
        },
      ),
    ]),

    const SizedBox(height: 15),

                _buildSectionTitle("Destek & Bilgi"),
                const SizedBox(height: 10),
                _buildSettingsBento([
                  _buildSettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: "Yardım Merkezi",
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: "Hakkımızda",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // 🚪 Çıkış Butonu
                _buildLogoutButton(),

                 const SizedBox(height: 150),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- MODERN COMPONENTLER ---

  Widget _buildProfileSummary(String name, bool completed) {
    return Card( // ✅ AppTheme'deki CardTheme otomatik Bento yapar
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: const CircleAvatar(
          radius: 35,
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.person, color: Color(0xFF2E6F5E), size: 35),
        ),
        title: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        subtitle: Text(
          completed ? "✅ Profil Tamamlandı" : "🟡 Eksik Bilgiler Var",
          style: TextStyle(color: completed ? const Color(0xFF2E6F5E) : Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileDetailsScreen()),
          );
          _refresh();
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingsBento(List<Widget> children) {
    return Card( // ✅ AppTheme tasarımı burayı Bento kutusu yapar
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFBFBF9).withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF2E6F5E), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black38)) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black12, size: 20),
    );
  }

  Widget _buildToggleTile({required IconData icon, required String title, required bool value, required Function(bool) onChanged}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFBFBF9).withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF2E6F5E), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2E6F5E),
      ),
    );
  }
  Widget _buildWeighIntervalTile({
    required IconData icon,
    required String title,
    required int value,
    required bool saving,
    required Future<void> Function(int) onChanged,
  }) {
    const options = [7, 14, 30];

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBF9).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2E6F5E), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Text(
        "Hatırlatma / öneri hesaplamalarında kullanılır",
        style: const TextStyle(fontSize: 12, color: Colors.black38),
      ),
      trailing: saving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: options.contains(value) ? value : 7,
                items: options
                    .map((d) => DropdownMenuItem<int>(
                          value: d,
                          child: Text("$d gün"),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(v);
                },
              ),
            ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () async {
          await _authService.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.red.withOpacity(0.1))),
        ),
        child: const Text("Hesaptan Çıkış Yap", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}