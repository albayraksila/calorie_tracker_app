// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// TEMEL RENKLER & RADIUS (değişmez, tek kaynak)
// ─────────────────────────────────────────────
class AppThemeColors {
  static const Color primary = Color(0xFF2E6F5E);
  static const Color accent = Color(0xFF128D64);
  static const Color title = Color(0xFF0B3D2E);
  static const Color backgroundLight = Color(0xFFFBFBF9);

  static Color textSecondary() => Colors.black.withOpacity(0.55);
}

class AppRadius {
  static const BorderRadius r32 = BorderRadius.all(Radius.circular(32));
  static const BorderRadius r24 = BorderRadius.all(Radius.circular(24));
  static const BorderRadius r22 = BorderRadius.all(Radius.circular(22));
  static const BorderRadius r18 = BorderRadius.all(Radius.circular(18));
  static const BorderRadius r14 = BorderRadius.all(Radius.circular(14));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

// ─────────────────────────────────────────────
// KART — tüm beyaz cam kartlar için tek widget
// ─────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius radius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = AppRadius.r24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: Colors.white.withOpacity(0.80),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class AppMiniCard extends StatelessWidget {
  final Widget child;
  const AppMiniCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: AppRadius.r18,
        border: Border.all(color: Colors.white),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// PİLL — küçük bilgi etiketi
// ─────────────────────────────────────────────
class AppPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const AppPill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: AppRadius.r14,
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black.withOpacity(0.60)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black.withOpacity(0.70),
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  final String text;
  const AppBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeColors.primary.withOpacity(0.14),
        borderRadius: AppRadius.pill,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
            color: AppThemeColors.primary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BÖLÜM BAŞLIĞI
// ─────────────────────────────────────────────
class AppSectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const AppSectionTitle({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppThemeColors.title,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionText!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppThemeColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// LİSTE SATIRI — Meal / Activity gibi satırlar
// ─────────────────────────────────────────────
class AppListRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget> pills;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const AppListRow({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.badge,
    this.pills = const [],
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.r18,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppThemeColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: AppThemeColors.title,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppThemeColors.textSecondary(),
                    ),
                  ),
                ],
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: pills),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (badge != null) badge!,
              if (onDelete != null) ...[
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ✅ YENİ: SETTINGS TILE — Settings ekranı için
//    AppCard içinde tutarlı tile yapısı
// ─────────────────────────────────────────────
class AppSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const AppSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppThemeColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: AppThemeColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppThemeColors.title,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.40),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black.withOpacity(0.20),
                        size: 20,
                      ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.black.withOpacity(0.05),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ✅ YENİ: SETTINGS GRUBU — Başlık + tile'ları saran AppCard
// ─────────────────────────────────────────────
class AppSettingsGroup extends StatelessWidget {
  final String? label;
  final List<AppSettingsTile> tiles;

  const AppSettingsGroup({
    super.key,
    this.label,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              label!.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.black.withOpacity(0.35),
              ),
            ),
          ),
        ],
        AppCard(
          radius: AppRadius.r22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++)
                AppSettingsTile(
                  key: tiles[i].key,
                  icon: tiles[i].icon,
                  title: tiles[i].title,
                  subtitle: tiles[i].subtitle,
                  trailing: tiles[i].trailing,
                  onTap: tiles[i].onTap,
                  showDivider: i < tiles.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ✅ YENİ: FORM GRUBU — Dropdown/TextField'ları saran AppCard
// ─────────────────────────────────────────────
class AppFormGroup extends StatelessWidget {
  final String? label;
  final List<Widget> fields;

  const AppFormGroup({
    super.key,
    this.label,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              label!.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.black.withOpacity(0.35),
              ),
            ),
          ),
        ],
        AppCard(
          radius: AppRadius.r22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i < fields.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ✅ YENİ: SONUÇ KARTI — hesaplama sonucu göstermek için
// ─────────────────────────────────────────────
class AppResultCard extends StatelessWidget {
  final List<AppResultItem> items;

  const AppResultCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: AppRadius.r18,
        color: AppThemeColors.primary.withOpacity(0.08),
        border: Border.all(
          color: AppThemeColors.primary.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: Column(
                  children: [
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppThemeColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class AppResultItem {
  final String value;
  final String label;
  const AppResultItem({required this.value, required this.label});
}

// ─────────────────────────────────────────────
// ✅ YENİ: PROFİL SUMMARY KARTI — Settings'de üstte göstermek için
// ─────────────────────────────────────────────
class AppProfileCard extends StatelessWidget {
  final String name;
  final bool isComplete;
  final VoidCallback? onTap;

  const AppProfileCard({
    super.key,
    required this.name,
    required this.isComplete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.r24,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppThemeColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppThemeColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppThemeColors.title,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isComplete
                            ? const Color(0xFF2E6F5E)
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isComplete ? 'Profil tamamlandı' : 'Eksik bilgiler var',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isComplete
                            ? const Color(0xFF2E6F5E)
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.black.withOpacity(0.20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ✅ YENİ: MENÜ KARTI (HOME) — Yatay scroll yerine dikey liste
//    DailyTracker ile aynı dil, daha temiz
// ─────────────────────────────────────────────
class AppMealSummaryCard extends StatelessWidget {
  final String mealType;
  final IconData icon;
  final double totalKcal;
  final List<String> itemNames; // max 4 gösterilir
  final VoidCallback? onTap;

  const AppMealSummaryCard({
    super.key,
    required this.mealType,
    required this.icon,
    required this.totalKcal,
    required this.itemNames,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF128D64);
    const titleColor = Color(0xFF0B3D2E);

    final visible = itemNames.take(3).toList();
    final remaining = itemNames.length - visible.length;

    return AppCard(
      radius: AppRadius.r22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  visible.isEmpty
                      ? 'Henüz eklenmedi'
                      : [
                          ...visible,
                          if (remaining > 0) '+$remaining daha',
                        ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              '${totalKcal.round()} kcal',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}